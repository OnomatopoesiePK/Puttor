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

    private let size: CGFloat = 268
    /// The outer ring, and how far a dot may stray beyond it before the plot
    /// runs out of room.
    private let maxR: CGFloat = 100
    private let plotLimit: CGFloat = 110

    /// Largest shading value in view, which the colour ramp stretches over.
    /// Zero means the putts carry nothing to shade by — slope left unrecorded,
    /// for instance.
    private var shadingScale: Double {
        dots.flatMap(\.values).map { abs($0) }.max() ?? 0
    }

    /// Ring distances, marked on the scale line. The outer one — 3 m, or 10 ft
    /// in imperial — is what the plot is normalised to; a longer leave than
    /// that is drawn outside the rings rather than pinned to them.
    private var ringDistances: [Double] {
        useFeet
            ? [3, 6, 10].map { UnitConverter.feetToMetres($0) }
            : [1, 2, 3]
    }

    /// The innermost ring is drawn but not numbered — that close to the hole
    /// the label would sit among the dots it is meant to measure.
    private var labelledRingDistances: [Double] {
        Array(ringDistances.dropFirst())
    }

    private var outerDistance: Double { ringDistances.last ?? 3 }

    /// Where a leave of this length sits, in points from the centre.
    private func radius(forLeave leave: Double) -> CGFloat {
        let scaled = maxR * CGFloat(leave / outerDistance)
        return min(plotLimit, max(12, scaled))
    }

    private var dots: [DispersionDot] {
        var byHole: [String: [Putt]] = [:]
        for p in putts {
            let key = "\(p.round?.id.uuidString ?? "-")-\(p.holeNumber)"
            byHole[key, default: []].append(p)
        }

        var result: [DispersionDot] = []
        var index: [String: Int] = [:]

        for holePutts in byHole.values {
            let sorted = holePutts.sorted { $0.puttNumber < $1.puttNumber }
            for (i, p) in sorted.enumerated() {
                guard p.result != .holed, includeByFilter(p, filter) else { continue }
                let next = i + 1 < sorted.count ? sorted[i + 1] : nil
                let leave = next.map { max(0.3, $0.distanceM) } ?? max(0.3, p.distanceM * 0.35)
                let radial = radius(forLeave: Double(leave))
                let vec = missVector(p.result)
                let x = (vec.x * radial * 10).rounded() / 10
                let y = (vec.y * radial * 10).rounded() / 10
                let key = "\(x)|\(y)"
                let shadingValue = shading.value(for: p)
                if let idx = index[key] {
                    result[idx].count += 1
                    if let shadingValue { result[idx].values.append(shadingValue) }
                } else {
                    index[key] = result.count
                    result.append(DispersionDot(
                        x: x, y: y, count: 1,
                        values: shadingValue.map { [$0] } ?? []
                    ))
                }
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 6) {
            if filter == .rl || filter == .lr {
                slopeArrowHorizontal
            }

            HStack(spacing: 8) {
                if dots.isEmpty {
                    VStack {
                        Text(L("dispersion.noData"))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .frame(width: size, height: size)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
                } else {
                    ZStack {
                        plot
                        Text(L("dispersion.left")).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textMuted)
                            .position(x: 2, y: size / 2)
                        Text(L("dispersion.right")).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textMuted)
                            .position(x: size - 2, y: size / 2)
                        Text(L("dispersion.long")).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textMuted)
                            .position(x: size / 2, y: 10)
                        Text(L("dispersion.short")).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textMuted)
                            .position(x: size / 2, y: size - 10)
                    }
                    .frame(width: size, height: size)
                }

                if filter == .up || filter == .down {
                    slopeArrowVertical
                }
            }

            if shading != .none, !dots.isEmpty {
                if shadingScale > 0.0001 {
                    shadingLegend
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
    private func normalisedStrength(_ value: Double) -> Double {
        switch shading {
        case .none:
            return 0
        case .breakMagnitude:
            return Double(breakClass(value)) / 4
        case .puttLength:
            return shadingScale > 0.0001 ? min(1, max(0, value / shadingScale)) : 0
        case .slope:
            return shadingScale > 0.0001 ? min(1, abs(value) / shadingScale) : 0
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
    private func shadingColor(_ value: Double) -> Color {
        if shading == .breakMagnitude {
            return Theme.slopeClassColors[breakClass(value)]
                .opacity(dotOpacity(normalisedStrength(value)))
        }
        guard shadingScale > 0.0001 else { return Theme.error.opacity(maxDotOpacity) }
        let ends = rampEnds
        if shading.isSigned {
            let t = max(-1, min(1, value / shadingScale))
            let base = t >= 0
                ? mix(Theme.textMuted, ends.high, t)
                : mix(Theme.textMuted, ends.low, -t)
            // A level putt has nothing to say, a steep one has all of it.
            return base.opacity(dotOpacity(normalisedStrength(value)))
        }
        let t = max(0, min(1, value / shadingScale))
        if shading == .puttLength {
            // One colour, carried from barely there to nearly solid — a longer
            // reach than any hue shift over this small a dot.
            return ends.high.opacity(dotOpacity(normalisedStrength(value)))
        }
        return mix(ends.low, ends.high, t).opacity(dotOpacity(normalisedStrength(value)))
    }

    @ViewBuilder
    private var shadingLegend: some View {
        if shading == .breakMagnitude {
            breakLegend
        } else {
            rampLegend
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
        .frame(width: size)
    }

    private var rampLegend: some View {
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
                Text(legendLabel(shading.isSigned ? -shadingScale : 0))
                Spacer()
                if shading.isSigned {
                    Text(L("dispersion.shading.flat"))
                    Spacer()
                }
                Text(legendLabel(shadingScale))
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Theme.textMuted)
        }
        .frame(width: size)
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

    private var plot: some View {
        Canvas { context, canvasSize in
            let c = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            // The scale reads outwards from the hole along one line to the
            // right, and each ring opens where its label sits rather than
            // running through it.
            for distance in ringDistances {
                let r = radius(forLeave: distance)
                let labelled = labelledRingDistances.contains(distance)
                let gapHalfWidth: CGFloat = 15
                let gap: Angle = labelled ? .radians(Double(atan(gapHalfWidth / r))) : .degrees(0)

                var ring = Path()
                ring.addArc(
                    center: c, radius: r,
                    startAngle: .degrees(0) + gap,
                    endAngle: .degrees(360) - gap,
                    clockwise: false
                )
                context.stroke(ring, with: .color(Theme.borderLight), lineWidth: 1)
            }
            var crosshair = Path()
            crosshair.move(to: CGPoint(x: c.x - maxR, y: c.y)); crosshair.addLine(to: CGPoint(x: c.x + maxR, y: c.y))
            crosshair.move(to: CGPoint(x: c.x, y: c.y - maxR)); crosshair.addLine(to: CGPoint(x: c.x, y: c.y + maxR))
            context.stroke(crosshair, with: .color(.white.opacity(0.18)), lineWidth: 1)

            // Clear the crosshair behind each number, then set the scale on it.
            for distance in labelledRingDistances {
                let r = radius(forLeave: distance)
                let plate = CGRect(x: c.x + r - 15, y: c.y - 7, width: 30, height: 14)
                context.fill(Path(roundedRect: plate, cornerRadius: 3), with: .color(Theme.surface))
                context.draw(
                    Text(UnitConverter.formatDistance(distance, useFeet: useFeet))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.textMuted),
                    at: CGPoint(x: c.x + r, y: c.y),
                    anchor: .center
                )
            }

            context.fill(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(Theme.primary))
            context.stroke(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(.white), lineWidth: 2)

            // Strongest first, so the solid markers lie underneath and the
            // pale short-and-straight ones sit on top without hiding them.
            let ordered = shading == .none
                ? dots
                : dots.sorted { normalisedStrength($0.shadingAverage ?? 0) > normalisedStrength($1.shadingAverage ?? 0) }

            for dot in ordered {
                let r = min(22, 6 + CGFloat(dot.count - 1) * 2.4)
                let centre = CGPoint(x: c.x + dot.x, y: c.y + dot.y)
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
                        context.fill(wedge, with: .color(shadingColor(value)))
                    }
                    context.stroke(Path(ellipseIn: rect), with: .color(Theme.background.opacity(0.8)), lineWidth: 1)
                } else if let value = dot.values.first {
                    context.fill(Path(ellipseIn: rect), with: .color(shadingColor(value)))
                    context.stroke(Path(ellipseIn: rect), with: .color(Theme.background.opacity(0.8)), lineWidth: 1)
                } else {
                    let alpha = min(maxDotOpacity, minDotOpacity + Double(dot.count) * 0.08)
                    context.fill(Path(ellipseIn: rect), with: .color(Theme.error.opacity(alpha)))
                    context.stroke(Path(ellipseIn: rect), with: .color(Color(hex: 0x7A1111).opacity(0.6)), lineWidth: 1)
                }
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
        .frame(width: size, height: 24)
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
        .frame(width: 24, height: size)
    }
}
