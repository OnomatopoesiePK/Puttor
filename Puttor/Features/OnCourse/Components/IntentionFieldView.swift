//
//  IntentionFieldView.swift
//  Puttor
//
//  What the putt is meant to do, one row per part switched on in Settings —
//  the situation only in match play — and, once anything is chosen, whether
//  it came off. Tapping a chosen option again clears it.
//

import SwiftUI

struct IntentionFieldView: View {
    let parts: [IntentionPart]
    let isMatchPlay: Bool
    var useFeet = false
    @Binding var intention: PuttIntention

    private var shownParts: [IntentionPart] {
        parts.filter { $0 != .situation || isMatchPlay }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(L("input.intention"))
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMuted)

            if shownParts.isEmpty {
                Text(L("intention.matchPlayOnly"))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }

            ForEach(shownParts) { part in
                VStack(alignment: .leading, spacing: 5) {
                    Text(L(part.titleKey))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 6) {
                        options(part)
                    }
                }
            }

            if !intention.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L("intention.executedQuestion"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 6) {
                        execution(true)
                        execution(false)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: intention.isEmpty)
    }

    @ViewBuilder
    private func options(_ part: IntentionPart) -> some View {
        switch part {
        case .goal:
            ForEach(PuttGoal.allCases) { goal in
                chip(L(goal.labelKey), active: intention.goal == goal) {
                    update { $0.goal = $0.goal == goal ? nil : goal }
                }
            }
        case .speed:
            ForEach(PuttSpeed.allCases) { speed in
                chip(L(speed.labelKey), detail: speed == .pelz ? pelzDetail : nil, active: intention.speed == speed) {
                    update { $0.speed = $0.speed == speed ? nil : speed }
                }
            }
        case .line:
            ForEach(PuttLine.allCases) { line in
                chip(L(line.labelKey), active: intention.line == line) {
                    update { $0.line = $0.line == line ? nil : line }
                }
            }
        case .situation:
            ForEach(PuttSituation.allCases) { situation in
                chip(L(situation.labelKey), active: intention.situation == situation) {
                    update { $0.situation = $0.situation == situation ? nil : situation }
                }
            }
        }
    }

    private var pelzDetail: String { useFeet ? "+17 in" : "+43 cm" }

    /// Changes the intention; with nothing left chosen, whether it came off
    /// goes too.
    private func update(_ change: (inout PuttIntention) -> Void) {
        var changed = intention
        change(&changed)
        if changed.isEmpty { changed.executed = nil }
        intention = changed
    }

    private func execution(_ value: Bool) -> some View {
        chip(
            L(value ? "intention.executed" : "intention.notExecuted"),
            icon: value ? "checkmark" : "xmark",
            tint: value ? Theme.primary : Theme.error,
            active: intention.executed == value
        ) {
            update { $0.executed = $0.executed == value ? nil : value }
        }
    }

    private func chip(
        _ title: String,
        detail: String? = nil,
        icon: String? = nil,
        tint: Color = Theme.accent,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                HStack(spacing: 4) {
                    if let icon {
                        Image(systemName: icon).font(.system(size: 12, weight: .heavy))
                    }
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                if let detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .opacity(0.8)
                }
            }
            .foregroundStyle(active ? tint : Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 40)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(active ? tint.opacity(0.13) : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(active ? tint : Theme.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(detail.map { "\(title) \($0)" } ?? title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
