//
//  DartboardMissView.swift
//  Puttor
//
//  Dartboard-style miss/result selector: 8 directional sectors around a
//  lip-out ring and a holed center. Ported from the prototype's
//  DartboardMiss.tsx; hit-testing uses precise polar (angle/radius) math
//  instead of the prototype's approximate touch boxes.
//

import SwiftUI

private struct DartSector {
    let result: PuttResult
    let symbol: String
    let isWord: Bool
    let startDeg: Double
    let fillA: Color
    let fillB: Color
}

private let dartSectors: [DartSector] = [
    DartSector(result: .long, symbol: "result.long", isWord: true, startDeg: -112.5, fillA: Color(hex: 0x3A5060), fillB: Color(hex: 0x2E3F50)),
    DartSector(result: .longRight, symbol: "↗", isWord: false, startDeg: -67.5, fillA: Color(hex: 0x3E3040), fillB: Color(hex: 0x322635)),
    DartSector(result: .right, symbol: "result.right", isWord: true, startDeg: -22.5, fillA: Color(hex: 0x3A2A20), fillB: Color(hex: 0x2E201A)),
    DartSector(result: .shortRight, symbol: "↘", isWord: false, startDeg: 22.5, fillA: Color(hex: 0x3E3040), fillB: Color(hex: 0x322635)),
    DartSector(result: .short, symbol: "result.short", isWord: true, startDeg: 67.5, fillA: Color(hex: 0x3A5060), fillB: Color(hex: 0x2E3F50)),
    DartSector(result: .shortLeft, symbol: "↙", isWord: false, startDeg: 112.5, fillA: Color(hex: 0x3E3040), fillB: Color(hex: 0x322635)),
    DartSector(result: .left, symbol: "result.left", isWord: true, startDeg: 157.5, fillA: Color(hex: 0x3A2A20), fillB: Color(hex: 0x2E201A)),
    DartSector(result: .longLeft, symbol: "↖", isWord: false, startDeg: 202.5, fillA: Color(hex: 0x3E3040), fillB: Color(hex: 0x322635)),
]

private func polarPoint(_ deg: Double, _ r: CGFloat, _ center: CGPoint) -> CGPoint {
    let rad = deg * .pi / 180
    return CGPoint(x: center.x + r * CGFloat(cos(rad)), y: center.y + r * CGFloat(sin(rad)))
}

private func annularSectorPath(startDeg: Double, endDeg: Double, r1: CGFloat, r2: CGFloat, center: CGPoint) -> Path {
    var path = Path()
    let steps = 10
    path.move(to: polarPoint(startDeg, r2, center))
    for i in 1...steps {
        let d = startDeg + (endDeg - startDeg) * Double(i) / Double(steps)
        path.addLine(to: polarPoint(d, r2, center))
    }
    for i in 0...steps {
        let d = endDeg - (endDeg - startDeg) * Double(i) / Double(steps)
        path.addLine(to: polarPoint(d, r1, center))
    }
    path.closeSubpath()
    return path
}

/// Is `angle` within [start, start+45) modulo 360?
private func angleInSector(_ angle: Double, start: Double) -> Bool {
    var diff = (angle - start).truncatingRemainder(dividingBy: 360)
    if diff < 0 { diff += 360 }
    return diff < 45
}

struct DartboardMissView: View {
    @Binding var result: PuttResult?
    @Binding var lipOut: Bool

    private let size: CGFloat = 280

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Text(L("input.missBoard"))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity)
                HStack {
                    Spacer()
                    FieldInfoButton(titleKey: "input.missBoard", textKey: "input.missBoard.info")
                }
            }

            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let outerR = canvasSize.width / 2 - 4
                let lipOutR = outerR * 0.35
                let holedR = outerR * 0.20
                let sectorR1 = outerR * 0.35
                let sectorR2 = outerR

                for (i, s) in dartSectors.enumerated() {
                    let endDeg = s.startDeg + 45
                    let path = annularSectorPath(startDeg: s.startDeg, endDeg: endDeg, r1: sectorR1, r2: sectorR2, center: center)
                    let selected = result == s.result
                    let fill = selected ? Theme.error.opacity(0.87) : (i % 2 == 0 ? s.fillA : s.fillB)
                    context.fill(path, with: .color(fill))
                    context.stroke(path, with: .color(Theme.border), lineWidth: 0.5)
                }

                // Lip-out ring (drawn as a full circle, then covered by the smaller holed circle).
                let lipRect = CGRect(x: center.x - lipOutR, y: center.y - lipOutR, width: lipOutR * 2, height: lipOutR * 2)
                context.fill(Path(ellipseIn: lipRect), with: .color(lipOut ? Theme.lipOut.opacity(0.87) : Color(hex: 0x2A3D2A)))
                context.stroke(Path(ellipseIn: lipRect), with: .color(lipOut ? Theme.lipOut : Theme.border), lineWidth: lipOut ? 2 : 1)

                let holedRect = CGRect(x: center.x - holedR, y: center.y - holedR, width: holedR * 2, height: holedR * 2)
                let isHoled = result == .holed
                context.fill(Path(ellipseIn: holedRect), with: .color(isHoled ? Theme.holed : Color(hex: 0x1E3A28)))
                context.stroke(Path(ellipseIn: holedRect), with: .color(isHoled ? Theme.primaryLight : Theme.primary.opacity(0.53)), lineWidth: 2)

                for s in dartSectors {
                    let endDeg = s.startDeg + 45
                    let mid = (s.startDeg + endDeg) / 2
                    let lp = polarPoint(mid, (sectorR1 + sectorR2) / 2, center)
                    let selected = result == s.result
                    let text = s.isWord ? L(s.symbol).uppercased() : s.symbol
                    var resolved = context.resolve(
                        Text(text).font(.system(size: s.isWord ? 12 : 15, weight: .semibold))
                    )
                    resolved.shading = .color(selected ? .white : .white.opacity(0.53))
                    context.draw(resolved, at: lp, anchor: .center)
                }

                var lipLabel = context.resolve(Text(L("input.lip")).font(.system(size: 7, weight: .semibold)))
                lipLabel.shading = .color(lipOut ? .white : .white.opacity(0.4))
                context.draw(lipLabel, at: CGPoint(x: center.x, y: center.y - (holedR + lipOutR) / 2), anchor: .center)

                var holedLabel = context.resolve(Text("⬤").font(.system(size: 8, weight: .bold)))
                holedLabel.shading = .color(isHoled ? .white : Theme.holed.opacity(0.8))
                context.draw(holedLabel, at: center, anchor: .center)

                context.stroke(Path(ellipseIn: CGRect(x: center.x - outerR, y: center.y - outerR, width: outerR * 2, height: outerR * 2)), with: .color(Theme.border), lineWidth: 1.5)
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .gesture(
                // SpatialTapGesture (a true tap, not a 0-distance drag) coexists cleanly
                // with the outer ScrollView's pan gesture, so scrolling that starts on
                // top of the dartboard isn't swallowed.
                SpatialTapGesture()
                    .onEnded { tap in
                        let center = CGPoint(x: size / 2, y: size / 2)
                        let outerR = size / 2 - 4
                        let lipOutR = outerR * 0.35
                        let holedR = outerR * 0.20
                        let dx = tap.location.x - center.x
                        let dy = tap.location.y - center.y
                        let r = (dx * dx + dy * dy).squareRoot()

                        if r <= holedR {
                            result = .holed
                        } else if r <= lipOutR {
                            lipOut.toggle()
                        } else if r <= outerR {
                            let angle = atan2(dy, dx) * 180 / .pi
                            if let hit = dartSectors.first(where: { angleInSector(angle, start: $0.startDeg) }) {
                                result = hit.result
                            }
                        }
                    }
            )

            if result != nil || lipOut {
                Text(resultSummary)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.text)
            }
        }
    }

    private var resultSummary: String {
        if lipOut, let r = result, r != .holed {
            return "🔄 \(L("input.lip")) + \(L(r.labelKey))"
        }
        if lipOut { return "🕳 \(L("result.lipOut"))" }
        if let r = result { return "\(r.emoji) \(L(r.labelKey))" }
        return ""
    }
}

#Preview {
    DartboardMissView(result: .constant(.short), lipOut: .constant(false))
        .padding()
        .background(Theme.background)
}
