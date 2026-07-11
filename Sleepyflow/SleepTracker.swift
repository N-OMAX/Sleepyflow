import Foundation
import Combine

enum SleepState: String, Codable {
    case awake
    case sleeping
    case interrupted
}

// A single recorded sleep segment (one "Schlafen gehen" -> "Aufwachen" stretch).
// A night with an interruption produces two of these. Fully editable/deletable.
struct SleepSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var start: Date
    var end: Date
    var quality: Int? = nil // 1...5 stars, optional
    var note: String = ""

    var duration: TimeInterval {
        max(0, end.timeIntervalSince(start))
    }

    // Sleep is attributed to the day the person woke up on (matches how the
    // app always behaved, and how most sleep trackers group nights).
    var dayKey: Date {
        Calendar.current.startOfDay(for: end)
    }
}

// Legacy shape, kept only so old UserDefaults data can be migrated once.
private struct LegacyDailySleepStats: Codable {
    var id = UUID()
    let date: Date
    let totalDuration: TimeInterval
}

// Aggregated view of a day's sessions, used by the calendar.
struct DayStat: Identifiable {
    let id: Date
    let sessions: [SleepSession]

    var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }
}

class SleepTracker: ObservableObject {
    @Published var currentState: SleepState = .awake {
        didSet { UserDefaults.standard.set(currentState.rawValue, forKey: "currentState") }
    }

    @Published var currentSessionStart: Date? {
        didSet {
            if let date = currentSessionStart {
                UserDefaults.standard.set(date, forKey: "currentSessionStart")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentSessionStart")
            }
        }
    }

    @Published var totalSleepDuration: TimeInterval = 0 {
        didSet { UserDefaults.standard.set(totalSleepDuration, forKey: "totalSleepDuration") }
    }

    // All recorded sleep sessions, newest last. This replaces the old
    // "one entry per day" storage that silently dropped a 2nd entry.
    @Published var sessions: [SleepSession] = []

    private var timer: AnyCancellable?
    private let sessionsKey = "sleepSessions"

    init() {
        loadState()
        loadSessions()
        if currentState != .awake {
            startTimer()
        }
    }

    private func loadState() {
        if let stateString = UserDefaults.standard.string(forKey: "currentState"),
           let state = SleepState(rawValue: stateString) {
            currentState = state
        }
        currentSessionStart = UserDefaults.standard.object(forKey: "currentSessionStart") as? Date
        totalSleepDuration = UserDefaults.standard.double(forKey: "totalSleepDuration")
    }

    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let saved = try? JSONDecoder().decode([SleepSession].self, from: data) {
            sessions = saved
            return
        }

        // One-time migration from the old "dailyStats" format (one entry per
        // day, overwritten on every wake-up). We don't know the real start
        // time from back then, so we approximate: end = stored day at 07:00,
        // start = end - duration. Users can correct these manually afterwards.
        if let legacyData = UserDefaults.standard.data(forKey: "dailyStats"),
           let legacy = try? JSONDecoder().decode([LegacyDailySleepStats].self, from: legacyData) {
            let calendar = Calendar.current
            sessions = legacy.map { entry in
                let end = calendar.date(byAdding: .hour, value: 7, to: entry.date) ?? entry.date
                let start = end.addingTimeInterval(-entry.totalDuration)
                return SleepSession(start: start, end: end)
            }
            saveSessions()
            UserDefaults.standard.removeObject(forKey: "dailyStats")
        }
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    func startSleeping() {
        currentState = .sleeping
        currentSessionStart = Date()
        totalSleepDuration = 0
        startTimer()
    }

    func wakeUpInNight() {
        guard currentState == .sleeping, let start = currentSessionStart else { return }
        let end = Date()
        totalSleepDuration += end.timeIntervalSince(start)
        recordSession(start: start, end: end)

        currentState = .interrupted
        currentSessionStart = nil
        stopTimer()
    }

    func resumeSleeping() {
        guard currentState == .interrupted else { return }
        currentState = .sleeping
        currentSessionStart = Date()
        startTimer()
    }

    func finalWakeUp() {
        if currentState == .sleeping, let start = currentSessionStart {
            let end = Date()
            totalSleepDuration += end.timeIntervalSince(start)
            recordSession(start: start, end: end)
        }

        currentState = .awake
        currentSessionStart = nil
        stopTimer()
        totalSleepDuration = 0
    }

    func resetSession() {
        currentState = .awake
        currentSessionStart = nil
        totalSleepDuration = 0
        stopTimer()
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    func currentLiveSleepDuration() -> TimeInterval {
        var duration = totalSleepDuration
        if currentState == .sleeping, let start = currentSessionStart {
            duration += Date().timeIntervalSince(start)
        }
        return duration
    }

    // MARK: - Calendar editing

    private func recordSession(start: Date, end: Date) {
        guard end > start else { return }
        sessions.append(SleepSession(start: start, end: end))
        saveSessions()
    }

    /// Manually add a sleep entry for a past (or present) day, e.g. to fill in
    /// a night that wasn't tracked live.
    @discardableResult
    func addManualSession(start: Date, end: Date, quality: Int? = nil, note: String = "") -> Bool {
        guard end > start else { return false }
        sessions.append(SleepSession(start: start, end: end, quality: quality, note: note))
        saveSessions()
        return true
    }

    func updateSession(id: UUID, start: Date, end: Date, quality: Int? = nil, note: String = "") {
        guard let idx = sessions.firstIndex(where: { $0.id == id }), end > start else { return }
        sessions[idx].start = start
        sessions[idx].end = end
        sessions[idx].quality = quality
        sessions[idx].note = note
        saveSessions()
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        saveSessions()
    }

    func sessions(on date: Date) -> [SleepSession] {
        let calendar = Calendar.current
        return sessions
            .filter { calendar.isDate($0.dayKey, inSameDayAs: date) }
            .sorted { $0.start < $1.start }
    }

    func dayStat(for date: Date) -> DayStat? {
        let daySessions = sessions(on: date)
        guard !daySessions.isEmpty else { return nil }
        return DayStat(id: Calendar.current.startOfDay(for: date), sessions: daySessions)
    }

    /// Average total sleep per day across the last `days` calendar days that
    /// actually have at least one recorded session (avoids skewing the
    /// average down on days with nothing tracked yet).
    func averageDuration(lastDays days: Int) -> TimeInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let rangeStart = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return 0 }

        var totalsByDay: [Date: TimeInterval] = [:]
        for session in sessions where session.dayKey >= rangeStart && session.dayKey <= today {
            totalsByDay[session.dayKey, default: 0] += session.duration
        }
        guard !totalsByDay.isEmpty else { return 0 }
        let sum = totalsByDay.values.reduce(0, +)
        return sum / Double(totalsByDay.count)
    }

    /// Current streak of consecutive days (ending today or yesterday) with at
    /// least one recorded sleep session.
    func currentStreak() -> Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: Date())
        let daysWithData = Set(sessions.map { $0.dayKey })

        // If nothing logged yet today, streak can still count from yesterday.
        if !daysWithData.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while daysWithData.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    // MARK: - Trend

    struct TrendPoint: Identifiable {
        let id = UUID()
        let day: Date
        let hours: Double
    }

    /// One point per day for the last `days` days (0 hours on days with no
    /// recorded sleep), oldest first — ready to hand straight to a chart.
    func trend(lastDays days: Int) -> [TrendPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var totalsByDay: [Date: TimeInterval] = [:]
        for session in sessions {
            totalsByDay[session.dayKey, default: 0] += session.duration
        }

        var points: [TrendPoint] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let hours = (totalsByDay[day] ?? 0) / 3600
            points.append(TrendPoint(day: day, hours: hours))
        }
        return points
    }

    // MARK: - Export

    /// All sessions as CSV (semicolon-separated so it opens cleanly in a
    /// German-locale Excel), newest first.
    func exportCSV() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM.yyyy HH:mm"

        var lines = ["Datum;Start;Ende;Dauer (Std);Qualitaet;Notiz"]
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "de_DE")
        dayFormatter.dateFormat = "dd.MM.yyyy"

        for session in sessions.sorted(by: { $0.start > $1.start }) {
            let hours = String(format: "%.2f", session.duration / 3600)
            let quality = session.quality.map(String.init) ?? ""
            let note = session.note.replacingOccurrences(of: ";", with: ",")
            let line = [
                dayFormatter.string(from: session.dayKey),
                f.string(from: session.start),
                f.string(from: session.end),
                hours,
                quality,
                note
            ].joined(separator: ";")
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }
}
