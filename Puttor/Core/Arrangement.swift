//
//  Arrangement.swift
//  Puttor
//
//  The order a set of things is shown in and which of them were taken out,
//  kept as one line of text, and the list they are arranged in: names dragged
//  into order, taken out with the red minus, brought back with the green plus.
//  Only the names move, so a long stack is arranged at a glance. The
//  evolution charts and the statistics sections both use it.
//

import SwiftUI

/// Something that can be put in order by name.
protocol Arrangeable: RawRepresentable, CaseIterable, Identifiable, Hashable where RawValue == String {}

/// Which items show, in what order, and which were taken out, kept as one
/// line of text: the items in order, the taken-out ones marked. An item the
/// text has never heard of joins the end of the shown ones.
struct Arrangement<Item: Arrangeable>: Equatable {
    private(set) var shown: [Item]
    private(set) var hidden: [Item]

    init(text: String) {
        var shown: [Item] = []
        var hidden: [Item] = []
        for entry in text.split(separator: ",") {
            let isHidden = entry.hasPrefix("-")
            guard let item = Item(rawValue: String(isHidden ? entry.dropFirst() : entry)),
                  !shown.contains(item), !hidden.contains(item)
            else { continue }
            if isHidden { hidden.append(item) } else { shown.append(item) }
        }
        shown += Item.allCases.filter { !shown.contains($0) && !hidden.contains($0) }
        self.shown = shown
        self.hidden = hidden
    }

    var text: String {
        (shown.map(\.rawValue) + hidden.map { "-" + $0.rawValue }).joined(separator: ",")
    }

    func moving(from source: IndexSet, to destination: Int) -> Arrangement {
        var copy = self
        copy.shown.move(fromOffsets: source, toOffset: destination)
        return copy
    }

    /// Taken out, and first in line to come back.
    func hiding(at offsets: IndexSet) -> Arrangement {
        var copy = self
        let taken = offsets.map { shown[$0] }
        copy.shown.remove(atOffsets: offsets)
        copy.hidden = taken + copy.hidden
        return copy
    }

    /// Back in, at the bottom.
    func showing(_ item: Item) -> Arrangement {
        guard let index = hidden.firstIndex(of: item) else { return self }
        var copy = self
        copy.hidden.remove(at: index)
        copy.shown.append(item)
        return copy
    }
}

/// The items by name, to put in order, take out and bring back.
struct ArrangementList<Item: Arrangeable>: View {
    @Binding var arrangement: Arrangement<Item>
    let name: (Item) -> String
    let colour: (Item) -> Color

    var body: some View {
        List {
            Section(L("arrange.shown")) {
                ForEach(arrangement.shown) { item in
                    label(item)
                        .listRowBackground(Theme.surface)
                }
                .onMove { source, destination in arrangement = arrangement.moving(from: source, to: destination) }
                .onDelete { offsets in arrangement = arrangement.hiding(at: offsets) }
            }
            if !arrangement.hidden.isEmpty {
                Section(L("arrange.hidden")) {
                    ForEach(arrangement.hidden) { item in
                        HStack(spacing: 12) {
                            Button {
                                withAnimation { arrangement = arrangement.showing(item) }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .green)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(format: L("arrange.add"), name(item)))
                            label(item)
                        }
                        .listRowBackground(Theme.surface)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }

    private func label(_ item: Item) -> some View {
        Text(name(item))
            .font(.system(size: 13, weight: .bold))
            .tracking(1.0)
            .foregroundStyle(colour(item))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
