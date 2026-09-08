//
//  ScrollHint.swift
//  Puttor
//
//  A row that scrolls sideways looks exactly like a row that doesn't, until
//  someone happens to drag it. This puts the difference on screen: whichever
//  end still has something behind it fades out under a chevron pointing that
//  way, and the hint disappears once that end is reached.
//

import SwiftUI

private struct ScrollEdges: Equatable {
    var leading = false
    var trailing = false
}

private struct HorizontalScrollHint: ViewModifier {
    /// The colour the content fades into — whatever sits behind the scroller.
    let fade: Color
    @State private var edges = ScrollEdges()

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: ScrollEdges.self) { geometry in
                ScrollEdges(
                    leading: geometry.contentOffset.x > 2,
                    trailing: geometry.contentOffset.x + geometry.containerSize.width
                        < geometry.contentSize.width - 2
                )
            } action: { _, new in
                withAnimation(.easeOut(duration: 0.15)) { edges = new }
            }
            .overlay(alignment: .leading) {
                if edges.leading { hint(trailing: false) }
            }
            .overlay(alignment: .trailing) {
                if edges.trailing { hint(trailing: true) }
            }
    }

    private func hint(trailing: Bool) -> some View {
        Image(systemName: trailing ? "chevron.right" : "chevron.left")
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(Theme.textMuted)
            .frame(width: 30)
            .frame(maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: trailing ? [fade.opacity(0), fade] : [fade, fade.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            // A hint, not a control: the row underneath keeps every touch.
            .allowsHitTesting(false)
            .transition(.opacity)
    }
}

extension View {
    /// Marks a horizontal scroller with where it still has content, fading the
    /// row out into `fade` — the colour behind it.
    func horizontalScrollHint(fade: Color = Theme.background) -> some View {
        modifier(HorizontalScrollHint(fade: fade))
    }
}
