//
//  StatisticsView.swift
//  Puttor
//
//  Tab 2 root. Ported from (tabs)/statistics.tsx.
//

import SwiftUI
import SwiftData

private enum FilterMode: String, CaseIterable, Identifiable {
    case last1, last3, last5, last10, custom, all, byPutter
    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .last1: return "stats.last1"
        case .last3: return "stats.last3"
        case .last5: return "stats.last5"
        case .last10: return "stats.last10"
        case .custom: return "stats.customCount"
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
        case .custom, .all, .byPutter: return nil
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
    @State private var dispersionFilter: DispersionFilter = .all

    private var useFeet: Bool { unitsPref == "imperial" }

    private var completeRounds: [Round] { allRounds.filter { $0.isComplete } }

    private var filteredRounds: [Round] {
        if let count = filterMode.fixedCount {
            return Array(completeRounds.prefix(count))
        }
        switch filterMode {
        case .custom: return Array(completeRounds.prefix(customCount))
        case .byPutter:
            guard let id = selectedPutterID else { return completeRounds }
            return completeRounds.filter { $0.putter?.persistentModelID == id }
        default: return completeRounds
        }
    }

    private var statsByRound: [PersistentIdentifier: RoundStats] {
        var map: [PersistentIdentifier: RoundStats] = [:]
        for r in filteredRounds {
            map[r.persistentModelID] = RoundStats.compute(putts: r.putts, useFeet: useFeet)
        }
        return map
    }

    private var aggregated: RoundStats { RoundStats.merge(Array(statsByRound.values), useFeet: useFeet) }

    private var sgAverage: Double {
        guard !statsByRound.isEmpty else { return 0 }
        return statsByRound.values.reduce(0) { $0 + $1.sgTotal } / Double(statsByRound.count)
    }

    /// GSD summed over a round, averaged across the filtered rounds — the
    /// make-rate companion to strokes gained.
    private var gsdAverage: Double {
        guard !statsByRound.isEmpty else { return 0 }
        return statsByRound.values.reduce(0) { $0 + $1.gsdTotal } / Double(statsByRound.count)
    }

    /// Score against putting for the filtered rounds — nil until there are
    /// enough finished rounds for a spread to mean anything.
    private var scorePuttingAnalysis: ScorePuttingAnalysis? {
        ScorePuttingAnalysis.make(rounds: filteredRounds.compactMap { r in
            guard let stats = statsByRound[r.persistentModelID] else { return nil }
            return (date: r.date, courseName: r.courseName, stats: stats)
        })
    }

    /// Average strokes over par per round, scaled to 18 holes so a 9-hole card
    /// doesn't drag the average down.
    private var avgScorePerRound: Double? {
        let scored = statsByRound.values.filter { $0.scoredHoles > 0 }
        guard !scored.isEmpty else { return nil }
        let perRound = scored.map { Double($0.scoreRelativeToPar) * 18 / Double($0.scoredHoles) }
        return perRound.reduce(0, +) / Double(perRound.count)
    }

    private var avgScorePerRoundText: String {
        guard let avg = avgScorePerRound else { return "—" }
        if abs(avg) < 0.05 { return "E" }
        return "\(avg > 0 ? "+" : "")\(String(format: "%.1f", avg))"
    }

    private var dispersionPutts: [Putt] { filteredRounds.flatMap { $0.putts } }

    private var hasSituationData: Bool {
        RoundStats.situationCategories.contains {
            aggregated.makeByCategory[$0]?.contains { $0.total > 0 } ?? false
        }
    }

    var body: some View {
        NavigationStack {
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
                        emptyState(L("stats.noMatch"), "🔍")
                    } else {
                        VStack(spacing: Theme.Spacing.md) {
                            CollapsibleStatSection(title: "\(L("stats.rounds")) (\(filteredRounds.count))", storageKey: "rounds") {
                                roundsGrid
                            }

                            HStack(spacing: Theme.Spacing.sm) {
                                statBox(L("summary.putts"), "\(aggregated.totalPutts)")
                                statBox(L("summary.holes"), "\(aggregated.holes)")
                                statBox(L("summary.avgPerHole"), String(format: "%.1f", aggregated.avgPuttsPerHole))
                            }

                            CollapsibleStatSection(title: L("stats.sgPutting"), storageKey: "strokesGained") {
                                VStack(spacing: 4) {
                                    Text("\(sgAverage > 0 ? "+" : "")\(String(format: "%.2f", sgAverage))")
                                        .font(.system(size: 40, weight: .black))
                                        .foregroundStyle(sgAverage > 0.5 ? Theme.primary : (sgAverage < -0.5 ? Theme.error : Theme.warning))
                                    Text(L("stats.sgSubtitle")).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)

                                    Rectangle().fill(Theme.borderLight).frame(height: 1).padding(.vertical, 8)

                                    Text("\(L("stats.gsd")) \(gsdAverage > 0 ? "+" : "")\(String(format: "%.2f", gsdAverage))")
                                        .font(.system(size: 20, weight: .black))
                                        .foregroundStyle(gsdAverage > 0 ? Theme.primary : (gsdAverage < 0 ? Theme.error : Theme.textSecondary))
                                    Text(L("stats.gsdSubtitle")).font(.system(size: 11)).foregroundStyle(Theme.textMuted)
                                }
                                .frame(maxWidth: .infinity)
                            }

                            // Score, GIR and scramble come from the holes, so a
                            // round of nothing but hole-outs still has them —
                            // only the per-category putt comparison needs putts.
                            if aggregated.holes > 0 {
                                CollapsibleStatSection(title: L("stats.playingStats"), storageKey: "playingStats") {
                                    HStack(spacing: Theme.Spacing.sm) {
                                        // An average per round compares across
                                        // filters; a running total only grows.
                                        playingStat(L("stats.score"), avgScorePerRoundText, subtitle: L("stats.svp.perRound"), color: scoreColor(aggregated.scoreRelativeToPar))
                                        playingStat(L("stats.gir"), "\(Int(aggregated.girPercent.rounded()))%", subtitle: "\(aggregated.girCount)/\(aggregated.holes)")
                                        playingStat(L("stats.scramble"), "\(Int(aggregated.scramblePercent.rounded()))%", subtitle: "\(aggregated.scrambleSuccesses)/\(aggregated.scrambleAttempts)")
                                    }
                                }
                            }

                            CollapsibleStatSection(title: L("stats.scoreVsPutting"), storageKey: "scoreVsPutting") {
                                if let analysis = scorePuttingAnalysis {
                                    ScoreVsPuttingView(analysis: analysis)
                                } else {
                                    Text(String(format: L("stats.svp.needMore"), ScorePuttingAnalysis.minimumRounds))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textMuted)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            if !aggregated.makeByDistance.isEmpty {
                                CollapsibleStatSection(title: L("chart.makeVsTour"), storageKey: "makeByDistance") {
                                    DistanceMakeChartView(data: aggregated.makeByDistance, gsdDivisor: max(1, filteredRounds.count), showsTitle: false)
                                }
                            }

                            if hasSituationData {
                                CollapsibleStatSection(title: L("stats.makeBySituation"), storageKey: "situation") {
                                    SituationComparisonView(makeByCategory: aggregated.makeByCategory, useFeet: useFeet, showsTitle: false)
                                }
                            }

                            if !aggregated.missCounts.filter({ $0.key != .holed }).isEmpty {
                                CollapsibleStatSection(title: L("summary.missTendency"), storageKey: "missTendency") {
                                    MissDonutView(missCounts: aggregated.missCounts)
                                }
                            }

                            CollapsibleStatSection(title: L("stats.dispersion"), storageKey: "dispersion") {
                                Picker(L(dispersionFilter.labelKey), selection: $dispersionFilter) {
                                    ForEach(DispersionFilter.allCases) { f in
                                        Text(L(f.labelKey)).tag(f)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Theme.text)
                                MissDispersionPlotView(putts: dispersionPutts, filter: dispersionFilter)
                            }

                            if aggregated.missReasonCounts.total > 0 {
                                CollapsibleStatSection(title: L("summary.missReasons"), storageKey: "missReasons") {
                                    HStack(spacing: Theme.Spacing.md) {
                                        if aggregated.missReasonCounts.missRead > 0 { reasonStat("\(aggregated.missReasonCounts.missRead)", L("input.missRead")) }
                                        if aggregated.missReasonCounts.badStroke > 0 { reasonStat("\(aggregated.missReasonCounts.badStroke)", L("input.badStroke")) }
                                        if aggregated.missReasonCounts.wrongAim > 0 { reasonStat("\(aggregated.missReasonCounts.wrongAim)", L("input.wrongAim")) }
                                        if aggregated.missReasonCounts.multiple > 0 { reasonStat("\(aggregated.missReasonCounts.multiple)", L("summary.multipleReasons"), color: Theme.warning) }
                                    }
                                }
                            }

                            let leave = RoundStats.computeLeaveByMissDirection(dispersionPutts)
                            if !leave.isEmpty {
                                CollapsibleStatSection(title: L("summary.leaveByMiss"), storageKey: "leaveByMiss") {
                                    ForEach(leave.sorted { $0.value.count > $1.value.count }, id: \.key) { dir, info in
                                        HStack(spacing: 8) {
                                            Text(L(dir.labelKey)).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textSecondary).frame(width: 76, alignment: .leading)
                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.borderLight)
                                                    RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.accent)
                                                        .frame(width: geo.size.width * min(1, info.avgLeaveM / 5))
                                                }
                                            }
                                            .frame(height: 8)
                                            Text(UnitConverter.formatDistance(info.avgLeaveM, useFeet: useFeet)).font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.accent).frame(width: 40, alignment: .trailing)
                                            Text("\(info.count) \(L("summary.puttsAbbr"))").font(.system(size: 10)).foregroundStyle(Theme.textMuted)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(Theme.Spacing.lg)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .onAppear {
                if selectedPutterID == nil { selectedPutterID = putters.first?.persistentModelID }
            }
        }
    }

    private var roundsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], spacing: 6) {
            ForEach(filteredRounds.prefix(18)) { r in
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
                .background(Capsule().fill(selected ? color.opacity(0.13) : Theme.surface))
                .overlay(Capsule().stroke(selected ? color : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func scoreColor(_ score: Int) -> Color {
        score < 0 ? Theme.primary : (score > 0 ? Theme.error : Theme.text)
    }

    private func playingStat(_ label: String, _ value: String, subtitle: String, color: Color = Theme.primary) -> some View {
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
