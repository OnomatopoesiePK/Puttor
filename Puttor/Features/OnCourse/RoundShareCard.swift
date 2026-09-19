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

struct RoundShareCard: View {
    let round: Round
    var useFeet = false

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
        VStack(alignment: .leading, spacing: 12) {
            header
            if showsScorecard {
                scorecard(stats)
            }
            HStack(spacing: 10) {
                metricBox(stats.sgTotal, metric: .sg, highlighted: RoundHighlights.strongStrokesGained(stats.sgTotal))
                metricBox(stats.pcgTotal, metric: .pcg, highlighted: RoundHighlights.strongPCG(stats.pcgTotal))
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(round.courseName.isEmpty ? L("onCourse.unnamedCourse") : round.courseName)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(([round.date.formatted(date: .long, time: .omitted)] + [round.putter?.name].compactMap { $0 }).joined(separator: " · "))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
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
        let totalPar = roundHoles.compactMap { details[$0]?.par }.reduce(0, +)
        let strokes = stats.strokesSum
        let relative = stats.scoreRelativeToPar

        return VStack(spacing: 8) {
            Text(L("share.scorecard"))
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(nines, id: \.self) { nine in
                // One row is the whole card: its total stands below it.
                nineRow(nine, details: details, stats: stats, showsTotal: nines.count > 1)
            }

            Rectangle().fill(Theme.border).frame(height: 1)

            HStack(alignment: .lastTextBaseline) {
                Text(String(format: L("input.holePar.value"), totalPar))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(L("share.total"))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textMuted)
                Text("\(strokes)")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(Theme.text)
                Text(stats.scoreRelativeToParText)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(relative < 0 ? Theme.primary : (relative > 0 ? Theme.error : Theme.text))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .shareHighlight(RoundHighlights.scoreUnderPar(relative))
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

    private func metricBox(_ value: Double, metric: MetricValue.Metric, highlighted: Bool) -> some View {
        VStack(spacing: 2) {
            MetricValue(value: value, metric: metric, size: 22, colour: value > 0 ? Theme.primary : (value < 0 ? Theme.error : Theme.text))
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

    /// Only what the round has: the score figures where it was entered with
    /// the score reference, the chances at the green where they were asked,
    /// the putting always.
    private func tiles(_ stats: RoundStats) -> [Tile] {
        let averagePerHole = Tile(label: L("summary.avgPerHole"), value: String(format: "%.2f", stats.avgPuttsPerHole),
                                  subtitle: String(format: L("stats.overHoles"), stats.holes), colour: Theme.text,
                                  highlighted: RoundHighlights.lowPuttsPerHole(stats.avgPuttsPerHole))
        let totalPutts = Tile(label: L("summary.putts"), value: "\(stats.totalPutts)",
                              subtitle: String(format: L("stats.overHoles"), stats.holes), colour: Theme.text)
        var tiles: [Tile] = []
        if tracksScore {
            if !showsScorecard {
                let score = stats.scoreRelativeToPar
                tiles.append(Tile(
                    label: L("stats.score"), value: stats.scoreRelativeToParText,
                    subtitle: String(format: L("stats.overHoles"), stats.scoredHoles),
                    colour: score < 0 ? Theme.primary : (score > 0 ? Theme.error : Theme.text),
                    highlighted: RoundHighlights.scoreUnderPar(score)
                ))
            }
            tiles.append(Tile(label: L("stats.gir"), value: "\(Int(stats.girPercent.rounded()))%",
                              subtitle: "\(stats.girCount)/\(stats.holes)",
                              highlighted: RoundHighlights.strongGreensInRegulation(stats.girPercent)))
            tiles.append(Tile(label: L("stats.conversion"),
                              value: stats.girCount > 0 ? "\(Int(stats.girConversionPercent.rounded()))%" : "—",
                              subtitle: "\(stats.girConversions)/\(stats.girCount)",
                              highlighted: RoundHighlights.strongConversion(stats.girConversionPercent)))
            tiles.append(Tile(label: L("stats.scramble"), value: "\(Int(stats.scramblePercent.rounded()))%",
                              subtitle: "\(stats.scrambleSuccesses)/\(stats.scrambleAttempts)",
                              highlighted: RoundHighlights.strongScrambling(stats.scramblePercent)))
            tiles.append(Tile(label: L("stats.puttsGir"), value: stats.avgPuttsOnGir.map { String(format: "%.2f", $0) } ?? "—",
                              subtitle: String(format: L("stats.overHoles"), stats.girPuttedHoles)))
            tiles.append(Tile(label: L("stats.puttsNoGir"), value: stats.avgPuttsOffGir.map { String(format: "%.2f", $0) } ?? "—",
                              subtitle: String(format: L("stats.overHoles"), stats.nonGirPuttedHoles)))
            // Three putting figures side by side, the chances at the green
            // as a pair after them.
            tiles.append(averagePerHole)
            if stats.girOpportunityAnswered > 0 {
                tiles.append(Tile(label: L("stats.girOpportunity"),
                                  value: stats.girOpportunityPercent.map { "\(Int($0.rounded()))%" } ?? "—",
                                  subtitle: "\(stats.girOpportunities)/\(stats.girOpportunityAnswered)",
                                  highlighted: stats.girOpportunityPercent.map(RoundHighlights.manyGirOpportunities) ?? false))
                tiles.append(Tile(label: L("stats.girOpportunityConversion"),
                                  value: stats.girOpportunityConversionPercent.map { "\(Int($0.rounded()))%" } ?? "—",
                                  subtitle: "\(stats.girOpportunitiesConverted)/\(stats.girOpportunities)",
                                  highlighted: stats.girOpportunityConversionPercent.map(RoundHighlights.strongGirOpportunityConversion) ?? false))
            }
        }
        if !tracksScore { tiles.append(averagePerHole) }
        tiles.append(totalPutts)
        tiles.append(Tile(label: L("stats.threePutts"), value: "\(stats.threePuttHoles)",
                          subtitle: String(format: L("stats.overHoles"), stats.holes)))
        tiles.append(Tile(label: L("stats.lipOuts"), value: "\(stats.lipOutCount)",
                          subtitle: String(format: L("stats.ofPutts"), stats.totalPutts)))
        if tracksScore {
            tiles.append(Tile(label: L("stats.girProximity"),
                              value: stats.avgGirProximityM.map { UnitConverter.formatDistance($0, useFeet: useFeet) } ?? "—",
                              subtitle: L("stats.firstPutt")))
        }
        return tiles
    }

    /// Rows of three; where one tile would be left alone, the last two rows
    /// share four between them instead.
    private func rows(_ tiles: [Tile]) -> [[Tile]] {
        var rows: [[Tile]] = []
        var rest = tiles[...]
        while !rest.isEmpty {
            let take = rest.count == 4 ? 2 : min(3, rest.count)
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
    /// number keeps the glow it would have at its brightest but one.
    func shareHighlight(_ isActive: Bool) -> some View {
        background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.primary.opacity(isActive ? 0.3 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.primary.opacity(isActive ? 0.9 : 0), lineWidth: isActive ? 2.5 : 0)
        )
    }
}

/// The card as a picture: 1080 pixels wide, as tall as it needs to be up to
/// four to five, laid out wider where it would run taller than that.
enum RoundShareImage {
    static let pixelWidth: CGFloat = 1080
    static let maxAspect: CGFloat = 5.0 / 4.0

    @MainActor
    static func render(_ round: Round, useFeet: Bool) -> UIImage? {
        var width: CGFloat = 400
        var image: UIImage?
        for _ in 0..<4 {
            let renderer = ImageRenderer(content: RoundShareCard(round: round, useFeet: useFeet).frame(width: width))
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
