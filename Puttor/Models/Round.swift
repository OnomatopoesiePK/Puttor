//
//  Round.swift
//  Puttor
//

import Foundation
import SwiftData

@Model
final class Round {
    var id: UUID = UUID()
    var courseName: String = ""
    var date: Date = Date()
    var putter: Putter?
    var stimp: Double = 9
    var windRaw: String = WindLevel.none.rawValue
    var weatherRaw: String = WeatherTemp.warm.rawValue
    var precipitationRaw: String = Precipitation.sun.rawValue
    var grainyGreens: Bool = false
    /// Whether the round was played in a competition. Defaults to false so
    /// rounds recorded before the flag existed stay what they were: practice.
    var isTournament: Bool = false
    /// Stroke play unless said otherwise — the format rounds were recorded in
    /// before the question was asked.
    var playFormatRaw: String = PlayFormat.strokePlay.rawValue
    var startingHole: Int = 1
    var inputModeRaw: String = InputMode.pro.rawValue
    var holeCount: Int = 18
    var isComplete: Bool = false
    var notes: String = ""
    /// Whether the score reference ("putt for birdie/par/…") was actually asked
    /// for while this round was entered. Custom mode can leave that field out,
    /// and then every putt silently carries the default par — which would make
    /// up a scorecard that was never played. Stored so the score statistics can
    /// leave those rounds out instead of inventing numbers for them.
    ///
    /// Defaults to true so rounds recorded before the flag existed keep
    /// counting; `init` starts a new round at false and the session raises it
    /// on the first putt entered from a surface that shows the field.
    var tracksScoreCategory: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \Putt.round)
    var putts: [Putt] = []

    var playFormat: PlayFormat {
        get { PlayFormat(rawValue: playFormatRaw) ?? .strokePlay }
        set { playFormatRaw = newValue.rawValue }
    }

    var wind: WindLevel {
        get { WindLevel(rawValue: windRaw) ?? .none }
        set { windRaw = newValue.rawValue }
    }

    var weather: WeatherTemp {
        get { WeatherTemp(rawValue: weatherRaw) ?? .warm }
        set { weatherRaw = newValue.rawValue }
    }

    var precipitation: Precipitation {
        get { Precipitation(rawValue: precipitationRaw) ?? .sun }
        set { precipitationRaw = newValue.rawValue }
    }

    var inputMode: InputMode {
        get { InputMode(rawValue: inputModeRaw) ?? .pro }
        set { inputModeRaw = newValue.rawValue }
    }

    /// Hole play order for the round: starting on 1 plays 1...18; starting on
    /// 10 plays the back nine first (10...18) then the front nine (1...9).
    var holeSequence: [Int] {
        if startingHole == 10 {
            return Array(10...18) + Array(1...9)
        }
        return Array(1...18)
    }

    init(
        courseName: String,
        date: Date = Date(),
        putter: Putter? = nil,
        stimp: Double = 9,
        wind: WindLevel = .none,
        weather: WeatherTemp = .warm,
        precipitation: Precipitation = .sun,
        grainyGreens: Bool = false,
        isTournament: Bool = false,
        playFormat: PlayFormat = .strokePlay,
        startingHole: Int = 1,
        inputMode: InputMode = .pro
    ) {
        self.id = UUID()
        self.courseName = courseName
        self.date = date
        self.putter = putter
        self.stimp = stimp
        self.windRaw = wind.rawValue
        self.weatherRaw = weather.rawValue
        self.precipitationRaw = precipitation.rawValue
        self.grainyGreens = grainyGreens
        self.isTournament = isTournament
        self.playFormatRaw = playFormat.rawValue
        self.startingHole = startingHole
        self.inputModeRaw = inputMode.rawValue
        self.holeCount = 18
        self.isComplete = false
        self.notes = ""
        // Raised by the session as soon as a putt is entered from a surface
        // that asks for the score reference.
        self.tracksScoreCategory = false
    }
}
