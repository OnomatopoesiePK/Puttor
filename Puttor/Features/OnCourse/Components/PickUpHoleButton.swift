//
//  PickUpHoleButton.swift
//  Puttor
//
//  Giving a hole up. Sits next to the bin and is its exact opposite: there
//  while the hole is still empty, gone the moment anything is recorded on it —
//  so the two never appear together and the corner never grows.
//
//  Shared by all three input modes, which otherwise each had their own copy of
//  the same corner.
//

import SwiftUI

struct PickUpHoleButton: View {
    let session: RoundSession
    /// Handed the outcome so the screen can react the way it does to a holed
    /// putt — the last hole of a round ends it either way.
    var onPicked: (RoundOutcome) -> Void

    @State private var confirming = false

    var body: some View {
        if session.canPickUpBall {
            Button {
                confirming = true
            } label: {
                PickUpBallIcon()
                    .fill(Theme.accent)
                    .frame(width: 19, height: 19)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.accent.opacity(0.13)))
                    .overlay(Circle().stroke(Theme.accent, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("input.pickUp"))
            .confirmationDialog(
                String(format: L("input.pickUpConfirm"), session.displayHole),
                isPresented: $confirming,
                titleVisibility: .visible
            ) {
                Button(L("input.pickUp")) { onPicked(session.pickUpBall()) }
                Button(L("common.cancel"), role: .cancel) {}
            } message: {
                Text(L("input.pickUpMessage"))
            }
        }
    }
}
