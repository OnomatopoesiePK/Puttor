//
//  RoundSummaryView.swift
//  Puttor
//
//  Ported from round/summary.tsx, plus a "Highlight" card (best single putt
//  of the round by strokes gained) to satisfy the spec's "highlight" ask.
//

import SwiftUI
import SwiftData

struct RoundSummaryView: View {
    let round: Round
    var onDone: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"
    @State private var expandedHole: Int?
    @State private var editingHole: Int?

    private var useFeet: Bool { unitsPref == "imperial" }

    private var putts: [Putt] {
        round.putts.sorted { $0.holeNumber != $1.holeNumber ? $0.holeNumber < $1.holeNumber : $0.puttNumber < $1.puttNumber }
    }

    private var stats: RoundStats { RoundStats.compute(putts: putts, useFeet: useFeet) }

    private var holeCount: Int { round.holeCount == 9 ? 9 : 18 }

    private var highlight: Putt? {
        putts.filter { $0.result == .holed && $0.distanceM >= 1.5 }.max { $0.gsd < $1.gsd }
    }

    private var hasSituationData: Bool {
        RoundStats.situationCategories.contains {
            stats.makeByCategory[$0]?.contains { $0.total > 0 } ?? false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
        topBar
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(round.courseName.isEmpty ? L("onCourse.unnamedCourse") : round.courseName)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Theme.text)
                    Text(round.date.formatted(date: .complete, time: .omitted))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    if let putter = round.putter {
                        Text("🏌️ \(putter.name)").font(.system(size: 13)).foregroundStyle(Theme.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Theme.Spacing.xs) {
                    bigStat(L("summary.putts"), "\(stats.totalPutts)")
                    bigStat(L("summary.holes"), "\(stats.holes)")
                    bigStat(L("summary.avgPerHole"), String(format: "%.1f", stats.avgPuttsPerHole))
                }

                // Two different questions, so they get their own row: strokes
                // gained scores whole holes, GSD scores single putts.
                HStack(spacing: Theme.Spacing.xs) {
                    bigStat(L("summary.sg"),
                            "\(stats.sgTotal > 0 ? "+" : "")\(String(format: "%.2f", stats.sgTotal))",
                            caption: L("summary.sgCaption"),
                            color: sgColor(stats.sgTotal))
                    bigStat(L("stats.gsd"),
                            "\(stats.gsdTotal > 0 ? "+" : "")\(String(format: "%.2f", stats.gsdTotal))",
                            caption: L("summary.gsdCaption"),
                            color: sgColor(stats.gsdTotal))
                }

                if let highlight {
                    highlightCard(highlight)
                }

                // A round entered without the score reference has no scorecard
                // to report — every putt would carry the default par.
                if round.tracksScoreCategory {
                card {
                    Text(L("stats.playingStats")).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
                    HStack(spacing: Theme.Spacing.sm) {
                        playingStat(L("stats.score"), stats.scoreRelativeToParText, subtitle: String(format: L("stats.overHoles"), stats.scoredHoles), color: scoreColor(stats.scoreRelativeToPar))
                        playingStat(L("stats.gir"), "\(Int(stats.girPercent.rounded()))%", subtitle: "\(stats.girCount)/\(stats.holes)")
                        playingStat(L("stats.scramble"), "\(Int(stats.scramblePercent.rounded()))%", subtitle: "\(stats.scrambleSuccesses)/\(stats.scrambleAttempts)")
                    }
                    HStack(spacing: Theme.Spacing.sm) {
                        playingStat(
                            L("stats.puttsGir"),
                            stats.avgPuttsOnGir.map { String(format: "%.2f", $0) } ?? "—",
                            subtitle: String(format: L("stats.overHoles"), stats.girPuttedHoles)
                        )
                        playingStat(
                            L("stats.puttsNoGir"),
                            stats.avgPuttsOffGir.map { String(format: "%.2f", $0) } ?? "—",
                            subtitle: String(format: L("stats.overHoles"), stats.nonGirPuttedHoles)
                        )
                        playingStat(
                            L("stats.girProximity"),
                            stats.avgGirProximityM.map { UnitConverter.formatDistance($0, useFeet: useFeet) } ?? "—",
                            subtitle: L("stats.firstPutt")
                        )
                    }
                }
                }

                card {
                    Text(L("summary.holes").uppercased()).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
                    holeGrid
                    if let expandedHole {
                        holeDetail(expandedHole)
                    }
                    HStack(spacing: 14) {
                        legendDot(Theme.primary, L("summary.onePutt"))
                        legendDot(Theme.text, L("summary.twoPutts"))
                        legendDot(Theme.error, L("summary.threePlusPutts"))
                    }
                }

                card {
                    DistanceMakeChartView(data: stats.makeByDistance)
                }

                if hasSituationData {
                    card {
                        SituationComparisonView(makeByCategory: stats.makeByCategory, useFeet: useFeet)
                    }
                }

                if let topMiss = topMiss {
                    card {
                        Text(L("summary.missTendency")).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
                        Text("\(L("summary.mostCommonMiss")): \(L(topMiss.0.labelKey)) (\(topMiss.1)×)")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.text)
                        missGrid
                    }
                }

                if stats.missReasonCounts.total > 0 {
                    card {
                        Text(L("summary.missReasons")).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
                        HStack(spacing: Theme.Spacing.md) {
                            if stats.missReasonCounts.missRead > 0 { reasonStat("\(stats.missReasonCounts.missRead)", L("input.missRead")) }
                            if stats.missReasonCounts.badStroke > 0 { reasonStat("\(stats.missReasonCounts.badStroke)", L("input.badStroke")) }
                            if stats.missReasonCounts.wrongAim > 0 { reasonStat("\(stats.missReasonCounts.wrongAim)", L("input.wrongAim")) }
                            if stats.missReasonCounts.multiple > 0 { reasonStat("\(stats.missReasonCounts.multiple)", L("summary.multipleReasons"), color: Theme.warning) }
                        }
                    }
                }

                if !stats.leaveByMissDirection.isEmpty {
                    card {
                        Text(L("summary.leaveByMiss")).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
                        ForEach(stats.leaveByMissDirection.sorted { $0.value.count > $1.value.count }, id: \.key) { dir, info in
                            leaveRow(dir, info)
                        }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(item: $editingHole) { hole in
            switch round.inputMode {
            case .quick:
                RoundInputQuickView(round: round, initialHole: hole, isPostRoundEdit: true, onDone: onDone)
            case .custom:
                RoundInputCustomView(round: round, initialHole: hole, isPostRoundEdit: true, onDone: onDone)
            case .pro:
                RoundInputView(round: round, initialHole: hole, isPostRoundEdit: true, onDone: onDone)
            }
        }
    }

    /// Drawn in the content rather than the navigation bar, matching the input
    /// screens — toolbar items carry their own capsule background, which an
    /// outlined button shows through as a stray shape around it.
    private var topBar: some View {
        HStack {
            Text(L("summary.title"))
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Theme.text)
            Spacer()
            Button { onDone() } label: {
                Text(L("summary.done"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.primary, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    private func editHole(_ hole: Int) {
        round.isComplete = false
        try? modelContext.save()
        editingHole = hole
    }

    private var topMiss: (PuttResult, Int)? {
        stats.missCounts.filter { $0.key != .holed }.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    private func sgColor(_ sg: Double) -> Color {
        sg > 0.5 ? Theme.primary : (sg < -0.5 ? Theme.error : Theme.warning)
    }

    private func bigStat(_ label: String, _ value: String, caption: String? = nil, color: Color = Theme.text) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .black)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 9, weight: .semibold)).tracking(0.6).foregroundStyle(Theme.textMuted)
            if let caption {
                Text(caption).font(.system(size: 9)).foregroundStyle(Theme.textMuted.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }

    private func highlightCard(_ putt: Putt) -> some View {
        VStack(spacing: 6) {
            Text("⭐ \(L("summary.highlight"))").font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.accent)
            Text("\(L("summary.holeAbbr")) \(putt.holeNumber) · \(UnitConverter.formatDistance(putt.distanceM, useFeet: useFeet)) \(L("result.holed"))")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Theme.text)
            Text("+\(String(format: "%.2f", putt.gsd)) \(L("stats.gsd"))")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.accent.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
    }

    private func scoreText(_ score: Int) -> String {
        if score == 0 { return "E" }
        return score > 0 ? "+\(score)" : "\(score)"
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

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 10) { content() }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
    }

    /// The holes this round actually consists of, in play order — a 9-hole
    /// round started on 10 is holes 10...18, not 1...9.
    private var roundHoles: [Int] { Array(round.holeSequence.prefix(holeCount)) }

    private var holeGrid: some View {
        // 9 holes fill a 3x3 block; 18 use 3 rows of 6.
        let columns = holeCount == 9 ? 3 : 6
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
            ForEach(roundHoles, id: \.self) { hole in
                holeCell(hole)
            }
        }
    }

    private func holeCell(_ hole: Int) -> some View {
        let played = stats.puttsByHole[hole] != nil
        let count = stats.puttsByHole[hole] ?? 0
        let bg: Color = !played ? Theme.borderLight : (count == 0 ? Theme.accent.opacity(0.25) : (count == 1 ? Theme.primary.opacity(0.2) : (count >= 3 ? Theme.error.opacity(0.2) : Theme.surface)))
        let fg: Color = !played ? Theme.textMuted : (count == 0 ? Theme.accent : (count == 1 ? Theme.primary : (count >= 3 ? Theme.error : Theme.text)))
        let isOpen = expandedHole == hole

        return Button {
            // Unplayed holes stay tappable on purpose — that's the entry point
            // for backfilling a hole that was skipped during the round.
            expandedHole = (expandedHole == hole) ? nil : hole
        } label: {
            VStack(spacing: 2) {
                Text("\(hole)").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.textMuted)
                Text(played ? "\(count)" : "–").font(.system(size: 18, weight: .black)).foregroundStyle(fg)
            }
            .frame(maxWidth: .infinity, minHeight: holeCount == 9 ? 64 : 48)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(bg))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(isOpen ? Theme.accent : Theme.border, lineWidth: isOpen ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func holeDetail(_ hole: Int) -> some View {
        let holePutts = putts.filter { $0.holeNumber == hole && $0.puttNumber > 0 }.sorted { $0.puttNumber < $1.puttNumber }
        // No putt records at all means the hole was never played; a hole with
        // only the 0-putt sentinel was played but holed out from off the green.
        let neverPlayed = stats.puttsByHole[hole] == nil
        let isHoleOut = holePutts.isEmpty && !neverPlayed

        return VStack(alignment: .leading, spacing: 6) {
            let holeRecords = putts.filter { $0.holeNumber == hole }
            HStack {
                Text("\(L("summary.holeAbbr")) \(hole)").font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.accent)
                Spacer()
                // Strokes gained belongs to the hole, so it sits in the hole's
                // own header rather than among the per-putt numbers.
                if let holeSG = RoundStats.holeStrokesGained(holeRecords) {
                    Text("\(L("summary.sg")) \(holeSG > 0 ? "+" : "")\(String(format: "%.2f", holeSG))")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(holeSG > 0 ? Theme.primary : (holeSG < 0 ? Theme.error : Theme.textSecondary))
                        .padding(.trailing, 4)
                }
                Button {
                    editHole(hole)
                } label: {
                    Label(neverPlayed ? L("summary.addPutts") : L("summary.editHole"), systemImage: neverPlayed ? "plus" : "pencil")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.primary.opacity(0.13)))
                        .overlay(Capsule().stroke(Theme.primary, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            if neverPlayed {
                Text(L("summary.notPlayed"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            if isHoleOut {
                let category = putts.first { $0.holeNumber == hole && $0.puttNumber == 0 }?.puttFor ?? .par
                // Naming the score it was holed out for matters: that's what
                // decides the hole's score, its GIR and its scramble.
                Text("🎯 \(String(format: L("summary.holedOutFor"), L(category.labelKey)))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            let holeScore = round.tracksScoreCategory ? RoundStats.holeScoreRelativeToPar(holeRecords) : nil
            if holeScore != nil || !holePutts.isEmpty {
                HStack(spacing: 8) {
                    if let holeScore {
                        Text(String(format: L("summary.holeScore"), scoreText(holeScore)))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(scoreColor(holeScore))
                        // Same weight and size as the score — it reads as part
                        // of the same sentence about the hole.
                        if RoundStats.holeCategory(holeRecords)?.isGreenInRegulation == true {
                            Text(L("stats.gir"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.primary)
                        }
                    }
                    Spacer(minLength: 0)
                    // Column heading for the per-putt numbers listed below.
                    if !holePutts.isEmpty {
                        Text(L("stats.gsd"))
                            .font(.system(size: 9, weight: .bold)).tracking(0.8)
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
            ForEach(holePutts) { p in
                HStack(spacing: 8) {
                    // "Birdie putt" says more than "putt 1" — it's the score
                    // that putt was for.
                    Text(String(format: L("summary.puttForLabel"), L(p.puttFor.labelKey)))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(p.puttFor.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 78, alignment: .leading)
                    Text(UnitConverter.formatDistance(p.distanceM, useFeet: useFeet)).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text).frame(width: 46, alignment: .leading)
                    Text(L(p.result.labelKey)).font(.system(size: 12, weight: .semibold)).foregroundStyle(p.result == .holed ? Theme.primary : Theme.error)
                    Spacer()
                    Text("\(p.gsd > 0 ? "+" : "")\(String(format: "%.2f", p.gsd))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(p.gsd > 0 ? Theme.primary : (p.gsd < 0 ? Theme.error : Theme.textSecondary))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
    }

    private var missGrid: some View {
        MissDonutView(missCounts: stats.missCounts)
    }

    private func reasonStat(_ value: String, _ label: String, color: Color = Theme.warning) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 26, weight: .black)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)
        }
    }

    private func leaveRow(_ dir: PuttResult, _ info: LeaveInfo) -> some View {
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
            Text("(\(info.count)×)").font(.system(size: 10)).foregroundStyle(Theme.textMuted)
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
        }
    }
}
