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

/// The padding a tab's title row sits in. Shared, so the five tabs start on
/// the same line — and tighter in landscape, where the height is worth more
/// than the air above a heading.
private struct ScreenHeaderPadding: ViewModifier {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Theme.Spacing.lg)
            // Landscape is tight, but not so tight that the title should sit
            // on the status bar — and the tab strip floats in this row too.
            .padding(.top, verticalSizeClass == .compact ? 14 : Theme.Spacing.lg)
            .padding(.bottom, 4)
    }
}

extension View {
    func screenHeaderPadding() -> some View { modifier(ScreenHeaderPadding()) }
}
