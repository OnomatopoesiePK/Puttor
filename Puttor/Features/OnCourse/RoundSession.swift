//
//  RoundSession.swift
//  Puttor
//
//  In-memory state machine for entering putts during a round. Plays the role
//  of the prototype's store/roundStore.ts (a zustand store), adapted to
//  SwiftData persistence and to the spec additions not present in the
//  prototype: hole sequencing that can start on 10, and putt-for-category
//  auto-advance.
//

import Foundation
import SwiftData
import Observation

enum RoundOutcome {
    /// Putt was holed and the round reached the last hole of its sequence — ask the user whether to end it.
    case reachedSequenceEnd
    /// Putt was holed; moved on to the next hole.
    case advancedToNextHole
    /// Putt was missed; still on the same hole.
    case missed
    /// An existing putt was edited in place.
    case edited
}

@Observable
final class RoundSession {
    let round: Round
    private let modelContext: ModelContext

    var currentHole: Int
    var reviewIndex: Int?

    // Draft fields for the putt currently being entered/edited.
    var draftDistanceM: Double
    var draftSideSlopePct: Double = 0
    var draftHillSlopePct: Double = 0
    var draftDoubleBreak: DoubleBreakType?
    var draftPuttFor: ScoreCategory = .birdie
    var draftResult: PuttResult?
    var draftLipOut = false
    var draftMissRead = false
    var draftBadStroke = false
    var draftBadStrokeType: BadStrokeType?
    var draftWrongAim = false

    /// PCG of the putt most recently saved by recordDraft()/recordTapIn() — used
    /// to show the "Saved +0.34" / "Saved -0.18" flash after every save.
    var lastSavedPCG: Double?
    /// Set when a putt for birdie or eagle drops, so the input screen can put
    /// the wordmark up. Cleared by the view once it has shown it.
    var celebration: ScoreCategory?

    /// Set by the input view: does the surface the player is using actually ask
    /// which score the putt is for? Custom mode can leave that field out.
    var asksForScoreCategory: Bool = true

    private let defaultFirstPuttDistance: Double
    private let useFeet: Bool
    /// Distance a putt defaults to after a miss (2ft in imperial, 1m in metric).
    private var defaultFollowUpDistance: Double { useFeet ? UnitConverter.feetToMetres(2) : 1.0 }
    /// Tap-in distance (exactly 1ft in imperial, 0.3m in metric).
    private var tapInDistance: Double { UnitConverter.underThresholdM(useFeet: useFeet) }

    /// True when this session was opened to fix up a specific hole after the
    /// round was already finished — saving an edit must never auto-advance to
    /// another hole or trigger the "end of round" prompt.
    let isPostRoundEdit: Bool

    init(round: Round, modelContext: ModelContext, initialHole: Int? = nil, isPostRoundEdit: Bool = false) {
        self.round = round
        self.modelContext = modelContext
        self.isPostRoundEdit = isPostRoundEdit
        let stored = UserDefaults.standard.double(forKey: AppStorageKeys.defaultFirstPuttDistance)
        let rawDefault = stored > 0 ? stored : 5.0
        let feetMode = (UserDefaults.standard.string(forKey: AppStorageKeys.units) ?? "metric") == "imperial"
        self.useFeet = feetMode
        // Snap onto the picker's actual steps — the settings value may have been
        // set in the other unit (or on a slider granularity the picker doesn't
        // share), and an unmatched value leaves the picker unable to scroll to
        // it, silently landing on its first item instead.
        self.defaultFirstPuttDistance = UnitConverter.snapToNearest(rawDefault, useFeet: feetMode)
        self.draftDistanceM = self.defaultFirstPuttDistance
        self.currentHole = initialHole ?? round.holeSequence.first ?? 1
        if let initialHole {
            jumpToHole(initialHole)
        } else {
            restorePosition()
        }
    }

    // MARK: - Derived

    var holeSequence: [Int] { round.holeSequence }

    var allPutts: [Putt] {
        round.putts.sorted {
            $0.holeNumber != $1.holeNumber ? $0.holeNumber < $1.holeNumber : $0.createdAt < $1.createdAt
        }
    }

    var isReviewing: Bool { reviewIndex != nil }

    var reviewedPutt: Putt? {
        guard let i = reviewIndex, allPutts.indices.contains(i) else { return nil }
        return allPutts[i]
    }

    var displayHole: Int { reviewedPutt?.holeNumber ?? currentHole }

    func puttsOnHole(_ hole: Int) -> [Putt] {
        allPutts.filter { $0.holeNumber == hole }.sorted { $0.puttNumber < $1.puttNumber }
    }

    /// Putts on a hole, excluding the puttNumber == 0 "holed out, 0 putts" sentinel.
    /// Use this for anything that means "putts you can review/count/number", since
    /// the sentinel isn't a putt — it's a marker that the hole was played without one.
    func realPuttsOnHole(_ hole: Int) -> [Putt] {
        puttsOnHole(hole).filter { $0.puttNumber > 0 }
    }

    var canRecord: Bool { draftResult != nil || draftLipOut }

    /// True only when a stored putt is loaded *and* the draft has actually been
    /// changed away from it. Merely landing on a hole that already has putts is
    /// browsing, not editing — the "EDITING" banner keys off this so it only
    /// appears when existing data is genuinely being modified.
    var hasUnsavedEdits: Bool {
        guard let p = reviewedPutt else { return false }
        return draftDistanceM != p.distanceM
            || draftSideSlopePct != p.sideSlopePct
            || draftHillSlopePct != p.hillSlopePct
            || draftDoubleBreak != p.doubleBreak
            || draftPuttFor != p.puttFor
            || draftResult != p.result
            || draftLipOut != p.lipOut
            || draftMissRead != p.missRead
            || draftBadStroke != p.badStroke
            || draftBadStrokeType != p.badStrokeType
            || draftWrongAim != p.wrongAim
    }

    /// The displayed hole still needs another putt — either nothing is recorded
    /// yet, or the last putt was a miss. Drives the "start a new putt" slot so a
    /// hole can always be filled in, whichever hole you navigated to.
    var canStartNewPutt: Bool {
        guard let last = realPuttsOnHole(displayHole).last else { return true }
        return last.result != .holed
    }

    private var isAtLastHoleOfSequence: Bool {
        currentHole == holeSequence.last
    }

    private var displayHoleIndex: Int? { holeSequence.firstIndex(of: displayHole) }

    var canGoPreviousHole: Bool { (displayHoleIndex ?? 0) > 0 }
    var canGoNextHole: Bool {
        guard let idx = displayHoleIndex else { return false }
        return idx + 1 < holeSequence.count
    }

    // MARK: - Position restore (resume an in-progress round)

    private func restorePosition() {
        let seq = holeSequence
        var lastPlayedIndex: Int?
        for (i, hole) in seq.enumerated() where !puttsOnHole(hole).isEmpty {
            lastPlayedIndex = i
        }
        guard let idx = lastPlayedIndex else { return }
        let hole = seq[idx]
        guard let last = puttsOnHole(hole).last else { return }
        if last.result == .holed {
            currentHole = idx + 1 < seq.count ? seq[idx + 1] : hole
            // resetDraft() defaults already match "fresh hole" (default distance, birdie).
        } else {
            // Resuming mid-hole after a miss: restore the same "post-miss" draft
            // defaults recordDraft()/resetAfterMiss() would have set at the time.
            currentHole = hole
            draftDistanceM = defaultFollowUpDistance
            draftPuttFor = last.puttFor.next
        }
    }

    /// Jump directly to a hole: loads its *last* real putt if it has any (that's
    /// the one you'd normally want to correct), otherwise starts a fresh draft
    /// for a new putt there. A hole recorded as a 0-putt hole-out has no *real*
    /// putt, so this correctly drops you into normal new-putt entry for it.
    func jumpToHole(_ hole: Int) {
        currentHole = hole
        let existing = realPuttsOnHole(hole)
        if let last = existing.last, let idx = allPutts.firstIndex(where: { $0.id == last.id }) {
            loadDraft(fromReviewIndex: idx)
        } else {
            resetDraft()
        }
    }

    /// Step one hole back/forward through the round's play order. The arrows are
    /// pure navigation — walking onto a finished hole just shows it, and walking
    /// past an empty one leaves it empty (it only becomes a 0-putt hole-out when
    /// the round is ended).
    func goToPreviousHole() {
        guard let idx = displayHoleIndex, idx > 0 else { return }
        jumpToHole(holeSequence[idx - 1])
    }

    func goToNextHole() {
        guard let idx = displayHoleIndex, idx + 1 < holeSequence.count else { return }
        jumpToHole(holeSequence[idx + 1])
    }

    /// Leaves review and opens a blank slot for the next putt on the displayed
    /// hole — the first one if the hole is untouched, otherwise the follow-up to
    /// the miss that's already there.
    func startNewPutt() {
        guard canStartNewPutt else { return }
        currentHole = displayHole
        if let last = realPuttsOnHole(displayHole).last {
            resetAfterMiss(previousPuttFor: last.puttFor)
        } else {
            resetDraft()
        }
    }

    // MARK: - Draft management

    func resetDraft() {
        draftDistanceM = defaultFirstPuttDistance
        draftSideSlopePct = 0
        draftHillSlopePct = 0
        draftDoubleBreak = nil
        draftPuttFor = .birdie
        draftResult = nil
        draftLipOut = false
        draftMissRead = false
        draftBadStroke = false
        draftBadStrokeType = nil
        draftWrongAim = false
        reviewIndex = nil
    }

    private func resetAfterMiss(previousPuttFor: ScoreCategory) {
        draftDistanceM = defaultFollowUpDistance
        draftSideSlopePct = 0
        draftHillSlopePct = 0
        draftDoubleBreak = nil
        draftPuttFor = previousPuttFor.next
        draftResult = nil
        draftLipOut = false
        draftMissRead = false
        draftBadStroke = false
        draftBadStrokeType = nil
        draftWrongAim = false
        reviewIndex = nil
    }

    func loadDraft(fromReviewIndex index: Int) {
        guard allPutts.indices.contains(index) else { return }
        let p = allPutts[index]
        reviewIndex = index
        draftDistanceM = p.distanceM
        draftSideSlopePct = p.sideSlopePct
        draftHillSlopePct = p.hillSlopePct
        draftDoubleBreak = p.doubleBreak
        draftPuttFor = p.puttFor
        draftResult = p.result
        draftLipOut = p.lipOut
        draftMissRead = p.missRead
        draftBadStroke = p.badStroke
        draftBadStrokeType = p.badStrokeType
        draftWrongAim = p.wrongAim
    }

    // MARK: - Recording

    @discardableResult
    func recordDraft() -> RoundOutcome {
        let effectiveResult = draftResult ?? (draftLipOut ? .holeHigh : .missedGeneric)
        let effectiveDistance = draftDistanceM < 0.5 ? tapInDistance : draftDistanceM

        if let putt = reviewedPutt {
            let wasHoled = putt.result == .holed
            putt.distanceM = effectiveDistance
            putt.sideSlopePct = draftSideSlopePct
            putt.hillSlopePct = draftHillSlopePct
            putt.doubleBreak = draftDoubleBreak
            putt.puttFor = draftPuttFor
            putt.result = effectiveResult
            putt.lipOut = draftLipOut
            putt.missRead = draftMissRead
            putt.badStroke = draftBadStroke
            putt.badStrokeType = draftBadStroke ? draftBadStrokeType : nil
            putt.wrongAim = draftWrongAim
            lastSavedPCG = putt.pcg

            if effectiveResult == .holed {
                // Holing out here ends the hole — anything recorded after it no longer applies.
                deletePutts(after: putt)
            } else if !wasHoled {
                // Was a miss and still is: keep every later putt on this hole's "putt for"
                // chain consistent with the category we just changed (e.g. birdie -> par
                // here means the next putt shifts from par -> bogey, and so on).
                cascadePuttForCategories(after: putt)
            }
            try? modelContext.save()
            let editedPuttID = putt.id

            if wasHoled && effectiveResult != .holed {
                // Un-holing a previously-made putt means the hole isn't finished anymore —
                // automatically add the natural follow-up putt instead of leaving a gap
                // the user has to notice and fill in themselves.
                currentHole = putt.holeNumber
                let followUp = Putt(
                    holeNumber: putt.holeNumber,
                    puttNumber: putt.puttNumber + 1,
                    distanceM: defaultFollowUpDistance,
                    puttFor: putt.puttFor.next,
                    result: .missedGeneric
                )
                followUp.round = round
                round.putts.append(followUp)
                modelContext.insert(followUp)
                try? modelContext.save()

                if let idx = allPutts.firstIndex(where: { $0.id == followUp.id }) {
                    loadDraft(fromReviewIndex: idx)
                } else {
                    resetAfterMiss(previousPuttFor: putt.puttFor)
                }
                return .edited
            }

            if isPostRoundEdit {
                // Fixing up historical data must never spawn a fresh "new putt" slot —
                // always land back on the putt that was just edited.
                if let idx = allPutts.firstIndex(where: { $0.id == editedPuttID }) {
                    loadDraft(fromReviewIndex: idx)
                } else {
                    resetDraft()
                }
                return .edited
            }

            if effectiveResult == .holed && putt.holeNumber == currentHole {
                resetDraft()
                return advanceAfterHole()
            }
            if let idx = allPutts.firstIndex(where: { $0.id == editedPuttID }) {
                loadDraft(fromReviewIndex: idx)
            } else {
                resetDraft()
            }
            return .edited
        }

        let puttNumber = realPuttsOnHole(currentHole).count + 1
        // If this hole was previously recorded as a 0-putt hole-out, a real putt
        // now being recorded here supersedes that — the two are mutually exclusive.
        deleteSentinel(forHole: currentHole)
        let putt = Putt(
            holeNumber: currentHole,
            puttNumber: puttNumber,
            distanceM: effectiveDistance,
            sideSlopePct: draftSideSlopePct,
            hillSlopePct: draftHillSlopePct,
            doubleBreak: draftDoubleBreak,
            puttFor: draftPuttFor,
            result: effectiveResult,
            lipOut: draftLipOut,
            missRead: draftMissRead,
            badStroke: draftBadStroke,
            badStrokeType: draftBadStroke ? draftBadStrokeType : nil,
            wrongAim: draftWrongAim
        )
        putt.round = round
        round.putts.append(putt)
        modelContext.insert(putt)
        if asksForScoreCategory { round.tracksScoreCategory = true }
        try? modelContext.save()
        lastSavedPCG = putt.pcg
        // Only the two that are worth a shout, and only when the field that
        // says which is even on screen.
        if asksForScoreCategory, effectiveResult == .holed, putt.puttFor == .birdie || putt.puttFor == .eagle {
            celebration = putt.puttFor
        }

        if effectiveResult == .holed {
            if isPostRoundEdit {
                // The hole is finished at this putt — land back in review on it
                // instead of resetting into a "new putt" slot that would let the
                // user keep adding putts to an already-finished hole indefinitely.
                if let idx = allPutts.firstIndex(where: { $0.id == putt.id }) {
                    loadDraft(fromReviewIndex: idx)
                } else {
                    resetDraft()
                }
                return .edited
            }
            resetDraft()
            return advanceAfterHole()
        } else {
            resetAfterMiss(previousPuttFor: draftPuttFor)
            return .missed
        }
    }

    /// Tap-in: holed at a fixed near-zero distance (0.3m metric, exactly 1ft imperial), break irrelevant.
    @discardableResult
    func recordTapIn() -> RoundOutcome {
        draftResult = .holed
        draftDistanceM = tapInDistance
        draftSideSlopePct = 0
        draftHillSlopePct = 0
        draftLipOut = false
        draftMissRead = false
        draftBadStroke = false
        draftBadStrokeType = nil
        draftWrongAim = false
        return recordDraft()
    }

    /// Records a hole as holed out from off the green (chip-in, etc.) — 0 putts.
    /// During play this is never called directly: a hole simply stays empty
    /// while the round is live, and `endRound` converts whatever is still empty
    /// into hole-outs. Kept for the explicit case and used by that conversion.
    /// `puttFor` on a sentinel is the score the hole was holed out for, which is
    /// what the scoring, GIR and scramble stats read.
    private func insertHoleOutSentinel(forHole hole: Int, puttFor: ScoreCategory = .par) {
        let sentinel = Putt(holeNumber: hole, puttNumber: 0, distanceM: 0, puttFor: puttFor, result: .holed)
        sentinel.round = round
        round.putts.append(sentinel)
        modelContext.insert(sentinel)
    }

    /// Deletes every putt (including a hole-out sentinel) recorded for `hole` —
    /// for fixing a hole that was entered by mistake and never actually played.
    ///
    /// In a finished round every hole is either putts or a hole-out, so clearing
    /// one there leaves a hole-out behind rather than a hole that is part of the
    /// round but has no record at all.
    @discardableResult
    func deleteAllPuttsOnHole(_ hole: Int) -> Bool {
        let toDelete = round.putts.filter { $0.holeNumber == hole }
        guard !toDelete.isEmpty else { return false }
        let previousCategory = toDelete.min { $0.puttNumber < $1.puttNumber }?.puttFor ?? .par
        for p in toDelete {
            round.putts.removeAll { $0.id == p.id }
            modelContext.delete(p)
        }
        if round.isComplete {
            insertHoleOutSentinel(forHole: hole, puttFor: previousCategory)
        }
        try? modelContext.save()
        currentHole = hole
        resetDraft()
        return true
    }

    /// Saves a category change on a hole that has no real putts — the hole-out's
    /// score, which drives whether it counts as a GIR or a scramble save. Used
    /// when editing such a hole and only the putt-for was changed.
    @discardableResult
    func updateHoleOutCategory(_ hole: Int, to category: ScoreCategory) -> Bool {
        guard realPuttsOnHole(hole).isEmpty else { return false }
        let sentinels = round.putts.filter { $0.holeNumber == hole && $0.puttNumber == 0 }
        guard !sentinels.isEmpty else { return false }
        for sentinel in sentinels {
            sentinel.puttFor = category
        }
        try? modelContext.save()
        return true
    }

    /// True when the displayed hole is recorded as a hole-out with no real putts,
    /// so the screen should offer the hole-out's category rather than putt entry.
    var isDisplayingHoleOut: Bool {
        realPuttsOnHole(displayHole).isEmpty && !puttsOnHole(displayHole).isEmpty
    }

    var displayedHoleOutCategory: ScoreCategory? {
        guard isDisplayingHoleOut else { return nil }
        return puttsOnHole(displayHole).first { $0.puttNumber == 0 }?.puttFor
    }

    private func advanceAfterHole() -> RoundOutcome {
        if isAtLastHoleOfSequence { return .reachedSequenceEnd }
        guard let idx = holeSequence.firstIndex(of: currentHole), idx + 1 < holeSequence.count else {
            return .reachedSequenceEnd
        }
        currentHole = holeSequence[idx + 1]
        return .advancedToNextHole
    }

    private func deleteSentinel(forHole hole: Int) {
        let sentinels = round.putts.filter { $0.holeNumber == hole && $0.puttNumber == 0 }
        for s in sentinels {
            round.putts.removeAll { $0.id == s.id }
            modelContext.delete(s)
        }
    }

    private func deletePutts(after putt: Putt) {
        let toDelete = round.putts.filter { $0.holeNumber == putt.holeNumber && $0.puttNumber > putt.puttNumber }
        for p in toDelete {
            round.putts.removeAll { $0.id == p.id }
            modelContext.delete(p)
        }
    }

    /// Re-chains every later putt on the same hole's "putt for" category off of
    /// `putt`'s (now possibly-edited) category, so e.g. changing putt 1 from
    /// birdie to par correctly shifts putt 2 from par to bogey, putt 3 from
    /// bogey to double+, etc.
    private func cascadePuttForCategories(after putt: Putt) {
        let subsequent = round.putts
            .filter { $0.holeNumber == putt.holeNumber && $0.puttNumber > putt.puttNumber }
            .sorted { $0.puttNumber < $1.puttNumber }
        var previous = putt.puttFor
        for p in subsequent {
            let next = previous.next
            if p.puttFor != next { p.puttFor = next }
            previous = next
        }
    }

    // MARK: - Navigation through recorded putts

    func reviewPrevious() {
        let idx = reviewIndex.map { $0 - 1 } ?? (allPutts.count - 1)
        guard idx >= 0 else { return }
        loadDraft(fromReviewIndex: idx)
    }

    func reviewNext() {
        guard let idx = reviewIndex else { return }
        if idx + 1 < allPutts.count {
            loadDraft(fromReviewIndex: idx + 1)
        } else {
            resetDraft()
        }
    }

    // MARK: - Ending the round

    /// Ends the round, settling which still-empty holes were genuine 0-putt
    /// hole-outs.
    ///
    /// A hole the player moved *past* — one with entries after it — was played
    /// without putting, so it becomes a hole-out. Empty holes at the *end*
    /// normally just mean the round was cut short and are left out of it
    /// entirely, since counting them would drag the round's stats down for
    /// holes that were never played. The exception is a round that is all but
    /// complete (within two holes of its full length): there the trailing
    /// blanks really are hole-outs, so they're filled in too.
    func endRound(holeCount: Int) {
        let roundHoles = Array(holeSequence.prefix(holeCount))
        let isPlayed: (Int) -> Bool = { !self.puttsOnHole($0).isEmpty }
        let playedCount = roundHoles.filter(isPlayed).count
        let fillTrailingBlanks = playedCount >= holeCount - 2
        let lastPlayedIndex = roundHoles.lastIndex(where: isPlayed)

        for (index, hole) in roundHoles.enumerated() where !isPlayed(hole) {
            let wasSkippedOver = lastPlayedIndex.map { index < $0 } ?? false
            guard wasSkippedOver || fillTrailingBlanks else { continue }
            insertHoleOutSentinel(forHole: hole)
        }

        round.holeCount = holeCount
        round.isComplete = true
        try? modelContext.save()
    }

    var playedHoleCount: Int {
        Set(allPutts.map { $0.holeNumber }).count
    }

    /// Total putts taken so far, excluding 0-putt hole-out sentinels — matches
    /// what RoundStats/the round summary counts, so the in-round "TOTAL" badge
    /// never disagrees with the summary once the round is saved.
    var totalRealPutts: Int {
        allPutts.filter { $0.puttNumber > 0 }.count
    }
}
