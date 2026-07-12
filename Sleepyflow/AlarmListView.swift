import SwiftUI

// MARK: - List of active alarms with edit/delete
struct AlarmListView: View {
    @ObservedObject var alarmManager: AlarmManager
    @State private var editingAlarm: ScheduledAlarm? = nil
    @State private var showEditSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !alarmManager.scheduledAlarms.isEmpty {
                HStack {
                    Text("Aktive Wecker")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("\(alarmManager.scheduledAlarms.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }

                VStack(spacing: 8) {
                    ForEach(alarmManager.scheduledAlarms) { alarm in
                        AlarmRow(
                            alarm: alarm,
                            onEdit: {
                                editingAlarm = alarm
                                showEditSheet = true
                            },
                            onDelete: {
                                withAnimation { alarmManager.deleteAlarm(id: alarm.id) }
                            }
                        )
                    }
                }
            } else {
                HStack {
                    Image(systemName: "alarm")
                        .foregroundColor(.white.opacity(0.3))
                    Text("Kein Wecker aktiv")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                }
            }
        }
        .onAppear { alarmManager.refreshAlarms() }
        .sheet(isPresented: $showEditSheet) {
            if let alarm = editingAlarm {
                AlarmEditSheet(alarmManager: alarmManager, alarm: alarm)
            }
        }
    }
}

// MARK: - Single alarm row
private struct AlarmRow: View {
    let alarm: ScheduledAlarm
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alarm.isRecurringWakeTime ? "alarm.fill" : "hourglass")
                .font(.system(size: 15))
                .foregroundColor(AppColors.accentLightPurple)
                .frame(width: 30, height: 30)
                .background(AppColors.accentLightPurple.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(timeString(alarm.fireDate))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
            }

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(alarm.usesRealSystemAlarm ? Color.green : Color.orange)
                    .frame(width: 5, height: 5)
            }

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.75))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .confirmationDialog("Wecker löschen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { onDelete() }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    private var subtitle: String {
        let base = alarm.isRecurringWakeTime ? "Feste Uhrzeit" : "Countdown"
        let relative = relativeString(to: alarm.fireDate)
        return "\(base) · \(relative)"
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func relativeString(to date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "fällig" }
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        if h > 0 { return "in \(h)h \(m)min" }
        return "in \(m)min"
    }
}

// MARK: - Edit sheet (change time, or delete)
struct AlarmEditSheet: View {
    @ObservedObject var alarmManager: AlarmManager
    let alarm: ScheduledAlarm
    @Environment(\.dismiss) private var dismiss

    @State private var newDate: Date
    @State private var showDeleteConfirm = false

    init(alarmManager: AlarmManager, alarm: ScheduledAlarm) {
        self.alarmManager = alarmManager
        self.alarm = alarm
        _newDate = State(initialValue: alarm.fireDate)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    DatePicker("", selection: $newDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .accentColor(AppColors.accentPurple)
                        .padding(16)
                        .glassmorphic()

                    Button("Änderungen speichern") {
                        alarmManager.editAlarm(id: alarm.id, newFireDate: newDate, isRecurringWakeTime: alarm.isRecurringWakeTime)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Wecker löschen", systemImage: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.red.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.red.opacity(0.25), lineWidth: 1)
                    )

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Wecker bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .confirmationDialog("Wecker wirklich löschen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    alarmManager.deleteAlarm(id: alarm.id)
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
    }
}
