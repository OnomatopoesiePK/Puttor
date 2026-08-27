//
//  DistanceRangeFilter.swift
//  Puttor
//
//  Turns two typed-in bounds into a range of putt distances in metres. Used by
//  the miss dispersion plot, where narrowing to a band of distances is what
//  makes a slope filter say something: how the 2–4 m breaking putts miss is a
//  different question from how the tap-ins do.
//

import Foundation

enum DistanceRangeFilter {
    /// Reads what the player typed, in whatever unit they are working in, and
    /// hands back metres. An empty or unreadable field falls back to its end of
    /// the full range, and bounds entered the wrong way round are swapped
    /// rather than rejected. Both ends are inclusive.
    static func range(
        fromText: String,
        toText: String,
        useFeet: Bool,
        fullRangeMaxM: Double
    ) -> ClosedRange<Double> {
        let lower = parse(fromText, useFeet: useFeet) ?? 0
        let upper = parse(toText, useFeet: useFeet) ?? max(fullRangeMaxM, lower)
        let low = min(lower, upper)
        let high = max(lower, upper)
        // A hair either side, so a putt entered as exactly 2.0 m is inside a
        // 2–4 m band rather than a rounding accident away from it.
        return (low - 0.001)...(high + 0.001)
    }

    /// Accepts a comma as well as a point, since the numpad writes commas.
    static func parse(_ text: String, useFeet: Bool) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned), value >= 0 else { return nil }
        return useFeet ? UnitConverter.feetToMetres(value) : value
    }

    /// The text a field starts with: the bound as the player would write it.
    static func text(forMetres metres: Double, useFeet: Bool) -> String {
        let value = useFeet ? UnitConverter.metresToFeet(metres) : metres
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
