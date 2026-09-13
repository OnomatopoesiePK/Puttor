//
//  CircularMissSliderView.swift
//  Puttor
//
//  The miss board as a dial. Instead of eight sectors, a ring around the hole
//  that is dragged to where the ball stopped, in five-degree steps: straight
//  short at the bottom, left and right at the sides, long-left and long-right
//  at the two ends. The gap at the top is Long. How far the ball ran is not
//  asked — the next putt's distance already says it.
//
//  Holed in the centre and the lip ring around it work exactly as on the
//  board.
//

import SwiftUI

struct CircularMissSliderView: View {
    @Binding var result: PuttResult?
    @Binding var lipOut: Bool
    @Binding var angle: Double?

    var size: CGFloat = 280

    @AppStorage(AppStorageKeys.haptics) private var hapticsEnabled = true

    private var outerR: CGFloat { size / 2 - 4 }
    private var lipR: CGFloat { outerR * 0.35 }
    private var holedR: CGFloat { outerR * 0.20 }
    private var center: CGPoint { CGPoint(x: size / 2, y: size / 2) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Text(L("input.missAngle"))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity)
                HStack {
                    Spacer()
                    FieldInfoButton(titleKey: "input.missAngle", textKey: "input.missAngle.info")
                }
            }

            ZStack {
                Canvas { context, _ in draw(in: &context) }
                    .frame(width: size, height: size)
                    .contentShape(Rectangle())
                    // Taps only down here: the centre, the lip ring and the gap.
                    // The track itself sits on top and takes its own touches.
                    .gesture(SpatialTapGesture().onEnded { handleTap($0.location) })

                // The track alone catches drags, so a scroll that starts on the
                // hole or outside the ring still scrolls the page.
                Color.clear
                    .frame(width: size, height: size)
                    .contentShape(TrackShape())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { setAngle(at: $0.location) }
                    )
            }
            .sensoryFeedback(.selection, trigger: angle) { _, _ in hapticsEnabled }

            Text(readout)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(angle == nil && result == nil && !lipOut ? Theme.textMuted : Theme.text)
        }
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext) {
        let bandInner = lipR
        let active = angle != nil

        // The track: grey until a direction is picked, coloured once it is.
        let track = band(from: MissAngle.trackStartScreen, to: MissAngle.trackEndScreen, inner: bandInner, outer: outerR)
        context.fill(track, with: .color(active ? Theme.missSectorBlueA : Theme.surfaceElevated))
        context.stroke(track, with: .color(Theme.border), lineWidth: 0.5)

        // Orientation marks every 45°, heavier at short, left and right.
        for mark in stride(from: -135.0, through: 135.0, by: 45.0) {
            let screen = MissAngle.screenDegrees(mark)
            let major = mark.truncatingRemainder(dividingBy: 90) == 0
            var tick = Path()
            tick.move(to: PolarGeometry.point(screen, outerR * (major ? 0.84 : 0.9), center))
            tick.addLine(to: PolarGeometry.point(screen, outerR, center))
            context.stroke(tick, with: .color(.white.opacity(active ? 0.55 : 0.25)), lineWidth: major ? 1.5 : 1)
        }
        for (mark, key) in [(0.0, "result.short"), (-90.0, "result.left"), (90.0, "result.right")] {
            var label = context.resolve(Text(L(key).uppercased()).font(.system(size: 10, weight: .semibold)))
            label.shading = .color(.white.opacity(active ? 0.7 : 0.35))
            context.draw(label, at: PolarGeometry.point(MissAngle.screenDegrees(mark), (bandInner + outerR) / 2, center), anchor: .center)
        }

        // Long, in the gap at the top — its own button, set a little apart.
        let isLong = result == .long
        let gap = band(from: MissAngle.trackEndScreen + 4, to: MissAngle.trackStartScreen + 360 - 4, inner: bandInner, outer: outerR)
        context.fill(gap, with: .color(isLong ? Theme.error.opacity(0.87) : Theme.missSectorBlueB))
        context.stroke(gap, with: .color(Theme.border), lineWidth: 0.5)
        var longLabel = context.resolve(Text(L("result.long").uppercased()).font(.system(size: 12, weight: .semibold)))
        longLabel.shading = .color(isLong ? .white : .white.opacity(0.6))
        context.draw(longLabel, at: PolarGeometry.point(-90, (bandInner + outerR) / 2, center), anchor: .center)

        // The chosen direction: a line out from the lip to a handle on the track.
        if let angle {
            let screen = MissAngle.screenDegrees(angle)
            var ray = Path()
            ray.move(to: PolarGeometry.point(screen, lipR, center))
            ray.addLine(to: PolarGeometry.point(screen, outerR, center))
            context.stroke(ray, with: .color(Theme.error), lineWidth: 2.5)

            let handleCenter = PolarGeometry.point(screen, (bandInner + outerR) / 2, center)
            let handleR = (outerR - bandInner) * 0.3
            let handle = Path(ellipseIn: CGRect(x: handleCenter.x - handleR, y: handleCenter.y - handleR, width: handleR * 2, height: handleR * 2))
            context.fill(handle, with: .color(Theme.error))
            context.stroke(handle, with: .color(.white), lineWidth: 2)
        }

        // Lip and hole, as on the board.
        let lipRect = CGRect(x: center.x - lipR, y: center.y - lipR, width: lipR * 2, height: lipR * 2)
        context.fill(Path(ellipseIn: lipRect), with: .color(lipOut ? Theme.lipOut.opacity(0.87) : Theme.missLipIdle))
        context.stroke(Path(ellipseIn: lipRect), with: .color(lipOut ? Theme.lipOut : Theme.border), lineWidth: lipOut ? 2 : 1)

        let holedRect = CGRect(x: center.x - holedR, y: center.y - holedR, width: holedR * 2, height: holedR * 2)
        let isHoled = result == .holed
        context.fill(Path(ellipseIn: holedRect), with: .color(isHoled ? Theme.holed : Theme.missHoledIdle))
        context.stroke(Path(ellipseIn: holedRect), with: .color(isHoled ? Theme.primaryLight : Theme.primary.opacity(0.53)), lineWidth: 2)

        var lipLabel = context.resolve(Text(L("input.lip")).font(.system(size: 7, weight: .semibold)))
        lipLabel.shading = .color(lipOut ? .white : .white.opacity(0.4))
        context.draw(lipLabel, at: CGPoint(x: center.x, y: center.y - (holedR + lipR) / 2), anchor: .center)

        var holedLabel = context.resolve(Text("⬤").font(.system(size: 8, weight: .bold)))
        holedLabel.shading = .color(isHoled ? .white : Theme.holed.opacity(0.8))
        context.draw(holedLabel, at: center, anchor: .center)

        context.stroke(Path(ellipseIn: CGRect(x: center.x - outerR, y: center.y - outerR, width: outerR * 2, height: outerR * 2)), with: .color(Theme.border), lineWidth: 1.5)
    }

    /// A smooth ring segment — finer than the board's, since this one runs
    /// three quarters of the way round.
    private func band(from start: Double, to end: Double, inner: CGFloat, outer: CGFloat) -> Path {
        var path = Path()
        let steps = max(8, Int(abs(end - start) / 3))
        path.move(to: PolarGeometry.point(start, outer, center))
        for i in 1...steps {
            path.addLine(to: PolarGeometry.point(start + (end - start) * Double(i) / Double(steps), outer, center))
        }
        for i in 0...steps {
            path.addLine(to: PolarGeometry.point(end - (end - start) * Double(i) / Double(steps), inner, center))
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Input

    private func handleTap(_ location: CGPoint) {
        let dx = location.x - center.x, dy = location.y - center.y
        let radius = (dx * dx + dy * dy).squareRoot()
        if radius <= holedR {
            result = .holed
            angle = nil
        } else if radius <= lipR {
            lipOut.toggle()
        } else if radius <= outerR, MissAngle.isInGap(screen: atan2(dy, dx) * 180 / .pi) {
            result = .long
            angle = nil
        }
    }

    private func setAngle(at location: CGPoint) {
        let dx = location.x - center.x, dy = location.y - center.y
        let snapped = MissAngle.snap(MissAngle.angle(fromScreen: atan2(dy, dx) * 180 / .pi))
        guard snapped != angle else { return }
        angle = snapped
        result = MissAngle.result(for: snapped)
    }

    private var readout: String {
        let direction: String? = {
            if let angle, let result {
                return "\(result.emoji) \(L(result.labelKey)) · \(Int(abs(angle)))°"
            }
            if let result { return "\(result.emoji) \(L(result.labelKey))" }
            return nil
        }()
        if lipOut, let direction, result != .holed { return "🔄 \(L("input.lip")) + \(direction)" }
        if lipOut { return "🕳 \(L("result.lipOut"))" }
        return direction ?? L("input.missAngle.none")
    }
}

/// The draggable part of the dial: the ring between the lip and the edge, with
/// the gap at the top left out.
private struct TrackShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2 - 4
        return PolarGeometry.annularSector(
            startDeg: MissAngle.trackStartScreen,
            endDeg: MissAngle.trackEndScreen,
            r1: outer * 0.35,
            r2: outer,
            center: center
        )
    }
}

#Preview {
    CircularMissSliderView(result: .constant(.shortLeft), lipOut: .constant(false), angle: .constant(-35))
        .padding()
        .background(Theme.background)
}
