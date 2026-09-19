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
    /// Straight over the list of rounds a swipe back does what the button does.
    /// Straight after entering a round it would land back in the input
    /// instead, so there it stays off.
    var allowsSwipeBack = false

    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"
    @State private var expandedHole: Int?
    @State private var editingHole: Int?
    /// The holes as a scorecard rather than by putts; kept between rounds.
    @AppStorage("summary.holesShowScore") private var holesShowScore = false
    @State private var showHoleColours = false

    private var useFeet: Bool { unitsPref == "imperial" }

    private var putts: [Putt] {
        round.putts.sorted { $0.holeNumber != $1.holeNumber ? $0.holeNumber < $1.holeNumber : $0.puttNumber < $1.puttNumber }
    }

    private var stats: RoundStats { RoundStats.compute(putts: putts, useFeet: useFeet) }

    private var holeCount: Int { round.holeCount == 9 ? 9 : 18 }

    private var highlight: Putt? {
        putts.filter { $0.result == .holed && $0.distanceM >= 1.5 }.max { $0.pcg < $1.pcg }
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
                    // The round's own size, picked-up holes included — the
                    // averages beside it are the ones that leave them out.
                    bigStat(
                        L("summary.holes"),
                        "\(stats.playedHoles)",
                        caption: stats.pickedUpHoles > 0
                            ? String(format: L("summary.puttedHoles"), stats.holes)
                            : nil
                    )
                    bigStat(
                        L("summary.avgPerHole"),
                        String(format: "%.1f", stats.avgPuttsPerHole),
                        highlighted: RoundHighlights.lowPuttsPerHole(stats.avgPuttsPerHole)
                    )
                }

                // Two different questions, so they get their own row: strokes
                // gained scores whole holes, PCG scores single putts.
                HStack(spacing: Theme.Spacing.xs) {
                    bigMetric(stats.sgTotal, metric: .sg,
                              caption: L("summary.sgCaption"),
                              highlighted: RoundHighlights.strongStrokesGained(stats.sgTotal))
                    bigMetric(stats.pcgTotal, metric: .pcg,
                              caption: L("summary.pcgCaption"),
                              highlighted: RoundHighlights.strongPCG(stats.pcgTotal))
                }

                if let highlight {
                    highlightCard(highlight)
                }

                // A round entered without the score reference has no scorecard
                // to report — every putt would carry the default par.
                if round.tracksScoreCategory {
                card {
                    Text(L("stats.playingStats")).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.sm), count: 3), spacing: Theme.Spacing.sm) {
                        playingStat(
                            L(stats.pickedUpHoles > 0 ? "stats.gbe" : "stats.score"),
                            stats.scoreRelativeToParText,
                            // In strokes where every hole has its par.
                            subtitle: stats.averageStrokesPerRound.map { String(format: L("stats.strokesPerRound"), String(Int($0.rounded()))) }
                                ?? String(format: L("stats.overHoles"), stats.scoredHoles),
                            color: scoreColor(stats.scoreRelativeToPar),
                            highlighted: RoundHighlights.scoreUnderPar(stats.scoreRelativeToPar)
                        )
                        playingStat(
                            L("stats.gir"), "\(Int(stats.girPercent.rounded()))%",
                            subtitle: "\(stats.girCount)/\(stats.holes)",
                            highlighted: RoundHighlights.strongGreensInRegulation(stats.girPercent)
                        )
                        playingStat(
                            L("stats.scramble"), "\(Int(stats.scramblePercent.rounded()))%",
                            subtitle: "\(stats.scrambleSuccesses)/\(stats.scrambleAttempts)",
                            highlighted: RoundHighlights.strongScrambling(stats.scramblePercent)
                        )
                        playingStat(
                            L("stats.conversion"),
                            stats.girCount > 0 ? "\(Int(stats.girConversionPercent.rounded()))%" : "—",
                            subtitle: "\(stats.girConversions)/\(stats.girCount)",
                            highlighted: RoundHighlights.strongConversion(stats.girConversionPercent)
                        )
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
                        // Where putt 0 or the course's card gave the pars.
                        if !stats.parHoles.isEmpty {
                            ForEach(HoleDetails.pars, id: \.self) { par in
                                playingStat(
                                    String(format: L("stats.parAverage"), par),
                                    stats.averageStrokes(onPar: par).map { String(format: "%.2f", $0) } ?? "—",
                                    subtitle: String(format: L("stats.overHoles"), stats.parHoles[par] ?? 0)
                                )
                            }
                        }
                    }
                    if stats.girOpportunityAnswered > 0 {
                        HStack(spacing: Theme.Spacing.sm) {
                            playingStat(
                                L("stats.girOpportunity"),
                                stats.girOpportunityPercent.map { "\(Int($0.rounded()))%" } ?? "—",
                                subtitle: "\(stats.girOpportunities)/\(stats.girOpportunityAnswered)"
                            )
                            playingStat(
                                L("stats.girOpportunityConversion"),
                                stats.girOpportunityConversionPercent.map { "\(Int($0.rounded()))%" } ?? "—",
                                subtitle: "\(stats.girOpportunitiesConverted)/\(stats.girOpportunities)"
                            )
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    playingStatWide(
                        L("stats.girProximity"),
                        stats.avgGirProximityM.map { UnitConverter.formatDistance($0, useFeet: useFeet) } ?? "—",
                        subtitle: L("stats.firstPutt")
                    )
                }
                }

                mistakesCard

                card {
                    holesHeader
                    holeGrid
                    if let expandedHole {
                        holeDetail(expandedHole)
                    }
                    holeLegend
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
            .padding(.horizontal, Theme.Spacing.edge)
            .padding(.vertical, Theme.Spacing.lg)
        }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .swipeBack(allowed: allowsSwipeBack)
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

    /// The strokes this round handed back where it shouldn't have: a three-putt
    /// from two-putt range, a miss from inside the near-certain distances.
    @ViewBuilder
    private var mistakesCard: some View {
        let mistakes = AvoidableMistakeFinder.find(inRounds: [putts])
        if mistakes.hasAny {
            card {
                Text(L("coach.mistakes"))
                    .font(.system(size: 10, weight: .bold)).tracking(1.2)
                    .foregroundStyle(Theme.error)

                if mistakes.threePutts > 0 {
                    mistakeRow(String(format: L("coach.mistakes.threePutts"),
                                      mistakes.threePutts, mistakes.holes, mistakes.threePuttStrokesLost))
                }
                if mistakes.missedSureThings > 0 {
                    mistakeRow(String(format: L("coach.mistakes.sureThings"),
                                      mistakes.missedSureThings,
                                      mistakes.sureThingAttempts,
                                      Int(AvoidableMistakeFinder.sureThingProbability * 100)))
                }
            }
        }
    }

    private func mistakeRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.error)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The same box, for the two numbers that carry their own name: the unit
    /// sits beside the figure instead of under it.
    private func bigMetric(
        _ value: Double,
        metric: MetricValue.Metric,
        caption: String,
        highlighted: Bool = false
    ) -> some View {
        VStack(spacing: 2) {
            MetricValue(value: value, metric: metric, size: 20, colour: sgColor(value))
            Text(caption).font(.system(size: 9)).foregroundStyle(Theme.textMuted.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
        .pulsingHighlight(highlighted)
    }

    private func bigStat(_ label: String, _ value: String, caption: String? = nil, color: Color = Theme.text, highlighted: Bool = false) -> some View {
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
        .pulsingHighlight(highlighted)
    }

    private func highlightCard(_ putt: Putt) -> some View {
        VStack(spacing: 6) {
            Text("⭐ \(L("summary.highlight"))").font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.accent)
            Text("\(L("summary.holeAbbr")) \(putt.holeNumber) · \(UnitConverter.formatDistance(putt.distanceM, useFeet: useFeet)) \(L("result.holed"))")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Theme.text)
            MetricValue(value: putt.pcg, metric: .pcg, size: 14, colour: Theme.primary)
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


    /// A full-width row rather than a tile: the proximity is one number with a
    /// long name, and a seventh square in a three-column grid left a hole.
    private func playingStatWide(_ label: String, _ value: String, subtitle: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Theme.text)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }

    private func playingStat(_ label: String, _ value: String, subtitle: String, color: Color = Theme.primary, highlighted: Bool = false) -> some View {
        // Every box the same size, whatever length its label happens to be —
        // a row of six that steps up and down reads as an accident.
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                // Two lines, so a label like "Eagle/Birdie conversion rate"
                // can say what it is instead of shrinking to nothing.
                .lineLimit(2).minimumScaleFactor(0.6)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textMuted)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        // maxHeight lets every box in a grid row match the tallest of them.
        .frame(maxWidth: .infinity, minHeight: 78, maxHeight: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
        .pulsingHighlight(highlighted)
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

    /// What the hole says: the score it was given, or that it has none.
    private func pickUpText(_ hole: Int) -> String {
        let score = putts.first { $0.holeNumber == hole && $0.isPickUp }?.pickUpScore
        guard let score else { return L("summary.pickedUp") }
        return String(format: L("summary.pickedUpScored"), L(score.labelKey))
    }

    // MARK: - Holes: by putts or as a scorecard

    /// A scorecard only for a round entered with the score reference; without
    /// it every hole would read as par.
    private var showsScorecard: Bool { holesShowScore && round.tracksScoreCategory }

    /// The title says which colours are showing; the arrows switch them.
    private var holesHeader: some View {
        HStack(spacing: 10) {
            Text("\(L("summary.holes")) · \(L(showsScorecard ? "summary.holes.byScore" : "summary.holes.byPutts"))".uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            holeColoursInfo
            if round.tracksScoreCategory {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { holesShowScore.toggle() }
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 32, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L(showsScorecard ? "summary.holes.showPutts" : "summary.holes.showScore"))
            }
        }
    }

    /// What the colours on the holes mean, for the view that is showing.
    private var holeColoursInfo: some View {
        Button {
            showHoleColours = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("summary.holes.coloursTitle"))
        .popover(isPresented: $showHoleColours) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L(showsScorecard ? "summary.holes.coloursScore" : "summary.holes.coloursPutts"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(holeColourKey, id: \.label) { entry in
                    HStack(spacing: 10) {
                        Text(entry.sample)
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(entry.colour)
                            .frame(width: 36, height: 20)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(entry.colour.opacity(0.2)))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.border, lineWidth: 1))
                        Text(entry.label)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                if round.tracksScoreCategory {
                    Text(L("summary.holes.switchHint"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(width: 260, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(Theme.surface)
            .presentationCompactAdaptation(.popover)
        }
    }

    /// Each colour with what it stands for: putts on the hole, or the score
    /// against par in the score colours the rest of the app uses.
    private var holeColourKey: [(sample: String, colour: Color, label: String)] {
        guard showsScorecard else {
            return [
                ("1", Theme.primary, L("summary.onePutt")),
                ("2", Theme.text, L("summary.twoPutts")),
                ("3", Theme.error, L("summary.threePlusPutts")),
            ]
        }
        let scores: [(Int, ScoreCategory)] = [(-2, .eagle), (-1, .birdie), (0, .par), (1, .bogey), (2, .double), (3, .plus3)]
        return scores.map { score, category in
            (scoreCardText(score), category.color, L(score >= 3 ? "summary.holes.tripleOrWorse" : category.labelKey))
        }
    }

    private var holeLegend: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10, alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(holeColourKey, id: \.label) { entry in
                legendDot(entry.colour, entry.label)
            }
        }
    }

    /// The hole against par, as the scorecard counts it: a picked-up hole at
    /// what was entered for it, or at the pick-up score it is written down as.
    private func holeScore(_ hole: Int) -> Int? {
        if stats.pickedUpHoleNumbers.contains(hole) {
            let entered = putts.first { $0.holeNumber == hole && $0.isPickUp }?.pickUpScore
            return (entered ?? Putt.lowestPickUpScore).strokesRelativeToPar
        }
        return RoundStats.holeScoreRelativeToPar(putts.filter { $0.holeNumber == hole })
    }

    /// -2, -1, 0, +1, +2: the scorecard's shorthand.
    private func scoreCardText(_ score: Int) -> String {
        score > 0 ? "+\(score)" : "\(score)"
    }

    private func scoreCardColour(_ score: Int) -> Color {
        switch score {
        case ..<(-1): return ScoreCategory.eagle.color
        case -1: return ScoreCategory.birdie.color
        case 0: return ScoreCategory.par.color
        case 1: return ScoreCategory.bogey.color
        case 2: return ScoreCategory.double.color
        default: return ScoreCategory.plus3.color
        }
    }

    private func holeCell(_ hole: Int) -> some View {
        let pickedUp = stats.pickedUpHoleNumbers.contains(hole)
        let played = stats.puttsByHole[hole] != nil
        let count = stats.puttsByHole[hole] ?? 0
        let score = showsScorecard ? holeScore(hole) : nil
        let bg: Color
        let fg: Color
        if showsScorecard {
            let colour = score.map(scoreCardColour) ?? Theme.textMuted
            bg = score == nil ? Theme.borderLight : colour.opacity(0.2)
            fg = colour
        } else {
            bg = pickedUp ? Theme.accent.opacity(0.15) : !played ? Theme.borderLight : (count == 0 ? Theme.accent.opacity(0.25) : (count == 1 ? Theme.primary.opacity(0.2) : (count >= 3 ? Theme.error.opacity(0.2) : Theme.surface)))
            fg = !played ? Theme.textMuted : (count == 0 ? Theme.accent : (count == 1 ? Theme.primary : (count >= 3 ? Theme.error : Theme.text)))
        }
        let isOpen = expandedHole == hole

        return Button {
            // Unplayed holes stay tappable on purpose — that's the entry point
            // for backfilling a hole that was skipped during the round.
            expandedHole = (expandedHole == hole) ? nil : hole
        } label: {
            VStack(spacing: 2) {
                Text("\(hole)").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.textMuted)
                if showsScorecard {
                    // The strokes played where the hole's par is known, as a
                    // card reads; against par otherwise.
                    let par = round.holeDetails[hole]?.par
                    Text(score.map { s in par.map { String($0 + s) } ?? scoreCardText(s) } ?? "–").font(.system(size: 18, weight: .black)).foregroundStyle(fg)
                } else if pickedUp {
                    PickUpBallIcon()
                        .foregroundStyle(Theme.accent)
                        .frame(width: 18, height: 18)
                        .frame(height: 22)
                } else {
                    Text(played ? "\(count)" : "–").font(.system(size: 18, weight: .black)).foregroundStyle(fg)
                }
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
        let isPickedUp = stats.pickedUpHoleNumbers.contains(hole)
        let isHoleOut = holePutts.isEmpty && !neverPlayed && !isPickedUp

        return VStack(alignment: .leading, spacing: 6) {
            let holeRecords = putts.filter { $0.holeNumber == hole }
            HStack {
                Text("\(L("summary.holeAbbr")) \(hole)").font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.accent)
                Spacer()
                // Strokes gained belongs to the hole, so it sits in the hole's
                // own header rather than among the per-putt numbers.
                if let holeSG = RoundStats.holeStrokesGained(holeRecords) {
                    MetricValue(value: holeSG, metric: .sg, size: 13)
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
            if isPickedUp {
                HStack(spacing: 6) {
                    PickUpBallIcon()
                        .foregroundStyle(Theme.accent)
                        .frame(width: 15, height: 15)
                    Text(pickUpText(hole))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                    if let par = round.holeDetails[hole]?.par {
                        Text(String(format: L("input.holePar.value"), par))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                    }
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
                        Text(L("stats.pcg"))
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
                    Text("\(p.pcg > 0 ? "+" : "")\(String(format: "%.2f", p.pcg))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(p.pcg > 0 ? Theme.primary : (p.pcg < 0 ? Theme.error : Theme.textSecondary))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
    }

    private var missGrid: some View {
        MissDonutView(missCounts: stats.missCounts, lipOutCount: stats.lipOutCount)
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
