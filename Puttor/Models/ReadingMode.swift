//
//  ReadingMode.swift
//  Puttor
//
//  How the putts of a round were read: with AimPoint, by eye, or both.
//

import Foundation

enum ReadingMode: String, CaseIterable, Identifiable, Codable {
    case aimPoint, visual, hybrid

    var id: String { rawValue }
    var labelKey: String { "reading.\(rawValue)" }
}
