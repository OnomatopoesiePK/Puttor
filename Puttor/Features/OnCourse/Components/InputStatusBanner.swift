//
//  InputStatusBanner.swift
//  Puttor
//
//  The strip under the input top bar: a brief "Saved +0.34 SG" confirmation
//  after each putt, or the standing "EDITING" notice while stored data is
//  being changed.
//
//  Meant to be applied as an overlay rather than placed in the layout, so it
//  appears over the content instead of pushing it down — a strip that shoves
//  everything a row lower for a second reads as a glitch.
//

import SwiftUI

struct InputStatusBanner: View {
    /// Strokes gained by the putt just saved; nil when the flash isn't showing.
    let savedPCG: Double?
    let isEditing: Bool
    /// Landscape has no room to spare and the floating chrome above it, so the
    /// strip shrinks to the height of its own text and sits underneath.
    var compact: Bool = false

    var body: some View {
        if let savedPCG {
            let gained = savedPCG > 0
            let tint = gained ? Theme.primary : Theme.error
            strip(tint: tint) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(L("input.saved"))
                    Text("\(savedPCG >= 0 ? "+" : "")\(String(format: "%.2f", savedPCG)) \(L("stats.pcg"))")
                }
                .font(.system(size: compact ? 11 : 13, weight: .bold))
                .foregroundStyle(tint)
            }
        } else if isEditing {
            strip(tint: Theme.accent) {
                Text(L("input.editing"))
                    .font(.system(size: compact ? 11 : 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private func strip<Content: View>(tint: Color, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 3 : 8)
            // Opaque base under the tint, since this sits over live content.
            .background(tint.opacity(0.15))
            .background(Theme.surface)
            .overlay(Rectangle().fill(tint.opacity(0.4)).frame(height: 1), alignment: .bottom)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
