//
//  StatisticsView.swift
//  Puttor
//
//  Tab 2 root. Ported from (tabs)/statistics.tsx.
//

import SwiftUI
import SwiftData

private enum FilterMode: String, CaseIterable, Identifiable {
    case last1, last3, last5, last10, all, byPutter
    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .last1: return "stats.last1"
        case .last3: return "stats.last3"
        case .last5: return "stats.last5"
        case .last10: return "stats.last10"
        case .all: return "stats.allRounds"
        case .byPutter: return "stats.byPutter"
        }
    }
}

struct StatisticsView: View {
    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]
    @Query(sort: \Putter.name) private var putters: [Putter]

    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"
    @State private var filterMode: FilterMode = .last5
    @State private var selectedPutterID: PersistentIdentifier?
    @State private var dispersionFilter: DispersionFilter = .all

    private var useFeet: Bool { unitsPref == "imperial" }

    private var completeRounds: [Round] { allRounds.filter { $0.isComplete } }

    private var filteredRounds: [Round] {
        switch filterMode {
        case .last1: return Array(completeRounds.prefix(1))
        case .last3: return Array(completeRounds.prefix(3))
        case .last5: return Array(completeRounds.prefix(5))
        case .last10: return Array(completeRounds.prefix(10))
        case .all: return completeRounds
        case .byPutter:
            guard let id = selectedPutterID else { return completeRounds }
            return completeRounds.filter { $0.putter?.persistentModelID == id }
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
                }
                .frame(height: 46)

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
                    }
                    .frame(height: 46)
                }

                ScrollView {
                    if completeRounds.isEmpty {
                        emptyState(L("stats.noRounds"), "📊")
                    } else if filteredRounds.isEmpty {
                        emptyState(L("stats.noMatch"), "🔍")
                    } else {
                        VStack(spacing: Theme.Spacing.md) {
                            card {
                                Text("\(L("stats.rounds")) (\(filteredRounds.count))").font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
                                roundsGrid
                            }

                            HStack(spacing: Theme.Spacing.sm) {
                                statBox(L("summary.putts"), "\(aggregated.totalPutts)")
                                statBox(L("summary.holes"), "\(aggregated.holes)")
                                statBox(L("summary.avgPerHole"), String(format: "%.1f", aggregated.avgPuttsPerHole))
                            }

                            VStack(spacing: 4) {
                                Text(L("stats.sgPutting")).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
                                Text("\(sgAverage > 0 ? "+" : "")\(String(format: "%.2f", sgAverage))")
                                    .font(.system(size: 40, weight: .black))
                                    .foregroundStyle(sgAverage > 0.5 ? Theme.primary : (sgAverage < -0.5 ? Theme.error : Theme.warning))
                                Text(L("stats.sgSubtitle")).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Theme.Spacing.lg)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))

                            if !aggregated.makeByDistance.isEmpty {
                                card { DistanceMakeChartView(data: aggregated.makeByDistance, sgDivisor: max(1, filteredRounds.count)) }
                            }

                            if hasSituationData {
                                card {
                                    Text(L("stats.playingStats")).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
                                    HStack(spacing: Theme.Spacing.sm) {
                                        playingStat(L("stats.gir"), aggregated.girPercent, "\(aggregated.girCount)/\(aggregated.holes)")
                                        playingStat(L("stats.scramble"), aggregated.scramblePercent, "\(aggregated.scrambleSuccesses)/\(aggregated.scrambleAttempts)")
                                    }
                                }

                                card {
                                    SituationComparisonView(makeByCategory: aggregated.makeByCategory, useFeet: useFeet)
                                }
                            }

                            if !aggregated.missCounts.filter({ $0.key != .holed }).isEmpty {
                                card {
                                    Text(L("summary.missTendency")).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
                                    MissDonutView(missCounts: aggregated.missCounts)
                                }
                            }

                            card {
                                Text(L("stats.dispersion")).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
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
                                card {
                                    Text(L("summary.missReasons")).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
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
                                card {
                                    Text(L("summary.leaveByMiss")).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
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

    private func playingStat(_ label: String, _ percent: Double, _ fraction: String) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(percent.rounded()))%").font(.system(size: 22, weight: .black)).foregroundStyle(Theme.primary)
            Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.text)
            Text(fraction).font(.system(size: 10)).foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 10) { content() }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
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
