import SwiftUI

// MARK: - Add / Edit a single sleep entry
// Used from the calendar day detail to fix wrong times, fill in a missed
// entry, or remove one that shouldn't be there.
struct SessionEditView: View {
    @ObservedObject var tracker: SleepTracker
    @Environment(\.dismiss) private var dismiss

    /// Day this entry belongs to (used as the default date when adding new).
    let day: Date
    /// nil = creating a new entry, otherwise editing this existing one.
    let existingSession: SleepSession?

    @State private var start: Date
    @State private var end: Date
    @State private var quality: Int
    @State private var note: String
    @State private var showDeleteConfirm = false
    @State private var showInvalidRangeWarning = false

    init(tracker: SleepTracker, day: Date, existingSession: SleepSession? = nil) {
        self.tracker = tracker
        self.day = day
        self.existingSession = existingSession

        let calendar = Calendar.current
        if let session = existingSession {
            _start = State(initialValue: session.start)
            _end = State(initialValue: session.end)
            _quality = State(initialValue: session.quality ?? 0)
            _note = State(initialValue: session.note)
        } else {
            // Sensible default: 23:00 the evening before -> 07:00 on the
            // selected day, so the picker doesn't open on a 0-minute range.
            let dayStart = calendar.startOfDay(for: day)
            let defaultEnd = calendar.date(byAdding: .hour, value: 7, to: dayStart) ?? day
            let defaultStart = calendar.date(byAdding: .hour, value: -8, to: defaultEnd) ?? day
            _start = State(initialValue: defaultStart)
            _end = State(initialValue: defaultEnd)
            _quality = State(initialValue: 0)
            _note = State(initialValue: "")
        }
    }

    private var isValidRange: Bool { end > start }

    private var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Live duration preview
                        VStack(spacing: 4) {
                            Text(durationString(duration))
                                .font(.system(size: 40, weight: .thin, design: .monospaced))
                                .foregroundColor(isValidRange ? .white : .red)
                            Text("Gesamtdauer")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.top, 12)

                        VStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Eingeschlafen", systemImage: "moon.zzz.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.accentLightPurple)
                                DatePicker("", selection: $start, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.graphical)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .accentColor(AppColors.accentPurple)
                            }
                            .padding(16)

                            Divider().background(Color.white.opacity(0.1))

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Aufgewacht", systemImage: "sun.max.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.yellow.opacity(0.8))
                                DatePicker("", selection: $end, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.graphical)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .accentColor(AppColors.accentPurple)
                            }
                            .padding(16)
                        }
                        .glassmorphic()

                        if !isValidRange {
                            Text("„Aufgewacht“ muss nach „Eingeschlafen“ liegen.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                        }

                        // Quality rating
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Schlafqualität")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))

                            HStack(spacing: 10) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= quality ? "star.fill" : "star")
                                        .font(.system(size: 22))
                                        .foregroundColor(star <= quality ? .yellow : .white.opacity(0.25))
                                        .onTapGesture {
                                            quality = (quality == star) ? 0 : star
                                        }
                                }
                                Spacer()
                                if quality > 0 {
                                    Button("Zurücksetzen") { quality = 0 }
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                        }
                        .padding(16)
                        .glassmorphic()

                        // Note
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Notiz")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))

                            TextField("z.B. spät Kaffee, unruhig geschlafen ...", text: $note, axis: .vertical)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .lineLimit(3...6)
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .padding(16)
                        .glassmorphic()

                        Button(existingSession == nil ? "Eintrag speichern" : "Änderungen speichern") {
                            save()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!isValidRange)
                        .opacity(isValidRange ? 1 : 0.5)

                        if existingSession != nil {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("Eintrag löschen", systemImage: "trash")
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
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(existingSession == nil ? "Eintrag hinzufügen" : "Eintrag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .confirmationDialog("Eintrag wirklich löschen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    if let session = existingSession {
                        tracker.deleteSession(id: session.id)
                    }
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard isValidRange else { return }
        let finalQuality: Int? = quality > 0 ? quality : nil
        if let session = existingSession {
            tracker.updateSession(id: session.id, start: start, end: end, quality: finalQuality, note: note)
        } else {
            tracker.addManualSession(start: start, end: end, quality: finalQuality, note: note)
        }
        dismiss()
    }

    private func durationString(_ duration: TimeInterval) -> String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }
}
