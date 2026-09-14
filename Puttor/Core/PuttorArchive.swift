//
//  PuttorArchive.swift
//  Puttor
//
//  Everything a player has recorded, as one file: putters, rounds with their
//  putts, drill sessions with their attempts. It exists so data can leave one
//  install and arrive in another — a new phone, a backup, or the app under a
//  new bundle identifier, which iOS treats as a different app with an empty
//  store.
//
//  Importing only ever adds. A round or a session already in the store, by
//  its id, is left exactly as it is, so the same file can be read twice
//  without doubling anything.
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PuttorArchive: Codable {
    static let appName = "Puttor"
    static let currentVersion = 1

    var app: String = PuttorArchive.appName
    var version: Int = PuttorArchive.currentVersion
    var exportedAt: Date = Date()
    var putters: [PutterRecord] = []
    var rounds: [RoundRecord] = []
    var sessions: [SessionRecord] = []

    struct PutterRecord: Codable {
        var id: UUID
        var name: String
        var createdAt: Date
    }

    struct RoundRecord: Codable {
        var id: UUID
        var courseName: String
        var date: Date
        var putterID: UUID?
        var stimp: Double
        var windRaw: String
        var weatherRaw: String
        var precipitationRaw: String
        var grainyGreens: Bool
        var isTournament: Bool
        var playFormatRaw: String
        var startingHole: Int
        var inputModeRaw: String
        var holeCount: Int
        var isComplete: Bool
        var notes: String
        var tracksScoreCategory: Bool
        /// Optional, so archives from before it was asked still read.
        var readingModeRaw: String?
        var putts: [PuttRecord]
    }

    struct PuttRecord: Codable {
        var id: UUID
        var holeNumber: Int
        var puttNumber: Int
        var distanceM: Double
        var sideSlopePct: Double
        var hillSlopePct: Double
        var doubleBreakRaw: String?
        var puttForRaw: String
        var resultRaw: String
        var lipOut: Bool
        var missRead: Bool
        var badStroke: Bool
        var badStrokeTypeRaw: String?
        var wrongAim: Bool
        var missAngleDeg: Double?
        var createdAt: Date
    }

    struct SessionRecord: Codable {
        var id: UUID
        var gameTypeRaw: String
        var date: Date
        var isComplete: Bool
        var score: Double
        var attemptsTotal: Int
        var madeTotal: Int
        var configSummary: String
        var durationSeconds: Double
        var difficultyRaw: String?
        var configDistanceM: Double
        var targetRounds: Int
        /// Optional, so archives from before sides were kept still read.
        var missedLeft: Int?
        var missedRight: Int?
        var attempts: [AttemptRecord]
    }

    struct AttemptRecord: Codable {
        var id: UUID
        var groupIndex: Int
        var index: Int
        var label: String
        var distanceM: Double
        var breakPct: Double
        var success: Bool
        var strokes: Int
        var missSide: Int?
        var createdAt: Date
    }

    /// What an import did, for the message afterwards.
    struct Summary: Equatable {
        var roundsAdded = 0
        var sessionsAdded = 0
        var puttersAdded = 0
        /// Rounds and sessions already in the store, left untouched.
        var skipped = 0
    }

    enum ArchiveError: Error {
        /// Readable JSON, but not a Puttor export — or one from a newer
        /// version of the app than this one understands.
        case notAnArchive
    }

    // MARK: - File

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Seconds with their fraction: exact, so nothing that sorts by time
        // comes back in a different order.
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    func encoded() throws -> Data {
        try Self.encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> PuttorArchive {
        let archive = try decoder.decode(PuttorArchive.self, from: data)
        guard archive.app == appName, archive.version <= currentVersion else {
            throw ArchiveError.notAnArchive
        }
        return archive
    }

    // MARK: - Export

    @MainActor
    static func make(from context: ModelContext) throws -> PuttorArchive {
        let putters = try context.fetch(FetchDescriptor<Putter>())
        let rounds = try context.fetch(FetchDescriptor<Round>(sortBy: [SortDescriptor(\.date)]))
        let sessions = try context.fetch(FetchDescriptor<GameSession>(sortBy: [SortDescriptor(\.date)]))

        var archive = PuttorArchive()
        archive.putters = putters.map { PutterRecord(id: $0.id, name: $0.name, createdAt: $0.createdAt) }
        archive.rounds = rounds.map { round in
            RoundRecord(
                id: round.id,
                courseName: round.courseName,
                date: round.date,
                putterID: round.putter?.id,
                stimp: round.stimp,
                windRaw: round.windRaw,
                weatherRaw: round.weatherRaw,
                precipitationRaw: round.precipitationRaw,
                grainyGreens: round.grainyGreens,
                isTournament: round.isTournament,
                playFormatRaw: round.playFormatRaw,
                startingHole: round.startingHole,
                inputModeRaw: round.inputModeRaw,
                holeCount: round.holeCount,
                isComplete: round.isComplete,
                notes: round.notes,
                tracksScoreCategory: round.tracksScoreCategory,
                readingModeRaw: round.readingModeRaw,
                putts: round.putts
                    .sorted { ($0.holeNumber, $0.puttNumber) < ($1.holeNumber, $1.puttNumber) }
                    .map { putt in
                        PuttRecord(
                            id: putt.id,
                            holeNumber: putt.holeNumber,
                            puttNumber: putt.puttNumber,
                            distanceM: putt.distanceM,
                            sideSlopePct: putt.sideSlopePct,
                            hillSlopePct: putt.hillSlopePct,
                            doubleBreakRaw: putt.doubleBreakRaw,
                            puttForRaw: putt.puttForRaw,
                            resultRaw: putt.resultRaw,
                            lipOut: putt.lipOut,
                            missRead: putt.missRead,
                            badStroke: putt.badStroke,
                            badStrokeTypeRaw: putt.badStrokeTypeRaw,
                            wrongAim: putt.wrongAim,
                            missAngleDeg: putt.missAngleDeg,
                            createdAt: putt.createdAt
                        )
                    }
            )
        }
        archive.sessions = sessions.map { session in
            SessionRecord(
                id: session.id,
                gameTypeRaw: session.gameTypeRaw,
                date: session.date,
                isComplete: session.isComplete,
                score: session.score,
                attemptsTotal: session.attemptsTotal,
                madeTotal: session.madeTotal,
                configSummary: session.configSummary,
                durationSeconds: session.durationSeconds,
                difficultyRaw: session.difficultyRaw,
                configDistanceM: session.configDistanceM,
                targetRounds: session.targetRounds,
                missedLeft: session.missedLeft,
                missedRight: session.missedRight,
                attempts: session.attempts
                    .sorted { ($0.groupIndex, $0.index) < ($1.groupIndex, $1.index) }
                    .map { attempt in
                        AttemptRecord(
                            id: attempt.id,
                            groupIndex: attempt.groupIndex,
                            index: attempt.index,
                            label: attempt.label,
                            distanceM: attempt.distanceM,
                            breakPct: attempt.breakPct,
                            success: attempt.success,
                            strokes: attempt.strokes,
                            missSide: attempt.missSide,
                            createdAt: attempt.createdAt
                        )
                    }
            )
        }
        return archive
    }

    // MARK: - Import

    @MainActor
    @discardableResult
    func restore(into context: ModelContext) throws -> Summary {
        var summary = Summary()

        // Putters are matched by id, then by name: a putter added again by
        // hand in the new install is the same putter, not a second one.
        var puttersByID: [UUID: Putter] = [:]
        var puttersByName: [String: Putter] = [:]
        for putter in try context.fetch(FetchDescriptor<Putter>()) {
            puttersByID[putter.id] = putter
            puttersByName[Self.nameKey(putter.name)] = putter
        }
        for record in putters where puttersByID[record.id] == nil {
            if let sameName = puttersByName[Self.nameKey(record.name)] {
                puttersByID[record.id] = sameName
                continue
            }
            let putter = Putter(name: record.name)
            putter.id = record.id
            putter.createdAt = record.createdAt
            context.insert(putter)
            puttersByID[record.id] = putter
            puttersByName[Self.nameKey(record.name)] = putter
            summary.puttersAdded += 1
        }

        let existingRounds = Set(try context.fetch(FetchDescriptor<Round>()).map(\.id))
        for record in rounds {
            guard !existingRounds.contains(record.id) else {
                summary.skipped += 1
                continue
            }
            let round = Round(courseName: record.courseName, date: record.date)
            round.id = record.id
            round.putter = record.putterID.flatMap { puttersByID[$0] }
            round.stimp = record.stimp
            round.windRaw = record.windRaw
            round.weatherRaw = record.weatherRaw
            round.precipitationRaw = record.precipitationRaw
            round.grainyGreens = record.grainyGreens
            round.readingModeRaw = record.readingModeRaw
            round.isTournament = record.isTournament
            round.playFormatRaw = record.playFormatRaw
            round.startingHole = record.startingHole
            round.inputModeRaw = record.inputModeRaw
            round.holeCount = record.holeCount
            round.isComplete = record.isComplete
            round.notes = record.notes
            // Set last: the initialiser starts a new round at false.
            round.tracksScoreCategory = record.tracksScoreCategory
            context.insert(round)

            for puttRecord in record.putts {
                let putt = Putt(
                    holeNumber: puttRecord.holeNumber,
                    puttNumber: puttRecord.puttNumber,
                    distanceM: puttRecord.distanceM,
                    result: .holed
                )
                putt.id = puttRecord.id
                putt.sideSlopePct = puttRecord.sideSlopePct
                putt.hillSlopePct = puttRecord.hillSlopePct
                putt.doubleBreakRaw = puttRecord.doubleBreakRaw
                putt.puttForRaw = puttRecord.puttForRaw
                putt.resultRaw = puttRecord.resultRaw
                putt.lipOut = puttRecord.lipOut
                putt.missRead = puttRecord.missRead
                putt.badStroke = puttRecord.badStroke
                putt.badStrokeTypeRaw = puttRecord.badStrokeTypeRaw
                putt.wrongAim = puttRecord.wrongAim
                putt.missAngleDeg = puttRecord.missAngleDeg
                putt.createdAt = puttRecord.createdAt
                putt.round = round
                round.putts.append(putt)
                context.insert(putt)
            }
            summary.roundsAdded += 1
        }

        let existingSessions = Set(try context.fetch(FetchDescriptor<GameSession>()).map(\.id))
        for record in sessions {
            guard !existingSessions.contains(record.id) else {
                summary.skipped += 1
                continue
            }
            let session = GameSession(gameType: GameType(rawValue: record.gameTypeRaw) ?? .gate)
            session.id = record.id
            session.gameTypeRaw = record.gameTypeRaw
            session.date = record.date
            session.isComplete = record.isComplete
            session.score = record.score
            session.attemptsTotal = record.attemptsTotal
            session.madeTotal = record.madeTotal
            session.configSummary = record.configSummary
            session.durationSeconds = record.durationSeconds
            session.difficultyRaw = record.difficultyRaw
            session.configDistanceM = record.configDistanceM
            session.targetRounds = record.targetRounds
            session.missedLeft = record.missedLeft ?? 0
            session.missedRight = record.missedRight ?? 0
            context.insert(session)

            for attemptRecord in record.attempts {
                let attempt = GameAttempt(
                    groupIndex: attemptRecord.groupIndex,
                    index: attemptRecord.index,
                    label: attemptRecord.label,
                    distanceM: attemptRecord.distanceM,
                    breakPct: attemptRecord.breakPct,
                    success: attemptRecord.success,
                    strokes: attemptRecord.strokes,
                    missSide: attemptRecord.missSide ?? 0
                )
                attempt.id = attemptRecord.id
                attempt.createdAt = attemptRecord.createdAt
                attempt.session = session
                session.attempts.append(attempt)
                context.insert(attempt)
            }
            summary.sessionsAdded += 1
        }

        try context.save()
        return summary
    }

    private static func nameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// The archive as a document the system's save and open panels understand.
struct PuttorArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
