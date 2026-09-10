//
//  PickUpBallIcon.swift
//  Puttor
//
//  The pick-up symbol: a hand reaching down for the ball, in its ring. Drawn
//  as a vector asset and rendered as a template, so it takes whatever colour
//  the place it sits in gives it and stays sharp at every size.
//

import SwiftUI

struct PickUpBallIcon: View {
    var body: some View {
        Image("PickUpSymbol")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}
