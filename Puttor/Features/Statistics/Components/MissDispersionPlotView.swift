//
//  MissDispersionPlotView.swift
//  Puttor
//
//  Ported from the prototype's MissDispersionPlot.tsx.
//

import SwiftUI
import UIKit

enum DispersionFilter: String, CaseIterable, Identifiable {
    case all, rl, lr, up, down
    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .all: return "dispersion.all"
        case .rl: return "dispersion.rl"
        case .lr: return "dispersion.lr"
        case .up: return "dispersion.up"
        case .down: return "dispersion.down"
        }
    }
}

/// A second axis for the dispersion plot: the dots keep their position and
/// take their colour from something about the putt — how much it broke, how
/// long it was, or whether it ran up or down the hill.
enum DispersionShading: String, CaseIterable, Identifiable {
    case none, breakMagnitude, puttLength, slope
    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .none: return "dispersion.shading.none"
        case .breakMagnitude: return "dispersion.shading.break"
        case .puttLength: return "dispersion.shading.length"
        case .slope: return "dispersion.shading.slope"
        }
    }

    /// The number each putt contributes. Nil where nothing is shaded.
    func value(for putt: Putt) -> Double? {
        switch self {
        case .none: return nil
        case .breakMagnitude: return abs(putt.sideSlopePct)
        case .puttLength: return putt.distanceM
        case .slope: return putt.hillSlopePct
        }
    }

    /// Slope runs from downhill through flat to uphill, so its scale is
    /// symmetric around zero; the other two start at zero.
    var isSigned: Bool { self == .slope }
}

private struct DispersionDot {
    var x: CGFloat
    var y: CGFloat
    var count: Int
    /// One entry per putt stacked on this spot, so the dot can be drawn as a
    /// pie of what those putts had in common. Empty when nothing is shaded.
    var values: [Double] = []

    var shadingAverage: Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}

/// The unit direction for an angle from the dial, in the plot's own frame:
/// short points down, left points left.
private func angleVector(_ angle: Double) -> (x: CGFloat, y: CGFloat) {
    let radians = MissAngle.screenDegrees(angle) * .pi / 180
    return (CGFloat(cos(radians)), CGFloat(sin(radians)))
}

private func missVector(_ result: PuttResult) -> (x: CGFloat, y: CGFloat) {
    switch result {
    case .left: return (-1, 0)
    case .right: return (1, 0)
    case .short: return (0, 1)
    case .long: return (0, -1)
    case .shortLeft: return (-0.72, 0.72)
    case .shortRight: return (0.72, 0.72)
    case .longLeft: return (-0.72, -0.72)
    case .longRight: return (0.72, -0.72)
    case .holeHigh: return (0, -0.55)
    default: return (0, 0)
    }
}

private func includeByFilter(_ p: Putt, _ filter: DispersionFilter) -> Bool {
    switch filter {
    case .all: return true
    case .rl: return p.sideSlopePct < 0
    case .lr: return p.sideSlopePct > 0
    case .up: return p.hillSlopePct > 0
    case .down: return p.hillSlopePct < 0
    }
}

struct MissDispersionPlotView: View {
    let putts: [Putt]
    let filter: DispersionFilter
    var shading: DispersionShading = .none
    var useFeet: Bool = false
    /// Only putts struck from inside this band are plotted. The whole hole is
    /// still read, so a putt keeps the leave its follow-up recorded even when
    /// that follow-up is outside the band.
    var distanceRange: ClosedRange<Double>?

    /// As wide as the section allows, up to this — a phone's full width, but
    /// not a square taller than a landscape screen.
    var maxSide: CGFloat = 460

    /// The width the plot has to work with, measured rather than guessed.
    @State private var measuredWidth: CGFloat = 0

    private var hasVerticalArrow: Bool { filter == .up || filter == .down }

    /// The plot's edge: everything left once the slope arrow has its strip.
    private var side: CGFloat {
        let width = measuredWidth > 0 ? measuredWidth : 268
        return max(160, min(maxSide, width - (hasVerticalArrow ? 32 : 0)))
    }

    /// The band along each edge the LONG / SHORT / LEFT / RIGHT labels sit in.
    private static let edgeLabelBand: CGFloat = 16
    /// How far past the outer ring a dot may stray, as a share of that ring.
    private static let overshoot: CGFloat = 1.1
    /// The nearest a dot sits to the hole, as a share of the outer ring.
    private static let innermostShare: CGFloat = 0.12

    /// Everything the plot draws, worked out in one pass.
    ///
    /// This used to be two computed properties that each walked every putt of
    /// every round — and the colour of a single dot asked for the scale, which
    /// rebuilt the lot. Drawing a few dozen dots meant thousands of full
    /// rebuilds per frame, which is what made the tab crawl.
    private struct DispersionData {
        var dots: [DispersionDot] = []
        /// Largest shading value in view, which the colour ramp stretches over.
        /// Zero means the putts carry nothing to shade by — slope left
        /// unrecorded, for instance.
        var shadingScale: Double = 0
        /// Drawn stretched sideways: the sides reach only the lateral limit.
        /// False as soon as one miss lies further out to the side than that.
        var stretched = false
    }

    /// Ring distances, marked on the scale line. The outer one — 3 m, or 10 ft
    /// in imperial — is what the plot is normalised to; a longer leave than
    /// that is drawn outside the rings rather than pinned to them.
    private var ringDistances: [Double] {
        useFeet
            ? [3, 6, 10].map { UnitConverter.feetToMetres($0) }
            : [1, 2, 3]
    }

    private var outerDistance: Double { ringDistances.last ?? 3 }

    /// How far to the side the stretched plot reaches. A putt seldom misses
    /// far off line but often runs metres long or short, so the sides get half
    /// the reach of the top and bottom — 1.5 m against 3 m, 5 ft against 10.
    private var lateralLimitM: Double { useFeet ? UnitConverter.feetToMetres(5) : 1.5 }

    /// Where a leave of this length sits, as a share of the outer ring. Never
    /// on top of the hole, and never further out than the plot has room for.
    private func fraction(forLeave leave: Double) -> CGFloat {
        min(Self.overshoot, max(Self.innermostShare, CGFloat(leave / outerDistance)))
    }

    private func computeData() -> DispersionData {
        var byHole: [String: [Putt]] = [:]
        for p in putts {
            let key = "\(p.round?.id.uuidString ?? "-")-\(p.holeNumber)"
            byHole[key, default: []].append(p)
        }

        // Every miss first, so the scale is settled before anything is placed.
        var misses: [(vec: (x: CGFloat, y: CGFloat), leave: Double, shading: Double?)] = []
        for holePutts in byHole.values {
            let sorted = holePutts.sorted { $0.puttNumber < $1.puttNumber }
            for (i, p) in sorted.enumerated() {
                guard p.result != .holed, includeByFilter(p, filter) else { continue }
                if let distanceRange, !distanceRange.contains(p.distanceM) { continue }
                let next = i + 1 < sorted.count ? sorted[i + 1] : nil
                let leave = next.map { max(0.3, $0.distanceM) } ?? max(0.3, p.distanceM * 0.35)
                // An angle recorded on the dial places the dot where the ball
                // actually went; the eight sectors are only the fallback.
                let vec = p.missAngleDeg.map(angleVector) ?? missVector(p.result)
                misses.append((vec, leave, shading.value(for: p)))
            }
        }

        // Stretched sideways while every miss stays inside the lateral limit;
        // a single one beyond it puts the whole plot back on circles, so no
        // dot is ever pinned somewhere it did not go.
        let stretched = misses.allSatisfy { $0.leave * Double(abs($0.vec.x)) <= lateralLimitM + 0.0001 }

        var result: [DispersionDot] = []
        var index: [String: Int] = [:]
        for miss in misses {
            let radial = fraction(forLeave: miss.leave)
            // Sideways, stretched, a dot is measured against the lateral limit
            // instead of the outer ring — and never pinned, since it fits.
            let across = stretched
                ? CGFloat(max(Double(Self.innermostShare) * outerDistance, miss.leave) / lateralLimitM)
                : radial
            let x = (miss.vec.x * across * 1000).rounded() / 1000
            let y = (miss.vec.y * radial * 1000).rounded() / 1000
            let key = "\(x)|\(y)"
            if let idx = index[key] {
                result[idx].count += 1
                if let value = miss.shading { result[idx].values.append(value) }
            } else {
                index[key] = result.count
                result.append(DispersionDot(
                    x: x, y: y, count: 1,
                    values: miss.shading.map { [$0] } ?? []
                ))
            }
        }
        return DispersionData(
            dots: result,
            shadingScale: result.flatMap(\.values).map { abs($0) }.max() ?? 0,
            stretched: stretched
        )
    }

    var body: some View {
        let data = computeData()

        return VStack(spacing: 0) {
            // The width is read off an empty strip, which takes exactly the
            // width it is offered — and everything below may shrink under
            // `side` but never grow past what it is offered. A fixed-width plot
            // left over from landscape made the tab's scroll view as wide as
            // itself, which then offered that width back to this strip, so the
            // tab stayed wider than the screen for good.
            Color.clear
                .frame(height: 0)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { measuredWidth = $0 }

            content(data)
        }
        .frame(maxWidth: .infinity)
    }

    private func content(_ data: DispersionData) -> some View {
        VStack(spacing: 6) {
            if filter == .rl || filter == .lr {
                slopeArrowHorizontal
            }

            HStack(spacing: 8) {
                if data.dots.isEmpty {
                    Text(L("dispersion.noData"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: side)
                } else {
                    plot(data)
                        // Turned to run along their edges, so they take a
                        // label's height from the plot instead of its width.
                        // Pinned to the edges rather than to coordinates, so
                        // they sit right at whatever size the plot is given.
                        .overlay(alignment: .leading) {
                            edgeLabel("dispersion.left")
                                .rotationEffect(.degrees(-90))
                                .frame(width: Self.edgeLabelBand)
                        }
                        .overlay(alignment: .trailing) {
                            edgeLabel("dispersion.right")
                                .rotationEffect(.degrees(90))
                                .frame(width: Self.edgeLabelBand)
                        }
                        .overlay(alignment: .top) {
                            edgeLabel("dispersion.long")
                                .frame(height: Self.edgeLabelBand)
                        }
                        .overlay(alignment: .bottom) {
                            edgeLabel("dispersion.short")
                                .frame(height: Self.edgeLabelBand)
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: side)
                }

                if filter == .up || filter == .down {
                    slopeArrowVertical
                }
            }

            if data.stretched, !data.dots.isEmpty {
                Text(String(
                    format: L("dispersion.stretched"),
                    UnitConverter.formatDistance(lateralLimitM, useFeet: useFeet),
                    UnitConverter.formatDistance(outerDistance, useFeet: useFeet)
                ))
                .font(.system(size: 10))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: side)
            }

            if shading != .none, !data.dots.isEmpty {
                if data.shadingScale > 0.0001 {
                    shadingLegend(scale: data.shadingScale)
                } else {
                    Text(L("dispersion.shading.noValues"))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func edgeLabel(_ key: String) -> some View {
        Text(L(key))
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Theme.textMuted)
            .fixedSize()
    }

    // MARK: - Shading

    /// Dots sit back from full strength so a crowded board stays readable, and
    /// they earn their weight: the further the putt, the stronger the break or
    /// the steeper the slope, the more solid the marker.
    private let minDotOpacity: Double = 0.28
    private let maxDotOpacity: Double = 0.85

    private func dotOpacity(_ strength: Double) -> Double {
        minDotOpacity + (maxDotOpacity - minDotOpacity) * min(1, max(0, strength))
    }

    /// How much of a putt this is, on a 0…1 scale: the class of its break, its
    /// length against the longest in view, or how far its slope is from level.
    /// Drives both the opacity and the drawing order.
    private func normalisedStrength(_ value: Double, scale: Double) -> Double {
        switch shading {
        case .none:
            return 0
        case .breakMagnitude:
            return Double(breakClass(value)) / 4
        case .puttLength:
            return scale > 0.0001 ? min(1, max(0, value / scale)) : 0
        case .slope:
            return scale > 0.0001 ? min(1, abs(value) / scale) : 0
        }
    }

    /// Break strength is stepped, not blended: the grid the putt was entered
    /// on has five classes, so the plot uses the same five and the same
    /// colours.
    private func breakClass(_ percent: Double) -> Int {
        let value = abs(percent)
        if value < 0.5 { return 0 }
        if value < 1.5 { return 1 }
        if value < 2.5 { return 2 }
        if value < 3.25 { return 3 }
        return 4
    }

    private static let breakClassLabels = ["0", "1", "2", "3", ">3"]

    private var rampEnds: (low: Color, high: Color) {
        switch shading {
        case .none: return (Theme.error, Theme.error)
        case .breakMagnitude: return (Theme.slopeClassColors.first ?? Theme.error, Theme.slopeClassColors.last ?? Theme.error)
        case .puttLength: return (Theme.dispersionLengthLow, Theme.dispersionLengthHigh)
        // Deliberately the other way round from the slope grid: on the miss
        // board the uphill putts are the red ones.
        case .slope: return (Theme.uphill, Theme.downhill)
        }
    }

    /// Colour for one dot's averaged value. Slope reads outwards from a flat
    /// middle, the other two from nothing to the strongest in view.
    private func shadingColor(_ value: Double, scale: Double) -> Color {
        let strength = normalisedStrength(value, scale: scale)
        if shading == .breakMagnitude {
            return Theme.slopeClassColors[breakClass(value)].opacity(dotOpacity(strength))
        }
        guard scale > 0.0001 else { return Theme.error.opacity(maxDotOpacity) }
        let ends = rampEnds
        if shading.isSigned {
            let t = max(-1, min(1, value / scale))
            let base = t >= 0
                ? mix(Theme.textMuted, ends.high, t)
                : mix(Theme.textMuted, ends.low, -t)
            // A level putt has nothing to say, a steep one has all of it.
            return base.opacity(dotOpacity(strength))
        }
        let t = max(0, min(1, value / scale))
        if shading == .puttLength {
            // One colour, carried from barely there to nearly solid — a longer
            // reach than any hue shift over this small a dot.
            return ends.high.opacity(dotOpacity(strength))
        }
        return mix(ends.low, ends.high, t).opacity(dotOpacity(strength))
    }

    @ViewBuilder
    private func shadingLegend(scale: Double) -> some View {
        Group {
            if shading == .breakMagnitude {
                breakLegend
            } else {
                rampLegend(scale: scale)
            }
        }
    }

    /// One swatch per class, labelled with the percent it stands for.
    private var breakLegend: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(Array(Theme.slopeClassColors.enumerated()), id: \.offset) { index, color in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.opacity(dotOpacity(Double(index) / 4)))
                            .frame(height: 10)
                        Text(Self.breakClassLabels[index])
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
            Text(L("dispersion.shading.breakLegend"))
                .font(.system(size: 9))
                .foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: side)
    }

    private func rampLegend(scale: Double) -> some View {
        VStack(spacing: 4) {
            let ends = rampEnds
            LinearGradient(
                colors: shading.isSigned
                    ? [ends.low.opacity(maxDotOpacity), Theme.textMuted.opacity(minDotOpacity), ends.high.opacity(maxDotOpacity)]
                    : [ends.high.opacity(minDotOpacity), ends.high.opacity(maxDotOpacity)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 10)
            .clipShape(Capsule())

            HStack {
                Text(legendLabel(shading.isSigned ? -scale : 0))
                Spacer()
                if shading.isSigned {
                    Text(L("dispersion.shading.flat"))
                    Spacer()
                }
                Text(legendLabel(scale))
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: side)
    }

    private func legendLabel(_ value: Double) -> String {
        switch shading {
        case .none:
            return ""
        case .puttLength:
            return UnitConverter.formatDistance(abs(value), useFeet: useFeet)
        case .breakMagnitude:
            return "\(String(format: "%.1f", abs(value)))%"
        case .slope:
            let suffix = value >= 0 ? L("dispersion.shading.uphill") : L("dispersion.shading.downhill")
            return "\(String(format: "%.1f", abs(value)))% \(suffix)"
        }
    }

    private func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ca = UIColor(a).cgColor.components ?? [0, 0, 0, 1]
        let cb = UIColor(b).cgColor.components ?? [0, 0, 0, 1]
        func channel(_ i: Int) -> Double {
            let x = Double(ca.count > i ? ca[i] : ca[0])
            let y = Double(cb.count > i ? cb[i] : cb[0])
            return x + (y - x) * t
        }
        return Color(red: channel(0), green: channel(1), blue: channel(2))
    }

    private func plot(_ data: DispersionData) -> some View {
        Canvas { context, canvasSize in
            let c = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let plotLimit = canvasSize.width / 2 - Self.edgeLabelBand
            let maxR = plotLimit / Self.overshoot
            // The scale reads outwards from the hole along one line to the
            // right, and each ring opens where its label sits rather than
            // running through it.
            // Stretched, the sides reach only the lateral limit, so every ring
            // is that many times wider than it is tall; otherwise a circle.
            let stretch = data.stretched ? CGFloat(outerDistance / lateralLimitM) : 1
            context.drawLayer { rings in
                // The wider rings run off the sides; they stop before the edge
                // labels instead of running through them.
                rings.clip(to: Path(CGRect(x: c.x - plotLimit, y: 0, width: plotLimit * 2, height: canvasSize.height)))
                for distance in ringDistances {
                    let ry = maxR * fraction(forLeave: distance)
                    let rx = ry * stretch
                    rings.stroke(
                        Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2)),
                        with: .color(Theme.borderLight),
                        lineWidth: 1
                    )
                }
            }
            var crosshair = Path()
            crosshair.move(to: CGPoint(x: c.x - maxR, y: c.y)); crosshair.addLine(to: CGPoint(x: c.x + maxR, y: c.y))
            crosshair.move(to: CGPoint(x: c.x, y: c.y - maxR)); crosshair.addLine(to: CGPoint(x: c.x, y: c.y + maxR))
            context.stroke(crosshair, with: .color(.white.opacity(0.18)), lineWidth: 1)


            context.fill(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(Theme.primary))
            context.stroke(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(.white), lineWidth: 2)

            // Strongest first, so the solid markers lie underneath and the
            // pale short-and-straight ones sit on top without hiding them.
            let ordered = shading == .none
                ? data.dots
                : data.dots.sorted {
                    normalisedStrength($0.shadingAverage ?? 0, scale: data.shadingScale)
                        > normalisedStrength($1.shadingAverage ?? 0, scale: data.shadingScale)
                }

            for dot in ordered {
                let r = min(22, 6 + CGFloat(dot.count - 1) * 2.4)
                let centre = CGPoint(x: c.x + dot.x * maxR, y: c.y + dot.y * maxR)
                let rect = CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2)

                if dot.values.count > 1 {
                    // Several putts on one spot: a pie of what each of them
                    // was, so a cluster of gentle putts can't hide one severe
                    // one inside an average.
                    let sorted = dot.values.sorted()
                    let slice = 360.0 / Double(sorted.count)
                    for (i, value) in sorted.enumerated() {
                        var wedge = Path()
                        wedge.move(to: centre)
                        wedge.addArc(
                            center: centre, radius: r,
                            startAngle: .degrees(-90 + slice * Double(i)),
                            endAngle: .degrees(-90 + slice * Double(i + 1)),
                            clockwise: false
                        )
                        wedge.closeSubpath()
                        context.fill(wedge, with: .color(shadingColor(value, scale: data.shadingScale)))
                    }
                    context.stroke(Path(ellipseIn: rect), with: .color(Theme.background.opacity(0.8)), lineWidth: 1)
                } else if let value = dot.values.first {
                    context.fill(Path(ellipseIn: rect), with: .color(shadingColor(value, scale: data.shadingScale)))
                    context.stroke(Path(ellipseIn: rect), with: .color(Theme.background.opacity(0.8)), lineWidth: 1)
                } else {
                    let alpha = min(maxDotOpacity, minDotOpacity + Double(dot.count) * 0.08)
                    context.fill(Path(ellipseIn: rect), with: .color(Theme.error.opacity(alpha)))
                    context.stroke(Path(ellipseIn: rect), with: .color(Color(hex: 0x7A1111).opacity(0.6)), lineWidth: 1)
                }
            }

            // The scale goes on last, straight up from the hole — few misses
            // finish right above it — each number on a plate of the card's
            // colour, so no dot can bury what measures it.
            for distance in ringDistances {
                let point = CGPoint(x: c.x, y: c.y - maxR * fraction(forLeave: distance))
                let plate = CGRect(x: point.x - 15, y: point.y - 7, width: 30, height: 14)
                context.fill(Path(roundedRect: plate, cornerRadius: 3), with: .color(Theme.surface))
                context.draw(
                    Text(UnitConverter.formatDistance(distance, useFeet: useFeet))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.textMuted),
                    at: point,
                    anchor: .center
                )
            }
        }
    }

    private var slopeArrowHorizontal: some View {
        let isRight = filter == .lr
        return Canvas { context, canvasSize in
            let y: CGFloat = 12
            let leftX: CGFloat = 12, rightX = canvasSize.width - 12
            var path = Path()
            path.move(to: CGPoint(x: leftX, y: y)); path.addLine(to: CGPoint(x: rightX, y: y))
            context.stroke(path, with: .color(Theme.accent), lineWidth: 3)
            var head = Path()
            if isRight {
                head.move(to: CGPoint(x: rightX, y: y)); head.addLine(to: CGPoint(x: rightX - 10, y: y - 6))
                head.move(to: CGPoint(x: rightX, y: y)); head.addLine(to: CGPoint(x: rightX - 10, y: y + 6))
            } else {
                head.move(to: CGPoint(x: leftX, y: y)); head.addLine(to: CGPoint(x: leftX + 10, y: y - 6))
                head.move(to: CGPoint(x: leftX, y: y)); head.addLine(to: CGPoint(x: leftX + 10, y: y + 6))
            }
            context.stroke(head, with: .color(Theme.accent), lineWidth: 3)
        }
        .frame(maxWidth: side, minHeight: 24, maxHeight: 24)
    }

    private var slopeArrowVertical: some View {
        let isUp = filter == .up
        return Canvas { context, canvasSize in
            let x: CGFloat = 10
            let topY: CGFloat = 12, bottomY = canvasSize.height - 12
            var path = Path()
            path.move(to: CGPoint(x: x, y: topY)); path.addLine(to: CGPoint(x: x, y: bottomY))
            context.stroke(path, with: .color(Theme.accent), lineWidth: 3)
            var head = Path()
            if isUp {
                head.move(to: CGPoint(x: x, y: topY)); head.addLine(to: CGPoint(x: x - 6, y: topY + 10))
                head.move(to: CGPoint(x: x, y: topY)); head.addLine(to: CGPoint(x: x + 6, y: topY + 10))
            } else {
                head.move(to: CGPoint(x: x, y: bottomY)); head.addLine(to: CGPoint(x: x - 6, y: bottomY - 10))
                head.move(to: CGPoint(x: x, y: bottomY)); head.addLine(to: CGPoint(x: x + 6, y: bottomY - 10))
            }
            context.stroke(head, with: .color(Theme.accent), lineWidth: 3)
        }
        .frame(width: 24, height: side)
    }
}
