//
//  CollapsibleStatSection.swift
//  Puttor
//
//  A statistics card whose body folds away behind its title. The open/closed
//  state is stored per section, so the tab comes back the way it was left.
//

import SwiftUI

struct CollapsibleStatSection<Content: View>: View {
    let title: String
    /// Localisation key for an explanation, shown behind an (ⓘ) in the corner.
    var infoKey: String?
    private let content: () -> Content

    @AppStorage private var isExpanded: Bool

    init(
        title: String,
        storageKey: String,
        defaultExpanded: Bool = true,
        infoKey: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.infoKey = infoKey
        self.content = content
        _isExpanded = AppStorage(wrappedValue: defaultExpanded, AppStorageKeys.statsSection(storageKey))
    }

    var body: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Theme.primary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12)
                    Text(title)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                // Keep the title clear of the (ⓘ) sitting in the corner.
                .padding(.trailing, infoKey == nil ? 0 : 24)
                // The whole header row is the hit target, not just the glyph.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // Sits outside the toggle button so tapping (ⓘ) doesn't fold the
            // section away underneath the popover.
            .overlay(alignment: .trailing) {
                if let infoKey {
                    FieldInfoButton(titleKey: title, textKey: infoKey)
                }
            }

            if isExpanded {
                content()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
    }
}
