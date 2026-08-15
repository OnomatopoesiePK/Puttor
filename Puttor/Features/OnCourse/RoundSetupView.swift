//
//  RoundSetupView.swift
//  Puttor
//
//  Ported from round/setup.tsx, plus the spec additions not present in the
//  prototype: date/time picker, rain/sun + grainy-greens toggles, inline
//  "add putter", starting-hole 1/10 picker, Pro/Quick mode picker.
//

import SwiftUI
import SwiftData

struct RoundSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Putter.name) private var putters: [Putter]

    var existingRound: Round? = nil
    var onCreated: (Round) -> Void = { _ in }
    var onSaved: () -> Void = {}

    @State private var courseName: String
    @State private var date: Date
    @State private var putterID: PersistentIdentifier?
    @State private var stimp: Double
    @State private var wind: WindLevel
    @State private var weather: WeatherTemp
    @State private var precipitation: Precipitation
    @State private var grainyGreens: Bool
    @State private var startingHole: Int
    @State private var inputMode: InputMode

    @State private var addingPutter = false
    @State private var newPutterName = ""

    /// 6.5 and 12.5 are the open-ended "<7" / ">12" buckets, so the selectable
    /// readings in between run 7.0, 7.5 … 12.0.
    private static let stimpBounds: ClosedRange<Double> = 6.5...12.5
    static let defaultStimp: Double = 9
    private var stimpRange: ClosedRange<Double> { Self.stimpBounds }

    init(existingRound: Round? = nil, onCreated: @escaping (Round) -> Void = { _ in }, onSaved: @escaping () -> Void = {}) {
        self.existingRound = existingRound
        self.onCreated = onCreated
        self.onSaved = onSaved
        _courseName = State(initialValue: existingRound?.courseName ?? "")
        _date = State(initialValue: existingRound?.date ?? Date())
        _putterID = State(initialValue: existingRound?.putter?.persistentModelID)
        // Rounds saved under the older, wider scale can sit outside the current
        // bounds — clamp so the slider still shows a sensible position.
        let storedStimp = existingRound?.stimp ?? Self.defaultStimp
        _stimp = State(initialValue: min(max(storedStimp, Self.stimpBounds.lowerBound), Self.stimpBounds.upperBound))
        _wind = State(initialValue: existingRound?.wind ?? .none)
        _weather = State(initialValue: existingRound?.weather ?? .warm)
        _precipitation = State(initialValue: existingRound?.precipitation ?? .sun)
        _grainyGreens = State(initialValue: existingRound?.grainyGreens ?? false)
        _startingHole = State(initialValue: existingRound?.startingHole ?? 1)
        // New rounds start on whichever mode was used last, so a player who
        // always uses the same one never has to re-pick it.
        let lastMode = UserDefaults.standard.string(forKey: AppStorageKeys.lastInputMode).flatMap(InputMode.init(rawValue:))
        _inputMode = State(initialValue: existingRound?.inputMode ?? lastMode ?? .pro)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    label(L("setup.course"))
                    TextField(L("setup.courseNamePlaceholder"), text: $courseName)
                        .textFieldStyle(.plain)
                        .padding(Theme.Spacing.md)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
                        .foregroundStyle(Theme.text)

                    label(L("setup.date"))
                    DatePicker("", selection: $date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .colorScheme(.dark)

                    label(L("setup.putter"))
                    putterSection

                    label(L("setup.stimp"))
                    stimpCard

                    label(L("setup.wind"))
                    threeToggle(
                        selection: $wind,
                        options: WindLevel.allCases
                    )

                    label(L("setup.weather"))
                    threeToggle(
                        selection: $weather,
                        options: WeatherTemp.allCases
                    )

                    label(L("setup.precipitation"))
                    twoToggle(
                        selection: $precipitation,
                        options: Precipitation.allCases
                    )

                    label(L("setup.greens"))
                    Toggle(isOn: $grainyGreens) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("setup.grainyGreens")).foregroundStyle(Theme.text)
                            Text(L("setup.grainyGreens.desc")).font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .tint(Theme.primary)
                    .padding(Theme.Spacing.md)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))

                    label(L("setup.startingHole"))
                    HStack(spacing: 10) {
                        pillButton(title: "1", selected: startingHole == 1) { startingHole = 1 }
                        pillButton(title: "10", selected: startingHole == 10) { startingHole = 10 }
                    }

                    label(L("setup.inputMode"))
                    VStack(spacing: 8) {
                        ForEach(InputMode.allCases, id: \.self) { mode in
                            Button {
                                inputMode = mode
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(L(mode.labelKey)).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                                        Text(L(mode.descriptionKey)).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    if inputMode == mode {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary)
                                    }
                                }
                                .padding(Theme.Spacing.md)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(inputMode == mode ? Theme.primary.opacity(0.13) : Theme.surface))
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(inputMode == mode ? Theme.primary : Theme.border, lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    startButton
                        .padding(.top, Theme.Spacing.md)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(existingRound != nil ? L("setup.editRound") : L("setup.newRound")).font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.text)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Text("✕").foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
        .preferredColorScheme(ThemeManager.shared.colorScheme)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(Theme.textMuted)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }

    private var putterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if putters.isEmpty && !addingPutter {
                Text(L("setup.noPutters")).font(.caption).italic().foregroundStyle(Theme.textMuted)
            }
            FlowLayout(spacing: 8) {
                ForEach(putters) { putter in
                    pillButton(title: putter.name, selected: putterID == putter.persistentModelID) {
                        putterID = (putterID == putter.persistentModelID) ? nil : putter.persistentModelID
                    }
                }
            }
            if addingPutter {
                HStack {
                    TextField(L("setup.putterNamePlaceholder"), text: $newPutterName)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.card))
                        .foregroundStyle(Theme.text)
                    Button(L("common.add")) {
                        let name = newPutterName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        let putter = Putter(name: name)
                        modelContext.insert(putter)
                        try? modelContext.save()
                        putterID = putter.persistentModelID
                        newPutterName = ""
                        addingPutter = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
                    Button("✕") { addingPutter = false; newPutterName = "" }
                        .foregroundStyle(Theme.textMuted)
                }
            } else {
                Button("+ \(L("setup.addPutter"))") { addingPutter = true }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.primary)
            }
        }
    }

    private var stimpCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text(L("setup.slow")).opacity(stimp <= 8.5 ? 1 : 0.3)
                Spacer()
                Text(L("setup.medium")).opacity(stimp > 8.5 && stimp < 11 ? 1 : 0.3)
                Spacer()
                Text(L("setup.fast")).opacity(stimp >= 11 ? 1 : 0.3)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.textSecondary)

            Slider(value: $stimp, in: stimpRange, step: 0.5)
                .tint(Theme.primary)

            HStack {
                Text(Self.stimpText(for: stimpRange.lowerBound)).font(.caption).foregroundStyle(Theme.textMuted)
                Spacer()
                Text(Self.stimpText(for: stimp))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(stimpLabelColor)
                Text(stimpLabel)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(stimpLabelColor)
                Spacer()
                Text(Self.stimpText(for: stimpRange.upperBound)).font(.caption).foregroundStyle(Theme.textMuted)
            }
        }
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }

    /// The two ends of the slider are open-ended buckets rather than exact
    /// readings — anything slower than 7 or faster than 12 lands there.
    private static func stimpText(for value: Double) -> String {
        if value <= stimpBounds.lowerBound { return "<7" }
        if value >= stimpBounds.upperBound { return ">12" }
        return String(format: "%.1f", value)
    }

    private var stimpLabel: String {
        if stimp <= 8.5 { return L("setup.slow") }
        if stimp >= 11 { return L("setup.fast") }
        return L("setup.medium")
    }

    private var stimpLabelColor: Color {
        if stimp <= 8.5 { return Theme.uphill }
        if stimp >= 11 { return Theme.accent }
        return Theme.primary
    }

    private func threeToggle<T: Hashable & CaseIterable & RawRepresentable>(
        selection: Binding<T>, options: [T]
    ) -> some View where T.RawValue == String {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let selected = selection.wrappedValue == option
                Button {
                    selection.wrappedValue = option
                } label: {
                    VStack(spacing: 4) {
                        Text(emoji(for: option))
                        Text(L(labelKey(for: option)))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(selected ? Theme.primary : Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(selected ? Theme.primary.opacity(0.13) : Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(selected ? Theme.primary : Theme.border, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func twoToggle<T: Hashable & CaseIterable & RawRepresentable>(
        selection: Binding<T>, options: [T]
    ) -> some View where T.RawValue == String {
        threeToggle(selection: selection, options: options)
    }

    private func emoji(for value: any RawRepresentable<String>) -> String {
        switch value {
        case let v as WindLevel: return v.emoji
        case let v as WeatherTemp: return v.emoji
        case let v as Precipitation: return v.emoji
        default: return ""
        }
    }

    private func labelKey(for value: any RawRepresentable<String>) -> String {
        switch value {
        case let v as WindLevel: return v.labelKey
        case let v as WeatherTemp: return v.labelKey
        case let v as Precipitation: return v.labelKey
        default: return ""
        }
    }

    private func pillButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? Theme.primary : Theme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(selected ? Theme.primary.opacity(0.13) : Theme.surface))
                .overlay(Capsule().stroke(selected ? Theme.primary : Theme.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var startButton: some View {
        Button {
            startRound()
        } label: {
            Text(existingRound != nil ? L("setup.saveChanges") : "⛳  \(L("setup.startRound"))")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.primary))
        }
        .buttonStyle(.plain)
    }

    private func startRound() {
        let selectedPutter = putters.first { $0.persistentModelID == putterID }
        UserDefaults.standard.set(inputMode.rawValue, forKey: AppStorageKeys.lastInputMode)

        if let existingRound {
            existingRound.courseName = courseName.trimmingCharacters(in: .whitespaces)
            existingRound.date = date
            existingRound.putter = selectedPutter
            existingRound.stimp = stimp
            existingRound.wind = wind
            existingRound.weather = weather
            existingRound.precipitation = precipitation
            existingRound.grainyGreens = grainyGreens
            existingRound.startingHole = startingHole
            existingRound.inputMode = inputMode
            try? modelContext.save()
            onSaved()
            return
        }

        let round = Round(
            courseName: courseName.trimmingCharacters(in: .whitespaces),
            date: date,
            putter: selectedPutter,
            stimp: stimp,
            wind: wind,
            weather: weather,
            precipitation: precipitation,
            grainyGreens: grainyGreens,
            startingHole: startingHole,
            inputMode: inputMode
        )
        modelContext.insert(round)
        try? modelContext.save()
        onCreated(round)
    }
}

/// Simple wrapping row layout for putter chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var width: CGFloat = 0, height: CGFloat = 0, rowWidth: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                width = max(width, rowWidth)
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
            rowHeight = max(rowHeight, size.height)
        }
        width = max(width, rowWidth)
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    RoundSetupView { _ in }
        .modelContainer(for: [Putter.self, Round.self, Putt.self], inMemory: true)
}
