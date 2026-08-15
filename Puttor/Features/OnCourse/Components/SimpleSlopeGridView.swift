//
//  SimpleSlopeGridView.swift
//  Puttor
//
//  Simplified 3x3 slope grid for Custom mode: every combination of
//  uphill/flat/downhill x right-to-left/straight/left-to-right, laid out
//  like the professional grid but without the fine-grained degree steps.
//  Shares the same sideValue/hillValue storage as SlopeGridPickerView.
//

import SwiftUI

private let simpleAxis: [Double] = [-1, 0, 1] // side: rl break, straight, lr break
private let simpleHill: [Double] = [1, 0, -1] // hill: up, flat, down (top row = uphill)

struct SimpleSlopeGridView: View {
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
                    FieldInfoButton(titleKey: "input.slopeGrid", textKey: "custom.field.slope.desc")
                }
            }

            VStack(spacing: 6) {
                ForEach(simpleHill, id: \.self) { hill in
                    HStack(spacing: 6) {
                        ForEach(simpleAxis, id: \.self) { side in
                            cell(side: side, hill: hill)
                        }
                    }
                }
            }

            HStack {
                Text(L("input.left")).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textMuted)
                Spacer()
                Text(L("input.straight")).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textMuted)
                Spacer()
                Text(L("input.right")).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textMuted)
            }

            Text(selectionText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.text)
        }
    }

    private func cell(side: Double, hill: Double) -> some View {
        let selected = sideValue == side && hillValue == hill
        return Button {
            sideValue = side
            hillValue = hill
        } label: {
            Text(icon(side: side, hill: hill))
                .font(.system(size: 20))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(selected ? Theme.primary.opacity(0.25) : Theme.surfaceElevated))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(selected ? Theme.primary : Theme.border, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func icon(side: Double, hill: Double) -> String {
        let h = hill > 0 ? "⬆" : (hill < 0 ? "⬇" : "")
        let s = side < 0 ? "⬅" : (side > 0 ? "➡" : "")
        if h.isEmpty && s.isEmpty { return "●" }
        return "\(h)\(s)"
    }

    private var selectionText: String {
        let side = sideValue == 0 ? L("input.flat") : (sideValue < 0 ? L("input.rl") : L("input.lr"))
        let hill = hillValue == 0 ? L("input.flat") : (hillValue > 0 ? L("input.up") : L("input.down"))
        return "\(side) / \(hill)"
    }
}

#Preview {
    SimpleSlopeGridView(sideValue: .constant(1), hillValue: .constant(-1))
        .padding()
        .background(Theme.background)
}
