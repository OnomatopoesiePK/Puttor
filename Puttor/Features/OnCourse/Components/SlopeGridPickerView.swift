//
//  SlopeGridPickerView.swift
//  Puttor
//
//  Pixel-mapped slope grid picker overlaid on slopegrid_color.png. Ported
//  from the prototype's SlopeGridPicker.tsx, including its exact
//  10x10 mesh of intersection points extracted from the artwork.
//
//  Orientation (per user confirmation): viewed from behind the ball toward
//  the hole — top row = uphill, bottom row = downhill; columns run from
//  right-to-left break (negative) on the left to left-to-right break
//  (positive) on the right.
//

import SwiftUI

private enum SlopeGridGeometry {
    static let axisValues: [Double] = [-3.5, -3, -2, -1, 0, 1, 2, 3, 3.5]
    static let hillValues: [Double] = axisValues.reversed()
    static let gridSize = axisValues.count // 9
    static let imgW: CGFloat = 1743
    static let imgH: CGFloat = 1120

    // Pixel-extracted intersections from slopegrid_color.png (10x10 boundaries).
    static let intersectionPoints: [[CGPoint]] = [
        [CGPoint(x: 485, y: 75), CGPoint(x: 579, y: 40), CGPoint(x: 668, y: 21), CGPoint(x: 753, y: 10), CGPoint(x: 829, y: 5), CGPoint(x: 913, y: 5), CGPoint(x: 990, y: 11), CGPoint(x: 1077, y: 23), CGPoint(x: 1164, y: 42), CGPoint(x: 1258, y: 74)],
        [CGPoint(x: 447, y: 219), CGPoint(x: 555, y: 173), CGPoint(x: 651, y: 151), CGPoint(x: 740, y: 139), CGPoint(x: 826, y: 135), CGPoint(x: 922, y: 134), CGPoint(x: 1001, y: 141), CGPoint(x: 1094, y: 156), CGPoint(x: 1194, y: 178), CGPoint(x: 1296, y: 215)],
        [CGPoint(x: 411, y: 306), CGPoint(x: 518, y: 268), CGPoint(x: 627, y: 248), CGPoint(x: 721, y: 237), CGPoint(x: 820, y: 233), CGPoint(x: 926, y: 231), CGPoint(x: 1023, y: 240), CGPoint(x: 1122, y: 254), CGPoint(x: 1231, y: 275), CGPoint(x: 1333, y: 305)],
        [CGPoint(x: 344, y: 415), CGPoint(x: 467, y: 373), CGPoint(x: 585, y: 347), CGPoint(x: 695, y: 333), CGPoint(x: 804, y: 325), CGPoint(x: 941, y: 325), CGPoint(x: 1050, y: 334), CGPoint(x: 1166, y: 349), CGPoint(x: 1276, y: 372), CGPoint(x: 1400, y: 416)],
        [CGPoint(x: 292, y: 480), CGPoint(x: 421, y: 441), CGPoint(x: 543, y: 417), CGPoint(x: 663, y: 401), CGPoint(x: 792, y: 392), CGPoint(x: 949, y: 393), CGPoint(x: 1077, y: 403), CGPoint(x: 1207, y: 420), CGPoint(x: 1325, y: 444), CGPoint(x: 1451, y: 479)],
        [CGPoint(x: 212, y: 578), CGPoint(x: 364, y: 529), CGPoint(x: 497, y: 500), CGPoint(x: 637, y: 481), CGPoint(x: 783, y: 469), CGPoint(x: 962, y: 473), CGPoint(x: 1103, y: 482), CGPoint(x: 1255, y: 504), CGPoint(x: 1381, y: 532), CGPoint(x: 1533, y: 580)],
        [CGPoint(x: 142, y: 678), CGPoint(x: 315, y: 619), CGPoint(x: 458, y: 588), CGPoint(x: 613, y: 568), CGPoint(x: 774, y: 556), CGPoint(x: 970, y: 560), CGPoint(x: 1132, y: 573), CGPoint(x: 1289, y: 594), CGPoint(x: 1432, y: 624), CGPoint(x: 1601, y: 676)],
        [CGPoint(x: 92, y: 788), CGPoint(x: 256, y: 735), CGPoint(x: 411, y: 700), CGPoint(x: 586, y: 676), CGPoint(x: 762, y: 664), CGPoint(x: 979, y: 666), CGPoint(x: 1164, y: 682), CGPoint(x: 1333, y: 707), CGPoint(x: 1491, y: 744), CGPoint(x: 1652, y: 790)],
        [CGPoint(x: 43, y: 950), CGPoint(x: 212, y: 884), CGPoint(x: 376, y: 850), CGPoint(x: 558, y: 823), CGPoint(x: 755, y: 809), CGPoint(x: 990, y: 811), CGPoint(x: 1186, y: 826), CGPoint(x: 1372, y: 854), CGPoint(x: 1534, y: 891), CGPoint(x: 1696, y: 943)],
        [CGPoint(x: 9, y: 1106), CGPoint(x: 177, y: 1043), CGPoint(x: 349, y: 1004), CGPoint(x: 534, y: 977), CGPoint(x: 742, y: 961), CGPoint(x: 1001, y: 963), CGPoint(x: 1211, y: 982), CGPoint(x: 1404, y: 1011), CGPoint(x: 1568, y: 1050), CGPoint(x: 1735, y: 1108)],
    ]

    static func meshPoint(_ col: Int, _ row: Int) -> CGPoint { intersectionPoints[row][col] }

    static func cellPath(_ c: Int, _ r: Int) -> Path {
        var path = Path()
        path.move(to: meshPoint(c, r))
        path.addLine(to: meshPoint(c + 1, r))
        path.addLine(to: meshPoint(c + 1, r + 1))
        path.addLine(to: meshPoint(c, r + 1))
        path.closeSubpath()
        return path
    }

    static func valueToCol(_ v: Double) -> Int? { axisValues.firstIndex(of: v) }
    static func valueToRow(_ v: Double) -> Int? { hillValues.firstIndex(of: v) }

    static func labelFor(_ v: Double) -> String {
        abs(v) == 3.5 ? "3+" : String(Int(abs(v)))
    }
}

struct SlopeGridPickerView: View {
    @Binding var sideValue: Double
    @Binding var hillValue: Double

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Text(L("input.slopeGrid"))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity)
                HStack {
                    Spacer()
                    FieldInfoButton(titleKey: "input.slopeGrid", textKey: "input.slopeGrid.info")
                }
            }

            Text(L("input.uphill"))
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.uphill)

            GeometryReader { geo in
                let scale = geo.size.width / SlopeGridGeometry.imgW
                let selectedCol = SlopeGridGeometry.valueToCol(sideValue)
                let selectedRow = SlopeGridGeometry.valueToRow(hillValue)

                ZStack {
                    Canvas { context, size in
                        context.scaleBy(x: scale, y: scale)
                        if let image = context.resolveSymbol(id: "grid") {
                            context.draw(image, at: CGPoint(x: SlopeGridGeometry.imgW / 2, y: SlopeGridGeometry.imgH / 2))
                        }
                        for r in 0..<SlopeGridGeometry.gridSize {
                            for c in 0..<SlopeGridGeometry.gridSize {
                                guard c == selectedCol && r == selectedRow else { continue }
                                let path = SlopeGridGeometry.cellPath(c, r)
                                context.fill(path, with: .color(Theme.primary.opacity(0.25)))
                                context.stroke(path, with: .color(Theme.primary), lineWidth: 4 / scale)
                            }
                        }
                    } symbols: {
                        Image("SlopeGridColor")
                            .resizable()
                            .frame(width: SlopeGridGeometry.imgW, height: SlopeGridGeometry.imgH)
                            .tag("grid")
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        // SpatialTapGesture (a true tap, not a 0-distance drag) coexists
                        // cleanly with the outer ScrollView's pan gesture, so scrolling
                        // that starts on top of the grid isn't swallowed.
                        SpatialTapGesture()
                            .onEnded { tap in
                                guard scale > 0 else { return }
                                let imagePoint = CGPoint(x: tap.location.x / scale, y: tap.location.y / scale)
                                for r in 0..<SlopeGridGeometry.gridSize {
                                    for c in 0..<SlopeGridGeometry.gridSize {
                                        if SlopeGridGeometry.cellPath(c, r).contains(imagePoint) {
                                            sideValue = SlopeGridGeometry.axisValues[c]
                                            hillValue = SlopeGridGeometry.hillValues[r]
                                            return
                                        }
                                    }
                                }
                            }
                    )
                }
            }
            .aspectRatio(SlopeGridGeometry.imgW / SlopeGridGeometry.imgH, contentMode: .fit)
            .scaleEffect(1.18)
            .padding(.vertical, Theme.Spacing.md)
            .zIndex(1)

            HStack {
                Text(L("input.left")).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textMuted)
                Spacer()
                Text(L("input.straight")).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textMuted)
                Spacer()
                Text(L("input.right")).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textMuted)
            }

            Text(L("input.downhill"))
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.downhill)

            Text(selectionText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.text)
        }
    }

    private var selectionText: String {
        let side = sideValue == 0
            ? L("input.flat")
            : "\(SlopeGridGeometry.labelFor(sideValue))° \(sideValue < 0 ? L("input.rl") : L("input.lr"))"
        let hill = hillValue == 0
            ? L("input.flat")
            : "\(SlopeGridGeometry.labelFor(hillValue))° \(hillValue > 0 ? L("input.up") : L("input.down"))"
        return "\(side) / \(hill)"
    }
}

#Preview {
    SlopeGridPickerView(sideValue: .constant(1), hillValue: .constant(-1))
        .padding()
        .background(Theme.background)
}
