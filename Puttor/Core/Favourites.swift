//
//  Favourites.swift
//  Puttor
//
//  The putter and the way of reading a new round starts with. At most one of
//  each, kept as an id in the settings rather than on the models, so nothing
//  stored has to change and a putter deleted elsewhere simply stops matching.
//

import Foundation

enum Favourites {
    /// Marking the one already marked clears it; marking another moves the
    /// mark, so there is never more than one.
    static func toggled(_ id: String, current: String) -> String {
        current == id ? "" : id
    }

    static func putter(in putters: [Putter], stored: String) -> Putter? {
        guard !stored.isEmpty else { return nil }
        return putters.first { $0.id.uuidString == stored }
    }

    static func readingMethod(stored: String) -> ReadingMethod? {
        ReadingMethod(raw: stored)
    }
}
