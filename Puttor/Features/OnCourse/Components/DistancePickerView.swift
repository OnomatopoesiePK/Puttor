//
//  DistancePickerView.swift
//  Puttor
//
//  Horizontal snap-scroll distance picker. Ported from the prototype's
//  DistancePicker.tsx, using SwiftUI's native scroll-target-behavior instead
//  of manual momentum-scroll math.
//

import SwiftUI

struct DistancePickerView: View {
    @Binding var value: Double
    var useFeet: Bool

    @State private var scrollPosition: Double?
    private let itemWidth: CGFloat = 60
    private let itemHeight: CGFloat = 46

    private var items: [DistanceOption] { UnitConverter.distanceList(useFeet: useFeet) }

    var body: some View {
        VStack(spacing: 6) {
            Text(L("input.distanceLabel"))
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMuted)

            GeometryReader { geo in
                let sidePad = max(0, geo.size.width / 2 - itemWidth / 2)
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(Theme.primary.opacity(0.13))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Theme.primary, lineWidth: 2)
                        )
                        .frame(width: itemWidth, height: itemHeight - 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                            ForEach(items) { item in
                                let selected = abs(item.value - value) < 0.001
                                Text(item.label)
                                    .font(.system(size: selected ? 17 : 13, weight: selected ? .heavy : .medium))
                                    .foregroundStyle(selected ? Theme.primary : Theme.textSecondary)
                                    .offset(y: -1)
                                    .frame(width: itemWidth, height: itemHeight)
                                    .contentShape(Rectangle())
                                    .id(item.value)
                                    .onTapGesture {
                                        withAnimation(.easeOut(duration: 0.2)) { scrollPosition = item.value }
                                        value = item.value
                                    }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollPosition(id: $scrollPosition, anchor: .center)
                    .scrollTargetBehavior(.viewAligned)
                    .safeAreaPadding(.horizontal, sidePad)
                    .onChange(of: scrollPosition) { _, newValue in
                        if let v = newValue, abs(v - value) >= 0.001 { value = v }
                    }
                    .onChange(of: value) { _, newValue in
                        if abs((scrollPosition ?? newValue) - newValue) >= 0.001 {
                            withAnimation(.easeOut(duration: 0.2)) { scrollPosition = newValue }
                        }
                    }
                    .onAppear {
                        if scrollPosition == nil { scrollPosition = value }
                    }
                }
            }
            .frame(height: itemHeight + 4)
        }
    }
}

#Preview {
    DistancePickerView(value: .constant(6.0), useFeet: false)
        .padding()
        .background(Theme.background)
}
