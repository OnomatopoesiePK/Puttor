//
//  ClockDrillView.swift
//  Puttor
//
//  Clock Drill: balls placed around the hole like numbers on a clock, all at
//  the same distance, putted in order around the circle to feel different
//  breaks without the distance changing.
//

import SwiftUI

struct ClockDrillView: View {
    var onDone: () -> Void
    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"

    @State private var positionCount: Int = 4
    @State private var distance: Double = 1.2
    @State private var laps: Int = 2

    private var useFeet: Bool { unitsPref == "imperial" }
    private static let positionOptions = [3, 4, 6, 12]

    private var clockHours: [Int] {
        let step = 12 / positionCount
        return (0..<positionCount).map { i in
            let hour = (i * step) % 12
            return hour == 0 ? 12 : hour
        }
    }

    private var plan: [GamePlanItem] {
        var items: [GamePlanItem] = []
        for lap in 1...laps {
            for hour in clockHours {
                items.append(GamePlanItem(
                    groupIndex: lap,
                    label: "\(L("game.clock.round")) \(lap) · \(hour) \(L("game.clock.oclock"))",
                    distanceM: distance
                ))
            }
        }
        return items
    }

    private var configSummary: String {
        "\(positionCount) \(L("game.clock.positions")) · \(UnitConverter.formatDistance(distance, useFeet: useFeet)) · \(laps) \(L("game.clock.laps"))"
    }

    var body: some View {
        DrillSetupShell(gameType: .clock, onDone: onDone, plan: plan, configSummary: configSummary, useFeet: useFeet) {
            VStack(spacing: Theme.Spacing.md) {
                configCard {
                    Text(L("game.clock.positions")).font(.caption).foregroundStyle(Theme.textMuted)
                    Picker("", selection: $positionCount) {
                        ForEach(Self.positionOptions, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                configCard {
                    Text(L("game.distance")).font(.caption).foregroundStyle(Theme.textMuted)
                    Stepper(UnitConverter.formatDistance(distance, useFeet: useFeet), value: $distance, in: 0.5...5, step: 0.25)
                        .foregroundStyle(Theme.text)
                }
                configCard {
                    Text(L("game.clock.laps")).font(.caption).foregroundStyle(Theme.textMuted)
                    Stepper("\(laps)", value: $laps, in: 1...10)
                        .foregroundStyle(Theme.text)
                }
            }
        } breakdown: { session in
            if let hardest = hardestPosition(session) {
                VStack(spacing: 4) {
                    Text(L("game.clock.hardest")).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
                    Text(hardest).font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.error)
                }
                .padding(.top, 4)
            }
        }
    }

    private func hardestPosition(_ session: GameSession) -> String? {
        let misses = session.attempts.filter { !$0.success }
        guard !misses.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for m in misses {
            let position = m.label.components(separatedBy: "· ").last ?? m.label
            counts[position, default: 0] += 1
        }
        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        return "\(top.key) (\(top.value)×)"
    }

    private func configCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }
}
