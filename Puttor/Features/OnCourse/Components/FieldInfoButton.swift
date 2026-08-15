//
//  FieldInfoButton.swift
//  Puttor
//
//  Small (ⓘ) button with a popover explanation, for the top-right corner of
//  an input card (slope grid, result dartboard, etc.).
//

import SwiftUI

struct FieldInfoButton: View {
    let titleKey: String
    let textKey: String
    @State private var showInfo = false

    var body: some View {
        Button {
            showInfo = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showInfo) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L(titleKey))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L(textKey))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Spacing.md)
            .frame(width: 260, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(Theme.surface)
            .presentationCompactAdaptation(.popover)
        }
    }
}
