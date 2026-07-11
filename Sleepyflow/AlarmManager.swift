import Foundation
import SwiftUI
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif

// Empty metadata payload required by AlarmKit's generic AlarmAttributes<Metadata>.
// We don't need extra data on the Live Activity, so this stays empty.
@available(iOS 26.0, *)
nonisolated struct SleepyflowAlarmMetadata: AlarmMetadata {}

@MainActor
class AlarmManager: ObservableObject {
    @Published var isAuthorized = false
    /// True once AlarmKit itself is authorized (iOS 26+ only). When false,
    /// we transparently fall back to the old local-notification alarm so the
    /// app still works on iOS 16–25 or if the person denies the new
    /// permission.
    @Published var usesRealSystemAlarm = false

    init() {
        requestAuthorization()
    }

    func requestAuthorization() {
        if #available(iOS 26.0, *) {
            Task { await requestAlarmKitAuthorization() }
        } else {
            requestLegacyAuthorization()
        }
    }

    private func requestLegacyAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if let error = error {
                    print("Notification authorization error: \(error.localizedDescription)")
                }
            }
        }
    }

    @available(iOS 26.0, *)
    private func requestAlarmKitAuthorization() async {
        // NOTE: property is `authorizationState`, not `authorizationStatus`.
        switch AlarmKit.AlarmManager.shared.authorizationState {
        case .authorized:
            isAuthorized = true
            usesRealSystemAlarm = true
        case .notDetermined:
            do {
                let state = try await AlarmKit.AlarmManager.shared.requestAuthorization()
                isAuthorized = (state == .authorized)
                usesRealSystemAlarm = (state == .authorized)
            } catch {
                print("AlarmKit authorization error: \(error.localizedDescription)")
                isAuthorized = false
                usesRealSystemAlarm = false
            }
        case .denied:
            isAuthorized = false
            usesRealSystemAlarm = false
        @unknown default:
            isAuthorized = false
            usesRealSystemAlarm = false
        }
    }

    // MARK: - Public scheduling API (unchanged call sites in ContentView)

    func scheduleAlarm(inHours hours: Double) {
        if #available(iOS 26.0, *), usesRealSystemAlarm {
            Task { await scheduleAlarmKitCountdown(hours: hours) }
        } else {
            scheduleLegacyNotification(inHours: hours)
        }
    }

    func scheduleAlarm(at date: Date) {
        if #available(iOS 26.0, *), usesRealSystemAlarm {
            Task { await scheduleAlarmKitFixedTime(date: date) }
        } else {
            scheduleLegacyNotification(at: date)
        }
    }

    func cancelAllAlarms() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        if #available(iOS 26.0, *) {
            // AlarmKit has no "cancel all" — cancel each alarm we own individually.
            // `.alarms` can throw in this SDK version, so guard with try?.
            if let alarms = try? AlarmKit.AlarmManager.shared.alarms {
                for alarm in alarms {
                    try? AlarmKit.AlarmManager.shared.cancel(id: alarm.id)
                }
            }
        }
    }

    // MARK: - AlarmKit (iOS 26+)

    @available(iOS 26.0, *)
    private func makeAlertPresentation() -> AlarmPresentation {
        let stopButton = AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
        let alert = AlarmPresentation.Alert(title: "Sleepyflow", stopButton: stopButton)
        return AlarmPresentation(alert: alert)
    }

    @available(iOS 26.0, *)
    private func makeAttributes() -> AlarmAttributes<SleepyflowAlarmMetadata> {
        AlarmAttributes(
            presentation: makeAlertPresentation(),
            metadata: SleepyflowAlarmMetadata(),
            tintColor: AppColors.accentPurple
        )
    }

    @available(iOS 26.0, *)
    private func scheduleAlarmKitCountdown(hours: Double) async {
        let countdown = Alarm.CountdownDuration(preAlert: hours * 3600, postAlert: nil)
        let configuration = AlarmKit.AlarmManager.AlarmConfiguration(
            countdownDuration: countdown,
            schedule: nil,
            attributes: makeAttributes(),
            sound: .default
        )
        do {
            _ = try await AlarmKit.AlarmManager.shared.schedule(id: UUID(), configuration: configuration)
            print("AlarmKit: countdown alarm scheduled for \(hours)h from now.")
        } catch {
            print("AlarmKit scheduling failed (\(error.localizedDescription)), falling back to notification.")
            scheduleLegacyNotification(inHours: hours)
        }
    }

    @available(iOS 26.0, *)
    private func scheduleAlarmKitFixedTime(date: Date) async {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let time = Alarm.Schedule.Relative.Time(hour: components.hour ?? 7, minute: components.minute ?? 0)
        let schedule = Alarm.Schedule.relative(
            Alarm.Schedule.Relative(time: time, repeats: .never)
        )
        let configuration = AlarmKit.AlarmManager.AlarmConfiguration(
            countdownDuration: nil,
            schedule: schedule,
            attributes: makeAttributes(),
            sound: .default
        )
        do {
            _ = try await AlarmKit.AlarmManager.shared.schedule(id: UUID(), configuration: configuration)
            print("AlarmKit: alarm scheduled at \(components.hour ?? 0):\(components.minute ?? 0)")
        } catch {
            print("AlarmKit scheduling failed (\(error.localizedDescription)), falling back to notification.")
            scheduleLegacyNotification(at: date)
        }
    }

    // MARK: - Legacy notification fallback (iOS < 26, or AlarmKit denied)

    private func scheduleLegacyNotification(inHours hours: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Sleepyflow"
        content.body = "Time to wake up!"
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: hours * 3600, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling alarm: \(error.localizedDescription)")
            } else {
                print("Alarm (notification) scheduled for \(hours) hours from now.")
            }
        }
    }

    private func scheduleLegacyNotification(at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Sleepyflow"
        content.body = "Time to wake up!"
        content.sound = UNNotificationSound.default

        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling alarm: \(error.localizedDescription)")
            } else {
                print("Alarm (notification) scheduled at \(components.hour ?? 0):\(components.minute ?? 0)")
            }
        }
    }
}
