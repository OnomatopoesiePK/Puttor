//
//  UnitConverter.swift
//  Puttor
//
//  Ported from the PuttTrack prototype's utils/unitConverter.ts.
//

import Foundation

struct DistanceOption: Identifiable, Equatable {
    let value: Double
    let label: String
    var id: Double { value }
}

enum UnitConverter {
    static func metresToFeet(_ m: Double) -> Double { m * 3.28084 }
    static func feetToMetres(_ ft: Double) -> Double { ft * 0.3048 }

    /// Exact metres-equivalent of the tap-in / "essentially zero" distance
    /// bucket, per unit — 0.3m in metric, precisely 1ft in imperial. Shared by
    /// the distance lists (so the picker highlights the right bucket) and
    /// RoundSession's tap-in recording.
    static func underThresholdM(useFeet: Bool) -> Double {
        useFeet ? feetToMetres(1) : 0.3
    }

    static func formatDistance(_ metres: Double, useFeet: Bool) -> String {
        if useFeet {
            if metres < feetToMetres(1) { return L("distance.lessThan1ft") }
            let feet = metresToFeet(metres)
            return "\(Int(feet.rounded())) \(L("unit.ft"))"
        }
        if metres < 0.5 { return L("distance.lessThan0_5m") }
        let isWhole = metres.truncatingRemainder(dividingBy: 1) == 0
        let formatted = isWhole ? String(format: "%.0f", metres) : String(format: "%.1f", metres)
        return "\(formatted) \(L("unit.m"))"
    }

    /// 0.3m item, then 0.5m steps to 7m, then 1m steps to 30m.
    static func distanceList(useFeet: Bool) -> [DistanceOption] {
        useFeet ? distanceListFeet() : distanceListMetric()
    }

    /// Snaps an arbitrary metres value (e.g. a settings-configured default
    /// distance) onto the closest valid item in the current unit's picker
    /// list — otherwise a value that doesn't land exactly on one of the
    /// list's steps (very likely after a unit switch) leaves the picker
    /// unable to find a matching id to scroll to, so it silently falls back
    /// to its first item instead of the intended distance.
    static func snapToNearest(_ metres: Double, useFeet: Bool) -> Double {
        let list = distanceList(useFeet: useFeet)
        guard let closest = list.min(by: { abs($0.value - metres) < abs($1.value - metres) }) else { return metres }
        return closest.value
    }

    private static func distanceListMetric() -> [DistanceOption] {
        var items: [DistanceOption] = [
            DistanceOption(value: 0.3, label: L("distance.lessThan0_5m"))
        ]
        var m = 0.5
        while m <= 7.0 + 1e-9 {
            items.append(DistanceOption(value: m, label: formatDistance(m, useFeet: false)))
            m = ((m + 0.5) * 10).rounded() / 10
        }
        var whole = 8
        while whole <= 30 {
            let v = Double(whole)
            items.append(DistanceOption(value: v, label: formatDistance(v, useFeet: false)))
            whole += 1
        }
        return items
    }

    /// Feet-native steps (not a conversion of the metric list, which produces
    /// odd non-round foot values): <1 ft, then 1 ft steps 2...21, then 3 ft
    /// steps 24...60, then a >60 ft bucket.
    private static func distanceListFeet() -> [DistanceOption] {
        var items: [DistanceOption] = [
            DistanceOption(value: underThresholdM(useFeet: true), label: L("distance.lessThan1ft"))
        ]
        for ft in 2...21 {
            items.append(DistanceOption(value: feetToMetres(Double(ft)), label: "\(ft) \(L("unit.ft"))"))
        }
        var ft = 24
        while ft <= 60 {
            items.append(DistanceOption(value: feetToMetres(Double(ft)), label: "\(ft) \(L("unit.ft"))"))
            ft += 3
        }
        items.append(DistanceOption(value: feetToMetres(66), label: L("distance.moreThan60ft")))
        return items
    }
}
