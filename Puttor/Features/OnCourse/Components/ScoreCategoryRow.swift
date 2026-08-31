//
//  ScoreCategoryRow.swift
//  Puttor
//
//  The "putt for" selector, shared by Pro, Quick and Custom mode.
//
//  Eagle through DB fill the width as before; triple and worse are reached by
//  scrolling on, so adding them doesn't shrink the common choices into a
//  crowded row of seven.
//

import SwiftUI

struct ScoreCategoryRow: View {
    @Binding var selection: ScoreCategory
    var titleKey: String = "input.puttFor"
    /// Chips run across the screen in portrait. In a landscape column there is
    /// height to spare and no width, so they stack instead.
    var axis: Axis = .horizontal

    /// How many chips share the visible width; the rest scroll into view.
    private let visibleCount = 5
    private let spacing: CGFloat = 6

    var body: some View {
        VStack(spacing: 6) {
            Text(L(titleKey))
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMuted)

            if axis == .horizontal {
                GeometryReader { geo in
                    let chipWidth = (geo.size.width - spacing * CGFloat(visibleCount - 1)) / CGFloat(visibleCount)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing) {
                            ForEach(ScoreCategory.allCases) { category in
                                chip(category, width: chipWidth)
                            }
                        }
                    }
                    .scrollClipDisabled(false)
                }
                .frame(height: 34)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: spacing) {
                        ForEach(ScoreCategory.allCases) { category in
                            chip(category, width: nil)
                        }
                    }
                }
            }
        }
    }

    private func chip(_ category: ScoreCategory, width: CGFloat?) -> some View {
        let selected = selection == category
        return Button {
            selection = category
        } label: {
            Text(L(category.shortLabelKey))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(selected ? .white : category.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: width == nil ? .infinity : nil)
                .frame(width: width, height: 32)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(category.color.opacity(selected ? 0.85 : 0.18)))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(category.color, lineWidth: selected ? 2 : 1.2))
        }
        .buttonStyle(.plain)
    }
}

/// The three miss reasons, with the bad-stroke kind revealed underneath once
/// bad stroke is on — "bad stroke" alone doesn't say which way it went.
struct MissReasonRow: View {
    @Binding var missRead: Bool
    @Binding var badStroke: Bool
    @Binding var badStrokeType: BadStrokeType?
    @Binding var wrongAim: Bool
    var showsTitle: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            if showsTitle {
                Text(L("custom.field.missReasons"))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textMuted)
            }

            HStack(spacing: 8) {
                reasonButton(L("input.missRead"), icon: "📖", isOn: $missRead)
                reasonButton(L("input.badStroke"), icon: "🏌️", isOn: Binding(
                    get: { badStroke },
                    set: { isOn in
                        badStroke = isOn
                        // Dropping the reason drops the kind with it.
                        if !isOn { badStrokeType = nil }
                    }
                ))
                reasonButton(L("input.wrongAim"), icon: "🎯", isOn: $wrongAim)
            }

            if badStroke {
                HStack(spacing: 8) {
                    ForEach(BadStrokeType.allCases) { type in
                        badStrokeButton(type)
                    }
                }
            }
        }
    }

    private func badStrokeButton(_ type: BadStrokeType) -> some View {
        let selected = badStrokeType == type
        return Button {
            badStrokeType = selected ? nil : type
        } label: {
            Text(L(type.labelKey))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(selected ? .white : Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(selected ? Theme.accent.opacity(0.85) : Theme.surfaceElevated))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.accent.opacity(selected ? 1 : 0.5), lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }

    private func reasonButton(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text("\(icon) \(title)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? Theme.accent : Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(isOn.wrappedValue ? Theme.accent.opacity(0.13) : Theme.surfaceElevated))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(isOn.wrappedValue ? Theme.accent : Theme.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
