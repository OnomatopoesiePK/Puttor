//
//  DistanceNumpadView.swift
//  Puttor
//
//  Complex distance entry for Custom mode: a phone-style numeric keypad for
//  typing an exact distance, instead of snapping to the scroll picker's steps.
//
//  Typing writes straight into the readout in grey — no need to focus a field
//  first. Enter commits the value and the text turns solid. Typing again after
//  a commit replaces the whole number, the way a spreadsheet cell does.
//

import SwiftUI

struct DistanceNumpadView: View {
    @Binding var value: Double
    var useFeet: Bool

    /// Digits typed since the last commit. Empty means the readout is showing
    /// the committed `value`.
    @State private var draft: String = ""

    private let decimalSeparator = ","
    private let keyHeight: CGFloat = 54
    private let keySpacing: CGFloat = 8
    /// Guard rails so a slipped keypress can't store a 500 m putt.
    private let maxMetres: Double = 40

    private var isTyping: Bool { !draft.isEmpty }

    /// The committed value expressed in the unit the player is typing in.
    private var committedInDisplayUnit: Double {
        useFeet ? UnitConverter.metresToFeet(value) : value
    }

    private var readout: String {
        isTyping ? draft : formatted(committedInDisplayUnit)
    }

    private var unitLabel: String {
        L(useFeet ? "unit.ft" : "unit.m")
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Text(L("input.distanceLabel"))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity)
                HStack {
                    Spacer()
                    FieldInfoButton(titleKey: "input.distanceLabel", textKey: "custom.distance.desc")
                }
            }

            display
            keypad
        }
    }

    private var display: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Spacer()
            Text(readout)
                .font(.system(size: 34, weight: .black, design: .rounded))
                // Grey while uncommitted, solid once Enter has been pressed.
                .foregroundStyle(isTyping ? Theme.textMuted : Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(unitLabel)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(isTyping ? Theme.accent : Theme.border, lineWidth: 1.5))
    }

    private var keypad: some View {
        HStack(spacing: keySpacing) {
            VStack(spacing: keySpacing) {
                ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]], id: \.self) { row in
                    HStack(spacing: keySpacing) {
                        ForEach(row, id: \.self) { digit in
                            key(digit) { type(digit) }
                        }
                    }
                }
                HStack(spacing: keySpacing) {
                    key(systemImage: "delete.left", tint: Theme.error) { backspace() }
                    key("0") { type("0") }
                    key(decimalSeparator) { typeSeparator() }
                }
            }

            // Enter runs the full height of the pad, as on a calculator.
            Button(action: commit) {
                VStack(spacing: 4) {
                    Image(systemName: "return")
                        .font(.system(size: 20, weight: .heavy))
                    Text(L("numpad.enter"))
                        .font(.system(size: 11, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white)
                .frame(width: 78)
                .frame(maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(isTyping ? Theme.primary : Theme.border))
            }
            .buttonStyle(.plain)
            .disabled(!isTyping)
        }
        .frame(height: keyHeight * 4 + keySpacing * 3)
    }

    private func key(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .frame(height: keyHeight)
    }

    private func key(systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .frame(height: keyHeight)
    }

    // MARK: - Input handling

    private func type(_ digit: String) {
        // First keypress after a commit replaces the value outright.
        guard draft.count < 6 else { return }
        // Distances are only ever recorded to one decimal, so stop accepting
        // digits once one has been typed after the separator.
        if let separatorIndex = draft.firstIndex(of: Character(decimalSeparator)) {
            let decimals = draft.distance(from: draft.index(after: separatorIndex), to: draft.endIndex)
            guard decimals < 1 else { return }
        }
        draft += digit
    }

    private func typeSeparator() {
        guard !draft.contains(decimalSeparator) else { return }
        draft += draft.isEmpty ? "0\(decimalSeparator)" : decimalSeparator
    }

    private func backspace() {
        guard !draft.isEmpty else { return }
        draft.removeLast()
    }

    private func commit() {
        guard let typed = Double(draft.replacingOccurrences(of: decimalSeparator, with: ".")) else {
            draft = ""
            return
        }
        // Round in the unit that was typed, so 12,4 ft stores as exactly 12.4 ft.
        let rounded = (typed * 10).rounded() / 10
        let metres = useFeet ? UnitConverter.feetToMetres(rounded) : rounded
        value = min(max(metres, 0.1), maxMetres)
        draft = ""
    }

    private func formatted(_ number: Double) -> String {
        let text = number.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", number)
            : String(format: "%.1f", number)
        return text.replacingOccurrences(of: ".", with: decimalSeparator)
    }
}

#Preview {
    DistanceNumpadView(value: .constant(4.5), useFeet: false)
        .padding()
        .background(Theme.background)
}
