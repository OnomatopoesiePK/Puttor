//
//  SGRecalculation.swift
//  Puttor
//
//  Each putt stores the strokes gained it was worth, computed when it was
//  recorded. Changing the baseline table therefore only affects new putts, and
//  a round played before the change would sit in the statistics alongside newer
//  ones on a different scale. This refreshes them all, once, after such a change.
//

import Foundation
import SwiftData

enum SGRecalculation {
    /// Bump whenever `StrokesGained.tourBaseline` changes.
    ///
    /// 1: the original prototype table.
    /// 2: recalibrated to published Tour figures, with expected putts allowed
    ///    to rise past 2 beyond ~9 m.
    /// 3: putts chained on the real distance they left rather than an assumed one.
    static let currentBaselineVersion = 3

    /// Rewrites every putt on one hole so each is measured against the distance
    /// the previous one actually left. Call after anything that adds, edits,
    /// reorders or removes a putt on the hole — a putt's value depends on its
    /// neighbour, so changing one changes the one before it.
    static func recomputeHole(_ holePutts: [Putt]) {
        let real = holePutts
            .filter { $0.puttNumber > 0 }
            .sorted { $0.puttNumber < $1.puttNumber }

        for (index, putt) in real.enumerated() {
            if putt.result == .holed {
                putt.applySG(nextDistanceM: nil)
            } else if index + 1 < real.count {
                putt.applySG(nextDistanceM: real[index + 1].distanceM)
            } else {
                // Hole still open: estimate until the follow-up is entered.
                putt.applySG(nextDistanceM: StrokesGained.typicalLeave(putt.distanceM))
            }
        }
    }

    /// Groups by round as well as hole number, so two rounds' hole 3 don't merge.
    private struct HoleKey: Hashable {
        let roundID: UUID?
        let hole: Int
        init(_ putt: Putt) {
            roundID = putt.round?.id
            hole = putt.holeNumber
        }
    }

    @MainActor
    static func recomputeIfNeeded(in context: ModelContext) {
        let stored = UserDefaults.standard.integer(forKey: AppStorageKeys.sgBaselineVersion)
        guard stored < currentBaselineVersion else { return }

        guard let putts = try? context.fetch(FetchDescriptor<Putt>()) else { return }
        for (_, holePutts) in Dictionary(grouping: putts, by: { HoleKey($0) }) {
            recomputeHole(holePutts)
        }
        try? context.save()

        UserDefaults.standard.set(currentBaselineVersion, forKey: AppStorageKeys.sgBaselineVersion)
    }
}
