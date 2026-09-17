//
//  SimpleSlopeGridView.swift
//  Puttor
//
//  Simplified 3x3 slope grid for Custom mode: every combination of
//  uphill/flat/downhill x right-to-left/straight/left-to-right, laid out
//  like the professional grid but without the fine-grained percent steps.
//  Shares the same sideValue/hillValue storage as SlopeGridPickerView.
//

import SwiftUI

private let simpleAxis: [Double] = [-1, 0, 1] // side: rl break, straight, lr break
private let simpleHill: [Double] = [1, 0, -1] // hill: up, flat, down (top row = uphill)

struct SimpleSlopeGridView: View {
    @Binding var sideValue: Double
    @Binding var hillValue: Double

    /// The big grid's own colours: its flat middle, and the shade it gives a
    /// 1 % break — which is what a tap on this grid records.
    private static let flatColor = Theme.slopeClassColors[0]
    private static let breakColor = Theme.slopeClassColors[1]

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
                    FieldInfoButton(titleKey: "input.slopeGrid", textKey: "custom.field.slope.desc")
                }
            }

            sideLabel(L("input.uphill"))

            // Left and right beside the grid rather than under it, where they
            // would read as part of the downhill row.
            HStack(spacing: 6) {
                sideLabel(L("input.left"))
                VStack(spacing: 6) {
                    ForEach(simpleHill, id: \.self) { hill in
                        HStack(spacing: 6) {
                            ForEach(simpleAxis, id: \.self) { side in
                                cell(side: side, hill: hill)
                            }
                        }
                    }
                }
                sideLabel(L("input.right"))
            }

            sideLabel(L("input.downhill"))

            Text(selectionText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.text)
        }
    }

    private func sideLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Theme.textMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: 44)
    }

    private func cell(side: Double, hill: Double) -> some View {
        let selected = sideValue == side && hillValue == hill
        let fill = side == 0 && hill == 0 ? Self.flatColor : Self.breakColor
        return Button {
            sideValue = side
            hillValue = hill
        } label: {
            arrow(side: side, hill: hill)
                .foregroundStyle(fill.isLight ? Color(hex: 0x111418) : .white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(selected ? Theme.primary : Theme.border, lineWidth: selected ? 3 : 1))
        }
        .buttonStyle(.plain)
    }

    /// One arrow the app's own way, turned to where the putt runs: a corner is
    /// the same arrow at 45°, and a flat, straight putt has no direction at all.
    @ViewBuilder
    private func arrow(side: Double, hill: Double) -> some View {
        if side == 0 && hill == 0 {
            Image(systemName: "circle.fill")
                .font(.system(size: 12, weight: .bold))
        } else {
            Image(systemName: "arrow.up")
                .font(.system(size: 22, weight: .bold))
                .rotationEffect(.degrees(arrowDegrees(side: side, hill: hill)))
        }
    }

    /// Clockwise from straight up: right is a quarter turn, down a half.
    private func arrowDegrees(side: Double, hill: Double) -> Double {
        switch (side, hill) {
        case (0, 1...): return 0
        case (1..., 1...): return 45
        case (1..., 0): return 90
        case (1..., _): return 135
        case (0, _): return 180
        case (_, ...(-0.0001)): return 225
        case (_, 0): return 270
        default: return 315
        }
    }

    /// Only the directions that are there; a putt with neither is flat.
    private var selectionText: String {
        var parts: [String] = []
        if sideValue != 0 { parts.append(sideValue < 0 ? L("input.rl") : L("input.lr")) }
        if hillValue != 0 { parts.append(hillValue > 0 ? L("input.up") : L("input.down")) }
        return parts.isEmpty ? L("input.flat") : parts.joined(separator: " / ")
    }
}

#Preview {
    SimpleSlopeGridView(sideValue: .constant(1), hillValue: .constant(-1))
        .padding()
        .background(Theme.background)
}
