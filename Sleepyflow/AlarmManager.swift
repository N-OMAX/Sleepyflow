import Foundation
import UserNotifications

class AlarmManager: ObservableObject {
    @Published var isAuthorized = false
    
    init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if let error = error {
                    print("Notification authorization error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func scheduleAlarm(inHours hours: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Sleepyflow"
        content.body = "Time to wake up!"
        content.sound = UNNotificationSound.default
        // Using default sound; in a real app you might use a custom loud sound file
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: hours * 3600, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling alarm: \(error.localizedDescription)")
            } else {
                print("Alarm scheduled for \(hours) hours from now.")
            }
        }
    }
    
    func scheduleAlarm(at date: Date) {
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
                print("Alarm scheduled at \(components.hour ?? 0):\(components.minute ?? 0)")
            }
        }
    }
    
    func cancelAllAlarms() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
