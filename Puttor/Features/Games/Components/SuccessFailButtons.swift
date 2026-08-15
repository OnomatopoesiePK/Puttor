//
//  SuccessFailButtons.swift
//  Puttor
//
//  Shared big ✓ / ✗ pair used across every drill's play screen.
//

import SwiftUI

struct SuccessFailButtons: View {
    var successLabel: String
    var failLabel: String
    var onSuccess: () -> Void
    var onFail: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            button(label: failLabel, icon: "xmark", color: Theme.error, action: onFail)
            button(label: successLabel, icon: "checkmark", color: Theme.primary, action: onSuccess)
        }
    }

    private func button(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 26, weight: .heavy))
                Text(label).font(.system(size: 15, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(color))
        }
        .buttonStyle(.plain)
    }
}
