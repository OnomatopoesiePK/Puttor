//
//  ActivityBoardView.swift
//  Puttor
//
//  A year of practice at a glance, laid out like a contribution graph: one
//  square per day, a column per week, darker where more sessions were played.
//  For a drill you either finish or don't, turning up is the statistic.
//

import SwiftUI

struct ActivityBoardView: View {
    let sessions: [GameSession]
    /// How many weeks to show, counting back from this one.
    var weeks: Int = 20

    private let cell: CGFloat = 13
    private let gap: CGFloat = 3

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday, so a column reads Mon…Sun
        return calendar
    }

    /// Sessions per day, keyed by the day they started.
    private var countsByDay: [Date: Int] {
        var counts: [Date: Int] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.date)
            counts[day, default: 0] += 1
        }
        return counts
    }

    /// The Monday the board starts on.
    private var firstDay: Date {
        let today = calendar.startOfDay(for: Date())
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeek) ?? thisWeek
    }

    private var maxCount: Int { max(1, countsByDay.values.max() ?? 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: gap) {
                        ForEach(0..<weeks, id: \.self) { week in
                            VStack(spacing: gap) {
                                ForEach(0..<7, id: \.self) { weekday in
                                    square(week: week, weekday: weekday)
                                }
                            }
                            .id(week)
                        }
                    }
                    .padding(.vertical, 2)
                }
                // Opens on this week, the way a contribution graph does.
                .onAppear { proxy.scrollTo(weeks - 1, anchor: .trailing) }
            }

            HStack(spacing: 6) {
                Text(L("game.activity.less"))
                    .font(.system(size: 9)).foregroundStyle(Theme.textMuted)
                ForEach(0..<5, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colour(forIntensity: Double(step) / 4))
                        .frame(width: 10, height: 10)
                }
                Text(L("game.activity.more"))
                    .font(.system(size: 9)).foregroundStyle(Theme.textMuted)

                Spacer(minLength: 0)

                Text(String(format: L("game.activity.total"), sessions.count))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func square(week: Int, weekday: Int) -> some View {
        let day = calendar.date(byAdding: .day, value: week * 7 + weekday, to: firstDay) ?? firstDay
        let isFuture = day > calendar.startOfDay(for: Date())
        let count = countsByDay[calendar.startOfDay(for: day)] ?? 0

        RoundedRectangle(cornerRadius: 2)
            .fill(isFuture ? Color.clear : colour(forIntensity: Double(count) / Double(maxCount)))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Theme.border.opacity(isFuture ? 0 : 0.5), lineWidth: 0.5)
            )
            .frame(width: cell, height: cell)
    }

    /// Empty days keep a faint tile so the grid stays readable; from there the
    /// green deepens with the number of sessions.
    private func colour(forIntensity intensity: Double) -> Color {
        guard intensity > 0 else { return Theme.surfaceElevated }
        return Theme.primary.opacity(0.25 + 0.75 * min(1, intensity))
    }
}
