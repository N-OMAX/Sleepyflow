import SwiftUI

struct ContentView: View {
    @StateObject private var tracker = SleepTracker()
    @StateObject private var alarmManager = AlarmManager()
    @State private var selectedAlarmTime = Date()
    @State private var showDatePicker = false
    @State private var showStats = false
    
    var body: some View {
        ZStack {
            // Background Color
            AppColors.background.ignoresSafeArea()
            
            // Subtle ambient background gradient
            RadialGradient(gradient: Gradient(colors: [AppColors.accentPurple.opacity(0.3), .clear]), center: .top, startRadius: 0, endRadius: 500)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sleepyflow")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: AppColors.accentPurple, radius: 10, x: 0, y: 0)
                            
                            Text("Designed by Joshua Pawlowski")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        // Navigation to Stats
                        Button(action: { showStats = true }) {
                            Image(systemName: "calendar")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding(12)
                                .glassmorphic()
                        }
                    }
                    .padding(.top, 40)
                    
                    // Sleep Tracking Section
                    VStack(spacing: 20) {
                        HStack {
                            Text("Sleep Tracker")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // Reset Button
                            Button(action: { tracker.resetSession() }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundColor(.red)
                                    .padding(8)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        
                        let duration = tracker.currentLiveSleepDuration()
                        let hours = Int(duration) / 3600
                        let minutes = (Int(duration) % 3600) / 60
                        let seconds = Int(duration) % 60
                        
                        Text(String(format: "%02d:%02d:%02d", hours, minutes, seconds))
                            .font(.system(size: 48, weight: .semibold, design: .monospaced))
                            .foregroundColor(AppColors.accentLightPurple)
                            .padding()
                            .glassmorphic()
                        
                        Text("Status: \(statusText())")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        // Tracking Controls
                        VStack(spacing: 15) {
                            if tracker.currentState == .awake {
                                Button("Go to Sleep") {
                                    tracker.startSleeping()
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                
                            } else if tracker.currentState == .sleeping {
                                Button("Wake Up (In Night)") {
                                    tracker.wakeUpInNight()
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                
                                Button("Final Wake Up") {
                                    tracker.finalWakeUp()
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                
                            } else if tracker.currentState == .interrupted {
                                Button("Resume Sleep") {
                                    tracker.resumeSleeping()
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                
                                Button("Final Wake Up") {
                                    tracker.finalWakeUp()
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }
                    .padding()
                    .glassmorphic()
                    
                    // Alarms Section
                    VStack(spacing: 20) {
                        Text("Alarms")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 15) {
                            Button("+8 Hours Alarm") {
                                alarmManager.scheduleAlarm(inHours: 8)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            
                            Button("Set Manual Time") {
                                showDatePicker.toggle()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        
                        if showDatePicker {
                            DatePicker("Select Time", selection: $selectedAlarmTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(WheelDatePickerStyle())
                                .labelsHidden()
                                .colorScheme(.dark)
                                .background(Color.white.opacity(0.05).cornerRadius(15))
                            
                            Button("Schedule Alarm") {
                                alarmManager.scheduleAlarm(at: selectedAlarmTime)
                                showDatePicker = false
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    .padding()
                    .glassmorphic()
                    
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showStats) {
            SleepStatsView(tracker: tracker)
        }
    }
    
    private func statusText() -> String {
        switch tracker.currentState {
        case .awake:
            return "Awake"
        case .sleeping:
            return "Sleeping"
        case .interrupted:
            return "Interrupted (Awake in night)"
        }
    }
}
