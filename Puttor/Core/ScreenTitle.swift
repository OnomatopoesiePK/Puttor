//
//  ScreenTitle.swift
//  Puttor
//
//  The heading every tab wears. One definition, so the five of them can't
//  drift a couple of points apart — and one place to shrink them where a
//  landscape screen has no height to give a headline.
//

import SwiftUI

struct ScreenTitle: View {
    let text: String

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        Text(text)
            .font(.system(size: verticalSizeClass == .compact ? 20 : 28, weight: .heavy))
            .foregroundStyle(Theme.primary)
    }
}
