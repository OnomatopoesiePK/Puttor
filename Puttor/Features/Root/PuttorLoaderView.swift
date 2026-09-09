//
//  PuttorLoaderView.swift
//  Puttor
//
//  Ladeansicht: Ball rollt aufs Loch zu, verliert an der Kante die Auflage
//  und fällt in einer Wurfparabel hinter den vorderen Lochrand.
//
//  Gezeichnet in einem einzigen Canvas-Pass im 1024er-Designraum des App-Icons.
//

import SwiftUI

struct PuttorLoaderView: View {

    /// Kantenlänge der quadratischen Ansicht.
    var size: CGFloat = 220
    /// Hintergrund mitzeichnen (false = transparent, für Overlays über eigenem Grün).
    var drawsBackground: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Geometrie (Designraum 1024 × 1024, direkt aus dem Icon)

    private enum G {
        static let canvas: CGFloat = 1024

        static let holeCenter = CGPoint(x: 512, y: 553)
        static let holeRadii  = CGSize(width: 384, height: 174)

        static let wallCenter = CGPoint(x: 512, y: 641)   // helle Rückwand
        static let wallRadii  = CGSize(width: 334, height: 86)

        static let ballRadius: CGFloat = 174
        static let ballHome   = CGPoint(x: 389, y: 389)
    }

    private enum C {
        static let greenTop  = Color(red: 0.000, green: 0.847, blue: 0.098)  // #00D819
        static let greenBot  = Color(red: 0.000, green: 0.435, blue: 0.051)  // #006F0D
        static let brown     = Color(red: 0.259, green: 0.184, blue: 0.102)  // #422F1A
        static let wallTop   = Color(red: 0.761, green: 0.773, blue: 0.765)  // #C2C5C3
        static let wallBot   = Color(red: 0.486, green: 0.588, blue: 0.514)  // #7C9683
        static let ballWhite: CGFloat = 0.945                                // #F1F1F1
    }

    // MARK: - Bewegung (Designeinheiten pro Sekunde)

    private enum P {
        static let xLip: CGFloat      = 265     // hier verliert der Ball die Auflage
        static let vLip: CGFloat      = 660     // Tempo an der Kante
        static let rollDrag: CGFloat  = 0.453   // Rollreibung auf dem Grün
        static let airDrag: CGFloat   = 0.914   // Restwiderstand im Fall (bewusst klein)
        static let gravity: CGFloat   = 1989
        static let yEnd: CGFloat      = 830     // ab hier ist der Ball verdeckt

        static let roll: Double = 0.667
        static let fall: Double = 0.667
        static let hold: Double = 0.200
        static var loop: Double { roll + fall + hold }

        /// Anfangstempo, damit der Ball nach `roll` Sekunden genau `vLip` hat.
        static var v0: CGFloat { vLip * CGFloat(exp(Double(rollDrag) * roll)) }
        /// Rollstrecke bis zur Kante.
        static var rollDistance: CGFloat {
            v0 / rollDrag * (1 - CGFloat(exp(-Double(rollDrag) * roll)))
        }
    }

    private struct Ball {
        var center: CGPoint
        var scale: CGFloat
        var shade: CGFloat
    }

    /// Geschlossene Lösung statt Frame-für-Frame-Simulation: bei jeder Bildrate identisch.
    private func ball(at time: Double) -> Ball? {
        let t = time.truncatingRemainder(dividingBy: P.loop)

        if t < P.roll {                                   // ausrollen
            let s = P.v0 / P.rollDrag * (1 - CGFloat(exp(-Double(P.rollDrag) * t)))
            return Ball(center: CGPoint(x: P.xLip - P.rollDistance + s, y: G.ballHome.y),
                        scale: 1, shade: 1)
        }

        if t < P.roll + P.fall {                          // Wurfparabel
            let u = CGFloat(t - P.roll)
            let x = P.xLip + P.vLip / P.airDrag * (1 - CGFloat(exp(-Double(P.airDrag) * Double(u))))
            let y = G.ballHome.y + 0.5 * P.gravity * u * u
            let depth = min(1, max(0, (y - G.ballHome.y) / (P.yEnd - G.ballHome.y)))
            return Ball(center: CGPoint(x: x, y: y),
                        scale: 1 - 0.32 * depth,
                        shade: 1 - 0.45 * depth)
        }

        return nil                                        // Loch kurz leer, dann Loop
    }

    // MARK: - Zeichnen

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            Canvas(opaque: false, rendersAsynchronously: false) { gc, canvasSize in
                let k = canvasSize.width / G.canvas
                func rect(_ c: CGPoint, _ r: CGSize) -> CGRect {
                    CGRect(x: (c.x - r.width) * k, y: (c.y - r.height) * k,
                           width: r.width * 2 * k, height: r.height * 2 * k)
                }

                let holeRect = rect(G.holeCenter, G.holeRadii)
                let holePath = Path(ellipseIn: holeRect)

                if drawsBackground {
                    gc.fill(Path(CGRect(origin: .zero, size: canvasSize)),
                            with: .linearGradient(Gradient(colors: [C.greenTop, C.greenBot]),
                                                  startPoint: .zero,
                                                  endPoint: CGPoint(x: 0, y: canvasSize.height)))
                }

                gc.fill(holePath, with: .color(C.brown))

                // helle Rückwand, auf die Lochkontur beschnitten
                gc.drawLayer { layer in
                    layer.clip(to: holePath)
                    let wallRect = rect(G.wallCenter, G.wallRadii)
                    layer.fill(Path(ellipseIn: wallRect),
                               with: .linearGradient(Gradient(colors: [C.wallTop, C.wallBot]),
                                                     startPoint: CGPoint(x: 0, y: wallRect.minY),
                                                     endPoint: CGPoint(x: 0, y: wallRect.maxY)))
                }

                // Ball: läuft über die Rückwand, verschwindet am vorderen Rand
                let state = reduceMotion
                    ? Ball(center: G.ballHome, scale: 1, shade: 1)
                    : ball(at: context.date.timeIntervalSinceReferenceDate)

                if let b = state {
                    gc.drawLayer { layer in
                        layer.clip(to: frontRimMask(holeRect: holeRect, canvas: canvasSize))
                        let r = G.ballRadius * b.scale * k
                        layer.fill(
                            Path(ellipseIn: CGRect(x: b.center.x * k - r, y: b.center.y * k - r,
                                                   width: r * 2, height: r * 2)),
                            with: .color(Color(white: C.ballWhite * b.shade)))
                    }
                }
            }
            .frame(width: size, height: size)
        }
        .accessibilityLabel("Lädt")
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Alles oberhalb der vorderen Lochkante: Fläche über der Lochmitte plus das Loch selbst.
    /// Der Ball bleibt beim Anrollen sichtbar und wird erst im Fall abgeschnitten.
    private func frontRimMask(holeRect: CGRect, canvas: CGSize) -> Path {
        var p = Path()
        p.addRect(CGRect(x: 0, y: 0, width: canvas.width, height: holeRect.midY))
        p.addEllipse(in: holeRect)
        return p
    }
}

#Preview {
    ZStack {
        Color(white: 0.1).ignoresSafeArea()
        PuttorLoaderView(size: 240)
            .clipShape(RoundedRectangle(cornerRadius: 52, style: .continuous))
    }
}
