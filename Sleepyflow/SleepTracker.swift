import Foundation
import Combine

enum SleepState: String, Codable {
    case awake
    case sleeping
    case interrupted
}

struct SleepInterval: Codable, Identifiable {
    var id = UUID()
    let start: Date
    let end: Date
    
    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }
}

// A daily summary to show in the calendar
struct DailySleepStats: Codable, Identifiable {
    var id = UUID()
    let date: Date // e.g. start of the day
    let totalDuration: TimeInterval
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
    
    @Published var dailyStats: [DailySleepStats] = []
    
    private var timer: AnyCancellable?
    
    init() {
        loadState()
        loadStats()
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
    
    private func loadStats() {
        if let data = UserDefaults.standard.data(forKey: "dailyStats"),
           let stats = try? JSONDecoder().decode([DailySleepStats].self, from: data) {
            dailyStats = stats
        }
    }
    
    private func saveStats() {
        if let data = try? JSONEncoder().encode(dailyStats) {
            UserDefaults.standard.set(data, forKey: "dailyStats")
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
        }
        
        currentState = .awake
        currentSessionStart = nil
        stopTimer()
        
        // Save to daily stats
        if totalSleepDuration > 0 {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date()) // Saves it for today
            let newStat = DailySleepStats(date: startOfDay, totalDuration: totalSleepDuration)
            dailyStats.append(newStat)
            saveStats()
        }
        
        totalSleepDuration = 0
    }
    
    func resetSession() {
        currentState = .awake
        currentSessionStart = nil
        totalSleepDuration = 0
        stopTimer()
    }
    
    private func startTimer() {
        // Runs even when app is active to update UI.
        // When in background, UI doesn't update but `currentLiveSleepDuration` will be correct upon reopening.
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
}
