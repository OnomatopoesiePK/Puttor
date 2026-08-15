//
//  DoubleBreakButtonsView.swift
//  Puttor
//

import SwiftUI

struct DoubleBreakButtonsView: View {
    @Binding var value: DoubleBreakType?

    var body: some View {
        VStack(spacing: 6) {
            Text(L("input.doubleBreak"))
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMuted)

            HStack(spacing: 10) {
                button(.rlThenLr, icon: "↩")
                button(.lrThenRl, icon: "↪")
            }
        }
    }

    private func button(_ type: DoubleBreakType, icon: String) -> some View {
        let active = value == type
        return Button {
            value = (value == type) ? nil : type
        } label: {
            HStack(spacing: 6) {
                Text(icon).font(.system(size: 18)).foregroundStyle(Theme.text)
                Text(L(type.labelKey))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(active ? Theme.accent : Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(active ? Theme.accent.opacity(0.13) : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(active ? Theme.accent : Theme.border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
