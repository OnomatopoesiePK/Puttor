//
//  StatisticsView.swift
//  Puttor
//
//  Tab 2 root. Ported from (tabs)/statistics.tsx.
//

import SwiftUI
import SwiftData

private enum FilterMode: String, CaseIterable, Identifiable {
    case last1, last3, last5, last10, custom, thisMonth, dateRange, choose, all, byPutter
    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .last1: return "stats.last1"
        case .last3: return "stats.last3"
        case .last5: return "stats.last5"
        case .last10: return "stats.last10"
        case .custom: return "stats.customCount"
        case .thisMonth: return "stats.thisMonth"
        case .dateRange: return "stats.dateRange"
        case .choose: return "stats.choose"
        case .all: return "stats.allRounds"
        case .byPutter: return "stats.byPutter"
        }
    }

    /// The fixed presets carry their own round count; the rest are handled
    /// separately (a typed count, everything, or a putter filter).
    var fixedCount: Int? {
        switch self {
        case .last1: return 1
        case .last3: return 3
        case .last5: return 5
        case .last10: return 10
        case .custom, .thisMonth, .dateRange, .choose, .all, .byPutter: return nil
        }
    }
}

struct StatisticsView: View {
    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]
    @Query(sort: \Putter.name) private var putters: [Putter]

    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"
    @State private var filterMode: FilterMode = .last5
    @AppStorage(AppStorageKeys.statsCustomRoundCount) private var customCount: Int = 7
    @State private var selectedPutterID: PersistentIdentifier?
    @AppStorage(AppStorageKeys.statsSelectedRoundIDs) private var selectedRoundIDsRaw: String = ""
    @AppStorage(AppStorageKeys.statsRangeStart) private var rangeStartStamp: Double = 0
    @AppStorage(AppStorageKeys.statsRangeEnd) private var rangeEndStamp: Double = 0
    @AppStorage(AppStorageKeys.statsRoundSort) private var roundSortRaw: String = RoundSort.newest.rawValue
    @State private var showRoundPicker = false
    @State private var dispersionFilter: DispersionFilter = .all
    @State private var dispersionShading: DispersionShading = .none

    private var useFeet: Bool { unitsPref == "imperial" }

    private var roundSort: RoundSort {
        get { RoundSort(rawValue: roundSortRaw) ?? .newest }
        nonmutating set { roundSortRaw = newValue.rawValue }
    }

    private var selectedRoundIDs: Set<String> {
        get { Set(selectedRoundIDsRaw.split(separator: ",").map(String.init)) }
        nonmutating set { selectedRoundIDsRaw = newValue.sorted().joined(separator: ",") }
    }

    /// Defaults to the last month when the window has never been set.
    private var rangeStart: Date {
        get { rangeStartStamp > 0 ? Date(timeIntervalSince1970: rangeStartStamp) : Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date() }
        nonmutating set { rangeStartStamp = newValue.timeIntervalSince1970 }
    }

    private var rangeEnd: Date {
        get { rangeEndStamp > 0 ? Date(timeIntervalSince1970: rangeEndStamp) : Date() }
        nonmutating set { rangeEndStamp = newValue.timeIntervalSince1970 }
    }

    private var completeRounds: [Round] { allRounds.filter { $0.isComplete } }

    private var filteredRounds: [Round] {
        if let count = filterMode.fixedCount {
            return Array(completeRounds.prefix(count))
        }
        switch filterMode {
        case .custom: return Array(completeRounds.prefix(customCount))
        case .thisMonth:
            return completeRounds.filter {
                Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
            }
        case .dateRange:
            // Whole days at both ends, whichever way round the pickers are set.
            let calendar = Calendar.current
            let first = min(rangeStart, rangeEnd), last = max(rangeStart, rangeEnd)
            let from = calendar.startOfDay(for: first)
            let to = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)) ?? last
            return completeRounds.filter { $0.date >= from && $0.date < to }
        case .choose:
            let picked = selectedRoundIDs
            return completeRounds.filter { picked.contains($0.id.uuidString) }
        case .byPutter:
            guard let id = selectedPutterID else { return completeRounds }
            return completeRounds.filter { $0.putter?.persistentModelID == id }
        default: return completeRounds
        }
    }

    /// Everything the tab derives from the filtered rounds, worked out in one
    /// pass.
    ///
    /// These used to be separate computed properties, and the body reads
    /// `aggregated` a dozen times — which recomputed every round's statistics
    /// a dozen times per redraw and made the controls feel sticky.
    private struct StatsBundle {
        var byRound: [PersistentIdentifier: RoundStats] = [:]
        var aggregated = RoundStats()
        /// The same merge over only the rounds entered with a score reference.
        /// Score, GIR and scramble all read the "putt for" field, so a round
        /// recorded without it would contribute a scorecard nobody played.
        var scoreAggregated = RoundStats()
        var roundCount: Int = 0
        var scoredRoundCount: Int = 0
        var hasRoundsWithoutScore: Bool { scoredRoundCount < roundCount }
        var sgAverage: Double = 0
        var gsdAverage: Double = 0
        var avgScorePerRound: Double?
        var scorePutting: ScorePuttingAnalysis?
        var allPutts: [Putt] = []
        var leaveByMiss: [PuttResult: LeaveInfo] = [:]

        var hasScoreSituationData: Bool {
            RoundStats.situationCategories.contains {
                scoreAggregated.makeByCategory[$0]?.contains { $0.total > 0 } ?? false
            }
        }

        init(rounds: [Round], useFeet: Bool) {
            var perRound: [RoundStats] = []
            var scoreBearing: [RoundStats] = []
            for r in rounds {
                let stats = RoundStats.compute(putts: r.putts, useFeet: useFeet)
                byRound[r.persistentModelID] = stats
                perRound.append(stats)
                if r.tracksScoreCategory && stats.scoredHoles > 0 {
                    scoreBearing.append(stats)
                }
            }

            aggregated = RoundStats.merge(perRound, useFeet: useFeet)
            scoreAggregated = RoundStats.merge(scoreBearing, useFeet: useFeet)
            roundCount = perRound.filter { $0.holes > 0 }.count
            scoredRoundCount = scoreBearing.count

            if !perRound.isEmpty {
                sgAverage = perRound.reduce(0) { $0 + $1.sgTotal } / Double(perRound.count)
                gsdAverage = perRound.reduce(0) { $0 + $1.gsdTotal } / Double(perRound.count)
            }

            if !scoreBearing.isEmpty {
                avgScorePerRound = scoreBearing.reduce(0.0) { $0 + Double($1.scoreRelativeToPar) } / Double(scoreBearing.count)
            }

            scorePutting = ScorePuttingAnalysis.make(rounds: rounds.compactMap { r in
                guard let stats = byRound[r.persistentModelID] else { return nil }
                return (date: r.date, courseName: r.courseName, stats: stats, tracksScore: r.tracksScoreCategory)
            })

            allPutts = rounds.flatMap { $0.putts }
            leaveByMiss = RoundStats.computeLeaveByMissDirection(allPutts)
        }
    }

    /// Marks a section whose numbers rest on the score reference when some of
    /// the filtered rounds were entered without one.
    private func sectionTitle(_ title: String, marked: Bool) -> String {
        marked ? "\(title) *" : title
    }

    @ViewBuilder
    private func scoreCoverageNote(_ data: StatsBundle) -> some View {
        if data.hasRoundsWithoutScore {
            Text(String(format: L("stats.scoreCoverage"), data.scoredRoundCount, data.roundCount))
                .font(.system(size: 10))
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Longest average leave in view, rounded up to a readable step — half a
    /// metre, or a whole foot — so the bars share one honest scale.
    private func leaveScaleMax(_ leave: [PuttResult: LeaveInfo]) -> Double {
        let longest = leave.values.map(\.avgLeaveM).max() ?? 0
        guard longest > 0 else { return 1 }
        if useFeet {
            let feet = UnitConverter.metresToFeet(longest).rounded(.up)
            return UnitConverter.feetToMetres(max(1, feet))
        }
        return max(0.5, (longest * 2).rounded(.up) / 2)
    }

    private func avgScorePerRoundText(_ average: Double?) -> String {
        guard let average else { return "—" }
        if abs(average) < 0.05 { return "E" }
        return "\(average > 0 ? "+" : "")\(String(format: "%.1f", average))"
    }

    var body: some View {
        let data = StatsBundle(rounds: filteredRounds, useFeet: useFeet)

        return NavigationStack {
            VStack(spacing: 0) {
                Text(L("stats.title"))
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.lg)
                    .padding(.bottom, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FilterMode.allCases) { mode in
                            filterChip(L(mode.labelKey), selected: filterMode == mode) { filterMode = mode }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    // Breathing room inside the scroll view, so the capsule
                    // outlines aren't clipped by its bounds.
                    .padding(.vertical, 6)
                }
                .fixedSize(horizontal: false, vertical: true)

                if filterMode == .custom {
                    customCountRow
                }

                if filterMode == .dateRange {
                    dateRangeRow
                }

                if filterMode == .choose {
                    chooseRoundsRow
                }

                if filterMode == .byPutter && !putters.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(putters) { p in
                                filterChip("🏌️ \(p.name)", selected: selectedPutterID == p.persistentModelID, color: Theme.accent) {
                                    selectedPutterID = p.persistentModelID
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, 6)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }

                ScrollView {
                    if completeRounds.isEmpty {
                        emptyState(L("stats.noRounds"), "📊")
                    } else if filteredRounds.isEmpty {
                        emptyState(L(filterMode == .choose ? "stats.noneSelected" : "stats.noMatch"), "🔍")
                    } else {
                        VStack(spacing: Theme.Spacing.md) {
                            CollapsibleStatSection(title: "\(L("stats.rounds")) (\(filteredRounds.count))", storageKey: "rounds") {
                                roundsGrid(data.byRound)
                            }

                            HStack(spacing: Theme.Spacing.sm) {
                                statBox(L("summary.putts"), "\(data.aggregated.totalPutts)")
                                statBox(L("summary.holes"), "\(data.aggregated.holes)")
                                statBox(L("summary.avgPerHole"), String(format: "%.1f", data.aggregated.avgPuttsPerHole))
                            }

                            CollapsibleStatSection(title: L("stats.sgPutting"), storageKey: "strokesGained") {
                                VStack(spacing: 4) {
                                    Text("\(data.sgAverage > 0 ? "+" : "")\(String(format: "%.2f", data.sgAverage))")
                                        .font(.system(size: 40, weight: .black))
                                        .foregroundStyle(data.sgAverage > 0.5 ? Theme.primary : (data.sgAverage < -0.5 ? Theme.error : Theme.warning))
                                    Text(L("stats.sgSubtitle")).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)

                                    Rectangle().fill(Theme.borderLight).frame(height: 1).padding(.vertical, 8)

                                    Text("\(L("stats.gsd")) \(data.gsdAverage > 0 ? "+" : "")\(String(format: "%.2f", data.gsdAverage))")
                                        .font(.system(size: 20, weight: .black))
                                        .foregroundStyle(data.gsdAverage > 0 ? Theme.primary : (data.gsdAverage < 0 ? Theme.error : Theme.textSecondary))
                                    Text(L("stats.gsdSubtitle")).font(.system(size: 11)).foregroundStyle(Theme.textMuted)
                                }
                                .frame(maxWidth: .infinity)
                            }

                            // Score, GIR and scramble come from the holes, so a
                            // round of nothing but hole-outs still has them —
                            // only the per-category putt comparison needs putts.
                            if data.scoreAggregated.holes > 0 {
                                CollapsibleStatSection(title: sectionTitle(L("stats.playingStats"), marked: data.hasRoundsWithoutScore), storageKey: "playingStats") {
                                    HStack(spacing: Theme.Spacing.sm) {
                                        // An average per round compares across
                                        // filters; a running total only grows.
                                        playingStat(L("stats.svp.avgScore"), avgScorePerRoundText(data.avgScorePerRound), subtitle: L("stats.svp.perRound"))
                                        playingStat(L("stats.gir"), "\(Int(data.scoreAggregated.girPercent.rounded()))%", subtitle: "\(data.scoreAggregated.girCount)/\(data.scoreAggregated.holes)")
                                        playingStat(L("stats.scramble"), "\(Int(data.scoreAggregated.scramblePercent.rounded()))%", subtitle: "\(data.scoreAggregated.scrambleSuccesses)/\(data.scoreAggregated.scrambleAttempts)")
                                    }
                                    scoreCoverageNote(data)
                                }
                            }

                            CollapsibleStatSection(title: sectionTitle(L("stats.scoreVsPutting"), marked: data.hasRoundsWithoutScore), storageKey: "scoreVsPutting", infoKey: "stats.svp.note") {
                                if let analysis = data.scorePutting {
                                    ScoreVsPuttingView(analysis: analysis)
                                } else {
                                    Text(String(format: L("stats.svp.needMore"), ScorePuttingAnalysis.minimumRounds))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textMuted)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            if !data.aggregated.makeByDistance.isEmpty {
                                CollapsibleStatSection(title: L("chart.makeVsTour"), storageKey: "makeByDistance") {
                                    DistanceMakeChartView(data: data.aggregated.makeByDistance, gsdDivisor: max(1, filteredRounds.count), showsTitle: false)
                                }
                            }

                            if data.hasScoreSituationData {
                                CollapsibleStatSection(title: sectionTitle(L("stats.makeBySituation"), marked: data.hasRoundsWithoutScore), storageKey: "situation") {
                                    SituationComparisonView(makeByCategory: data.scoreAggregated.makeByCategory, useFeet: useFeet, showsTitle: false)
                                    scoreCoverageNote(data)
                                }
                            }

                            if !data.aggregated.missCounts.filter({ $0.key != .holed }).isEmpty {
                                CollapsibleStatSection(title: L("summary.missTendency"), storageKey: "missTendency") {
                                    MissDonutView(missCounts: data.aggregated.missCounts)
                                }
                            }

                            CollapsibleStatSection(title: L("stats.dispersion"), storageKey: "dispersion") {
                                // Which putts to plot, and what their colour
                                // should say about them.
                                HStack(spacing: Theme.Spacing.sm) {
                                    Picker(L(dispersionFilter.labelKey), selection: $dispersionFilter) {
                                        ForEach(DispersionFilter.allCases) { f in
                                            Text(L(f.labelKey)).tag(f)
                                        }
                                    }
                                    Picker(L(dispersionShading.labelKey), selection: $dispersionShading) {
                                        ForEach(DispersionShading.allCases) { s in
                                            Text(L(s.labelKey)).tag(s)
                                        }
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Theme.text)

                                MissDispersionPlotView(
                                    putts: data.allPutts,
                                    filter: dispersionFilter,
                                    shading: dispersionShading,
                                    useFeet: useFeet
                                )
                            }

                            if data.aggregated.missReasonCounts.total > 0 {
                                CollapsibleStatSection(title: L("summary.missReasons"), storageKey: "missReasons") {
                                    HStack(spacing: Theme.Spacing.md) {
                                        if data.aggregated.missReasonCounts.missRead > 0 { reasonStat("\(data.aggregated.missReasonCounts.missRead)", L("input.missRead")) }
                                        if data.aggregated.missReasonCounts.badStroke > 0 { reasonStat("\(data.aggregated.missReasonCounts.badStroke)", L("input.badStroke")) }
                                        if data.aggregated.missReasonCounts.wrongAim > 0 { reasonStat("\(data.aggregated.missReasonCounts.wrongAim)", L("input.wrongAim")) }
                                        if data.aggregated.missReasonCounts.multiple > 0 { reasonStat("\(data.aggregated.missReasonCounts.multiple)", L("summary.multipleReasons"), color: Theme.warning) }
                                    }
                                }
                            }

                            let leave = data.leaveByMiss
                            if !leave.isEmpty {
                                CollapsibleStatSection(title: L("summary.leaveByMiss"), storageKey: "leaveByMiss") {
                                    // Bars are scaled to the longest leave in
                                    // view, rounded up, so the widest one fills
                                    // the track and the labels keep their room.
                                    let leaveScale = leaveScaleMax(leave)
                                    ForEach(leave.sorted { $0.value.count > $1.value.count }, id: \.key) { dir, info in
                                        HStack(spacing: 8) {
                                            Text(L(dir.labelKey))
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(Theme.textSecondary)
                                                .lineLimit(1).minimumScaleFactor(0.75)
                                                .frame(width: 72, alignment: .leading)
                                            ZStack(alignment: .leading) {
                                                Capsule().fill(Theme.borderLight)
                                                Capsule().fill(Theme.accent)
                                                    .frame(width: 88 * min(1, info.avgLeaveM / leaveScale))
                                            }
                                            .frame(width: 88, height: 8)
                                            Text(UnitConverter.formatDistance(info.avgLeaveM, useFeet: useFeet))
                                                .font(.system(size: 12, weight: .heavy))
                                                .foregroundStyle(Theme.accent)
                                                .lineLimit(1).minimumScaleFactor(0.8)
                                                .frame(width: 46, alignment: .trailing)
                                            Spacer(minLength: 0)
                                            Text("\(info.count) \(L("summary.puttsAbbr"))")
                                                .font(.system(size: 10))
                                                .foregroundStyle(Theme.textMuted)
                                                .lineLimit(1).minimumScaleFactor(0.8)
                                        }
                                    }
                                    Text(String(format: L("summary.leaveScale"), UnitConverter.formatDistance(leaveScale, useFeet: useFeet)))
                                        .font(.system(size: 9))
                                        .foregroundStyle(Theme.textMuted)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(Theme.Spacing.lg)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showRoundPicker) {
                RoundSelectionSheet(
                    rounds: completeRounds,
                    selectedIDs: Binding(get: { selectedRoundIDs }, set: { selectedRoundIDs = $0 }),
                    sort: Binding(get: { roundSort }, set: { roundSort = $0 })
                )
            }
            .onAppear {
                if selectedPutterID == nil { selectedPutterID = putters.first?.persistentModelID }
            }
        }
    }

    private func roundsGrid(_ statsByRound: [PersistentIdentifier: RoundStats]) -> some View {
        let ordered = roundSort == .newest
            ? filteredRounds.sorted { $0.date > $1.date }
            : filteredRounds.sorted { $0.date < $1.date }
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], spacing: 6) {
            ForEach(ordered.prefix(18)) { r in
                let sg = statsByRound[r.persistentModelID]?.sgTotal
                let color: Color = sg == nil ? Theme.textMuted : (sg! > 0.5 ? Theme.primary : (sg! < -0.5 ? Theme.error : Theme.warning))
                VStack(spacing: 2) {
                    Text(r.date.formatted(.dateTime.day().month(.abbreviated))).font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.textMuted)
                    Text(sg == nil ? "…" : "\(sg! > 0 ? "+" : "")\(String(format: "%.1f", sg!))").font(.system(size: 14, weight: .black)).foregroundStyle(color)
                    Text(r.courseName.isEmpty ? "—" : r.courseName).font(.system(size: 8)).foregroundStyle(Theme.textMuted).lineLimit(1)
                }
                .frame(minHeight: 60)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(color.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.border, lineWidth: 1))
            }
        }
    }

    /// From/to pickers for the "Date Range" preset.
    private var dateRangeRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("stats.rangeFrom"))
                    .font(.system(size: 9, weight: .bold)).tracking(0.6)
                    .foregroundStyle(Theme.textMuted)
                DatePicker("", selection: Binding(get: { rangeStart }, set: { rangeStart = $0 }), displayedComponents: .date)
                    .labelsHidden()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(L("stats.rangeTo"))
                    .font(.system(size: 9, weight: .bold)).tracking(0.6)
                    .foregroundStyle(Theme.textMuted)
                DatePicker("", selection: Binding(get: { rangeEnd }, set: { rangeEnd = $0 }), displayedComponents: .date)
                    .labelsHidden()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, 6)
    }

    /// How many rounds are hand-picked, and the way into picking them.
    private var chooseRoundsRow: some View {
        HStack(spacing: 10) {
            Text(String(format: L("stats.chooseCount"), filteredRounds.count, completeRounds.count))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)

            Spacer(minLength: 0)

            Button {
                showRoundPicker = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "checklist")
                    Text(L("stats.chooseOpen"))
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Theme.primary.opacity(0.12)))
                .overlay(Capsule().stroke(Theme.primary.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, 6)
    }

    /// Stepper for the "Custom" preset, mirroring how the putter filter reveals
    /// a second row. Capped at the number of rounds that actually exist, since
    /// asking for more than that would silently behave like "All".
    private var customCountRow: some View {
        let maxCount = max(completeRounds.count, 1)
        return HStack(spacing: 10) {
            stepperButton(systemImage: "minus", enabled: customCount > 1) {
                customCount = max(1, customCount - 1)
            }

            VStack(spacing: 1) {
                Text("\(min(customCount, maxCount))")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.primary)
                Text(L("stats.roundsCounted"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textMuted)
            }
            .frame(minWidth: 76)

            stepperButton(systemImage: "plus", enabled: customCount < maxCount) {
                customCount = min(maxCount, customCount + 1)
            }

            Spacer()

            Text(String(format: L("stats.ofAvailable"), maxCount))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, 6)
    }

    private func stepperButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Theme.primary)
                .frame(width: 40, height: 34)
                .background(Capsule().fill(Theme.primary.opacity(0.13)))
                .overlay(Capsule().stroke(Theme.primary, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    private func filterChip(_ title: String, selected: Bool, color: Color = Theme.primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? color : Theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                // Quiet enough that the selected chip reads as marked rather
                // than shouting over the numbers below it.
                .background(Capsule().fill(selected ? color.opacity(0.08) : Theme.surface))
                .overlay(Capsule().stroke(selected ? color.opacity(0.6) : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func scoreColor(_ score: Int) -> Color {
        score < 0 ? Theme.primary : (score > 0 ? Theme.error : Theme.text)
    }

    private func playingStat(_ label: String, _ value: String, subtitle: String, color: Color = Theme.text) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 22, weight: .black)).foregroundStyle(color)
            Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.text)
            Text(subtitle).font(.system(size: 10)).foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }

    private func statBox(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 24, weight: .heavy)).foregroundStyle(Theme.text)
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }

    private func reasonStat(_ value: String, _ label: String, color: Color = Theme.warning) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 26, weight: .black)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)
        }
    }

    private func emptyState(_ text: String, _ icon: String) -> some View {
        VStack(spacing: 12) {
            Text(icon).font(.system(size: 48))
            Text(text).font(.system(size: 16)).foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
    }
}
