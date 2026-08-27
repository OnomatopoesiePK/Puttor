//
//  RoundSelectionSheet.swift
//  Puttor
//
//  Pick the exact rounds the statistics run on: tap to include, tap again to
//  drop. Backs the "Choose Rounds" filter on the statistics tab.
//

import SwiftUI

/// Reading order for the round list and the rounds grid.
enum RoundSort: String, CaseIterable, Identifiable {
    case newest, oldest
    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .newest: return "stats.sortNewest"
        case .oldest: return "stats.sortOldest"
        }
    }
}

struct RoundSelectionSheet: View {
    let rounds: [Round]
    @Binding var selectedIDs: Set<String>
    @Binding var sort: RoundSort

    @Environment(\.dismiss) private var dismiss

    private var sorted: [Round] {
        sort == .newest
            ? rounds.sorted { $0.date > $1.date }
            : rounds.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                list
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("stats.choose"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) { dismiss() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.primary)
                }
            }
            .preferredColorScheme(ThemeManager.shared.colorScheme)
        }
    }

    /// Everything that acts on the list as a whole: how it reads, and taking
    /// every round in or out at once.
    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    Picker(L("stats.sort"), selection: $sort) {
                        ForEach(RoundSort.allCases) { option in
                            Text(L(option.labelKey)).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(L(sort.labelKey))
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Theme.surfaceElevated))
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                }

                Spacer(minLength: 0)

                quickAction(L("stats.selectAll")) {
                    selectedIDs = Set(rounds.map { $0.id.uuidString })
                }
                quickAction(L("stats.selectNone")) {
                    selectedIDs = []
                }
            }

            Text(String(format: L("stats.chooseCount"), selectedIDs.count, rounds.count))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func quickAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Theme.primary.opacity(0.12)))
                .overlay(Capsule().stroke(Theme.primary.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(sorted) { round in
                    let isSelected = selectedIDs.contains(round.id.uuidString)
                    Button {
                        if isSelected {
                            selectedIDs.remove(round.id.uuidString)
                        } else {
                            selectedIDs.insert(round.id.uuidString)
                        }
                    } label: {
                        row(round, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
    }

    private func row(_ round: Round, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? Theme.primary : Theme.textMuted)

            VStack(alignment: .leading, spacing: 2) {
                Text(round.courseName.isEmpty ? L("onCourse.unnamedCourse") : round.courseName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(round.date.formatted(date: .abbreviated, time: .omitted))
                    Text("·")
                    Text("\(round.putts.filter { $0.puttNumber > 0 }.count) \(L("summary.puttsAbbr"))")
                    if let putter = round.putter {
                        Text("·")
                        Text(putter.name).lineLimit(1)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(isSelected ? Theme.primary.opacity(0.10) : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(isSelected ? Theme.primary.opacity(0.5) : Theme.border, lineWidth: 1)
        )
    }
}
