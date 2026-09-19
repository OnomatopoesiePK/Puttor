//
//  ScoreMark.swift
//  Puttor
//
//  The marks a scorecard draws around a hole's score, as most golfers keep
//  them: two circles for an eagle or better, one for a birdie, nothing for a
//  par, a square for a bogey and two for a double or worse. The same on the
//  round summary's holes and on the card shared from it.
//

import SwiftUI

struct ScoreMark: View {
    /// The hole against par.
    let score: Int
    let colour: Color
    var lineWidth: CGFloat = 1.5

    var body: some View {
        GeometryReader { proxy in
            let gap = max(2.5, proxy.size.width * 0.12)
            ZStack {
                switch score {
                case ..<(-1):
                    Circle().stroke(colour, lineWidth: lineWidth)
                    Circle().inset(by: gap).stroke(colour, lineWidth: lineWidth)
                case -1:
                    Circle().stroke(colour, lineWidth: lineWidth)
                case 0:
                    EmptyView()
                case 1:
                    RoundedRectangle(cornerRadius: proxy.size.width * 0.12).stroke(colour, lineWidth: lineWidth)
                default:
                    RoundedRectangle(cornerRadius: proxy.size.width * 0.12).stroke(colour, lineWidth: lineWidth)
                    RoundedRectangle(cornerRadius: proxy.size.width * 0.08).inset(by: gap).stroke(colour, lineWidth: lineWidth)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Frames the view to a square of `size` with the scorecard mark for
    /// `score` around it; none where the hole has no score.
    func scoreMark(_ score: Int?, colour: Color, size: CGFloat, lineWidth: CGFloat = 1.5) -> some View {
        frame(width: size, height: size)
            .overlay {
                if let score {
                    ScoreMark(score: score, colour: colour, lineWidth: lineWidth)
                }
            }
    }
}
