//
//  PulseHighlight.swift
//  Puttor
//
//  A slow breath of light behind a number that earned it. Used on the round
//  summary, where a handful of thresholds — under par, strokes gained past
//  two, greens hit, scrambles saved, putts per hole — are worth catching the
//  eye without shouting.
//

import SwiftUI

private struct PulseHighlight: ViewModifier {
    let isActive: Bool
    let color: Color

    @State private var on = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(color.opacity(isActive && on ? 0.55 : 0.05))
                    .shadow(color: color.opacity(isActive && on ? 0.9 : 0), radius: on ? 22 : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(color.opacity(isActive ? (on ? 1 : 0.4) : 0), lineWidth: isActive ? 3 : 0)
            )
            // Four times the swing it had: the box grows by eight percent
            // rather than two, and breathes a little faster with it.
            .scaleEffect(isActive && on ? 1.08 : 1)
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

extension View {
    /// Marks a value as one worth noticing. Inactive leaves the view untouched,
    /// so the same call site works for a good round and an ordinary one.
    func pulsingHighlight(_ isActive: Bool, color: Color = Theme.primary) -> some View {
        modifier(PulseHighlight(isActive: isActive, color: color))
    }
}

/// The marks that count as a good round. Kept in one place so the summary and
/// anything later that wants to praise the same things agree on what "good"
/// means.
enum RoundHighlights {
    static func scoreUnderPar(_ strokesRelativeToPar: Int) -> Bool { strokesRelativeToPar < 0 }
    static func strongStrokesGained(_ sgTotal: Double) -> Bool { sgTotal >= 2 }
    /// Fourteen greens out of eighteen, as a rate so nine-hole rounds count too.
    static func strongGreensInRegulation(_ girPercent: Double) -> Bool { girPercent >= 14.0 / 18.0 * 100 }
    static func strongScrambling(_ scramblePercent: Double) -> Bool { scramblePercent >= 70 }
    static func lowPuttsPerHole(_ average: Double) -> Bool { average > 0 && average < 1.5 }
}
