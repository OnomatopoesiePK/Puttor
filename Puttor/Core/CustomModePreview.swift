//
//  CustomModePreview.swift
//  Puttor
//
//  What a Custom mode layout is worth: which statistics the chosen fields
//  feed, and — for the ones they don't — what would have to be added. Read by
//  the preview in Settings, so the cost of every field is visible before a
//  round is played with it.
//

import Foundation

struct CustomModePreviewLine: Identifiable {
    /// What this line of the preview says can be read.
    let key: String
    let available: Bool
    /// The field or setting still missing for it, where one is.
    let missingKey: String?

    var id: String { key }
}

enum CustomModePreview {
    static func lines(for config: CustomModeConfig) -> [CustomModePreviewLine] {
        let kinds = Set(config.fields.map(\.kind))
        let slope = config.fields.first { $0.kind == .slope }
        let detailedResult = config.resultStyle != .simple

        func line(_ key: String, _ available: Bool, _ missing: String? = nil) -> CustomModePreviewLine {
            CustomModePreviewLine(key: key, available: available, missingKey: available ? nil : missing)
        }

        return [
            // Distance and the result are always in, so these two always are.
            line("custom.preview.strokesGained", true),
            line("custom.preview.distance", true),
            line("custom.preview.scoreRelation", kinds.contains(.puttForCategory), CustomFieldKind.puttForCategory.titleKey),
            line("custom.preview.missSide", detailedResult, "custom.result.style.dartboard"),
            line("custom.preview.lipOuts", detailedResult, "custom.result.style.dartboard"),
            line("custom.preview.dispersion", config.resultStyle == .angle, "custom.result.style.angle"),
            line("custom.preview.slope", kinds.contains(.slope), CustomFieldKind.slope.titleKey),
            line(
                "custom.preview.slopeExact",
                slope?.complexity == .numbers,
                slope == nil ? CustomFieldKind.slope.titleKey : FieldComplexity.numbers.labelKey
            ),
            line("custom.preview.doubleBreak", kinds.contains(.doubleBreak), CustomFieldKind.doubleBreak.titleKey),
            line("custom.preview.causes", kinds.contains(.missReasons), CustomFieldKind.missReasons.titleKey),
            line("custom.preview.intention", kinds.contains(.intention), CustomFieldKind.intention.titleKey),
            // Shown with the playing statistics, so these need the score reference too.
            line(
                "custom.preview.holePar",
                kinds.contains(.holePar) && kinds.contains(.puttForCategory),
                kinds.contains(.holePar) ? CustomFieldKind.puttForCategory.titleKey : CustomFieldKind.holePar.titleKey
            ),
            line(
                "custom.preview.girOpportunity",
                kinds.contains(.girOpportunity) && kinds.contains(.puttForCategory),
                kinds.contains(.girOpportunity) ? CustomFieldKind.puttForCategory.titleKey : CustomFieldKind.girOpportunity.titleKey
            ),
        ]
    }
}
