//
//  MissDispersionPlotView.swift
//  Puttor
//
//  Ported from the prototype's MissDispersionPlot.tsx.
//

import SwiftUI

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

private struct DispersionDot {
    var x: CGFloat
    var y: CGFloat
    var count: Int
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

    private let size: CGFloat = 268
    private let maxR: CGFloat = 108

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
                let radial = min(maxR, 18 + CGFloat(leave) * 24)
                let vec = missVector(p.result)
                let x = (vec.x * radial * 10).rounded() / 10
                let y = (vec.y * radial * 10).rounded() / 10
                let key = "\(x)|\(y)"
                if let idx = index[key] {
                    result[idx].count += 1
                } else {
                    index[key] = result.count
                    result.append(DispersionDot(x: x, y: y, count: 1))
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
                            .position(x: 10, y: size / 2)
                        Text(L("dispersion.right")).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textMuted)
                            .position(x: size - 10, y: size / 2)
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
        }
    }

    private var plot: some View {
        Canvas { context, canvasSize in
            let c = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            for r in [maxR, maxR * 0.66, maxR * 0.33] {
                context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Theme.borderLight), lineWidth: 1)
            }
            var crosshair = Path()
            crosshair.move(to: CGPoint(x: c.x - maxR, y: c.y)); crosshair.addLine(to: CGPoint(x: c.x + maxR, y: c.y))
            crosshair.move(to: CGPoint(x: c.x, y: c.y - maxR)); crosshair.addLine(to: CGPoint(x: c.x, y: c.y + maxR))
            context.stroke(crosshair, with: .color(.white.opacity(0.18)), lineWidth: 1)

            context.fill(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(Theme.primary))
            context.stroke(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(.white), lineWidth: 2)

            for dot in dots {
                let r = min(14, 5 + CGFloat(dot.count - 1) * 1.8)
                let alpha = min(0.95, 0.45 + Double(dot.count) * 0.08)
                let rect = CGRect(x: c.x + dot.x - r, y: c.y + dot.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(Theme.error.opacity(alpha)))
                context.stroke(Path(ellipseIn: rect), with: .color(Color(hex: 0x7A1111)), lineWidth: 1)
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
