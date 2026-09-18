//
//  CustomFieldPreview.swift
//  Puttor
//
//  A field of Custom mode as it stands in a round, drawn from the settings so
//  the choice can be seen rather than read. Every value it takes is its own,
//  so tapping about in a preview leaves nothing behind.
//

import SwiftUI

struct CustomFieldPreview: View {
    enum Subject: Equatable {
        case distance(DistanceInputStyle)
        case field(CustomField)
        case result(ResultInputStyle)
    }

    let subject: Subject
    var useFeet = false

    @State private var distanceM: Double = 5
    @State private var puttFor: ScoreCategory = .birdie
    @State private var side: Double = 0
    @State private var hill: Double = 0
    @State private var doubleBreak: DoubleBreakType?
    @State private var intention = PuttIntention()
    @State private var girOpportunity: Bool?
    @State private var missRead = false
    @State private var badStroke = false
    @State private var badStrokeType: BadStrokeType?
    @State private var wrongAim = false
    @State private var result: PuttResult?
    @State private var lipOut = false
    @State private var missAngle: Double?

    var body: some View {
        VStack(spacing: 10) {
            content
            Text(L("custom.preview.field.hint"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.background)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
        )
    }

    @ViewBuilder
    private var content: some View {
        switch subject {
        case .distance(let style):
            if style == .numpad {
                DistanceNumpadView(value: $distanceM, useFeet: useFeet)
            } else {
                DistancePickerView(value: $distanceM, useFeet: useFeet)
            }
        case .field(let field):
            fieldContent(field)
        case .result(let style):
            resultContent(style)
        }
    }

    @ViewBuilder
    private func fieldContent(_ field: CustomField) -> some View {
        switch field.kind {
        case .puttForCategory:
            ScoreCategoryRow(selection: $puttFor)
        case .slope:
            switch field.complexity {
            case .complex:
                SlopeGridPickerView(sideValue: $side, hillValue: $hill)
            case .numbers:
                SlopeNumpadView(sideValue: $side, hillValue: $hill)
            case .simple:
                SimpleSlopeGridView(sideValue: $side, hillValue: $hill)
            }
        case .doubleBreak:
            DoubleBreakButtonsView(value: $doubleBreak)
        case .intention:
            // Match play, so the situation shows too where it is switched on.
            IntentionFieldView(
                parts: field.intentionParts,
                isMatchPlay: true,
                useFeet: useFeet,
                normalPastM: field.normalPastM,
                intention: $intention
            )
        case .missReasons:
            MissReasonRow(
                missRead: $missRead,
                badStroke: $badStroke,
                badStrokeType: $badStrokeType,
                wrongAim: $wrongAim,
                showsTitle: true
            )
        case .girOpportunity:
            // Starts on the preset chosen above, as a hole does.
            GirOpportunityFieldView(value: $girOpportunity)
                .onChange(of: field.girOpportunityPreset, initial: true) { _, preset in girOpportunity = preset }
        }
    }

    @ViewBuilder
    private func resultContent(_ style: ResultInputStyle) -> some View {
        switch style {
        case .angle:
            CircularMissSliderView(result: $result, lipOut: $lipOut, angle: $missAngle)
        case .dartboard:
            DartboardMissView(result: $result, lipOut: $lipOut)
        case .simple:
            // In a round these two save the putt on the spot, so here they are
            // only drawn.
            VStack(spacing: 8) {
                Text(L("input.result"))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textMuted)
                HStack(spacing: 14) {
                    simpleResultButton(L("input.missed"), Theme.error)
                    simpleResultButton(L("input.holedBtn"), Theme.primary)
                }
            }
        }
    }

    private func simpleResultButton(_ title: String, _ color: Color) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(color))
    }
}
