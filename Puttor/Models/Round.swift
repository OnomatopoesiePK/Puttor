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
    var startingHole: Int = 1
    var inputModeRaw: String = InputMode.pro.rawValue
    var holeCount: Int = 18
    var isComplete: Bool = false
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Putt.round)
    var putts: [Putt] = []

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
        self.startingHole = startingHole
        self.inputModeRaw = inputMode.rawValue
        self.holeCount = 18
        self.isComplete = false
        self.notes = ""
    }
}
