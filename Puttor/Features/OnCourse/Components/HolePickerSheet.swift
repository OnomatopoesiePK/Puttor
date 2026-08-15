//
//  HolePickerSheet.swift
//  Puttor
//
//  Tap the hole number in the top bar (live play or post-round editing) to
//  jump directly to any hole in the round's play order.
//

import SwiftUI

struct HolePickerSheet: View {
    let holes: [Int]
    let current: Int
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                    ForEach(holes, id: \.self) { hole in
                        let isCurrent = hole == current
                        Button {
                            onSelect(hole)
                            dismiss()
                        } label: {
                            Text("\(hole)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(isCurrent ? .white : Theme.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(isCurrent ? Theme.primary : Theme.surface))
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(isCurrent ? Theme.primary : Theme.border, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("input.jumpToHole"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("common.cancel")) { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(ThemeManager.shared.colorScheme)
    }
}
