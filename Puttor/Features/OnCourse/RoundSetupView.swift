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
    @Query private var rounds: [Round]

    var existingRound: Round? = nil
    var onCreated: (Round) -> Void = { _ in }
    var onSaved: () -> Void = {}

    @State private var courseName: String
    @FocusState private var courseNameFocused: Bool
    @State private var date: Date
    @State private var putterID: PersistentIdentifier?
    @State private var stimp: Double
    @State private var wind: WindLevel
    @State private var weather: WeatherTemp
    @State private var precipitation: Precipitation
    @State private var grainyGreens: Bool
    @State private var isTournament: Bool
    @State private var playFormat: PlayFormat
    @State private var startingHole: Int
    @State private var inputMode: InputMode
    /// Optional: nil until a way of reading is picked.
    @State private var readingMethod: ReadingMethod?
    @State private var addingReading = false
    @State private var newReadingName = ""
    @AppStorage(AppStorageKeys.customReadingMethods) private var customReadingStored = ""

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
        _isTournament = State(initialValue: existingRound?.isTournament ?? false)
        _playFormat = State(initialValue: existingRound?.playFormat ?? .strokePlay)
        // A new round starts with whatever carries the heart in Settings.
        let favouriteReading = UserDefaults.standard.string(forKey: AppStorageKeys.favouriteReadingMethod) ?? ""
        _readingMethod = State(initialValue: existingRound == nil
            ? Favourites.readingMethod(stored: favouriteReading)
            : existingRound?.readingMethod)
        _startingHole = State(initialValue: existingRound?.startingHole ?? 1)
        // New rounds start on whichever mode was used last, so a player who
        // always uses the same one never has to re-pick it.
        let lastMode = UserDefaults.standard.string(forKey: AppStorageKeys.lastInputMode).flatMap(InputMode.init(rawValue:))
        _inputMode = State(initialValue: existingRound?.inputMode ?? lastMode ?? .pro)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    // The first heading sits right under the bar; the rest keep
                    // their gap to whatever is above them.
                    VStack(alignment: .leading, spacing: 4) {
                        label(L("setup.course"), top: 0)
                        TextField(L("setup.courseNamePlaceholder"), text: $courseName)
                            .textFieldStyle(.plain)
                            .padding(Theme.Spacing.md)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
                            .foregroundStyle(Theme.text)
                            .submitLabel(.done)
                            .focused($courseNameFocused)
                            .onSubmit { TutorialController.shared.advance(from: .courseName) }
                        courseSuggestions
                        scorecardNote
                    }
                    .tutorialTarget(.courseName, cornerRadius: Theme.Radius.md)

                    label(L("setup.date"))
                    DatePicker("", selection: $date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .colorScheme(.dark)

                    VStack(alignment: .leading, spacing: 4) {
                        label(L("setup.putter"), top: 4)
                        putterSection
                            .onAppear(perform: preselectFavouritePutter)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tutorialTarget(.putter, cornerRadius: Theme.Radius.md)
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 4) {
                        label(L("setup.stimp"), top: 4)
                        stimpCard
                    }
                    .tutorialTarget(.greenSpeed, cornerRadius: Theme.Radius.md)
                    .padding(.top, 12)
                    // Grain is part of how the greens roll, so it sits with
                    // their pace rather than with the weather.
                    switchRow(titleKey: "setup.grainyGreens", infoKey: "setup.grainyGreens.info", isOn: $grainyGreens)
                        .padding(.top, 8)

                    // Wind, temperature and precipitation are one question
                    // asked three ways, so they sit under one heading.
                    VStack(alignment: .leading, spacing: 4) {
                        label(L("setup.weather"), top: 4)
                        VStack(spacing: 8) {
                            threeToggle(selection: $wind, options: WindLevel.allCases)
                            threeToggle(selection: $weather, options: WeatherTemp.allCases)
                            twoToggle(selection: $precipitation, options: Precipitation.allCases)
                        }
                    }
                    .tutorialTarget(.weather, cornerRadius: Theme.Radius.md)
                    .padding(.top, 12)

                    // How the round is scored, then whether it counts.
                    VStack(alignment: .leading, spacing: 4) {
                        label(L("setup.mode"), top: 4)
                        formatRow
                    }
                    .tutorialTarget(.format, cornerRadius: Theme.Radius.md)
                    .padding(.top, 12)
                    switchRow(titleKey: "setup.tournament", infoKey: "setup.tournament.info", isOn: $isTournament)
                        .padding(.top, 8)

                    // How the putts get read. Optional: tapping the chosen one
                    // again leaves it open.
                    label(L("setup.readingMode"))
                    readingSection

                    label(L("setup.startingHole"))
                    HStack(spacing: 10) {
                        pillButton(title: "1", selected: startingHole == 1) { startingHole = 1 }
                        pillButton(title: "10", selected: startingHole == 10) { startingHole = 10 }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                    label(L("setup.inputMode"), top: 4)
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
                    }
                    .tutorialTarget(.inputModes, cornerRadius: Theme.Radius.md)
                    .padding(.top, 12)

                }
                .padding(.horizontal, Theme.Spacing.edge)
                .padding(.top, 8)
                .padding(.bottom, Theme.Spacing.lg)
            }
            .tutorialScrolling(proxy)
            }
            .background(Theme.background.ignoresSafeArea())
            // Always in reach, so a round starts without scrolling past every
            // question. An inset rather than an overlay: the scroll view makes
            // room for it, and the last field is never left underneath.
            .safeAreaInset(edge: .bottom, spacing: 0) { floatingStartButton }
            // Inline, or the bar keeps an empty large-title row under the title.
            .navigationBarTitleDisplayMode(.inline)
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
        .overlay { TutorialOverlay(screen: .setup) }
        // The first round, played along with the tutorial, is entered in Pro.
        .onChange(of: TutorialController.shared.step) { _, step in
            if step == .inputModes { inputMode = .pro }
        }
        .preferredColorScheme(ThemeManager.shared.colorScheme)
    }

    /// A yes-or-no question as one flat row: its name, an (ⓘ) with what it
    /// means, and the switch.
    private func switchRow(titleKey: String, infoKey: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 6) {
            Text(L(titleKey))
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
            FieldInfoButton(titleKey: titleKey, textKey: infoKey)
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.primary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(minHeight: Self.rowHeight)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }

    /// Stroke play or match play, as two flat buttons the height of a switch
    /// row.
    private var formatRow: some View {
        HStack(spacing: 8) {
            ForEach(PlayFormat.allCases, id: \.self) { format in
                let selected = playFormat == format
                Button {
                    playFormat = format
                } label: {
                    Text(L(format.labelKey))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selected ? Theme.primary : Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: Self.rowHeight)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(selected ? Theme.primary.opacity(0.13) : Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(selected ? Theme.primary : Theme.border, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Every heading sits the same distance above what it names, and that
    /// distance is the one between the fields themselves.
    static let labelGap: CGFloat = 8
    /// One height for every row of this screen, so a switch never reads as
    /// flatter than the buttons above it.
    static let rowHeight: CGFloat = 46

    private func label(_ text: String, top: CGFloat = 16) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(Theme.textMuted)
            .padding(.top, top)
            .padding(.bottom, Self.labelGap)
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

    /// The built-in ways, the ones the player named, and a + to name another.
    /// Holding a named one removes it; rounds read that way keep their name.
    private var readingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 8) {
                ForEach(offeredReadingMethods) { method in
                    pillButton(title: method.label, selected: readingMethod == method) {
                        readingMethod = readingMethod == method ? nil : method
                    }
                    .contextMenu {
                        if let name = method.customName {
                            Button(role: .destructive) {
                                customReadingStored = CustomReadingMethods.removing(name, from: customReadingStored)
                                if readingMethod == method { readingMethod = nil }
                            } label: {
                                Label(L("setup.removeReading"), systemImage: "trash")
                            }
                        }
                    }
                }
                if !addingReading {
                    pillButton(title: "+", selected: false) { addingReading = true }
                        .accessibilityLabel(L("setup.addReading"))
                }
            }
            if addingReading {
                HStack {
                    TextField(L("setup.readingNamePlaceholder"), text: $newReadingName)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.card))
                        .foregroundStyle(Theme.text)
                        .submitLabel(.done)
                        .onSubmit(addReading)
                    Button(L("common.add"), action: addReading)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.primary)
                    Button("✕") { addingReading = false; newReadingName = "" }
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
    }

    /// The built-in ways and the named ones, and the round's own if it was
    /// read a way since removed.
    private var offeredReadingMethods: [ReadingMethod] {
        var methods = ReadingMethod.builtIns + CustomReadingMethods.names(in: customReadingStored).map { ReadingMethod(custom: $0) }
        if let current = readingMethod, !methods.contains(current) {
            methods.append(current)
        }
        return methods
    }

    /// The putter marked in Settings, on a new round where none is picked yet.
    private func preselectFavouritePutter() {
        guard existingRound == nil, putterID == nil else { return }
        let stored = UserDefaults.standard.string(forKey: AppStorageKeys.favouritePutter) ?? ""
        putterID = Favourites.putter(in: putters, stored: stored)?.persistentModelID
    }

    private func addReading() {
        let result = CustomReadingMethods.adding(newReadingName, to: customReadingStored)
        guard let method = result.method else { return }
        customReadingStored = result.stored
        readingMethod = method
        newReadingName = ""
        addingReading = false
    }

    private var stimpCard: some View {
        VStack(spacing: 10) {
            // The reading on top names its scale, so the number is plainly a Stimp.
            Text(String(format: L("setup.stimpValue"), Self.stimpText(for: stimp), stimpLabel))
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(stimpLabelColor)
                .frame(maxWidth: .infinity)

            Slider(value: $stimp, in: stimpRange, step: 0.5)
                .tint(Theme.primary)

            HStack {
                Text(Self.stimpText(for: stimpRange.lowerBound)).font(.caption).foregroundStyle(Theme.textMuted)
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
        // Whole Stimps without a decimal: 9, 9.5, 10.
        return String(format: value.rounded() == value ? "%.0f" : "%.1f", value)
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
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var startButton: some View {
        Button {
            startRound()
        } label: {
            Text(existingRound != nil ? L("setup.saveChanges") : L("setup.startRound"))
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.primary))
        }
        .buttonStyle(.plain)
    }

    /// The start button over the bottom of the form, with the fields fading
    /// out behind it so it never reads as one of them.
    private var floatingStartButton: some View {
        startButton
            .tutorialTarget(.startRound)
            .padding(.horizontal, Theme.Spacing.edge)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.sm)
            .background(
                LinearGradient(
                    stops: [
                        .init(color: Theme.background.opacity(0), location: 0),
                        .init(color: Theme.background, location: 0.35),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
    }

    /// Courses played before, other rounds' than this one.
    private var knownCourses: [CourseScorecard] {
        CourseScorecard.courses(in: rounds.filter { $0.persistentModelID != existingRound?.persistentModelID })
    }

    /// The course the name picks out, if it was played before.
    private var selectedCourse: CourseScorecard? {
        let key = CourseScorecard.key(courseName)
        return knownCourses.first { $0.id == key }
    }

    /// While the name is typed: the courses played before that it matches,
    /// with a note on those whose scorecard is known.
    @ViewBuilder
    private var courseSuggestions: some View {
        let suggestions = CourseScorecard.suggestions(for: courseName, in: knownCourses)
        if courseNameFocused && !suggestions.isEmpty && TutorialController.shared.step == nil {
            VStack(spacing: 0) {
                ForEach(suggestions) { course in
                    Button {
                        courseName = course.name
                        courseNameFocused = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: course.hasScorecard ? "flag.fill" : "clock.arrow.circlepath")
                                .font(.system(size: 13))
                                .foregroundStyle(course.hasScorecard ? Theme.primary : Theme.textMuted)
                                .frame(width: 20)
                            Text(course.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if course.hasScorecard {
                                Text(scorecardSummary(course))
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if course.id != suggestions.last?.id {
                        Rectangle().fill(Theme.border).frame(height: 1)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
            .padding(.top, 4)
        }
    }

    /// Under a name whose course has a scorecard: its pars come along.
    @ViewBuilder
    private var scorecardNote: some View {
        if existingRound == nil, let course = selectedCourse, course.hasScorecard {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.primary)
                Text(String(format: L("setup.scorecardKnown"), scorecardSummary(course)))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 12))
            .padding(.top, 4)
        }
    }

    /// "Par 72" for a full card, "Par 36 · 9 holes" for a part of one.
    private func scorecardSummary(_ course: CourseScorecard) -> String {
        let par = String(format: L("input.holePar.value"), course.totalPar)
        return course.pars.count == 18 ? par : "\(par) · \(String(format: L("setup.scorecardHoles"), course.pars.count))"
    }

    private func startRound() {
        let tutorial = TutorialController.shared
        // The first round, played along with the tutorial, is entered in Pro.
        let mode: InputMode = tutorial.step == .startRound ? .pro : inputMode
        let selectedPutter = putters.first { $0.persistentModelID == putterID }
        UserDefaults.standard.set(mode.rawValue, forKey: AppStorageKeys.lastInputMode)

        if let existingRound {
            existingRound.courseName = courseName.trimmingCharacters(in: .whitespaces)
            existingRound.date = date
            existingRound.putter = selectedPutter
            existingRound.stimp = stimp
            existingRound.wind = wind
            existingRound.weather = weather
            existingRound.precipitation = precipitation
            existingRound.grainyGreens = grainyGreens
            existingRound.isTournament = isTournament
            existingRound.playFormat = playFormat
            existingRound.readingMethod = readingMethod
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
            isTournament: isTournament,
            playFormat: playFormat,
            startingHole: startingHole,
            inputMode: mode
        )
        round.readingMethod = readingMethod
        // A course played before brings its pars along.
        if let course = selectedCourse, course.hasScorecard {
            round.holeDetails = course.holeDetails
        }
        modelContext.insert(round)
        try? modelContext.save()
        tutorial.advance(from: .startRound)
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
