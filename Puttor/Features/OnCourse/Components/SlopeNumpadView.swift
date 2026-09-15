//
//  SlopeNumpadView.swift
//  Puttor
//
//  The break typed in percent rather than picked on a grid: side break in the
//  left field, up or down in the right one, one keypad for both. Typing with
//  neither field chosen writes the side break; Enter moves on to up or down,
//  and Enter there hands back to the side break for the next putt. Tapping a
//  field chooses it and empties it, to show it is being written; left without
//  a new number, it keeps the one it had.
//

import SwiftUI

struct SlopeNumpadView: View {
    @Binding var sideValue: Double
    @Binding var hillValue: Double

    private enum Field { case side, hill }

    @State private var active: Field = .side
    /// Typed since the field was chosen. Empty shows the stored value — or
    /// nothing, once the field has been tapped to be written.
    @State private var draft = ""
    @State private var cleared = false

    /// No green breaks more than this; a slipped key can't store 55 %.
    private static let limit = 10.0
    private let decimalSeparator = ","
    private let keyHeight: CGFloat = 50
    private let keySpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: 10) {
            Text(L("slopeNumpad.title"))
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity)

            HStack(spacing: keySpacing) {
                valueField(.side)
                valueField(.hill)
            }

            keypad
        }
    }

    // MARK: - Fields

    private func value(_ field: Field) -> Double {
        field == .side ? sideValue : hillValue
    }

    private func setValue(_ field: Field, _ newValue: Double) {
        let clamped = min(max((newValue * 10).rounded() / 10, -Self.limit), Self.limit)
        if field == .side { sideValue = clamped } else { hillValue = clamped }
    }

    private var typedValue: Double? {
        Double(draft.replacingOccurrences(of: decimalSeparator, with: "."))
    }

    private func valueField(_ field: Field) -> some View {
        let isActive = active == field
        let typing = isActive && !draft.isEmpty
        let shown = typing ? draft : (isActive && cleared ? "" : formatted(value(field)))

        return Button {
            choose(field)
        } label: {
            VStack(spacing: 4) {
                Text(L(field == .side ? "slopeNumpad.side" : "slopeNumpad.hill"))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(shown.isEmpty ? " " : shown)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        // Grey while typed but not entered, solid once it is.
                        .foregroundStyle(typing ? Theme.textMuted : Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("%")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textMuted)
                }
                // A minus pressed before any digit already says which way.
                let preview = typing ? (typedValue ?? (draft == "-" ? -1 : value(field))) : value(field)
                HStack(spacing: 6) {
                    Image(systemName: arrow(field, preview))
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(arrowTint(field, preview))
                    Text(direction(field, preview))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(height: 30)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(isActive ? Theme.accent : Theme.border, lineWidth: isActive ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L(field == .side ? "slopeNumpad.side" : "slopeNumpad.hill"))
        .accessibilityValue("\(formatted(value(field))) %, \(direction(field, value(field)))")
    }

    /// Which way the number means: the sign carries the direction.
    private func direction(_ field: Field, _ number: Double) -> String {
        switch field {
        case .side:
            if number < 0 { return L("slopeNumpad.rightToLeft") }
            if number > 0 { return L("slopeNumpad.leftToRight") }
            return L("slopeNumpad.straight")
        case .hill:
            if number > 0 { return L("slopeNumpad.uphill") }
            if number < 0 { return L("slopeNumpad.downhill") }
            return L("slopeNumpad.flat")
        }
    }

    /// The way the ball breaks, or runs up or down, as a big arrow.
    private func arrow(_ field: Field, _ number: Double) -> String {
        guard number != 0 else { return "minus" }
        switch field {
        case .side: return number < 0 ? "arrow.left" : "arrow.right"
        case .hill: return number > 0 ? "arrow.up" : "arrow.down"
        }
    }

    private func arrowTint(_ field: Field, _ number: Double) -> Color {
        guard number != 0 else { return Theme.textMuted }
        switch field {
        case .side: return number < 0 ? Theme.breakLeft : Theme.breakRight
        case .hill: return number > 0 ? Theme.uphill : Theme.downhill
        }
    }

    // MARK: - Keypad

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
                    key("±") { toggleSign() }
                    key("0") { type("0") }
                    key(decimalSeparator) { typeSeparator() }
                }
            }

            VStack(spacing: keySpacing) {
                key(systemImage: "delete.left", tint: Theme.error) { backspace() }
                Button(action: enter) {
                    VStack(spacing: 4) {
                        Image(systemName: "return")
                            .font(.system(size: 20, weight: .heavy))
                        Text(L("numpad.enter"))
                            .font(.system(size: 11, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.primary))
                }
                .buttonStyle(.plain)
            }
            .frame(width: 78)
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

    // MARK: - Input

    /// The other field's typing is kept, the chosen one emptied to be written.
    private func choose(_ field: Field) {
        commitDraft()
        active = field
        cleared = true
    }

    private func type(_ digit: String) {
        guard draft.filter(\.isNumber).count < 3 else { return }
        if let separator = draft.firstIndex(of: Character(decimalSeparator)) {
            // Break is read to one decimal at most.
            guard draft.distance(from: draft.index(after: separator), to: draft.endIndex) < 1 else { return }
        }
        draft += digit
    }

    private func typeSeparator() {
        guard !draft.contains(decimalSeparator) else { return }
        if draft.isEmpty || draft == "-" {
            draft += "0"
        }
        draft += decimalSeparator
    }

    /// Turns the sign of what is being typed. Pressed first, it holds a minus
    /// for the digits still to come; pressed and entered without any, it
    /// turns the stored number round.
    private func toggleSign() {
        if draft.hasPrefix("-") {
            draft.removeFirst()
        } else {
            draft = "-" + draft
        }
    }

    private func backspace() {
        guard !draft.isEmpty else { return }
        draft.removeLast()
    }

    /// Side break first, then up or down, then back to the side break.
    private func enter() {
        commitDraft()
        active = active == .side ? .hill : .side
        cleared = false
    }

    private func commitDraft() {
        if let typedValue {
            setValue(active, typedValue)
        } else if draft == "-" && !cleared {
            // A minus with no digits after it: the shown number, turned round.
            setValue(active, -value(active))
        }
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
    SlopeNumpadView(sideValue: .constant(-2), hillValue: .constant(1))
        .padding()
        .background(Theme.background)
}
