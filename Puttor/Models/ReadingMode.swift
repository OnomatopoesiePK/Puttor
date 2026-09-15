//
//  ReadingMode.swift
//  Puttor
//
//  How the putts of a round were read: by feel through the feet, by eye, or
//  both — or a way the player named. A round stores the built-in way's raw
//  value, or "custom:" and the name, so a named way is never taken for a
//  built-in one.
//

import Foundation

enum ReadingMode: String, CaseIterable, Identifiable, Codable {
    /// Feeling the slope through the feet and body weight. Stored as
    /// "aimPoint", the name it was first saved under.
    case aimPoint
    case visual, hybrid

    var id: String { rawValue }
    var labelKey: String { "reading.\(rawValue)" }
}

struct ReadingMethod: Hashable, Identifiable {
    private static let customPrefix = "custom:"

    let raw: String
    var id: String { raw }

    init(_ mode: ReadingMode) { raw = mode.rawValue }
    init(custom name: String) { raw = Self.customPrefix + name }

    /// Nil for anything that is neither a built-in way nor a named one.
    init?(raw: String) {
        let named = raw.hasPrefix(Self.customPrefix) && raw.count > Self.customPrefix.count
        guard ReadingMode(rawValue: raw) != nil || named else { return nil }
        self.raw = raw
    }

    var builtIn: ReadingMode? { ReadingMode(rawValue: raw) }
    var customName: String? { raw.hasPrefix(Self.customPrefix) ? String(raw.dropFirst(Self.customPrefix.count)) : nil }
    var label: String { builtIn.map { L($0.labelKey) } ?? customName ?? raw }

    static let builtIns = ReadingMode.allCases.map(ReadingMethod.init)

    /// Every way there is to filter by: the built-in ones, those the player
    /// named, and any other named way a round still carries — one since
    /// removed, or brought in with an archive.
    static func all(saved stored: String, rounds: [Round]) -> [ReadingMethod] {
        var methods = builtIns + CustomReadingMethods.names(in: stored).map { ReadingMethod(custom: $0) }
        for round in rounds {
            if let method = round.readingMethod, !methods.contains(method) {
                methods.append(method)
            }
        }
        return methods
    }
}

/// The ways of reading the player named, one per line in AppStorage, in the
/// order they were added.
enum CustomReadingMethods {
    static func names(in stored: String) -> [String] {
        stored.split(separator: "\n").map(String.init)
    }

    /// Adds a name and says which way it stands for. An empty name adds
    /// nothing; the name of a built-in way, or one already there in any case,
    /// picks that one instead of adding a twin.
    static func adding(_ name: String, to stored: String) -> (stored: String, method: ReadingMethod?) {
        let trimmed = name.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return (stored, nil) }
        if let mode = ReadingMode.allCases.first(where: { L($0.labelKey).caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return (stored, ReadingMethod(mode))
        }
        let names = names(in: stored)
        if let existing = names.first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return (stored, ReadingMethod(custom: existing))
        }
        return ((names + [trimmed]).joined(separator: "\n"), ReadingMethod(custom: trimmed))
    }

    static func removing(_ name: String, from stored: String) -> String {
        names(in: stored).filter { $0 != name }.joined(separator: "\n")
    }
}
