import SwiftUI
import Charts

// MARK: - Apple Calendar Style Stats View
struct SleepStatsView: View {
    @ObservedObject var tracker: SleepTracker
    @State private var selectedDate: Date? = nil
    @State private var currentMonth: Date = Date()
    @State private var editingSession: SleepSession? = nil
    @State private var isAddingSession = false
    @State private var showEditSheet = false

    let calendar = Calendar.current
    let weekdaySymbols = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // MARK: Title + Export
                    HStack {
                        Text("Statistik")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()

                        ShareLink(item: csvExportURL()) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 38, height: 38)
                        }
                        .floatingGlass(cornerRadius: 12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // MARK: Summary header (Ø week, streak)
                    SummaryHeader(tracker: tracker)

                    // MARK: Trend chart
                    TrendChartCard(tracker: tracker)
                        .padding(.horizontal, 16)

                    // MARK: Month Navigation
                    VStack(spacing: 0) {
                        HStack {
                            Button(action: { changeMonth(by: -1) }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                            }
                            .floatingGlassCircle()

                            Spacer()

                            Text(monthYearString(currentMonth))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: { changeMonth(by: 1) }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                            }
                            .floatingGlassCircle()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 10)

                        HStack(spacing: 0) {
                            ForEach(weekdaySymbols, id: \.self) { day in
                                Text(day)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)

                        Divider().background(Color.white.opacity(0.1))
                            .padding(.horizontal, 8)

                        let days = makeDays(for: currentMonth)
                        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

                        LazyVGrid(columns: columns, spacing: 0) {
                            ForEach(days, id: \.self) { date in
                                CalendarDayCell(
                                    date: date,
                                    isCurrentMonth: date != nil && calendar.isDate(date!, equalTo: currentMonth, toGranularity: .month),
                                    isToday: date != nil && calendar.isDateInToday(date!),
                                    isSelected: date != nil && selectedDate != nil && calendar.isDate(date!, inSameDayAs: selectedDate!),
                                    dayStat: date != nil ? tracker.dayStat(for: date!) : nil
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let d = date {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            selectedDate = (selectedDate != nil && calendar.isDate(selectedDate!, inSameDayAs: d)) ? nil : d
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    .glassmorphic()
                    .padding(.horizontal, 16)

                    // MARK: Day Detail (editable list of sessions)
                    if let selected = selectedDate {
                        DayDetailView(
                            tracker: tracker,
                            date: selected,
                            onAdd: {
                                isAddingSession = true
                                editingSession = nil
                                showEditSheet = true
                            },
                            onEdit: { session in
                                isAddingSession = false
                                editingSession = session
                                showEditSheet = true
                            }
                        )
                        .padding(.horizontal, 16)
                        .transition(.asymmetric(
                            insertion: .push(from: .bottom).combined(with: .opacity),
                            removal: .push(from: .top).combined(with: .opacity)
                        ))
                    }

                    // Legend
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            LegendChip(color: .red, text: "< 5h")
                            LegendChip(color: .yellow, text: "5-7h")
                            LegendChip(color: .green, text: "7-9h")
                            LegendChip(color: Color(red: 1.0, green: 0.98, blue: 0.75), text: "9-11h")
                            LegendChip(color: Color(red: 1.0, green: 0.65, blue: 0.65), text: ">11h")
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 30)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showEditSheet) {
            SessionEditView(
                tracker: tracker,
                day: selectedDate ?? Date(),
                existingSession: isAddingSession ? nil : editingSession
            )
        }
    }

    // MARK: - Helpers

    private func csvExportURL() -> URL {
        let csv = tracker.exportCSV()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Sleepyflow-Export.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func changeMonth(by value: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
                currentMonth = newMonth
                selectedDate = nil
            }
        }
    }

    private func monthYearString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    // Returns 42 slots (6 weeks), nil = empty
    private func makeDays(for monthDate: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start) else {
            return []
        }

        var days: [Date?] = []
        var current = firstWeek.start

        for _ in 0..<42 {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return days
    }
}

// MARK: - Summary Header
private struct SummaryHeader: View {
    @ObservedObject var tracker: SleepTracker

    var body: some View {
        HStack(spacing: 12) {
            StatPill(
                icon: "moon.stars.fill",
                value: durationString(tracker.averageDuration(lastDays: 7)),
                label: "Ø letzte 7 Tage",
                tint: AppColors.accentLightPurple
            )
            StatPill(
                icon: "flame.fill",
                value: "\(tracker.currentStreak())",
                label: tracker.currentStreak() == 1 ? "Tag Serie" : "Tage Serie",
                tint: .orange
            )
        }
        .padding(.horizontal, 16)
    }

    private func durationString(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "–" }
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }
}

private struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .glassmorphic(cornerRadius: 16)
    }
}

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let date: Date?
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let dayStat: DayStat?

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(AppColors.accentPurple)
                        .frame(width: 34, height: 34)
                }
                if isSelected && !isToday {
                    Circle()
                        .stroke(Color.white, lineWidth: 1.5)
                        .frame(width: 34, height: 34)
                }

                if let date = date {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 16, weight: isToday ? .bold : .regular))
                        .foregroundColor(textColor)
                }
            }
            .frame(width: 40, height: 40)

            // Sleep indicator: dot normally, small extra dot if
            // multiple sessions were logged that day.
            if let stat = dayStat {
                HStack(spacing: 2) {
                    Circle()
                        .fill(colorForDuration(stat.totalDuration))
                        .frame(width: 6, height: 6)
                    if stat.sessions.count > 1 {
                        Circle()
                            .fill(colorForDuration(stat.totalDuration).opacity(0.5))
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(height: 6)
            } else {
                Spacer().frame(height: 6)
            }
        }
        .padding(.vertical, 4)
    }

    private var textColor: Color {
        if !isCurrentMonth { return .white.opacity(0.25) }
        if isToday { return .white }
        return .white.opacity(0.85)
    }

    private func colorForDuration(_ duration: TimeInterval) -> Color {
        let hours = duration / 3600
        if hours < 5 { return .red }
        if hours < 7 { return .yellow }
        if hours <= 9 { return .green }
        if hours <= 11 { return Color(red: 1.0, green: 0.98, blue: 0.75) }
        return Color(red: 1.0, green: 0.65, blue: 0.65)
    }
}

// MARK: - Day Detail View (editable list of sessions for the selected day)
struct DayDetailView: View {
    @ObservedObject var tracker: SleepTracker
    let date: Date
    let onAdd: () -> Void
    let onEdit: (SleepSession) -> Void

    private let calendar = Calendar.current

    private var sessions: [SleepSession] { tracker.sessions(on: date) }
    private var totalDuration: TimeInterval { sessions.reduce(0) { $0 + $1.duration } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(formattedDayHeader(date))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                if !sessions.isEmpty {
                    Text(durationString(totalDuration) + " gesamt")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(colorForDuration(totalDuration))
                }

                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.accentLightPurple)
                }
            }

            if sessions.isEmpty {
                HStack {
                    Image(systemName: "moon.zzz")
                        .foregroundColor(.white.opacity(0.3))
                    Text("Kein Schlaf aufgezeichnet")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Button("Eintrag hinzufügen", action: onAdd)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.accentLightPurple)
                }
                .padding(.vertical, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach(sessions) { session in
                        SessionRow(
                            session: session,
                            onTap: { onEdit(session) },
                            onDelete: {
                                withAnimation { tracker.deleteSession(id: session.id) }
                            }
                        )
                    }
                }
            }
        }
        .padding(16)
        .glassmorphic()
    }

    private func formattedDayHeader(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, d. MMMM"
        return f.string(from: date)
    }

    private func durationString(_ duration: TimeInterval) -> String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }

    private func colorForDuration(_ duration: TimeInterval) -> Color {
        let hours = duration / 3600
        if hours < 5 { return .red }
        if hours < 7 { return .yellow }
        if hours <= 9 { return .green }
        if hours <= 11 { return Color(red: 1.0, green: 0.98, blue: 0.75) }
        return Color(red: 1.0, green: 0.65, blue: 0.65)
    }
}

// MARK: - Single session row (tap to edit, trash icon to delete)
private struct SessionRow: View {
    let session: SleepSession
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(colorForDuration(session.duration))
                .frame(width: 4)
                .frame(height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(timeString(session.start)) – \(timeString(session.end))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    Text(durationString(session.duration) + " Schlaf")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))

                    if let quality = session.quality {
                        HStack(spacing: 1) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= quality ? "star.fill" : "star")
                                    .font(.system(size: 8))
                                    .foregroundColor(star <= quality ? .yellow : .white.opacity(0.2))
                            }
                        }
                    }
                }

                if !session.note.isEmpty {
                    Text(session.note)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            Spacer()

            Image(systemName: "pencil")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))
                .contentShape(Rectangle())
                .onTapGesture { onTap() }

            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.75))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorForDuration(session.duration).opacity(0.1))
        )
        .confirmationDialog("Eintrag löschen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { onDelete() }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func durationString(_ duration: TimeInterval) -> String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }

    private func colorForDuration(_ duration: TimeInterval) -> Color {
        let hours = duration / 3600
        if hours < 5 { return .red }
        if hours < 7 { return .yellow }
        if hours <= 9 { return .green }
        if hours <= 11 { return Color(red: 1.0, green: 0.98, blue: 0.75) }
        return Color(red: 1.0, green: 0.65, blue: 0.65)
    }
}

// MARK: - Trend Chart (last 14 days)
private struct TrendChartCard: View {
    @ObservedObject var tracker: SleepTracker

    var body: some View {
        let points = tracker.trend(lastDays: 14)

        VStack(alignment: .leading, spacing: 12) {
            Text("Verlauf – letzte 14 Tage")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))

            Chart(points) { point in
                BarMark(
                    x: .value("Tag", point.day, unit: .day),
                    y: .value("Stunden", point.hours)
                )
                .foregroundStyle(barColor(point.hours))
                .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel().foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(), centered: true)
                        .foregroundStyle(Color.white.opacity(0.4))
                        .font(.system(size: 9))
                }
            }
            .frame(height: 140)
        }
        .padding(16)
        .glassmorphic()
    }

    private func barColor(_ hours: Double) -> Color {
        if hours == 0 { return Color.white.opacity(0.08) }
        if hours < 5 { return .red }
        if hours < 7 { return .yellow }
        if hours <= 9 { return .green }
        if hours <= 11 { return Color(red: 1.0, green: 0.98, blue: 0.75) }
        return Color(red: 1.0, green: 0.65, blue: 0.65)
    }
}

// MARK: - Legend Chip
struct LegendChip: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.07))
        .clipShape(Capsule())
    }
}
