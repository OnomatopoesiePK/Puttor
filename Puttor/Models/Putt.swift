//
//  Putt.swift
//  Puttor
//

import Foundation
import SwiftData

@Model
final class Putt {
    var id: UUID = UUID()
    var round: Round?

    var holeNumber: Int = 1
    var puttNumber: Int = 1

    var distanceM: Double = 3.0
    var sideSlopePct: Double = 0
    var hillSlopePct: Double = 0
    var doubleBreakRaw: String?

    var puttForRaw: String = ScoreCategory.par.rawValue
    var resultRaw: String = PuttResult.holed.rawValue

    var lipOut: Bool = false
    var missRead: Bool = false
    var badStroke: Bool = false
    var badStrokeTypeRaw: String?
    var wrongAim: Bool = false

    var sgBaseline: Double = 0
    var sgActual: Double = 0
    var createdAt: Date = Date()

    /// Only meaningful while `badStroke` is set.
    var badStrokeType: BadStrokeType? {
        get { badStrokeTypeRaw.flatMap { BadStrokeType(rawValue: $0) } }
        set { badStrokeTypeRaw = newValue?.rawValue }
    }

    var doubleBreak: DoubleBreakType? {
        get { doubleBreakRaw.flatMap { DoubleBreakType(rawValue: $0) } }
        set { doubleBreakRaw = newValue?.rawValue }
    }

    var puttFor: ScoreCategory {
        get { ScoreCategory(rawValue: puttForRaw) ?? .par }
        set { puttForRaw = newValue.rawValue }
    }

    var result: PuttResult {
        get { PuttResult(rawValue: resultRaw) ?? .holed }
        set { resultRaw = newValue.rawValue }
    }

    var missReasonCount: Int {
        [missRead, badStroke, wrongAim].filter { $0 }.count
    }

    init(
        holeNumber: Int,
        puttNumber: Int,
        distanceM: Double,
        sideSlopePct: Double = 0,
        hillSlopePct: Double = 0,
        doubleBreak: DoubleBreakType? = nil,
        puttFor: ScoreCategory = .par,
        result: PuttResult,
        lipOut: Bool = false,
        missRead: Bool = false,
        badStroke: Bool = false,
        badStrokeType: BadStrokeType? = nil,
        wrongAim: Bool = false
    ) {
        self.id = UUID()
        self.holeNumber = holeNumber
        self.puttNumber = puttNumber
        self.distanceM = distanceM
        self.sideSlopePct = sideSlopePct
        self.hillSlopePct = hillSlopePct
        self.doubleBreakRaw = doubleBreak?.rawValue
        self.puttForRaw = puttFor.rawValue
        self.resultRaw = result.rawValue
        self.lipOut = lipOut
        self.missRead = missRead
        self.badStroke = badStroke
        self.badStrokeTypeRaw = badStrokeType?.rawValue
        self.wrongAim = wrongAim
        let baseline = StrokesGained.baseline(at: distanceM)
        self.sgBaseline = baseline.makeProbability
        self.sgActual = StrokesGained.calculateSG(distanceM: distanceM, holed: result.isHoled)
        self.createdAt = Date()
    }

    /// Recomputes sgBaseline/sgActual after editing distance/result.
    func recomputeSG() {
        let baseline = StrokesGained.baseline(at: distanceM)
        sgBaseline = baseline.makeProbability
        sgActual = StrokesGained.calculateSG(distanceM: distanceM, holed: result.isHoled)
    }
}
