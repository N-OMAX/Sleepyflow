import SwiftUI

struct ContentView: View {
    @StateObject private var tracker = SleepTracker()
    @StateObject private var alarmManager = AlarmManager()
    @State private var selectedAlarmTime = Date()
    @State private var showDatePicker = false
    @State private var showStats = false
    @State private var showResetConfirm = false
    
    var body: some View {
        ZStack {
            // Deep black base
            Color.black.ignoresSafeArea()
            
            // Purple ambient glow top
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.accentPurple.opacity(0.35),
                    Color.clear
                ]),
                center: .init(x: 0.5, y: -0.1),
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            // Bottom glow
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.accentLightPurple.opacity(0.15),
                    Color.clear
                ]),
                center: .init(x: 0.2, y: 1.2),
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // MARK: Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sleepyflow")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("by Joshua Pawlowski")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(1)
                        }
                        
                        Spacer()
                        
                        Button(action: { showStats = true }) {
                            Image(systemName: "calendar")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                        .floatingGlass(cornerRadius: 14)
                    }
                    .padding(.top, 60)
                    
                    // MARK: Sleep Timer Card
                    VStack(spacing: 20) {
                        // Title row with reset button
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sleep Tracker")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(statusColor())
                                        .frame(width: 7, height: 7)
                                    Text(statusText())
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            
                            Spacer()
                            
                            // Reset button
                            Button(action: { showResetConfirm = true }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.red.opacity(0.9))
                                    .frame(width: 40, height: 40)
                            }
                            .resetButtonBackground()
                            .confirmationDialog("Tracker zurücksetzen?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                                Button("Zurücksetzen", role: .destructive) { tracker.resetSession() }
                                Button("Abbrechen", role: .cancel) {}
                            } message: {
                                Text("Die aktuelle Session wird beendet. Die gespeicherten Statistiken bleiben erhalten.")
                            }
                        }
                        
                        // Live Timer Display
                        let duration = tracker.currentLiveSleepDuration()
                        let h = Int(duration) / 3600
                        let m = (Int(duration) % 3600) / 60
                        let s = Int(duration) % 60
                        
                        VStack(spacing: 8) {
                            Text(String(format: "%02d:%02d:%02d", h, m, s))
                                .font(.system(size: 52, weight: .thin, design: .monospaced))
                                .foregroundColor(.white)
                                .shadow(color: AppColors.accentGlow, radius: tracker.currentState == .sleeping ? 20 : 0, x: 0, y: 0)
                            
                            if tracker.currentState == .sleeping, let start = tracker.currentSessionStart {
                                Text("Seit \(timeString(start))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        
                        // Control Buttons
                        VStack(spacing: 12) {
                            switch tracker.currentState {
                            case .awake:
                                Button("Schlafen gehen") { tracker.startSleeping() }
                                    .buttonStyle(PrimaryButtonStyle())
                                
                            case .sleeping:
                                Button("In der Nacht aufgewacht") { tracker.wakeUpInNight() }
                                    .buttonStyle(SecondaryButtonStyle())
                                Button("Aufwachen (Final)") { tracker.finalWakeUp() }
                                    .buttonStyle(PrimaryButtonStyle())
                                
                            case .interrupted:
                                Button("Wieder schlafen gehen") { tracker.resumeSleeping() }
                                    .buttonStyle(PrimaryButtonStyle())
                                Button("Aufwachen (Final)") { tracker.finalWakeUp() }
                                    .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }
                    .padding(20)
                    .glassmorphic()
                    
                    // MARK: Alarm Card
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "alarm")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.accentLightPurple)
                            Text("Wecker stellen")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Button(action: { alarmManager.scheduleAlarm(inHours: 8) }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 22))
                                    Text("+ 8 Stunden")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                            }
                            .floatingGlass(cornerRadius: 16)
                            
                            Button(action: { showDatePicker.toggle() }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 22))
                                    Text("Manuelle Zeit")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                            }
                            .floatingGlass(cornerRadius: 16)
                        }
                        
                        if showDatePicker {
                            VStack(spacing: 12) {
                                DatePicker(
                                    "",
                                    selection: $selectedAlarmTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .datePickerStyle(WheelDatePickerStyle())
                                .labelsHidden()
                                .colorScheme(.dark)
                                
                                Button("Wecker setzen") {
                                    alarmManager.scheduleAlarm(at: selectedAlarmTime)
                                    showDatePicker = false
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            }
                        }
                    }
                    .padding(20)
                    .glassmorphic()
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showStats) {
            SleepStatsView(tracker: tracker)
        }
    }
    
    private func statusText() -> String {
        switch tracker.currentState {
        case .awake: return "Wach"
        case .sleeping: return "Schläft gerade"
        case .interrupted: return "In der Nacht aufgewacht"
        }
    }
    
    private func statusColor() -> Color {
        switch tracker.currentState {
        case .awake: return .gray
        case .sleeping: return .green
        case .interrupted: return .orange
        }
    }
    
    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
