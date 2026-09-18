//
//  GirOpportunityFieldView.swift
//  Puttor
//
//  Whether the approach into the hole was a real chance at the green in
//  regulation: a clear shot at it, within reach. Asked with the hole's first
//  putt, in the chips of the intention field. Tapping the chosen answer
//  again clears it.
//

import SwiftUI

struct GirOpportunityFieldView: View {
    @Binding var value: Bool?

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Text(L("input.girOpportunity"))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity)
                HStack {
                    Spacer()
                    FieldInfoButton(titleKey: "input.girOpportunity", textKey: "input.girOpportunity.info")
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(L("input.girOpportunity.question"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 6) {
                    answer(true)
                    answer(false)
                }
            }
        }
    }

    private func answer(_ answer: Bool) -> some View {
        let active = value == answer
        // No is not a mistake, so it is marked in the accent rather than red.
        let tint = answer ? Theme.primary : Theme.accent
        let title = L(answer ? "common.yes" : "common.no")
        return Button {
            value = active ? nil : answer
        } label: {
            HStack(spacing: 4) {
                Image(systemName: answer ? "checkmark" : "xmark")
                    .font(.system(size: 12, weight: .heavy))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(active ? tint : Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 40)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(active ? tint.opacity(0.13) : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(active ? tint : Theme.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

#Preview {
    GirOpportunityFieldView(value: .constant(true))
        .padding()
        .background(Theme.background)
}
