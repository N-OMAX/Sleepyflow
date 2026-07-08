import SwiftUI

struct SleepStatsView: View {
    @ObservedObject var tracker: SleepTracker
    
    // Grid layout for a simple calendar
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    Text("Sleep Statistics")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.top, 40)
                    
                    if tracker.dailyStats.isEmpty {
                        Text("No sleep data recorded yet.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(tracker.dailyStats) { stat in
                                VStack {
                                    Text(formattedDate(stat.date))
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Circle()
                                        .fill(colorForDuration(stat.totalDuration))
                                        .frame(width: 30, height: 30)
                                        .shadow(color: colorForDuration(stat.totalDuration).opacity(0.5), radius: 5, x: 0, y: 0)
                                    
                                    Text(String(format: "%.1fh", stat.totalDuration / 3600))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                        .padding()
                        .glassmorphic()
                    }
                    
                    // Legend
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Legend")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        LegendRow(color: .red, text: "< 5 hours")
                        LegendRow(color: .yellow, text: "5 - 7 hours")
                        LegendRow(color: .green, text: "7 - 9 hours")
                        LegendRow(color: Color(red: 1.0, green: 0.98, blue: 0.7), text: "9 - 11 hours (Pastel Yellow)")
                        LegendRow(color: Color(red: 1.0, green: 0.6, blue: 0.6), text: "> 11 hours (Pastel Red)")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassmorphic()
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        return formatter.string(from: date)
    }
    
    private func colorForDuration(_ duration: TimeInterval) -> Color {
        let hours = duration / 3600
        if hours < 5 {
            return .red
        } else if hours < 7 {
            return .yellow
        } else if hours <= 9 {
            return .green
        } else if hours <= 11 {
            return Color(red: 1.0, green: 0.98, blue: 0.7) // Pastel yellow
        } else {
            return Color(red: 1.0, green: 0.6, blue: 0.6) // Pastel red
        }
    }
}

struct LegendRow: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 15, height: 15)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
