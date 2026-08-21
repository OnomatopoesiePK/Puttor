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
    static let currentBaselineVersion = 2

    @MainActor
    static func recomputeIfNeeded(in context: ModelContext) {
        let stored = UserDefaults.standard.integer(forKey: AppStorageKeys.sgBaselineVersion)
        guard stored < currentBaselineVersion else { return }

        guard let putts = try? context.fetch(FetchDescriptor<Putt>()) else { return }
        // Hole-out sentinels carry no distance and no strokes gained.
        for putt in putts where putt.puttNumber > 0 {
            putt.recomputeSG()
        }
        try? context.save()

        UserDefaults.standard.set(currentBaselineVersion, forKey: AppStorageKeys.sgBaselineVersion)
    }
}
