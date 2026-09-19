//
//  RoundShareCard.swift
//  Puttor
//
//  One round as a picture to send: the course and date, the scorecard where
//  the round was played with real scores, strokes gained and PCG, the
//  highlight, and the playing stats the round has. It is only as tall as
//  what was entered, and never taller than four to five: where the content
//  would run longer the card is laid out wider instead, so it still fits a
//  feed post.
//

import SwiftUI
import UIKit
import LinkPresentation
import SwiftData

struct RoundShareCard: View {
    let round: Round
    var useFeet = false
    /// The player's averages over their last ten other rounds: a figure
    /// better than its average is written green, a worse one red.
    var baseline = RoundBaseline()

    private var putts: [Putt] {
        round.putts.sorted { $0.holeNumber != $1.holeNumber ? $0.holeNumber < $1.holeNumber : $0.puttNumber < $1.puttNumber }
    }

    private var stats: RoundStats { RoundStats.compute(putts: putts, useFeet: useFeet) }
    private var holeCount: Int { round.holeCount == 9 ? 9 : 18 }
    private var roundHoles: [Int] { Array(round.holeSequence.prefix(holeCount)) }
    private var tracksScore: Bool { round.tracksScoreCategory && stats.scoredHoles > 0 }

    /// A scorecard in strokes: every scored hole has its par, and no hole was
    /// left without a score.
    private var showsScorecard: Bool {
        tracksScore && stats.averageStrokesPerRound != nil && stats.pickedUpWithoutScore == 0
    }

    private var highlight: Putt? {
        putts.filter { $0.result == .holed && $0.distanceM >= 1.5 }.max { $0.pcg < $1.pcg }
    }

    var body: some View {
        let stats = stats
        VStack(alignment: .leading, spacing: 10) {
            header(stats)
            if showsScorecard {
                scorecard(stats)
            }
            HStack(spacing: 10) {
                metricBox(stats.sgTotal, metric: .sg, highlighted: RoundHighlights.strongStrokesGained(stats.sgTotal),
                          colour: baseline.tone(stats.sgTotal / Double(max(1, stats.holes)), against: baseline.sgPerHole, higherIsBetter: true))
                metricBox(stats.pcgTotal, metric: .pcg, highlighted: RoundHighlights.strongPCG(stats.pcgTotal),
                          colour: baseline.tone(stats.pcgTotal / Double(max(1, stats.holes)), against: baseline.pcgPerHole, higherIsBetter: true))
            }
            if let highlight {
                highlightRow(highlight)
            }
            playingStats(stats)
            footer
        }
        .padding(18)
        .background(Theme.background)
    }

    // MARK: - Header and footer

    /// The course and the result on one line, the date and putter under
    /// the course: the result as strokes where every hole has its par,
    /// "75 (+3)" with the par raised beside it, against par otherwise.
    private func header(_ stats: RoundStats) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(round.courseName.isEmpty ? L("onCourse.unnamedCourse") : round.courseName)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(([Self.dateText(round.date)] + [round.putter?.name].compactMap { $0 }).joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if tracksScore {
                result(stats)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .shareHighlight(RoundHighlights.scoreUnderPar(stats.scoreRelativeToPar))
            }
        }
    }

    private func result(_ stats: RoundStats) -> some View {
        let relative = stats.scoreRelativeToPar
        let colour = baseline.tone(Double(relative) / Double(max(1, stats.scoredHoles)), against: baseline.scorePerHole, higherIsBetter: false)
            ?? (relative < 0 ? Theme.primary : (relative > 0 ? Theme.error : Theme.text))
        let par = roundHoles.compactMap { round.holeDetails[$0]?.par }.reduce(0, +)
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            if showsScorecard {
                Text("\(stats.strokesSum)")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(Theme.text)
                Text("(\(stats.scoreRelativeToParText))")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(colour)
                Text("\(par)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textMuted)
                    .baselineOffset(14)
            } else {
                Text(stats.scoreRelativeToParText)
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(colour)
            }
        }
        .lineLimit(1)
        .fixedSize()
    }

    /// The date as the app's language writes it in figures: 19.09.2026 in
    /// German, 19/09/2026 in British English, 09/19/2026 in American.
    static func dateText(_ date: Date) -> String {
        let code = LocalizationManager.shared.languageCode
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: code == "en" ? "en_GB" : code)
        formatter.setLocalizedDateFormatFromTemplate("ddMMyyyy")
        return formatter.string(from: date)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Image("PuttorWordmark")
                .resizable()
                .scaledToFit()
                .frame(height: 14)
                .opacity(0.8)
        }
    }

    // MARK: - Scorecard

    /// The hole against par, as the summary counts it.
    private func holeScore(_ hole: Int, _ stats: RoundStats) -> Int? {
        if stats.pickedUpHoleNumbers.contains(hole) {
            let entered = putts.first { $0.holeNumber == hole && $0.isPickUp }?.pickUpScore
            return (entered ?? Putt.lowestPickUpScore).strokesRelativeToPar
        }
        return RoundStats.holeScoreRelativeToPar(putts.filter { $0.holeNumber == hole })
    }

    private func scorecard(_ stats: RoundStats) -> some View {
        let details = round.holeDetails
        let nines = stride(from: 0, to: roundHoles.count, by: 9).map { Array(roundHoles[$0..<min($0 + 9, roundHoles.count)]) }
        return VStack(spacing: 8) {
            Text(L("share.scorecard"))
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(nines, id: \.self) { nine in
                // One row is the whole card: its total stands at the top.
                nineRow(nine, details: details, stats: stats, showsTotal: nines.count > 1)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
    }

    /// Nine holes: their numbers, their strokes marked as a card marks them,
    /// and the nine's total beside them.
    private func nineRow(_ nine: [Int], details: [Int: HoleDetails], stats: RoundStats, showsTotal: Bool) -> some View {
        let scored = nine.compactMap { hole -> Int? in
            guard let score = holeScore(hole, stats), let par = details[hole]?.par else { return nil }
            return par + score
        }
        return HStack(spacing: 3) {
            ForEach(nine, id: \.self) { hole in
                holeCell(hole, par: details[hole]?.par, score: holeScore(hole, stats))
            }
            if showsTotal {
                Rectangle().fill(Theme.border).frame(width: 1, height: 40)
                    .padding(.horizontal, 3)
                Text(scored.isEmpty ? "–" : "\(scored.reduce(0, +))")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.text)
                    .frame(minWidth: 34)
            }
        }
    }

    private func holeCell(_ hole: Int, par: Int?, score: Int?) -> some View {
        let colour = score.map(Self.scoreColour) ?? Theme.textMuted
        return VStack(spacing: 2) {
            Text("\(hole)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
            Text(score.flatMap { s in par.map { String($0 + s) } } ?? "–")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(colour)
                .scoreMark(score, colour: colour, size: 24, lineWidth: 1.3)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 5).fill(score == nil ? Theme.borderLight : colour.opacity(0.2)))
        }
        .frame(maxWidth: .infinity)
    }

    /// The summary's scorecard colours.
    static func scoreColour(_ score: Int) -> Color {
        switch score {
        case ..<(-1): return ScoreCategory.eagle.color
        case -1: return ScoreCategory.birdie.color
        case 0: return ScoreCategory.par.color
        case 1: return ScoreCategory.bogey.color
        default: return ScoreCategory.double.color
        }
    }

    // MARK: - Strokes gained, PCG and the highlight

    private func metricBox(_ value: Double, metric: MetricValue.Metric, highlighted: Bool, colour: Color?) -> some View {
        VStack(spacing: 2) {
            MetricValue(value: value, metric: metric, size: 22, colour: colour ?? (value > 0 ? Theme.primary : (value < 0 ? Theme.error : Theme.text)))
            Text(L(metric == .sg ? "stats.sgPutting" : "share.pcg"))
                .font(.system(size: 8, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Theme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
        .shareHighlight(highlighted)
    }

    private func highlightRow(_ putt: Putt) -> some View {
        HStack(spacing: 8) {
            Text("⭐ \(L("summary.highlight"))")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(Theme.accent)
            Text("\(L("summary.holeAbbr")) \(putt.holeNumber) · \(UnitConverter.formatDistance(putt.distanceM, useFeet: useFeet)) \(L("result.holed"))")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            MetricValue(value: putt.pcg, metric: .pcg, size: 13, colour: Theme.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.accent.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Playing stats

    private struct Tile: Identifiable {
        let label: String
        let value: String
        let subtitle: String
        var colour: Color = Theme.primary
        var highlighted = false
        var id: String { label }
    }

    /// Three rows as a card reads them — the putts, the greens and the
    /// scrambles; the birdies, the approach and the putts after a green hit;
    /// the mistakes and the putts after a green missed — and the chances at
    /// the green under them where they were asked. Without the score
    /// reference, only what the putts say. Each figure is written green or
    /// red against the player's own average, per hole where rounds differ in
    /// length.
    private func tiles(_ stats: RoundStats) -> [Tile] {
        let holes = Double(max(1, stats.holes))
        func tone(_ value: Double?, _ average: Double?, higher: Bool) -> Color {
            baseline.tone(value, against: average, higherIsBetter: higher) ?? Theme.text
        }
        let totalPutts = Tile(label: L("summary.putts"), value: "\(stats.totalPutts)",
                              subtitle: String(format: L("stats.overHoles"), stats.holes),
                              colour: tone(Double(stats.totalPutts) / holes, baseline.puttsPerHole, higher: false),
                              highlighted: RoundHighlights.lowPuttsPerHole(stats.avgPuttsPerHole))
        let threePutts = Tile(label: L("stats.threePutts"), value: "\(stats.threePuttHoles)",
                              subtitle: String(format: L("stats.overHoles"), stats.holes),
                              colour: tone(Double(stats.threePuttHoles) / holes, baseline.threePuttsPerHole, higher: false))
        let lipOuts = Tile(label: L("stats.lipOuts"), value: "\(stats.lipOutCount)",
                           subtitle: String(format: L("stats.ofPutts"), stats.totalPutts),
                           colour: tone(Double(stats.lipOutCount) / Double(max(1, stats.totalPutts)), baseline.lipOutsPerPutt, higher: false))
        guard tracksScore else { return [totalPutts, threePutts, lipOuts] }

        let conversion: Double? = stats.girCount > 0 ? stats.girConversionPercent : nil
        let scramble: Double? = stats.scrambleAttempts > 0 ? stats.scramblePercent : nil
        var tiles: [Tile] = [
            totalPutts,
            Tile(label: L("stats.gir"), value: "\(Int(stats.girPercent.rounded()))%",
                 subtitle: "\(stats.girCount)/\(stats.holes)",
                 colour: tone(stats.girPercent, baseline.girPercent, higher: true),
                 highlighted: RoundHighlights.strongGreensInRegulation(stats.girPercent)),
            Tile(label: L("stats.scramble"), value: "\(Int(stats.scramblePercent.rounded()))%",
                 subtitle: "\(stats.scrambleSuccesses)/\(stats.scrambleAttempts)",
                 colour: tone(scramble, baseline.scramblePercent, higher: true),
                 highlighted: RoundHighlights.strongScrambling(stats.scramblePercent)),
            Tile(label: L("stats.conversion"),
                 value: conversion.map { "\(Int($0.rounded()))%" } ?? "—",
                 subtitle: "\(stats.girConversions)/\(stats.girCount)",
                 colour: tone(conversion, baseline.conversionPercent, higher: true),
                 highlighted: RoundHighlights.strongConversion(stats.girConversionPercent)),
            Tile(label: L("stats.girProximity"),
                 value: stats.avgGirProximityM.map { UnitConverter.formatDistance($0, useFeet: useFeet) } ?? "—",
                 subtitle: L("stats.firstPutt"),
                 colour: tone(stats.avgGirProximityM, baseline.proximity, higher: false)),
            Tile(label: L("stats.puttsGir"), value: stats.avgPuttsOnGir.map { String(format: "%.2f", $0) } ?? "—",
                 subtitle: String(format: L("stats.overHoles"), stats.girPuttedHoles),
                 colour: tone(stats.avgPuttsOnGir, baseline.puttsOnGir, higher: false)),
            threePutts,
            lipOuts,
            Tile(label: L("stats.puttsNoGir"), value: stats.avgPuttsOffGir.map { String(format: "%.2f", $0) } ?? "—",
                 subtitle: String(format: L("stats.overHoles"), stats.nonGirPuttedHoles),
                 colour: tone(stats.avgPuttsOffGir, baseline.puttsOffGir, higher: false)),
        ]
        if stats.girOpportunityAnswered > 0 {
            tiles.append(Tile(label: L("stats.girOpportunity"),
                              value: stats.girOpportunityPercent.map { "\(Int($0.rounded()))%" } ?? "—",
                              subtitle: "\(stats.girOpportunities)/\(stats.girOpportunityAnswered)",
                              colour: tone(stats.girOpportunityPercent, baseline.girOpportunityPercent, higher: true),
                              highlighted: stats.girOpportunityPercent.map(RoundHighlights.manyGirOpportunities) ?? false))
            tiles.append(Tile(label: L("stats.girOpportunityConversion"),
                              value: stats.girOpportunityConversionPercent.map { "\(Int($0.rounded()))%" } ?? "—",
                              subtitle: "\(stats.girOpportunitiesConverted)/\(stats.girOpportunities)",
                              colour: tone(stats.girOpportunityConversionPercent, baseline.girOpportunityConversionPercent, higher: true),
                              highlighted: stats.girOpportunityConversionPercent.map(RoundHighlights.strongGirOpportunityConversion) ?? false))
        }
        return tiles
    }

    /// Rows of three, and a pair of its own at the end.
    private func rows(_ tiles: [Tile]) -> [[Tile]] {
        var rows: [[Tile]] = []
        var rest = tiles[...]
        while !rest.isEmpty {
            let take = min(3, rest.count)
            rows.append(Array(rest.prefix(take)))
            rest = rest.dropFirst(take)
        }
        return rows
    }

    private func playingStats(_ stats: RoundStats) -> some View {
        VStack(spacing: 8) {
            Text(L("stats.playingStats"))
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(rows(tiles(stats)).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row) { tile in
                        tileView(tile)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
    }

    private func tileView(_ tile: Tile) -> some View {
        VStack(spacing: 1) {
            Text(tile.value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(tile.colour)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(tile.label)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.7)
            Text(tile.subtitle)
                .font(.system(size: 8))
                .foregroundStyle(Theme.textMuted)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 7)
        .padding(.horizontal, 3)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
        .shareHighlight(tile.highlighted)
    }
}

private extension View {
    /// The app's pulse, held still: a picture cannot breathe, so the good
    /// number keeps the glow, and the size, it would have near its brightest.
    func shareHighlight(_ isActive: Bool) -> some View {
        background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.primary.opacity(isActive ? 0.3 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.primary.opacity(isActive ? 0.9 : 0), lineWidth: isActive ? 2.5 : 0)
        )
        .scaleEffect(isActive ? 1.04 : 1)
        .zIndex(isActive ? 1 : 0)
    }
}

/// The card as a picture: 1080 pixels wide, as tall as it needs to be up to
/// four to five, laid out wider where it would run taller than that.
enum RoundShareImage {
    static let pixelWidth: CGFloat = 1080
    static let maxAspect: CGFloat = 5.0 / 4.0

    @MainActor
    static func render(_ round: Round, useFeet: Bool, baseline: RoundBaseline = RoundBaseline()) -> UIImage? {
        var width: CGFloat = 400
        var image: UIImage?
        for _ in 0..<4 {
            let renderer = ImageRenderer(content: RoundShareCard(round: round, useFeet: useFeet, baseline: baseline).frame(width: width))
            renderer.scale = pixelWidth / width
            renderer.isOpaque = true
            guard let rendered = renderer.uiImage else { return image }
            image = rendered
            let height = rendered.size.height
            if height <= width * maxAspect + 1 { break }
            width = (height / maxAspect).rounded(.up)
        }
        return image
    }
}

/// The system share sheet, for a picture: Instagram, WhatsApp, Facebook,
/// Snapchat and the rest where they are installed, and saving it to Photos.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// A picture ready to share, for a sheet to present by.
struct SharedImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let title: String

    /// What the share sheet is handed: the picture, with a title and a
    /// thumbnail of itself for the sheet's header.
    var activityItem: ShareImageItem { ShareImageItem(image: image, title: title) }
}

final class ShareImageItem: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any { image }

    func activityViewController(_ controller: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? { image }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        metadata.iconProvider = NSItemProvider(object: image)
        return metadata
    }
}

/// The player's averages over their last ten other rounds, per hole where a
/// round's length would otherwise decide: what a round's figures are written
/// green or red against, on the summary and on the shared picture alike.
/// Nil wherever those rounds cannot say.
struct RoundBaseline {
    /// How many of the player's latest rounds the averages are taken over.
    static let roundCount = 10

    var puttsPerHole: Double?
    var threePuttsPerHole: Double?
    var lipOutsPerPutt: Double?
    var sgPerHole: Double?
    var pcgPerHole: Double?
    var scorePerHole: Double?
    var girPercent: Double?
    var scramblePercent: Double?
    var conversionPercent: Double?
    var proximity: Double?
    var puttsOnGir: Double?
    var puttsOffGir: Double?
    var girOpportunityPercent: Double?
    var girOpportunityConversionPercent: Double?

    init() {}

    /// The latest ten rounds but `round`, the score figures only from those
    /// entered with the score reference, as the statistics tab takes them.
    init(excluding round: Round, from rounds: [Round], useFeet: Bool = false) {
        var all: [RoundStats] = []
        var scored: [RoundStats] = []
        let latest = rounds
            .filter { $0.persistentModelID != round.persistentModelID && !$0.putts.isEmpty }
            .sorted { $0.date > $1.date }
            .prefix(Self.roundCount)
        for other in latest {
            let stats = RoundStats.compute(putts: other.putts, useFeet: useFeet)
            guard stats.holes > 0 else { continue }
            all.append(stats)
            if other.tracksScoreCategory && stats.scoredHoles > 0 && stats.pickedUpWithoutScore == 0 {
                scored.append(stats)
            }
        }
        if !all.isEmpty {
            let merged = RoundStats.merge(all, useFeet: useFeet)
            let holes = Double(max(1, merged.holes))
            puttsPerHole = Double(merged.totalPutts) / holes
            threePuttsPerHole = Double(merged.threePuttHoles) / holes
            lipOutsPerPutt = merged.totalPutts > 0 ? Double(merged.lipOutCount) / Double(merged.totalPutts) : nil
            sgPerHole = merged.sgTotal / holes
            pcgPerHole = merged.pcgTotal / holes
        }
        if !scored.isEmpty {
            let merged = RoundStats.merge(scored, useFeet: useFeet)
            scorePerHole = merged.scoredHoles > 0 ? Double(merged.scoreRelativeToPar) / Double(merged.scoredHoles) : nil
            girPercent = merged.holes > 0 ? merged.girPercent : nil
            scramblePercent = merged.scrambleAttempts > 0 ? merged.scramblePercent : nil
            conversionPercent = merged.girCount > 0 ? merged.girConversionPercent : nil
            proximity = merged.avgGirProximityM
            puttsOnGir = merged.avgPuttsOnGir
            puttsOffGir = merged.avgPuttsOffGir
            girOpportunityPercent = merged.girOpportunityPercent
            girOpportunityConversionPercent = merged.girOpportunityConversionPercent
        }
    }

    /// Green where the figure beats the average, red where it falls short,
    /// white where it matches; nil where either is missing.
    func tone(_ value: Double?, against average: Double?, higherIsBetter: Bool) -> Color? {
        guard let value, let average else { return nil }
        let margin = max(abs(average) * 0.01, 0.001)
        if abs(value - average) <= margin { return Theme.text }
        return (value > average) == higherIsBetter ? Theme.primary : Theme.error
    }
}
