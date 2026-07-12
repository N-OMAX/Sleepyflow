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

// Locally tracked record of an alarm we scheduled, so the app can actually
// show/edit/delete it — AlarmKit itself only lets you schedule/cancel by id,
// it has no "list with details" API that's convenient for UI.
struct ScheduledAlarm: Identifiable, Codable, Hashable {
    var id: UUID
    var fireDate: Date
    var isRecurringWakeTime: Bool // true = "fixed time" alarm, false = countdown
    var usesRealSystemAlarm: Bool
    var createdAt: Date = Date()
}

@MainActor
class AlarmManager: ObservableObject {
    @Published var isAuthorized = false
    /// True once AlarmKit itself is authorized (iOS 26+ only). When false,
    /// we transparently fall back to the old local-notification alarm so the
    /// app still works on iOS 16–25 or if the person denies the new
    /// permission.
    @Published var usesRealSystemAlarm = false

    @Published var scheduledAlarms: [ScheduledAlarm] = []
    private let storageKey = "scheduledAlarms"

    init() {
        loadAlarms()
        requestAuthorization()
        refreshAlarms()
    }

    private func loadAlarms() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([ScheduledAlarm].self, from: data) else { return }
        scheduledAlarms = saved
    }

    private func persistAlarms() {
        if let data = try? JSONEncoder().encode(scheduledAlarms) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func requestAuthorization() {
        if #available(iOS 26.0, *) {
            Task { await requestAlarmKitAuthorization() }
        } else {
            requestLegacyAuthorization()
        }
    }

    private func requestLegacyAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .timeSensitive]) { granted, error in
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

    // MARK: - Public scheduling API

    @discardableResult
    func scheduleAlarm(inHours hours: Double) -> UUID {
        let id = UUID()
        let fireDate = Date().addingTimeInterval(hours * 3600)
        if #available(iOS 26.0, *), usesRealSystemAlarm {
            Task { await scheduleAlarmKitCountdown(id: id, hours: hours) }
        } else {
            scheduleLegacyNotification(id: id, inHours: hours)
        }
        addLocalRecord(id: id, fireDate: fireDate, isRecurringWakeTime: false)
        return id
    }

    @discardableResult
    func scheduleAlarm(at date: Date) -> UUID {
        let id = UUID()
        if #available(iOS 26.0, *), usesRealSystemAlarm {
            Task { await scheduleAlarmKitFixedTime(id: id, date: date) }
        } else {
            scheduleLegacyNotification(id: id, at: date)
        }
        addLocalRecord(id: id, fireDate: date, isRecurringWakeTime: true)
        return id
    }

    private func addLocalRecord(id: UUID, fireDate: Date, isRecurringWakeTime: Bool) {
        let record = ScheduledAlarm(
            id: id,
            fireDate: fireDate,
            isRecurringWakeTime: isRecurringWakeTime,
            usesRealSystemAlarm: usesRealSystemAlarm
        )
        scheduledAlarms.append(record)
        scheduledAlarms.sort { $0.fireDate < $1.fireDate }
        persistAlarms()
    }

    /// Delete a single alarm — cancels it at the system level too, not just
    /// in our local list.
    func deleteAlarm(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        if #available(iOS 26.0, *) {
            try? AlarmKit.AlarmManager.shared.cancel(id: id)
        }
        scheduledAlarms.removeAll { $0.id == id }
        persistAlarms()
    }

    /// "Editing" an alarm = cancel the old one, schedule a fresh one at the
    /// new time (AlarmKit has no in-place update API).
    @discardableResult
    func editAlarm(id: UUID, newFireDate: Date, isRecurringWakeTime: Bool) -> UUID {
        deleteAlarm(id: id)
        if isRecurringWakeTime {
            return scheduleAlarm(at: newFireDate)
        } else {
            let hours = max(0, newFireDate.timeIntervalSinceNow / 3600)
            return scheduleAlarm(inHours: hours)
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
        scheduledAlarms.removeAll()
        persistAlarms()
    }

    /// Prunes our local list against what the system actually still knows
    /// about — catches alarms that already fired or were stopped/removed
    /// from the Lock Screen / Notification Center directly, outside the app.
    func refreshAlarms() {
        if #available(iOS 26.0, *) {
            Task { await refreshAlarmKitState() }
        }
        refreshLegacyState()
    }

    @available(iOS 26.0, *)
    private func refreshAlarmKitState() async {
        guard let remoteAlarms = try? AlarmKit.AlarmManager.shared.alarms else { return }
        let remoteIDs = Set(remoteAlarms.map { $0.id })
        let before = scheduledAlarms.count
        scheduledAlarms.removeAll { $0.usesRealSystemAlarm && !remoteIDs.contains($0.id) }
        if scheduledAlarms.count != before { persistAlarms() }
    }

    private func refreshLegacyState() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            let pendingIDs = Set(requests.compactMap { UUID(uuidString: $0.identifier) })
            Task { @MainActor in
                guard let self = self else { return }
                let before = self.scheduledAlarms.count
                self.scheduledAlarms.removeAll { !$0.usesRealSystemAlarm && !pendingIDs.contains($0.id) }
                if self.scheduledAlarms.count != before { self.persistAlarms() }
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
    private func scheduleAlarmKitCountdown(id: UUID, hours: Double) async {
        let countdown = Alarm.CountdownDuration(preAlert: hours * 3600, postAlert: nil)
        let configuration = AlarmKit.AlarmManager.AlarmConfiguration(
            countdownDuration: countdown,
            schedule: nil,
            attributes: makeAttributes(),
            sound: .default
        )
        do {
            _ = try await AlarmKit.AlarmManager.shared.schedule(id: id, configuration: configuration)
            print("AlarmKit: countdown alarm scheduled for \(hours)h from now.")
        } catch {
            print("AlarmKit scheduling failed (\(error.localizedDescription)), falling back to notification.")
            scheduleLegacyNotification(id: id, inHours: hours)
        }
    }

    @available(iOS 26.0, *)
    private func scheduleAlarmKitFixedTime(id: UUID, date: Date) async {
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
            _ = try await AlarmKit.AlarmManager.shared.schedule(id: id, configuration: configuration)
            print("AlarmKit: alarm scheduled at \(components.hour ?? 0):\(components.minute ?? 0)")
        } catch {
            print("AlarmKit scheduling failed (\(error.localizedDescription)), falling back to notification.")
            scheduleLegacyNotification(id: id, at: date)
        }
    }

    // MARK: - Legacy notification fallback (iOS < 26, or AlarmKit denied)

    private func scheduleLegacyNotification(id: UUID, inHours hours: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Sleepyflow"
        content.body = "Time to wake up!"
        content.sound = UNNotificationSound.default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: hours * 3600, repeats: false)
        let request = UNNotificationRequest(identifier: id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling alarm: \(error.localizedDescription)")
            } else {
                print("Alarm (notification) scheduled for \(hours) hours from now.")
            }
        }
    }

    private func scheduleLegacyNotification(id: UUID, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Sleepyflow"
        content.body = "Time to wake up!"
        content.sound = UNNotificationSound.default
        content.interruptionLevel = .timeSensitive

        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling alarm: \(error.localizedDescription)")
            } else {
                print("Alarm (notification) scheduled at \(components.hour ?? 0):\(components.minute ?? 0)")
            }
        }
    }
}
