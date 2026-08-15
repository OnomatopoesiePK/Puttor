//
//  RoutineDrillView.swift
//  Puttor
//
//  Routine Putt Drill: the app randomly prescribes each putt's distance and
//  break within your configured ranges — play it exactly as given, with your
//  full pre-shot routine, no do-overs. Simulates never facing the same putt
//  twice, like on the course.
//

import SwiftUI

struct RoutineDrillView: View {
    var onDone: () -> Void
    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"

    @State private var puttCount: Double = 10
    @State private var minDistance: Double = 1.0
    @State private var maxDistance: Double = 4.0
    @State private var maxBreak: Double = 3

    // Generated once per configuration (not a computed property) so the plan
    // doesn't silently reshuffle under the user while they're mid-drill.
    @State private var generatedPlan: [GamePlanItem] = []

    private var useFeet: Bool { unitsPref == "imperial" }
    private var canStart: Bool { maxDistance >= minDistance }

    private var configSummary: String {
        "\(Int(puttCount)) \(L("game.routine.putts")) · \(UnitConverter.formatDistance(minDistance, useFeet: useFeet))–\(UnitConverter.formatDistance(maxDistance, useFeet: useFeet)) · ±\(Int(maxBreak))%"
    }

    var body: some View {
        DrillSetupShell(
            gameType: .routine, onDone: onDone, plan: generatedPlan, configSummary: configSummary,
            useFeet: useFeet, canStart: canStart
        ) {
            VStack(spacing: Theme.Spacing.md) {
                configCard {
                    Text(L("game.routine.putts")).font(.caption).foregroundStyle(Theme.textMuted)
                    Stepper("\(Int(puttCount))", value: $puttCount, in: 3...30)
                        .foregroundStyle(Theme.text)
                }
                configCard {
                    Text(L("game.routine.minDistance")).font(.caption).foregroundStyle(Theme.textMuted)
                    Stepper(UnitConverter.formatDistance(minDistance, useFeet: useFeet), value: $minDistance, in: 0.5...10, step: 0.5)
                        .foregroundStyle(Theme.text)
                }
                configCard {
                    Text(L("game.routine.maxDistance")).font(.caption).foregroundStyle(Theme.textMuted)
                    Stepper(UnitConverter.formatDistance(maxDistance, useFeet: useFeet), value: $maxDistance, in: 0.5...15, step: 0.5)
                        .foregroundStyle(Theme.text)
                }
                configCard {
                    Text(L("game.routine.maxBreak")).font(.caption).foregroundStyle(Theme.textMuted)
                    Stepper("±\(Int(maxBreak))%", value: $maxBreak, in: 0...3, step: 1)
                        .foregroundStyle(Theme.text)
                }
                if !canStart {
                    Text(L("game.routine.rangeError")).font(.caption).foregroundStyle(Theme.error)
                }
            }
        }
        .onAppear { regenerate() }
        .onChange(of: puttCount) { _, _ in regenerate() }
        .onChange(of: minDistance) { _, _ in regenerate() }
        .onChange(of: maxDistance) { _, _ in regenerate() }
        .onChange(of: maxBreak) { _, _ in regenerate() }
    }

    private func regenerate() {
        guard canStart else { generatedPlan = []; return }
        generatedPlan = (1...Int(puttCount)).map { i in
            let raw = Double.random(in: minDistance...maxDistance)
            let distance = (raw * 2).rounded() / 2
            let breakOptions = maxBreak > 0 ? Array(stride(from: -maxBreak, through: maxBreak, by: 1)) : [0]
            let breakPct = breakOptions.randomElement() ?? 0
            return GamePlanItem(groupIndex: 0, label: "\(L("game.routine.putt")) \(i)", distanceM: distance, breakPct: breakPct)
        }
    }

    private func configCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }
}
