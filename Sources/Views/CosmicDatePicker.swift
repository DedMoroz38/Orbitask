import SwiftUI

struct CosmicDatePicker: View {
    @Binding var date: Date
    @State private var displayedMonth: Date = Date()
    private let cal = Calendar.current
    private let weekdays = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func daysInMonth() -> [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        let startWeekday = cal.component(.weekday, from: firstOfMonth) - 1
        var days: [Date?] = Array(repeating: nil, count: startWeekday)
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(d)
            }
        }
        return days
    }

    private func isSelected(_ d: Date) -> Bool { cal.isDate(d, inSameDayAs: date) }
    private func isToday(_ d: Date) -> Bool { cal.isDateInToday(d) }

    var body: some View {
        VStack(spacing: 10) {
            // Month navigation
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = cal.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = cal.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let days = daysInMonth()
            let rows = stride(from: 0, to: days.count, by: 7).map { Array(days.dropFirst($0).prefix(7)) }
            ForEach(0..<rows.count, id: \.self) { rowIdx in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { colIdx in
                        if colIdx < rows[rowIdx].count, let d = rows[rowIdx][colIdx] {
                            let dayNum = cal.component(.day, from: d)
                            let selected = isSelected(d)
                            let today = isToday(d)
                            Button(action: {
                                let timeComps = cal.dateComponents([.hour, .minute], from: date)
                                var dayComps = cal.dateComponents([.year, .month, .day], from: d)
                                dayComps.hour = timeComps.hour
                                dayComps.minute = timeComps.minute
                                if let newDate = cal.date(from: dayComps) {
                                    withAnimation(.easeInOut(duration: 0.15)) { date = newDate }
                                }
                            }) {
                                Text("\(dayNum)")
                                    .font(.system(size: 10, weight: selected ? .bold : .regular))
                                    .foregroundColor(selected ? .white : today ? .white.opacity(0.9) : .white.opacity(0.55))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 26)
                                    .background(
                                        Group {
                                            if selected {
                                                Circle()
                                                    .fill(Color.white.opacity(0.18))
                                                    .overlay(
                                                        Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                                                    )
                                            } else if today {
                                                Circle()
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                            }
                                        }
                                    )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 26)
                        }
                    }
                }
            }

            // Time row
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))

                Text(timeString)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                HStack(spacing: 2) {
                    Button(action: { date = cal.date(byAdding: .hour, value: -1, to: date) ?? date }) {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)

                    Text("hr")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.3))

                    Button(action: { date = cal.date(byAdding: .hour, value: 1, to: date) ?? date }) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 2) {
                    Button(action: { date = cal.date(byAdding: .minute, value: -5, to: date) ?? date }) {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)

                    Text("min")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.3))

                    Button(action: { date = cal.date(byAdding: .minute, value: 5, to: date) ?? date }) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .onAppear { displayedMonth = date }
    }
}
