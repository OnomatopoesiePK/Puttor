//
//  GameDestinationView.swift
//  Puttor
//
//  Maps a GameType to its drill screen, so both the games home screen and the
//  per-game statistics screen can push a game without duplicating the switch.
//

import SwiftUI

struct GameDestinationView: View {
    let gameType: GameType
    var onDone: () -> Void = {}

    var body: some View {
        switch gameType {
        case .gate: GateDrillView(onDone: onDone)
        case .clock: ClockDrillView(onDone: onDone)
        case .ninePutt: NinePuttDrillView(onDone: onDone)
        case .routine: RoutineDrillView(onDone: onDone)
        case .aroundTheWorld: AroundTheWorldView(onDone: onDone)
        }
    }
}
