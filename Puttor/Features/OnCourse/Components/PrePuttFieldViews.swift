//
//  PrePuttFieldViews.swift
//  Puttor
//
//  The two questions of putt 0, asked once per hole before its first putt:
//  the hole's par, and whether the approach was a real chance at the green
//  in regulation. Both in the chips of the intention field; tapping the
//  chosen answer again clears it.
//

import SwiftUI

struct HoleParFieldView: View {
    @Binding var par: Int?

    var body: some View {
        VStack(spacing: 10) {
            PrePuttFieldTitle(titleKey: "input.holePar", infoKey: "input.holePar.info")
            HStack(spacing: 6) {
                ForEach(HoleDetails.pars, id: \.self) { value in
                    PrePuttChip(title: String(format: L("input.holePar.value"), value), tint: Theme.accent, active: par == value) {
                        par = par == value ? nil : value
                    }
                }
            }
        }
    }
}

struct GirOpportunityFieldView: View {
    @Binding var value: Bool?

    var body: some View {
        VStack(spacing: 10) {
            PrePuttFieldTitle(titleKey: "input.girOpportunity", infoKey: "input.girOpportunity.info")
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
        // No is not a mistake, so it is marked in the accent rather than red.
        PrePuttChip(
            title: L(answer ? "common.yes" : "common.no"),
            icon: answer ? "checkmark" : "xmark",
            tint: answer ? Theme.primary : Theme.accent,
            active: value == answer
        ) {
            value = value == answer ? nil : answer
        }
    }
}

private struct PrePuttFieldTitle: View {
    let titleKey: String
    let infoKey: String

    var body: some View {
        ZStack {
            Text(L(titleKey))
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity)
            HStack {
                Spacer()
                FieldInfoButton(titleKey: titleKey, textKey: infoKey)
            }
        }
    }
}

private struct PrePuttChip: View {
    let title: String
    var icon: String? = nil
    let tint: Color
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 12, weight: .heavy))
                }
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(active ? tint : Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
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
    VStack(spacing: 20) {
        HoleParFieldView(par: .constant(4))
        GirOpportunityFieldView(value: .constant(true))
    }
    .padding()
    .background(Theme.background)
}
