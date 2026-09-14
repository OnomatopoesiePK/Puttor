//
//  StatisticsSection.swift
//  Puttor
//
//  The sections of the statistics tab, in the order they stand until the
//  player arranges them otherwise.
//

import Foundation

enum StatisticsSection: String, CaseIterable, Identifiable, Arrangeable {
    case rounds, totals, strokesGained, playingStats, scoreVsPutting, dispersion
    case makeByDistance, situation, missTendency, leaveByMiss, missReasons
    case intentionOutcome

    var id: String { rawValue }

    /// Its name in the list it is arranged in.
    var titleKey: String {
        switch self {
        case .rounds: return "stats.rounds"
        case .totals: return "stats.section.totals"
        case .strokesGained: return "stats.sgPutting"
        case .playingStats: return "stats.playingStats"
        case .scoreVsPutting: return "stats.scoreVsPutting"
        case .dispersion: return "stats.dispersion"
        case .makeByDistance: return "chart.makeVsTour"
        case .situation: return "stats.makeBySituation"
        case .missTendency: return "summary.missTendency"
        case .leaveByMiss: return "summary.leaveByMiss"
        case .missReasons: return "summary.missReasons"
        case .intentionOutcome: return "stats.intention"
        }
    }
}
