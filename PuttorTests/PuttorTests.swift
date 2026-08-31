//
//  PuttorTests.swift
//  PuttorTests
//
//  Created by Paul Kaineder on 23.07.26.
//

import Testing
import Foundation
import SwiftData
@testable import Puttor

struct PuttorTests {

    // MARK: - Games: scoring

    @Test func gameTypeLowerScoreIsBetterOnlyForCyclesStrokesAndTime() async throws {
        for gameType in GameType.allCases {
            let expected = gameType == .ninePutt || gameType == .aroundTheWorld || gameType == .aroundTheHole
            #expect(gameType.lowerScoreIsBetter == expected)
        }
    }

    @Test func bestSessionPicksHighestPercentForMakePercentGames() async throws {
        let low = GameSession(gameType: .gate); low.isComplete = true; low.score = 60
        let high = GameSession(gameType: .gate); high.isComplete = true; high.score = 90
        let incomplete = GameSession(gameType: .gate); incomplete.isComplete = false; incomplete.score = 99

        let best = GameScoring.bestSession(for: .gate, in: [low, high, incomplete])

        #expect(best?.score == 90) // higher % wins, incomplete sessions are ignored
    }

    @Test func bestSessionPicksTheQuickestTimeForNinePutt() async throws {
        let slow = GameSession(gameType: .ninePutt)
        slow.isComplete = true; slow.durationSeconds = 540; slow.score = 9
        let quick = GameSession(gameType: .ninePutt)
        quick.isComplete = true; quick.durationSeconds = 260; quick.score = 260.0 / 60

        let best = GameScoring.bestSession(for: .ninePutt, in: [slow, quick])

        #expect(best?.durationSeconds == 260) // the quicker clear wins
    }

    @Test func bestSessionPicksLowestStrokesForAroundTheWorld() async throws {
        let high = GameSession(gameType: .aroundTheWorld); high.isComplete = true; high.score = 30
        let low = GameSession(gameType: .aroundTheWorld); low.isComplete = true; low.score = 22

        let best = GameScoring.bestSession(for: .aroundTheWorld, in: [high, low])

        #expect(best?.score == 22) // fewer total strokes wins
    }

    @Test func isNewBestComparesOnlyAgainstSameGameType() async throws {
        let existingGate = GameSession(gameType: .gate); existingGate.isComplete = true; existingGate.score = 80
        let existingClock = GameSession(gameType: .clock); existingClock.isComplete = true; existingClock.score = 95

        let newGateSession = GameSession(gameType: .gate)
        newGateSession.isComplete = true
        newGateSession.score = 85

        // Beats the previous gate-drill best (80%); the unrelated clock-drill
        // session's higher score must not affect this comparison.
        #expect(GameScoring.isNewBest(newGateSession, among: [existingGate, existingClock, newGateSession]))
    }

    // MARK: - Scoring relative to par

    @Test func holeScoreIsTheFirstPuttsCategoryPlusEveryExtraPutt() async throws {
        // A birdie putt holed is one under.
        let made = [Putt(holeNumber: 1, puttNumber: 1, distanceM: 3, puttFor: .birdie, result: .holed)]
        #expect(RoundStats.holeScoreRelativeToPar(made) == -1)

        // Two-putting from that same birdie putt is level par.
        let twoPutt = [
            Putt(holeNumber: 1, puttNumber: 1, distanceM: 8, puttFor: .birdie, result: .short),
            Putt(holeNumber: 1, puttNumber: 2, distanceM: 1, puttFor: .par, result: .holed),
        ]
        #expect(RoundStats.holeScoreRelativeToPar(twoPutt) == 0)

        // Three-putting it is a bogey.
        let threePutt = twoPutt + [Putt(holeNumber: 1, puttNumber: 3, distanceM: 0.5, puttFor: .bogey, result: .holed)]
        #expect(RoundStats.holeScoreRelativeToPar(threePutt) == 1)

        // The deeper numeric categories carry through.
        let plus3 = [Putt(holeNumber: 1, puttNumber: 1, distanceM: 2, puttFor: .plus3, result: .holed)]
        #expect(RoundStats.holeScoreRelativeToPar(plus3) == 3)
        let plus6 = [Putt(holeNumber: 1, puttNumber: 1, distanceM: 2, puttFor: .plus6, result: .holed)]
        #expect(RoundStats.holeScoreRelativeToPar(plus6) == 6)
    }

    /// A hole with no putts scores whatever it was holed out for, rather than
    /// the putt formula, which would read one stroke too good.
    @Test func holeOutScoresTheCategoryItWasHoledOutFor() async throws {
        let parHoleOut = [Putt(holeNumber: 4, puttNumber: 0, distanceM: 0, puttFor: .par, result: .holed)]
        #expect(RoundStats.holeScoreRelativeToPar(parHoleOut) == 0)

        let birdieHoleOut = [Putt(holeNumber: 4, puttNumber: 0, distanceM: 0, puttFor: .birdie, result: .holed)]
        #expect(RoundStats.holeScoreRelativeToPar(birdieHoleOut) == -1)

        #expect(RoundStats.holeScoreRelativeToPar([]) == nil)
    }

    @MainActor
    @Test func holeOutsCountTowardGirScrambleAndScore() async throws {
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)

        func add(_ putt: Putt) {
            putt.round = round
            round.putts.append(putt)
            context.insert(putt)
        }

        // Hole 1: chipped in for birdie -> GIR, -1.
        add(Putt(holeNumber: 1, puttNumber: 0, distanceM: 0, puttFor: .birdie, result: .holed))
        // Hole 2: chipped in for par -> scramble attempt and save, level.
        add(Putt(holeNumber: 2, puttNumber: 0, distanceM: 0, puttFor: .par, result: .holed))
        // Hole 3: one putt for par -> scramble attempt and save, level.
        add(Putt(holeNumber: 3, puttNumber: 1, distanceM: 2, puttFor: .par, result: .holed))
        // Hole 4: two putts from a par putt -> scramble attempt, missed, +1.
        add(Putt(holeNumber: 4, puttNumber: 1, distanceM: 9, puttFor: .par, result: .short))
        add(Putt(holeNumber: 4, puttNumber: 2, distanceM: 1, puttFor: .bogey, result: .holed))
        try context.save()

        let stats = RoundStats.compute(putts: round.putts)

        #expect(stats.girCount == 1)                 // only the birdie hole-out
        #expect(stats.scrambleAttempts == 3)         // holes 2, 3 and 4
        #expect(stats.scrambleSuccesses == 2)        // holes 2 and 3
        #expect(stats.scoreRelativeToPar == 0)       // -1 + 0 + 0 + 1
        #expect(stats.scoredHoles == 4)
    }

    /// Reported bug: clearing a hole-out hole in a finished round left the hole
    /// with no record at all, so it stopped counting as played.
    @MainActor
    @Test func clearingAHoleInAFinishedRoundLeavesAHoleOutBehind() async throws {
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        round.isComplete = true
        context.insert(round)
        let putt = Putt(holeNumber: 3, puttNumber: 1, distanceM: 4, puttFor: .birdie, result: .holed)
        putt.round = round
        round.putts.append(putt)
        context.insert(putt)
        try context.save()

        let session = RoundSession(round: round, modelContext: context, initialHole: 3, isPostRoundEdit: true)
        session.deleteAllPuttsOnHole(3)

        let remaining = round.putts.filter { $0.holeNumber == 3 }
        #expect(remaining.count == 1)
        #expect(remaining[0].puttNumber == 0)        // reverted to a hole-out
        #expect(remaining[0].puttFor == .birdie)     // keeping the hole's category

        // Editing that hole-out's category must move the stats with it.
        session.updateHoleOutCategory(3, to: .par)
        let stats = RoundStats.compute(putts: round.putts)
        #expect(stats.girCount == 0)
        #expect(stats.scrambleAttempts == 1)
        #expect(stats.scrambleSuccesses == 1)
        #expect(stats.scoreRelativeToPar == 0)
    }

    /// An in-progress round is different: a hole cleared there is genuinely not
    /// entered yet, and only becomes a hole-out when the round is ended.
    @MainActor
    @Test func clearingAHoleInALiveRoundLeavesItEmpty() async throws {
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)
        let putt = Putt(holeNumber: 3, puttNumber: 1, distanceM: 4, puttFor: .birdie, result: .holed)
        putt.round = round
        round.putts.append(putt)
        context.insert(putt)
        try context.save()

        let session = RoundSession(round: round, modelContext: context)
        session.deleteAllPuttsOnHole(3)

        #expect(round.putts.filter { $0.holeNumber == 3 }.isEmpty)
    }

    @Test func scoreCategoryStepDownReachesTheDeeperCategories() async throws {
        #expect(ScoreCategory.bogey.next == .double)
        #expect(ScoreCategory.double.next == .plus3)
        #expect(ScoreCategory.plus3.next == .plus4)
        #expect(ScoreCategory.plus5.next == .plus6)
        #expect(ScoreCategory.plus6.next == .plus6) // clamps at the deepest
    }

    /// Putts stored before triple existed used "doubleOrWorse" as their raw
    /// value; that must still decode to the double-bogey case.
    @Test func doubleBogeyKeepsItsLegacyRawValue() async throws {
        #expect(ScoreCategory(rawValue: "doubleOrWorse") == .double)
        #expect(ScoreCategory.double.strokesRelativeToPar == 2)
    }

    // MARK: - Custom mode configuration

    /// Configs stored before the distance field gained a simple/complex setting
    /// must still decode — otherwise loading falls back to the default and the
    /// player silently loses their whole field layout.
    @Test func customModeConfigDecodesLayoutsSavedBeforeDistanceComplexity() async throws {
        let legacy = Data("""
        {"resultComplexity":"complex","fields":[{"id":"5E8B2A1C-0000-4000-8000-000000000001","kind":"slope","complexity":"complex"}]}
        """.utf8)

        let config = try JSONDecoder().decode(CustomModeConfig.self, from: legacy)

        #expect(config.resultComplexity == .complex)
        #expect(config.fields.map(\.kind) == [.slope])
        #expect(config.fields[0].complexity == .complex)
        #expect(config.distanceStyle == .slider)
    }

    @Test func customModeConfigRoundTripsDistanceStyle() async throws {
        var config = CustomModeConfig.defaultConfig
        config.distanceStyle = .numpad

        let decoded = try JSONDecoder().decode(
            CustomModeConfig.self,
            from: JSONEncoder().encode(config)
        )

        #expect(decoded.distanceStyle == .numpad)
        #expect(decoded == config)
    }

    @Test func historyReturnsOnlyCompletedSessionsOfThatGameNewestFirst() async throws {
        let old = GameSession(gameType: .gate)
        old.score = 40; old.isComplete = true
        old.date = Date(timeIntervalSince1970: 1_000)
        let new = GameSession(gameType: .gate)
        new.score = 60; new.isComplete = true
        new.date = Date(timeIntervalSince1970: 2_000)
        let abandoned = GameSession(gameType: .gate)
        abandoned.score = 99; abandoned.isComplete = false
        let otherGame = GameSession(gameType: .clock)
        otherGame.score = 99; otherGame.isComplete = true

        let history = GameScoring.history(for: .gate, in: [old, new, abandoned, otherGame])

        #expect(history.map(\.score) == [60, 40])
    }

    @Test func recentAverageUsesOnlyTheMostRecentSessions() async throws {
        // Six completed gate rounds, newest last in construction order.
        let scores: [Double] = [10, 20, 30, 40, 50, 60]
        let sessions = scores.enumerated().map { index, score -> GameSession in
            let s = GameSession(gameType: .gate)
            s.score = score
            s.isComplete = true
            s.date = Date(timeIntervalSince1970: TimeInterval(index) * 100)
            return s
        }

        // Newest five are 60, 50, 40, 30, 20 -> mean 40. The oldest (10) drops out.
        let average = GameScoring.recentAverage(for: .gate, in: sessions, count: 5)
        #expect(average == 40)

        #expect(GameScoring.recentAverage(for: .clock, in: sessions) == nil)
    }

    @Test func scoreFormattingFollowsTheGamesUnit() async throws {
        #expect(GameScoreFormat.text(72.4, for: .gate) == "72%")
        #expect(GameScoreFormat.text(14, for: .aroundTheWorld) == "14")
        // The 9-putt drill is timed now: a score of 3 means three minutes.
        #expect(GameScoreFormat.text(3, for: .ninePutt) == "3:00")
        #expect(GameScoreFormat.preciseText(72.45, for: .gate) == "72.5%")
        #expect(GameScoreFormat.preciseText(13.5, for: .aroundTheWorld) == "13.5")
    }

    @Test func isNewBestIsTrueWhenNoPriorSessionsExist() async throws {
        let firstEver = GameSession(gameType: .routine)
        firstEver.isComplete = true
        firstEver.score = 20
        #expect(GameScoring.isNewBest(firstEver, among: [firstEver]))
    }

    @Test func isNewBestIsFalseWhenWorseThanExistingBest() async throws {
        let existing = GameSession(gameType: .routine); existing.isComplete = true; existing.score = 90
        let worse = GameSession(gameType: .routine); worse.isComplete = true; worse.score = 70

        #expect(!GameScoring.isNewBest(worse, among: [existing, worse]))
    }

    // MARK: - Games: session scoring formulas (mirrors each drill's finish() logic)

    @Test func percentScoreFormulaMatchesMadeOverAttempts() async throws {
        // 7 made out of 10 attempts -> 70%, as every % based drill computes it.
        let made = 7, total = 10
        let score = total > 0 ? Double(made) / Double(total) * 100 : 0
        #expect(abs(score - 70.0) < 0.0001)
    }

    @Test func aroundTheWorldScoreIsSumOfPerHoleStrokes() async throws {
        let strokesPerHole = [1, 2, 3, 1, 2, 4, 1, 1, 2] // 9 holes
        let total = strokesPerHole.reduce(0, +)
        #expect(total == 17)
    }

    // MARK: - Post-round editing (RoundSession)

    /// Reproduces the reported bug: skip ahead to a later hole mid-round (not
    /// post-round-edit), play it, then jump back to a still-empty skipped hole
    /// — recording a putt there must work without needing edit mode.
    @MainActor
    @Test func jumpingBackToSkippedHoleDuringLiveRoundStillAllowsRecording() async throws {
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)
        try context.save()

        let session = RoundSession(round: round, modelContext: context)
        #expect(session.currentHole == 1)

        // Skip ahead to hole 5 (holes 2-4 left empty), play it.
        session.jumpToHole(5)
        session.draftResult = .holed
        _ = session.recordDraft()
        #expect(session.currentHole == 6) // advanced past hole 5

        // Jump back to a skipped, still-empty hole and try to record a putt.
        session.jumpToHole(2)
        #expect(session.currentHole == 2)
        #expect(session.reviewIndex == nil)
        session.draftResult = .missedGeneric
        let outcome = session.recordDraft()

        let hole2Putts = round.putts.filter { $0.holeNumber == 2 }
        #expect(hole2Putts.count == 1)
        #expect(outcome == .missed)
    }

    /// Arrows are hole navigation, not putt recording: stepping past an empty
    /// hole must leave it empty (no hole-out sentinel) while the round is live.
    @MainActor
    @Test func arrowsNavigateHolesAndLeaveEmptyHolesEmpty() async throws {
        Self.withUnits("metric")
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)
        try context.save()

        let session = RoundSession(round: round, modelContext: context)
        #expect(session.displayHole == 1)
        #expect(!session.canGoPreviousHole)

        session.goToNextHole()
        session.goToNextHole()
        #expect(session.displayHole == 3)
        #expect(round.putts.isEmpty) // walking past holes 1-2 recorded nothing

        session.goToPreviousHole()
        #expect(session.displayHole == 2)
    }

    /// Ending a round turns *skipped* holes — empty ones the player moved past —
    /// into 0-putt hole-outs, while empty holes at the end are left out of the
    /// round entirely (the round was simply cut short there).
    @MainActor
    @Test func endingRoundConvertsOnlySkippedHolesToHoleOuts() async throws {
        Self.withUnits("metric")
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)
        try context.save()

        let session = RoundSession(round: round, modelContext: context)
        for hole in [2, 5] {
            session.jumpToHole(hole)
            session.draftResult = .holed
            _ = session.recordDraft()
        }
        #expect(round.putts.count == 2) // nothing implicit yet

        session.endRound(holeCount: 18)

        // Holes 1, 3 and 4 were skipped over -> hole-outs. Holes 6...18 come
        // after the last entry, so they stay out of the round.
        let sentinels = round.putts.filter { $0.puttNumber == 0 }.map(\.holeNumber).sorted()
        #expect(sentinels == [1, 3, 4])
        #expect(round.putts.filter { $0.puttNumber > 0 }.count == 2)
        #expect(round.isComplete)
    }

    /// A 9-hole round started on the back nine consists of holes 10...18 — the
    /// summary grid must show those, not 1...9.
    @Test func nineHoleRoundStartedOnTenCoversTheBackNine() async throws {
        let round = Round(courseName: "Test", startingHole: 10)
        round.holeCount = 9
        #expect(Array(round.holeSequence.prefix(9)) == [10, 11, 12, 13, 14, 15, 16, 17, 18])

        let front = Round(courseName: "Test", startingHole: 1)
        front.holeCount = 9
        #expect(Array(front.holeSequence.prefix(9)) == [1, 2, 3, 4, 5, 6, 7, 8, 9])
    }

    /// An all-but-complete round (within two holes of full length) does count
    /// its trailing blanks as hole-outs — those last holes plausibly were.
    @MainActor
    @Test func endingNearlyFullRoundAlsoFillsTrailingHoleOuts() async throws {
        Self.withUnits("metric")
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)
        try context.save()

        let session = RoundSession(round: round, modelContext: context)
        for hole in 1...16 {
            session.jumpToHole(hole)
            session.draftResult = .holed
            _ = session.recordDraft()
        }

        session.endRound(holeCount: 18)

        // 16 of 18 entered -> holes 17 and 18 are treated as hole-outs.
        let sentinels = round.putts.filter { $0.puttNumber == 0 }.map(\.holeNumber).sorted()
        #expect(sentinels == [17, 18])
        #expect(round.putts.filter { $0.puttNumber > 0 }.count == 16)
    }

    /// Landing on a hole that already has putts is browsing, not editing — the
    /// EDITING state only turns on once a stored value is actually changed.
    @MainActor
    @Test func editingStateOnlyTurnsOnAfterChangingStoredValue() async throws {
        Self.withUnits("metric")
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)
        let putt = Putt(holeNumber: 4, puttNumber: 1, distanceM: 3.0, puttFor: .birdie, result: .holed)
        putt.round = round
        round.putts.append(putt)
        context.insert(putt)
        try context.save()

        let session = RoundSession(round: round, modelContext: context)
        session.jumpToHole(4)

        #expect(session.isReviewing)          // the stored putt is shown…
        #expect(!session.hasUnsavedEdits)     // …but nothing has been altered

        session.draftDistanceM = 5.0
        #expect(session.hasUnsavedEdits)      // now it's a real edit
    }

    /// On a hole whose last putt was a miss, a follow-up putt can be started;
    /// on a finished hole it cannot.
    @MainActor
    @Test func newPuttSlotAvailableOnlyWhileHoleIsUnfinished() async throws {
        Self.withUnits("metric")
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)
        let miss = Putt(holeNumber: 6, puttNumber: 1, distanceM: 8.0, puttFor: .birdie, result: .short)
        miss.round = round
        round.putts.append(miss)
        context.insert(miss)
        try context.save()

        let session = RoundSession(round: round, modelContext: context)
        session.jumpToHole(6)
        #expect(session.isReviewing)
        #expect(session.canStartNewPutt)

        session.startNewPutt()
        #expect(!session.isReviewing)          // left review, blank slot open
        #expect(session.draftPuttFor == .par)  // stepped down from birdie

        session.draftResult = .holed
        _ = session.recordDraft()
        #expect(round.putts.filter { $0.holeNumber == 6 }.count == 2)

        session.jumpToHole(6)
        #expect(!session.canStartNewPutt)      // hole is finished now
    }

    @MainActor
    @Test func jumpToHoleLoadsExistingPuttIntoReview() async throws {
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)
        let putt = Putt(holeNumber: 5, puttNumber: 1, distanceM: 2.0, puttFor: .par, result: .holed)
        putt.round = round
        round.putts.append(putt)
        context.insert(putt)
        try context.save()

        let session = RoundSession(round: round, modelContext: context, initialHole: 5, isPostRoundEdit: true)

        #expect(session.currentHole == 5)
        #expect(session.isReviewing)
        #expect(session.reviewedPutt?.id == putt.id)
    }

    @MainActor
    @Test func postRoundEditSavingDoesNotAdvanceOrEndRound() async throws {
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)
        // A fully-played 18-hole round; hole 18's last putt is holed.
        let putt5 = Putt(holeNumber: 5, puttNumber: 1, distanceM: 2.0, puttFor: .par, result: .holed)
        putt5.round = round
        round.putts.append(putt5)
        context.insert(putt5)
        let putt18 = Putt(holeNumber: 18, puttNumber: 1, distanceM: 1.0, puttFor: .birdie, result: .holed)
        putt18.round = round
        round.putts.append(putt18)
        context.insert(putt18)
        try context.save()

        let session = RoundSession(round: round, modelContext: context, initialHole: 5, isPostRoundEdit: true)
        session.draftDistanceM = 2.5 // correct the recorded distance

        let outcome = session.recordDraft()

        #expect(outcome == .edited)
        #expect(session.currentHole == 5) // must stay put, not jump to hole 18 / end-of-round
        #expect(putt5.distanceM == 2.5)
    }

    /// Reproduces the reported bug: editing putt 1's category on a 2-putt hole
    /// must update in place and cascade putt 2's category — never spawn a new
    /// putt, even across repeated saves.
    @MainActor
    @Test func editingPuttForCascadesAndNeverCreatesExtraPutts() async throws {
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)
        let putt1 = Putt(holeNumber: 3, puttNumber: 1, distanceM: 4.0, puttFor: .birdie, result: .short)
        putt1.round = round
        round.putts.append(putt1)
        context.insert(putt1)
        let putt2 = Putt(holeNumber: 3, puttNumber: 2, distanceM: 1.0, puttFor: .par, result: .holed)
        putt2.round = round
        round.putts.append(putt2)
        context.insert(putt2)
        try context.save()

        let session = RoundSession(round: round, modelContext: context, initialHole: 3, isPostRoundEdit: true)
        // Landing on a hole shows its *last* putt; select putt 1 to edit it.
        #expect(session.reviewedPutt?.id == putt2.id)
        session.reviewPrevious()
        #expect(session.reviewedPutt?.id == putt1.id)

        // Change putt 1's category from birdie to par (result stays a miss).
        session.draftPuttFor = .par
        _ = session.recordDraft()

        #expect(round.putts.filter { $0.holeNumber == 3 }.count == 2) // no new putt created
        #expect(putt1.puttFor == .par)
        #expect(putt2.puttFor == .bogey) // cascaded from par -> bogey
        #expect(session.isReviewing) // stayed on putt 1, not dropped into "new putt" mode
        #expect(session.reviewedPutt?.id == putt1.id)

        // Saving again (e.g. re-confirming) must still not create a new putt.
        _ = session.recordDraft()
        #expect(round.putts.filter { $0.holeNumber == 3 }.count == 2)

        // Nor does saving putt 2 unchanged.
        session.reviewNext()
        #expect(session.reviewedPutt?.id == putt2.id)
        _ = session.recordDraft()
        #expect(round.putts.filter { $0.holeNumber == 3 }.count == 2)
    }

    /// Un-holing a putt (holed -> missed) must automatically add the natural
    /// follow-up putt, in both live and post-round-edit sessions.
    @MainActor
    @Test func unholingAPuttAutoCreatesFollowUpPutt() async throws {
        // The follow-up distance is unit-dependent (1m vs 2ft), and the test
        // host shares the app's UserDefaults — pin the unit so this doesn't
        // depend on whatever the app was last left set to.
        Self.withUnits("metric")
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)
        let putt = Putt(holeNumber: 7, puttNumber: 1, distanceM: 2.0, puttFor: .birdie, result: .holed)
        putt.round = round
        round.putts.append(putt)
        context.insert(putt)
        try context.save()

        let session = RoundSession(round: round, modelContext: context, initialHole: 7, isPostRoundEdit: true)
        #expect(session.reviewedPutt?.id == putt.id)

        // Mark it missed instead of holed.
        session.draftResult = .short

        let outcome = session.recordDraft()

        #expect(outcome == .edited)
        let holePutts = round.putts.filter { $0.holeNumber == 7 }.sorted { $0.puttNumber < $1.puttNumber }
        #expect(holePutts.count == 2) // follow-up putt was created
        #expect(holePutts[0].result == .short)
        #expect(holePutts[1].puttNumber == 2)
        #expect(holePutts[1].puttFor == .par) // stepped down from birdie
        #expect(holePutts[1].distanceM == 1.0)
        #expect(session.isReviewing)
        #expect(session.reviewedPutt?.id == holePutts[1].id) // landed on the new follow-up putt

        // Saving the follow-up again (still missed) must not create yet another putt.
        _ = session.recordDraft()
        #expect(round.putts.filter { $0.holeNumber == 7 }.count == 2)
    }

    /// Reproduces the reported bug: editing a hole that was recorded as a
    /// 0-putt hole-out to add a real putt must actually persist it (supersede
    /// the sentinel), not silently do nothing or get lost on reopen.
    @MainActor
    @Test func addingRealPuttToHoleOutHoleReplacesSentinel() async throws {
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)
        let sentinel = Putt(holeNumber: 9, puttNumber: 0, distanceM: 0, result: .holed)
        sentinel.round = round
        round.putts.append(sentinel)
        context.insert(sentinel)
        try context.save()

        let session = RoundSession(round: round, modelContext: context, initialHole: 9, isPostRoundEdit: true)

        // Jumping to a hole-out hole must NOT load the sentinel into review —
        // it should be a fresh "new putt" entry.
        #expect(!session.isReviewing)
        #expect(session.currentHole == 9)

        // Record an actual putt: 2m, holed.
        session.draftDistanceM = 2.0
        session.draftResult = .holed
        let outcome = session.recordDraft()

        #expect(outcome == .edited)
        let holePutts = round.putts.filter { $0.holeNumber == 9 }
        #expect(holePutts.count == 1) // sentinel replaced, not appended alongside
        #expect(holePutts[0].puttNumber == 1)
        #expect(holePutts[0].distanceM == 2.0)
        #expect(holePutts[0].result == .holed)

        // The round's real stats must now reflect exactly one putt on this hole.
        let stats = RoundStats.compute(putts: round.putts)
        #expect(stats.puttsByHole[9] == 1)
        #expect(stats.totalPutts == 1)

        // Holing out must close the hole out (land in review on it), not leave
        // a "new putt" slot open that lets you keep adding more indefinitely.
        #expect(session.isReviewing)
        #expect(session.reviewedPutt?.id == holePutts[0].id)

        // Saving again (e.g. re-confirming the same putt) must not add a 2nd putt.
        _ = session.recordDraft()
        #expect(round.putts.filter { $0.holeNumber == 9 }.count == 1)
    }

    // MARK: - Strokes Gained (ported PGA Tour baseline math)

    @Test func holedPuttGainsExpectedPuttsMinusOne() async throws {
        let expected = StrokesGained.baseline(at: 2.0).expectedPutts
        let sg = StrokesGained.calculateSG(distanceM: 2.0, holed: true)
        #expect(abs(sg - (expected - 1)) < 0.0001)
        // Around 1.38 expected putts from 2m, so holing one is worth about a
        // third of a stroke.
        #expect(sg > 0.3 && sg < 0.45)
    }

    @Test func missedPuttFromSixMetresCostsTheAssumedLeave() async throws {
        // Faced 6m, used one putt, left the assumed 0.7m behind.
        let faced = StrokesGained.baseline(at: 6.0).expectedPutts
        let left = StrokesGained.baseline(at: StrokesGained.typicalLeave(6.0)).expectedPutts
        let sg = StrokesGained.calculateSG(distanceM: 6.0, holed: false)
        #expect(abs(sg - (faced - 1 - left)) < 0.0001)
        // Missing from six metres is a small loss, not a gain.
        #expect(sg < 0 && sg > -0.3)
    }

    /// The baseline must keep rising past two putts at long range. Capping it at
    /// two would mean a lag from 20m is treated as a certain two-putt, so laying
    /// it dead would earn nothing and leaving it miles away would cost nothing.
    @Test func expectedPuttsRisePastTwoOnLongPutts() async throws {
        #expect(StrokesGained.baseline(at: 8.0).expectedPutts < 2.0)
        #expect(StrokesGained.baseline(at: 10.0).expectedPutts > 2.0)
        #expect(StrokesGained.baseline(at: 30.0).expectedPutts > 2.4)

        // Which makes a good lag from 20m a genuine gain rather than a loss.
        #expect(StrokesGained.calculateSG(distanceM: 20.0, holed: false) > 0)
    }

    @Test func baselineStaysMonotonic() async throws {
        let table = StrokesGained.tourBaseline
        for (earlier, later) in zip(table, table.dropFirst()) {
            #expect(later.distanceM > earlier.distanceM)
            #expect(later.makeProbability < earlier.makeProbability)
            #expect(later.expectedPutts > earlier.expectedPutts)
        }
    }

    /// Strokes gained is a whole-hole number: the putts the tour would expect
    /// from where you first stood, minus the putts you actually took.
    @MainActor
    @Test func holeStrokesGainedIsExpectedPuttsMinusPuttsTaken() async throws {
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)

        // Three-putt from 30m: lagged to 4m, missed to 0.5m, holed.
        let distances = [30.0, 4.0, 0.5]
        for (index, distance) in distances.enumerated() {
            let putt = Putt(
                holeNumber: 1,
                puttNumber: index + 1,
                distanceM: distance,
                puttFor: .par,
                result: index == distances.count - 1 ? .holed : .short
            )
            putt.round = round
            round.putts.append(putt)
            context.insert(putt)
        }
        try context.save()

        let total = try #require(RoundStats.holeStrokesGained(round.putts))
        let expected = StrokesGained.baseline(at: 30.0).expectedPutts - Double(distances.count)
        #expect(abs(total - expected) < 0.0001)

        // Three putts from 30m is a loss, not the small gain the old per-putt
        // model used to report.
        #expect(total < -0.5)
    }

    /// Two-putting a long lag is roughly par for the course, and holing out
    /// from range is a large gain — both fall out of the same per-hole formula.
    @MainActor
    @Test func twoPuttAndOnePuttMatchTheirHoleTotals() async throws {
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)

        func addHole(_ hole: Int, distances: [Double]) {
            for (index, distance) in distances.enumerated() {
                let putt = Putt(
                    holeNumber: hole,
                    puttNumber: index + 1,
                    distanceM: distance,
                    puttFor: .par,
                    result: index == distances.count - 1 ? .holed : .short
                )
                putt.round = round
                round.putts.append(putt)
                context.insert(putt)
            }
        }
        addHole(1, distances: [20.0, 1.0])  // solid lag, two putts
        addHole(2, distances: [8.0])        // holed from range
        try context.save()

        let holeOne = try #require(RoundStats.holeStrokesGained(round.putts.filter { $0.holeNumber == 1 }))
        let holeTwo = try #require(RoundStats.holeStrokesGained(round.putts.filter { $0.holeNumber == 2 }))

        #expect(abs(holeOne - (StrokesGained.baseline(at: 20.0).expectedPutts - 2)) < 0.0001)
        #expect(abs(holeTwo - (StrokesGained.baseline(at: 8.0).expectedPutts - 1)) < 0.0001)
        #expect(holeTwo > 0.9)  // holing an 8m putt is worth close to a full stroke
    }

    /// Holing out from off the green isn't a putting result, so the hole has no
    /// putting strokes gained at all.
    @MainActor
    @Test func holeOutHasNoStrokesGained() async throws {
        let sentinel = Putt(holeNumber: 1, puttNumber: 0, distanceM: 0, puttFor: .birdie, result: .holed)
        #expect(RoundStats.holeStrokesGained([sentinel]) == nil)
    }

    /// PCG scores a single putt against the odds of making it: holing a
    /// coin-flip is +0.5, missing it -0.5.
    @Test func pcgIsTheComplementOfTheMakeProbability() async throws {
        let coinFlipDistance = 2.3
        let p = StrokesGained.baseline(at: coinFlipDistance).makeProbability
        #expect(abs(p - 0.5) < 0.06)  // the table really is near a coin flip here

        let holed = Putt(holeNumber: 1, puttNumber: 1, distanceM: coinFlipDistance, puttFor: .par, result: .holed)
        let missed = Putt(holeNumber: 1, puttNumber: 1, distanceM: coinFlipDistance, puttFor: .par, result: .short)
        #expect(abs(holed.pcg - (1 - p)) < 0.0001)
        #expect(abs(missed.pcg + p) < 0.0001)
        #expect(abs(holed.pcg + missed.pcg - (1 - 2 * p)) < 0.0001)
    }

    /// The long putt nobody makes: holing it is worth nearly a full shot,
    /// missing it costs almost nothing.
    @Test func pcgRewardsHolingUnlikelyPutts() async throws {
        let holed = Putt(holeNumber: 1, puttNumber: 1, distanceM: 20, puttFor: .par, result: .holed)
        let missed = Putt(holeNumber: 1, puttNumber: 1, distanceM: 20, puttFor: .par, result: .short)
        #expect(holed.pcg > 0.95)
        #expect(missed.pcg > -0.05 && missed.pcg < 0)
    }

    /// A tap-in is the mirror image: expected, so holing it gains nothing and
    /// missing it is a full-shot blunder.
    @Test func pcgPunishesMissingGimmes() async throws {
        let holed = Putt(holeNumber: 1, puttNumber: 1, distanceM: 0.3, puttFor: .par, result: .holed)
        let missed = Putt(holeNumber: 1, puttNumber: 1, distanceM: 0.3, puttFor: .par, result: .short)
        #expect(holed.pcg < 0.01)
        #expect(missed.pcg < -0.95)
    }

    // MARK: - Score vs putting

    private static func scoreRound(_ date: Date, score: Int, sg: Double, holes: Int = 18, tracksScore: Bool = true) -> (date: Date, courseName: String, stats: RoundStats, tracksScore: Bool) {
        var stats = RoundStats()
        stats.scoreRelativeToPar = score
        stats.scoredHoles = holes
        stats.holes = holes
        stats.sgTotal = sg
        return (date: date, courseName: "Test", stats: stats, tracksScore: tracksScore)
    }

    private static func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 86_400 * Double(offset))
    }

    /// Gaining strokes on the greens made the card better, so taking putting
    /// back out has to put them on again.
    @Test func scoreWithoutPuttingAddsTheStrokesGainedBackOn() async throws {
        let analysis = try #require(ScorePuttingAnalysis.make(rounds: [
            Self.scoreRound(Self.day(1), score: 5, sg: 2),
            Self.scoreRound(Self.day(2), score: 3, sg: -1),
            Self.scoreRound(Self.day(3), score: 4, sg: 0),
        ]))
        #expect(abs(analysis.rounds[0].scoreWithoutPutting - 7) < 0.0001)
        #expect(abs(analysis.rounds[1].scoreWithoutPutting - 2) < 0.0001)
        #expect(abs(analysis.rounds[2].scoreWithoutPutting - 4) < 0.0001)
    }

    /// A 9-hole card counts as the round it was — no scaling up to 18.
    @Test func nineHoleRoundsKeepTheirOwnScore() async throws {
        let analysis = try #require(ScorePuttingAnalysis.make(rounds: [
            Self.scoreRound(Self.day(1), score: 3, sg: 1, holes: 9),
            Self.scoreRound(Self.day(2), score: 6, sg: 2),
            Self.scoreRound(Self.day(3), score: 6, sg: 2),
        ]))
        #expect(abs(analysis.rounds[0].score - 3) < 0.0001)
        #expect(abs(analysis.rounds[0].sg - 1) < 0.0001)
    }

    /// A round entered without the score reference keeps its place on the time
    /// axis but is left out of the numbers, so the chart shows a gap instead of
    /// closing ranks over a round it knows nothing about.
    @Test func roundsWithoutAScoreReferenceLeaveTheirSlotEmpty() async throws {
        let analysis = try #require(ScorePuttingAnalysis.make(rounds: [
            Self.scoreRound(Self.day(1), score: 4, sg: 1),
            Self.scoreRound(Self.day(2), score: 9, sg: -2, tracksScore: false),
            Self.scoreRound(Self.day(3), score: 6, sg: 0),
            Self.scoreRound(Self.day(4), score: 2, sg: 3, tracksScore: false),
            Self.scoreRound(Self.day(5), score: 5, sg: 1),
        ]))
        #expect(analysis.rounds.count == 3)
        #expect(analysis.slotCount == 5)
        #expect(analysis.roundsWithoutScore == 2)
        #expect(analysis.rounds.map(\.slot) == [0, 2, 4])
        // The skipped rounds must not move the averages either.
        #expect(abs(analysis.avgScore - 5) < 0.0001)
    }

    /// Three rounds on file but only two with a scorecard is still too few.
    @Test func scoreComparisonCountsOnlyRoundsWithAScoreReference() async throws {
        #expect(ScorePuttingAnalysis.make(rounds: [
            Self.scoreRound(Self.day(1), score: 4, sg: 1),
            Self.scoreRound(Self.day(2), score: 5, sg: 0, tracksScore: false),
            Self.scoreRound(Self.day(3), score: 6, sg: -1),
        ]) == nil)
    }

    @Test func scorePuttingComparisonNeedsThreeRounds() async throws {
        #expect(ScorePuttingAnalysis.make(rounds: [
            Self.scoreRound(Self.day(1), score: 4, sg: 1),
            Self.scoreRound(Self.day(2), score: 5, sg: 0),
        ]) == nil)
    }

    /// Rounds come out of the query newest first; the chart has to read
    /// oldest to newest.
    @Test func scorePuttingRoundsAreOrderedOldestFirst() async throws {
        let analysis = try #require(ScorePuttingAnalysis.make(rounds: [
            Self.scoreRound(Self.day(9), score: 4, sg: 1),
            Self.scoreRound(Self.day(2), score: 5, sg: 0),
            Self.scoreRound(Self.day(5), score: 6, sg: -1),
        ]))
        #expect(analysis.rounds.map(\.date) == [Self.day(2), Self.day(5), Self.day(9)])
    }

    /// The curve is continuous, so a distance between two reference rows lands
    /// between their values rather than snapping to either.
    /// Putts split by whether the green was hit, plus how close the approach
    /// left the ball when it was.
    @MainActor
    @Test func girSplitCountsPuttsAndProximitySeparately() async throws {
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)

        func addHole(_ hole: Int, category: ScoreCategory, distances: [Double]) {
            for (index, distance) in distances.enumerated() {
                let putt = Putt(
                    holeNumber: hole,
                    puttNumber: index + 1,
                    distanceM: distance,
                    puttFor: index == 0 ? category : category.next,
                    result: index == distances.count - 1 ? .holed : .short
                )
                putt.round = round
                round.putts.append(putt)
                context.insert(putt)
            }
        }
        // Two greens hit: a 6m birdie putt two-putted, a 4m birdie holed.
        addHole(1, category: .birdie, distances: [6.0, 0.5])
        addHole(2, category: .birdie, distances: [4.0])
        // Two greens missed, played for par.
        addHole(3, category: .par, distances: [3.0])
        addHole(4, category: .par, distances: [2.0, 0.4, 0.2])
        try context.save()

        let stats = RoundStats.compute(putts: round.putts)
        #expect(stats.girPuttedHoles == 2)
        #expect(stats.nonGirPuttedHoles == 2)
        #expect(abs((stats.avgPuttsOnGir ?? 0) - 1.5) < 0.0001)
        #expect(abs((stats.avgPuttsOffGir ?? 0) - 2.0) < 0.0001)
        // Proximity is the first putt on the greens that were hit: (6 + 4) / 2.
        #expect(abs((stats.avgGirProximityM ?? 0) - 5.0) < 0.0001)
    }

    /// Holing out from off the green says nothing about putting, so it can't
    /// drag the per-hole putt averages down.
    @MainActor
    @Test func holeOutsStayOutOfTheGirPuttAverages() async throws {
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)

        let sentinel = Putt(holeNumber: 1, puttNumber: 0, distanceM: 0, puttFor: .birdie, result: .holed)
        sentinel.round = round
        round.putts.append(sentinel)
        context.insert(sentinel)

        let putt = Putt(holeNumber: 2, puttNumber: 1, distanceM: 5.0, puttFor: .birdie, result: .holed)
        putt.round = round
        round.putts.append(putt)
        context.insert(putt)
        try context.save()

        let stats = RoundStats.compute(putts: round.putts)
        #expect(stats.girCount == 2)
        #expect(stats.girPuttedHoles == 1)
        #expect(abs((stats.avgPuttsOnGir ?? 0) - 1.0) < 0.0001)
        #expect(abs((stats.avgGirProximityM ?? 0) - 5.0) < 0.0001)
    }

    /// Lip-outs are counted per round for the miss tendency after it — and a
    /// holed putt that touched the lip on its way in isn't one.
    @MainActor
    @Test func lipOutsCountOnlyWhenThePuttStayedOut() async throws {
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)

        func add(hole: Int, result: PuttResult, lipOut: Bool) {
            let putt = Putt(holeNumber: hole, puttNumber: 1, distanceM: 3, puttFor: .par, result: result, lipOut: lipOut)
            putt.round = round
            round.putts.append(putt)
            context.insert(putt)
        }
        add(hole: 1, result: .left, lipOut: true)
        add(hole: 2, result: .short, lipOut: true)
        add(hole: 3, result: .right, lipOut: false)
        add(hole: 4, result: .holed, lipOut: true)
        try context.save()

        #expect(RoundStats.compute(putts: round.putts).lipOutCount == 2)
    }

    // MARK: - Around The Hole

    private static func athSession(distance: Double, rounds: Int, difficulty: DrillDifficulty?, daysAgo: Int) -> GameSession {
        let session = GameSession(gameType: .aroundTheHole)
        session.configDistanceM = distance
        session.targetRounds = rounds
        session.difficulty = difficulty
        session.date = Date().addingTimeInterval(-86_400 * Double(daysAgo))
        session.isComplete = true
        return session
    }

    /// The published starting point: the shorter the putt, the more clean laps
    /// it takes to prove anything.
    @Test func aroundTheHoleDefaultsFollowTheDistance() async throws {
        #expect(AroundTheHolePlan.defaultRounds(forDistance: 1.0) == 5)
        #expect(AroundTheHolePlan.defaultRounds(forDistance: 1.3) == 3)
        #expect(AroundTheHolePlan.defaultRounds(forDistance: 2.0) == 2)
        #expect(AroundTheHolePlan.defaultRounds(forDistance: 2.5) == 1)
    }

    /// Marking a session too easy earns a lap next time, and the ladder climbs
    /// one rung at a time rather than compounding.
    @Test func tooEasySessionsAddOneLapAtATime() async throws {
        let first = [Self.athSession(distance: 1.0, rounds: 5, difficulty: .tooEasy, daysAgo: 1)]
        #expect(AroundTheHolePlan.suggestedRounds(forDistance: 1.0, history: first) == 6)

        let second = first + [Self.athSession(distance: 1.0, rounds: 6, difficulty: .tooEasy, daysAgo: 0)]
        #expect(AroundTheHolePlan.suggestedRounds(forDistance: 1.0, history: second) == 7)
    }

    /// "About right" holds the setup, "too hard" gives a lap back, and neither
    /// falls below one.
    @Test func difficultyFeedbackSteersTheNextSetup() async throws {
        let right = [Self.athSession(distance: 1.0, rounds: 7, difficulty: .justRight, daysAgo: 0)]
        #expect(AroundTheHolePlan.suggestedRounds(forDistance: 1.0, history: right) == 7)

        let hard = [Self.athSession(distance: 1.0, rounds: 5, difficulty: .tooHard, daysAgo: 0)]
        #expect(AroundTheHolePlan.suggestedRounds(forDistance: 1.0, history: hard) == 4)

        let veryHard = [Self.athSession(distance: 2.5, rounds: 1, difficulty: .tooHard, daysAgo: 0)]
        #expect(AroundTheHolePlan.suggestedRounds(forDistance: 2.5, history: veryHard) == 1)
    }

    /// Feedback from another distance, or none at all, leaves the default.
    @Test func suggestionIgnoresOtherDistancesAndUnratedSessions() async throws {
        let elsewhere = [Self.athSession(distance: 2.0, rounds: 4, difficulty: .tooEasy, daysAgo: 0)]
        #expect(AroundTheHolePlan.suggestedRounds(forDistance: 1.0, history: elsewhere) == 5)

        let unrated = [Self.athSession(distance: 1.0, rounds: 9, difficulty: nil, daysAgo: 0)]
        #expect(AroundTheHolePlan.suggestedRounds(forDistance: 1.0, history: unrated) == 5)
    }

    /// A lap is the five tees, and the drill is timed rather than scored.
    @Test func timedDrillsAreScoredOnTheClock() async throws {
        #expect(AroundTheHolePlan.puttsPerLap == 5)
        for drill in [GameType.aroundTheHole, .ninePutt] {
            #expect(drill.isTrainingDrill)
            #expect(drill.lowerScoreIsBetter)
            #expect(drill.scoreUnitKey == "game.unit.minutes")
        }
        #expect(GameScoreFormat.clockText(75) == "1:15")
        #expect(GameScoreFormat.clockText(600) == "10:00")
    }

    /// The 9-putt drill used to be scored in cycles. Those sessions stay in the
    /// history, but a cycle count is not a time, so it can't stand as a record.
    @Test func untimedSessionsAreNoLongerATimeToBeat() async throws {
        let old = GameSession(gameType: .ninePutt)
        old.score = 3            // three cycles, from the tapped-through days
        old.isComplete = true
        old.date = Date().addingTimeInterval(-86_400)

        let timed = GameSession(gameType: .ninePutt)
        timed.durationSeconds = 420
        timed.score = 7
        timed.isComplete = true

        let sessions = [old, timed]
        #expect(GameScoring.history(for: .ninePutt, in: sessions).count == 2)
        #expect(GameScoring.bestSession(for: .ninePutt, in: sessions)?.durationSeconds == 420)
        #expect(GameScoring.recentAverage(for: .ninePutt, in: sessions) == 7)
    }

    /// What the round summary is allowed to celebrate.
    @Test func roundHighlightsFireOnlyAtTheirThresholds() async throws {
        #expect(RoundHighlights.scoreUnderPar(-1))
        #expect(!RoundHighlights.scoreUnderPar(0))

        #expect(RoundHighlights.strongStrokesGained(2.0))
        #expect(!RoundHighlights.strongStrokesGained(1.99))

        // PCG counts every putt rather than every hole, so it takes more of it.
        #expect(RoundHighlights.strongPCG(3.0))
        #expect(!RoundHighlights.strongPCG(2.9))

        // Fourteen of eighteen, held as a rate so a nine-hole round qualifies
        // with seven of nine.
        #expect(RoundHighlights.strongGreensInRegulation(14.0 / 18 * 100))
        #expect(!RoundHighlights.strongGreensInRegulation(13.0 / 18 * 100))
        #expect(RoundHighlights.strongGreensInRegulation(8.0 / 9 * 100))

        #expect(RoundHighlights.strongScrambling(70))
        #expect(!RoundHighlights.strongScrambling(69.9))

        #expect(RoundHighlights.lowPuttsPerHole(1.49))
        #expect(!RoundHighlights.lowPuttsPerHole(1.5))
        // An empty round averages zero putts, which is not a triumph.
        #expect(!RoundHighlights.lowPuttsPerHole(0))
    }

    /// The dispersion plot's distance band: what the two fields add up to.
    @Test func distanceRangeReadsBothFieldsInclusively() async throws {
        let band = DistanceRangeFilter.range(fromText: "2", toText: "4", useFeet: false, fullRangeMaxM: 12)
        #expect(band.contains(2.0))   // both ends belong to the band
        #expect(band.contains(4.0))
        #expect(band.contains(3.1))
        #expect(!band.contains(1.9))
        #expect(!band.contains(4.2))
    }

    /// Empty fields mean the whole range, and bounds typed the wrong way round
    /// are read as the band they obviously mean.
    @Test func distanceRangeFallsBackAndSelfCorrects() async throws {
        let full = DistanceRangeFilter.range(fromText: "", toText: "", useFeet: false, fullRangeMaxM: 9)
        #expect(full.contains(0))
        #expect(full.contains(9))
        #expect(!full.contains(9.5))

        let reversed = DistanceRangeFilter.range(fromText: "5", toText: "3", useFeet: false, fullRangeMaxM: 12)
        #expect(reversed.contains(4))
        #expect(!reversed.contains(6))

        // Junk in a field is treated as "no bound on that side".
        let junk = DistanceRangeFilter.range(fromText: "abc", toText: "3", useFeet: false, fullRangeMaxM: 12)
        #expect(junk.contains(0.5))
        #expect(!junk.contains(3.5))
    }

    /// The fields are read in whatever unit the player works in.
    @Test func distanceRangeConvertsFromFeet() async throws {
        let band = DistanceRangeFilter.range(fromText: "3", toText: "6", useFeet: true, fullRangeMaxM: 12)
        #expect(band.contains(UnitConverter.feetToMetres(4)))
        #expect(!band.contains(UnitConverter.feetToMetres(7)))
        // A comma is what the app's own numpad writes.
        #expect(DistanceRangeFilter.parse("2,5", useFeet: false) == 2.5)
    }

    /// Conversion is the chance taken with the putter: greens hit in
    /// regulation turned into a birdie or better off one or two putts.
    @MainActor
    @Test func conversionCountsBirdiesMadeFromGreensHit() async throws {
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)

        func addHole(_ hole: Int, category: ScoreCategory, distances: [Double]) {
            for (index, distance) in distances.enumerated() {
                let putt = Putt(
                    holeNumber: hole,
                    puttNumber: index + 1,
                    distanceM: distance,
                    puttFor: index == 0 ? category : category.next,
                    result: index == distances.count - 1 ? .holed : .short
                )
                putt.round = round
                round.putts.append(putt)
                context.insert(putt)
            }
        }
        addHole(1, category: .birdie, distances: [4.0])            // green hit, birdie made
        addHole(2, category: .eagle, distances: [8.0, 1.0])        // green hit, birdie from an eagle putt
        addHole(3, category: .birdie, distances: [6.0, 0.6])       // green hit, two putts for par
        addHole(4, category: .par, distances: [3.0])               // green missed
        try context.save()

        let stats = RoundStats.compute(putts: round.putts)
        #expect(stats.girCount == 3)
        #expect(stats.girConversions == 2)
        #expect(abs(stats.girConversionPercent - 200.0 / 3) < 0.0001)
        #expect(RoundHighlights.strongConversion(stats.girConversionPercent))
    }

    /// A chip-in is not the putter taking the chance, so it stays out of the
    /// conversion rate even though the hole counts as a green hit.
    @MainActor
    @Test func chipInsAreNotBirdieConversions() async throws {
        let context = try Self.makeInMemoryContext()
        let round = Round(courseName: "Test", startingHole: 1)
        context.insert(round)

        let sentinel = Putt(holeNumber: 1, puttNumber: 0, distanceM: 0, puttFor: .birdie, result: .holed)
        sentinel.round = round
        round.putts.append(sentinel)
        context.insert(sentinel)

        let putt = Putt(holeNumber: 2, puttNumber: 1, distanceM: 4, puttFor: .birdie, result: .holed)
        putt.round = round
        round.putts.append(putt)
        context.insert(putt)
        try context.save()

        let stats = RoundStats.compute(putts: round.putts)
        #expect(stats.girCount == 2)      // both count as greens hit
        #expect(stats.girConversions == 1) // only the holed putt converted
    }

    /// Over half, not half: five of ten greens converted is not a highlight.
    @Test func conversionHighlightNeedsMoreThanHalf() async throws {
        #expect(!RoundHighlights.strongConversion(50))
        #expect(RoundHighlights.strongConversion(50.1))
        #expect(!RoundHighlights.strongConversion(0))
    }

    @Test func baselineIsContinuousBetweenReferencePoints() async throws {
        let low = StrokesGained.baseline(at: 3.0)
        let mid = StrokesGained.baseline(at: 3.25)
        let high = StrokesGained.baseline(at: 3.5)
        #expect(mid.makeProbability < low.makeProbability)
        #expect(mid.makeProbability > high.makeProbability)
        #expect(mid.expectedPutts > low.expectedPutts)
        #expect(mid.expectedPutts < high.expectedPutts)
    }

    /// The fitted curves stand in for the calibrated anchor points, so they
    /// have to stay close to them: within 0.02 on make probability and within
    /// a hundredth of a stroke on expected putts.
    @Test func fittedCurvesMatchTheCalibrationAnchors() async throws {
        let anchors: [(d: Double, make: Double, expected: Double)] = [
            (0.3, 0.999, 1.001), (0.5, 0.994, 1.006), (0.6, 0.990, 1.010),
            (0.8, 0.971, 1.029), (1.0, 0.938, 1.065), (1.2, 0.885, 1.124),
            (1.5, 0.779, 1.222), (1.8, 0.698, 1.311), (2.0, 0.634, 1.371),
            (2.5, 0.490, 1.512), (3.0, 0.408, 1.602), (3.5, 0.348, 1.669),
            (4.0, 0.293, 1.724), (4.5, 0.238, 1.773), (5.0, 0.208, 1.805),
            (6.0, 0.155, 1.864), (7.0, 0.126, 1.917), (8.0, 0.105, 1.965),
            (9.0, 0.092, 2.004), (10.0, 0.079, 2.032), (12.0, 0.053, 2.085),
            (15.0, 0.041, 2.164), (20.0, 0.027, 2.261), (25.0, 0.019, 2.350),
            (30.0, 0.015, 2.432),
            // Beyond the published range, continuing its trend.
            (35.0, 0.0123, 2.507), (40.0, 0.0103, 2.577),
        ]
        for anchor in anchors {
            let fitted = StrokesGained.baseline(at: anchor.d)
            #expect(abs(fitted.makeProbability - anchor.make) < 0.02)
            #expect(abs(fitted.expectedPutts - anchor.expected) < 0.009)
        }
    }

    /// No jumps and no wobbles anywhere in between: sampled every centimetre,
    /// make probability only falls and expected putts only rise.
    @Test func fittedCurvesStayMonotonicAcrossTheirWholeRange() async throws {
        var previous = StrokesGained.baseline(at: StrokesGained.shortestModelledDistanceM)
        var distance = StrokesGained.shortestModelledDistanceM
        while distance <= StrokesGained.longestModelledDistanceM {
            let current = StrokesGained.baseline(at: distance)
            #expect(current.makeProbability <= previous.makeProbability + 1e-9)
            #expect(current.expectedPutts >= previous.expectedPutts - 1e-9)
            previous = current
            distance += 0.01
        }
    }

    @Test func baselineClampsBeyondTableRange() async throws {
        let short = StrokesGained.baseline(at: 0.1)
        let long = StrokesGained.baseline(at: 100)
        #expect(short.makeProbability == StrokesGained.tourBaseline.first!.makeProbability)
        #expect(long.makeProbability == StrokesGained.tourBaseline.last!.makeProbability)
    }

    // MARK: - Score category auto-advance

    @Test func scoreCategorySteppsDownOneLevelAtATime() async throws {
        #expect(ScoreCategory.eagle.next == .birdie)
        #expect(ScoreCategory.birdie.next == .par)
        #expect(ScoreCategory.par.next == .bogey)
        #expect(ScoreCategory.bogey.next == .double)
    }

    // MARK: - Hole sequencing (starting hole 1 vs 10)

    @Test func holeSequenceStartingAtOnePlaysInOrder() async throws {
        let round = Round(courseName: "Test", startingHole: 1)
        #expect(round.holeSequence == Array(1...18))
    }

    @Test func holeSequenceStartingAtTenPlaysBackNineThenFrontNine() async throws {
        let round = Round(courseName: "Test", startingHole: 10)
        #expect(round.holeSequence == Array(10...18) + Array(1...9))
    }

    // MARK: - Distance list (picker source data)

    @Test func distanceListHasExpectedStepBreakpoints() async throws {
        let items = UnitConverter.distanceList(useFeet: false)
        #expect(items.first?.value == 0.3)
        // 0.5m steps from 0.5 to 7.0 (14 items) + 0.3 item + 1m steps from 8 to 30 (23 items)
        #expect(items.contains { $0.value == 7.0 })
        #expect(items.contains { $0.value == 8.0 })
        #expect(items.last?.value == 30.0)
    }

    // MARK: - Round stats aggregation

    @Test func roundStatsComputesMakeCountsAndTotals() async throws {
        let holedPutt = Putt(holeNumber: 1, puttNumber: 1, distanceM: 2.0, puttFor: .par, result: .holed)
        let missedPutt = Putt(holeNumber: 2, puttNumber: 1, distanceM: 4.0, puttFor: .par, result: .short, missRead: true)
        let tapIn = Putt(holeNumber: 2, puttNumber: 2, distanceM: 0.3, puttFor: .bogey, result: .holed)

        let stats = RoundStats.compute(putts: [holedPutt, missedPutt, tapIn])

        #expect(stats.totalPutts == 3)
        #expect(stats.holes == 2)
        #expect(stats.missCounts[.holed] == 2)
        #expect(stats.missCounts[.short] == 1)
        #expect(stats.missReasonCounts.missRead == 1)
    }

    // MARK: - 0-putt hole-out sentinel

    @Test func holeOutSentinelCountsAsPlayedHoleWithZeroPutts() async throws {
        let realPutt = Putt(holeNumber: 1, puttNumber: 1, distanceM: 2.0, puttFor: .par, result: .short)
        let holeOutSentinel = Putt(holeNumber: 2, puttNumber: 0, distanceM: 0, result: .holed)

        let stats = RoundStats.compute(putts: [realPutt, holeOutSentinel])

        #expect(stats.totalPutts == 1) // sentinel doesn't count as a putt
        #expect(stats.holes == 2) // but the hole it's on still counts as played
        #expect(stats.puttsByHole[2] == 0)
        #expect(stats.puttsByHole[1] == 1)
    }

    // MARK: - GIR / Scramble

    /// A green is in regulation when the hole was reached with an eagle or
    /// birdie putt — it's the hole's opening category that decides, not any
    /// later putt on it.
    @Test func girCountsHolesReachedWithAnEagleOrBirdiePutt() async throws {
        let birdieHole = Putt(holeNumber: 1, puttNumber: 1, distanceM: 3.0, puttFor: .birdie, result: .short)
        let birdieHoleFollowUp = Putt(holeNumber: 1, puttNumber: 2, distanceM: 1.0, puttFor: .par, result: .holed)
        let parHole = Putt(holeNumber: 2, puttNumber: 1, distanceM: 4.0, puttFor: .par, result: .holed)
        let eagleHole = Putt(holeNumber: 3, puttNumber: 1, distanceM: 6.0, puttFor: .eagle, result: .short)
        let eagleHoleFollowUp = Putt(holeNumber: 3, puttNumber: 2, distanceM: 1.0, puttFor: .birdie, result: .holed)

        let stats = RoundStats.compute(putts: [birdieHole, birdieHoleFollowUp, parHole, eagleHole, eagleHoleFollowUp])

        // Holes 1 and 3; hole 2 was played for par, and hole 3's second putt
        // being a birdie putt doesn't make it a second GIR.
        #expect(stats.girCount == 2)
    }

    @Test func scrambleRateIsSinglePuttParSavesOverParAttempts() async throws {
        let savedInOne = Putt(holeNumber: 1, puttNumber: 1, distanceM: 2.0, puttFor: .par, result: .holed)
        let tookTwo = Putt(holeNumber: 2, puttNumber: 1, distanceM: 3.0, puttFor: .par, result: .short)
        let tookTwoFollowUp = Putt(holeNumber: 2, puttNumber: 2, distanceM: 1.0, puttFor: .bogey, result: .holed)
        // Par putt reached via a missed birdie putt — not a scramble attempt (GIR was hit).
        let missedBirdie = Putt(holeNumber: 3, puttNumber: 1, distanceM: 3.0, puttFor: .birdie, result: .short)
        let parAfterBirdieMiss = Putt(holeNumber: 3, puttNumber: 2, distanceM: 1.0, puttFor: .par, result: .holed)

        let stats = RoundStats.compute(putts: [savedInOne, tookTwo, tookTwoFollowUp, missedBirdie, parAfterBirdieMiss])

        #expect(stats.scrambleAttempts == 2) // holes 1 and 2 only
        #expect(stats.scrambleSuccesses == 1) // only hole 1 saved in one putt
        #expect(abs(stats.scramblePercent - 50.0) < 0.001)
    }

    // MARK: - Multi-round stress test (5 rounds x ~32 random putts)

    @Test func fiveRoundsOfRandomPuttsAggregateWithoutCrashingAndStaySane() async throws {
        var rng = SeededGenerator(seed: 42)
        var allRoundStats: [RoundStats] = []

        for roundIndex in 0..<5 {
            let round = Round(courseName: "Random Course \(roundIndex)", startingHole: roundIndex % 2 == 0 ? 1 : 10)
            var putts: [Putt] = []
            let holeOrder = round.holeSequence
            var puttCount = 0
            let targetPutts = 32

            for hole in holeOrder {
                guard puttCount < targetPutts else { break }
                var category: ScoreCategory = ScoreCategory.allCases.randomElement(using: &rng) ?? .par
                var puttNumber = 1
                var distance = Double.random(in: 0.5...9.0, using: &rng)

                // Play out the hole: 1-4 putts, each either holed (stop) or missed (continue).
                let maxPuttsThisHole = Int.random(in: 1...4, using: &rng)
                for _ in 0..<maxPuttsThisHole {
                    guard puttCount < targetPutts else { break }
                    let holed = puttNumber == maxPuttsThisHole || Bool.random(using: &rng)
                    let result: PuttResult = holed
                        ? .holed
                        : [.short, .long, .left, .right, .shortLeft, .shortRight, .longLeft, .longRight].randomElement(using: &rng)!

                    let putt = Putt(
                        holeNumber: hole,
                        puttNumber: puttNumber,
                        distanceM: (distance * 10).rounded() / 10,
                        sideSlopePct: Double([-3, -2, -1, 0, 1, 2, 3].randomElement(using: &rng) ?? 0),
                        hillSlopePct: Double([-3, -2, -1, 0, 1, 2, 3].randomElement(using: &rng) ?? 0),
                        puttFor: category,
                        result: result,
                        missRead: Bool.random(using: &rng) && !holed,
                        badStroke: Bool.random(using: &rng) && !holed,
                        wrongAim: Bool.random(using: &rng) && !holed
                    )
                    putts.append(putt)
                    puttCount += 1
                    puttNumber += 1
                    category = category.next
                    distance = puttNumber == 2 ? 1.0 : Double.random(in: 0.3...2.0, using: &rng)

                    if holed { break }
                }
            }

            let stats = RoundStats.compute(putts: putts)
            allRoundStats.append(stats)

            #expect(stats.totalPutts == putts.count)
            #expect(stats.totalPutts <= targetPutts)
            #expect(stats.holes > 0)

            for bracket in stats.makeByDistance {
                #expect(bracket.made <= bracket.total)
                #expect(bracket.tourMakePct >= 0 && bracket.tourMakePct <= 100)
            }
            for category in RoundStats.situationCategories {
                let brackets = stats.makeByCategory[category] ?? []
                let totalInCategory = brackets.reduce(0) { $0 + $1.total }
                #expect(totalInCategory <= stats.totalPutts)
            }
        }

        #expect(allRoundStats.count == 5)

        let merged = RoundStats.merge(allRoundStats)
        let expectedTotal = allRoundStats.reduce(0) { $0 + $1.totalPutts }
        #expect(merged.totalPutts == expectedTotal)
        #expect(merged.holes == allRoundStats.reduce(0) { $0 + $1.holes })

        // Every merged distance bracket's makes must not exceed its attempts.
        for bracket in merged.makeByDistance {
            #expect(bracket.made <= bracket.total)
        }
        for category in RoundStats.situationCategories {
            for bracket in merged.makeByCategory[category] ?? [] {
                #expect(bracket.made <= bracket.total)
            }
        }
    }

    @MainActor
    /// Pins the unit preference so unit-dependent session defaults (post-miss
    /// distance, tap-in distance) are deterministic — the test bundle is hosted
    /// in the app and therefore shares its UserDefaults.
    private static func withUnits(_ units: String) {
        UserDefaults.standard.set(units, forKey: AppStorageKeys.units)
    }

    private static func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Putter.self, Round.self, Putt.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }
}

/// Deterministic RNG so the multi-round stress test is reproducible.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
