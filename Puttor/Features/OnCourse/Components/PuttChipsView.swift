//
//  PuttChipsView.swift
//  Puttor
//
//  The row of putt chips in the input top bar, shared by Pro, Quick and
//  Custom mode: one chip per recorded putt on the displayed hole (tap to
//  show it), plus a dashed slot for starting the hole's next putt.
//

import SwiftUI

struct PuttChipsView: View {
    let session: RoundSession

    private let side: CGFloat = 32

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Putt 0, where the layout asks about the hole before its
                // first putt: tapped, it opens again to change the answers.
                if !session.prePuttKinds.isEmpty {
                    prePuttChip
                }

                ForEach(Array(session.realPuttsOnHole(session.displayHole).enumerated()), id: \.element.id) { index, putt in
                    let globalIndex = session.allPutts.firstIndex { $0.id == putt.id }
                    chip(
                        number: index + 1,
                        isHoled: putt.result == .holed,
                        isActive: session.reviewIndex == globalIndex
                    ) {
                        if let g = globalIndex { session.loadDraft(fromReviewIndex: g) }
                    }
                }

                // Blank slot for the hole's next putt — tappable, so you can
                // leave a shown putt and add another one on the same hole.
                if session.canStartNewPutt {
                    newPuttSlot
                }
            }
        }
        .horizontalScrollHint(fade: Theme.surface)
    }

    private func chip(number: Int, isHoled: Bool, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isHoled {
                    // A checkmark reads as "this one went in" far more clearly
                    // at chip size than a flag glyph, and it takes the theme
                    // colour instead of staying multicolour.
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Theme.primary)
                } else {
                    Text("\(number)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: side, height: side)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(isHoled ? Theme.primary.opacity(0.2) : Theme.surfaceElevated))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(isActive ? Theme.accent : (isHoled ? Theme.primary : Theme.border), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var prePuttChip: some View {
        let details = session.displayedHoleDetails
        let answered = details.par != nil || details.girOpportunity != nil
        return Button {
            session.openPrePutt()
        } label: {
            Text("0")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(answered ? Theme.text : Theme.textMuted)
                .frame(width: side, height: side)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.surfaceElevated))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(session.isOnPrePutt ? Theme.accent : Theme.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("input.prePutt"))
    }

    private var newPuttSlot: some View {
        Button {
            session.startNewPutt()
        } label: {
            Text("\(session.realPuttsOnHole(session.displayHole).count + 1)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.primary)
                .frame(width: side, height: side)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(session.isReviewing || session.isOnPrePutt ? Color.clear : Theme.primary.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).strokeBorder(Theme.primary, style: StrokeStyle(lineWidth: 1.5, dash: [3])))
        }
        .buttonStyle(.plain)
    }
}
