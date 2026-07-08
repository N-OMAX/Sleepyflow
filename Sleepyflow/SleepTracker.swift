import Foundation
import Combine

enum SleepState {
    case awake
    case sleeping
    case interrupted // awake during the night
}

struct SleepInterval {
    let start: Date
    let end: Date
    
    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }
}

class SleepTracker: ObservableObject {
    @Published var currentState: SleepState = .awake
    @Published var currentSessionStart: Date?
    @Published var sleepIntervals: [SleepInterval] = []
    
    // Total sleep duration for the current night
    @Published var totalSleepDuration: TimeInterval = 0
    
    private var timer: AnyCancellable?
    
    func startSleeping() {
        currentState = .sleeping
        currentSessionStart = Date()
        startTimer()
    }
    
    func wakeUpInNight() {
        guard currentState == .sleeping, let start = currentSessionStart else { return }
        let end = Date()
        sleepIntervals.append(SleepInterval(start: start, end: end))
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
            sleepIntervals.append(SleepInterval(start: start, end: end))
            totalSleepDuration += end.timeIntervalSince(start)
        }
        
        currentState = .awake
        currentSessionStart = nil
        stopTimer()
        
        // At this point, we could save the sleepIntervals and totalSleepDuration to HealthKit or UserDefaults
    }
    
    func resetSession() {
        currentState = .awake
        currentSessionStart = nil
        sleepIntervals.removeAll()
        totalSleepDuration = 0
        stopTimer()
    }
    
    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.objectWillChange.send() // Triggers UI update to show elapsed time live
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
