import SwiftUI

// MARK: - Apple Calendar Style Stats View
struct SleepStatsView: View {
    @ObservedObject var tracker: SleepTracker
    @State private var selectedDate: Date? = nil
    @State private var currentMonth: Date = Date()
    
    let calendar = Calendar.current
    let weekdaySymbols = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Month Navigation Header
                HStack {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text(monthYearString(currentMonth))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Weekday Labels (Mo, Di, Mi ...)
                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                
                // Thin separator
                Divider().background(Color.white.opacity(0.1))
                
                // Calendar Grid
                let days = makeDays(for: currentMonth)
                let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
                
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(days, id: \.self) { date in
                        CalendarDayCell(
                            date: date,
                            isCurrentMonth: date != nil && calendar.isDate(date!, equalTo: currentMonth, toGranularity: .month),
                            isToday: date != nil && calendar.isDateInToday(date!),
                            isSelected: date != nil && selectedDate != nil && calendar.isDate(date!, inSameDayAs: selectedDate!),
                            sleepStat: date != nil ? statForDate(date!) : nil
                        )
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
                
                // Day Detail View (like Apple Calendar expanded row)
                if let selected = selectedDate {
                    DayDetailView(date: selected, stat: statForDate(selected))
                        .transition(.asymmetric(
                            insertion: .push(from: .bottom).combined(with: .opacity),
                            removal: .push(from: .top).combined(with: .opacity)
                        ))
                }
                
                Spacer()
                
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
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Helpers
    
    private func changeMonth(by value: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
                currentMonth = newMonth
                selectedDate = nil
            }
        }
    }
    
    private func statForDate(_ date: Date) -> DailySleepStats? {
        tracker.dailyStats.first {
            calendar.isDate($0.date, inSameDayAs: date)
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
            // Align to Monday-first grid (ISO)
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return days
    }
}

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let date: Date?
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let sleepStat: DailySleepStats?
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Today circle
                if isToday {
                    Circle()
                        .fill(AppColors.accentPurple)
                        .frame(width: 34, height: 34)
                }
                // Selected circle (white outline)
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
            
            // Sleep dot indicator
            if let stat = sleepStat {
                Circle()
                    .fill(colorForDuration(stat.totalDuration))
                    .frame(width: 6, height: 6)
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

// MARK: - Day Detail View (like Apple Calendar expanded day)
struct DayDetailView: View {
    let date: Date
    let stat: DailySleepStats?
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header
            Divider().background(Color.white.opacity(0.1))
            
            Text(formattedDayHeader(date))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            
            if let stat = stat {
                // Sleep block visualization (like Apple Calendar event)
                HStack(alignment: .top, spacing: 12) {
                    // Left colored bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForDuration(stat.totalDuration))
                        .frame(width: 4)
                        .frame(height: 70)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Schlaf aufgezeichnet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        
                        let hours = stat.totalDuration / 3600
                        let mins = Int(stat.totalDuration.truncatingRemainder(dividingBy: 3600)) / 60
                        
                        Text(String(format: "%.0fh %02dm Gesamtschlaf", hours, mins))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(ratingText(stat.totalDuration))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(colorForDuration(stat.totalDuration))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(colorForDuration(stat.totalDuration).opacity(0.12))
                )
                .padding(.horizontal, 16)
                
            } else {
                HStack {
                    Image(systemName: "moon.zzz")
                        .foregroundColor(.white.opacity(0.3))
                    Text("Kein Schlaf aufgezeichnet")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .padding(.top, 4)
    }
    
    private func formattedDayHeader(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE – d. MMMM yyyy"
        return f.string(from: date)
    }
    
    private func colorForDuration(_ duration: TimeInterval) -> Color {
        let hours = duration / 3600
        if hours < 5 { return .red }
        if hours < 7 { return .yellow }
        if hours <= 9 { return .green }
        if hours <= 11 { return Color(red: 1.0, green: 0.98, blue: 0.75) }
        return Color(red: 1.0, green: 0.65, blue: 0.65)
    }
    
    private func ratingText(_ duration: TimeInterval) -> String {
        let hours = duration / 3600
        if hours < 5 { return "Zu wenig Schlaf" }
        if hours < 7 { return "Unterdurchschnittlich" }
        if hours <= 9 { return "Optimal" }
        if hours <= 11 { return "Überdurchschnittlich" }
        return "Zu viel Schlaf"
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

// MARK: - Old LegendRow kept for compatibility
struct LegendRow: View {
    let color: Color
    let text: String
    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 15, height: 15)
            Text(text).font(.subheadline).foregroundColor(.white.opacity(0.8))
        }
    }
}
