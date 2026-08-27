//
//  AroundTheHoleMap.swift
//  Puttor
//
//  The five tees drawn around the hole, viewed from behind: uphill putts below
//  the cup, downhill above, and the break of each shown by which side it comes
//  from. Doubles as the setup diagram and the position marker during play.
//

import SwiftUI

struct AroundTheHoleMap: View {
    /// Highlighted as the putt to play now. Nil on the setup screen, where no
    /// putt is next yet.
    var currentStation: AroundTheHoleStation?
    /// Stations already holed in the current lap.
    var madeStations: Set<AroundTheHoleStation> = []

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = side * 0.36

            ZStack {
                // Slope arrow: the hill runs up the screen, so a putt from
                // below the hole is the uphill one.
                slopeArrow(height: side)

                Circle()
                    .fill(Theme.primary)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .frame(width: 18, height: 18)
                    .position(centre)

                ForEach(AroundTheHolePlan.stations) { station in
                    let point = position(for: station, centre: centre, radius: radius)
                    tee(station)
                        .position(point)
                }
            }
        }
    }

    private func position(for station: AroundTheHoleStation, centre: CGPoint, radius: CGFloat) -> CGPoint {
        // 0° points straight down the screen, angles run clockwise from there.
        let radians = station.angleDegrees * .pi / 180
        return CGPoint(
            x: centre.x + radius * CGFloat(sin(radians)),
            y: centre.y + radius * CGFloat(cos(radians))
        )
    }

    private func tee(_ station: AroundTheHoleStation) -> some View {
        let isCurrent = station == currentStation
        let isDone = madeStations.contains(station)
        let fill: Color = isCurrent ? Theme.accent : (isDone ? Theme.primary.opacity(0.25) : Theme.surfaceElevated)
        let border: Color = isCurrent ? Theme.accent : (isDone ? Theme.primary : Theme.border)

        return VStack(spacing: 3) {
            ZStack {
                Circle().fill(fill)
                Circle().stroke(border, lineWidth: isCurrent ? 2.5 : 1.5)
                if isDone && !isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Theme.primary)
                } else {
                    Text("\(station.rawValue + 1)")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(isCurrent ? .white : Theme.textSecondary)
                }
            }
            .frame(width: 28, height: 28)

            Text(L(station.labelKey))
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(isCurrent ? Theme.accent : Theme.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 78)
        }
    }

    private func slopeArrow(height: CGFloat) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "arrow.up")
                .font(.system(size: 11, weight: .bold))
            Text(L("game.ath.uphill"))
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(Theme.uphill)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 2)
    }
}
