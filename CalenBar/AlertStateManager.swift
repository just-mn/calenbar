import EventKit
import Foundation
import Combine
import os

@MainActor
class AlertStateManager: ObservableObject {
    static let shared = AlertStateManager()

    // Events whose alarm has fired and haven't been dismissed
    @Published var activeEventAlerts: [EKEvent] = []
    // Events happening right now
    @Published var currentEvents: [EKEvent] = []
    // Reminders that are due/overdue and awaiting action
    @Published var activeReminders: [EKReminder] = []

    // eventIdentifier + "_" + alarmTimestamp — dismissed by user
    private var dismissedEventAlerts: Set<String> = []
    private let dismissedKey = "dismissedEventAlerts"

    // reminderID → snooze-until date (internal only, Reminders.app is not touched)
    private var snoozedReminders: [String: Date] = [:]
    private let snoozedRemindersKey = "snoozedReminders"

    // Track reminders we already played sound for
    private var soundedEventAlerts: Set<String> = []
    private var soundedReminderIDs: Set<String> = []

    private init() {
        loadDismissed()
        loadSnoozed()
        Log.state.info("AlertStateManager initialized — \(self.dismissedEventAlerts.count) dismissed, \(self.snoozedReminders.count) snoozed loaded")
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Log.state.debug("EKEventStoreChanged notification received")
            Task { @MainActor [weak self] in
                await self?.tick()
            }
        }
    }

    // MARK: - Main tick (called every 30s + on store change)

    func tick() async {
        guard !TestModeManager.shared.isEnabled else {
            Log.state.debug("Tick skipped — test mode active")
            return
        }
        guard CalendarManager.shared.calendarAccessGranted else {
            Log.state.debug("Tick skipped — no calendar access")
            return
        }

        let now = Date()
        let dayAgo = now.addingTimeInterval(-86400)
        let twoDaysAhead = now.addingTimeInterval(2 * 86400)

        let events = CalendarManager.shared.fetchEvents(from: dayAgo, to: twoDaysAhead)

        var newAlerts: [EKEvent] = []
        var nowEvents: [EKEvent] = []

        for event in events {
            guard !event.isAllDay else { continue }

            guard let start = event.startDate, let end = event.endDate else { continue }

            // Currently in progress
            if start <= now && now < end {
                nowEvents.append(event)
            }

            // Check if any alarm has fired
            if let alarms = event.alarms {
                for alarm in alarms {
                    let alarmDate = alarmTriggerDate(alarm, eventStart: start)
                    guard let alarmDate else { continue }
                    let key = dismissKey(event: event, alarmDate: alarmDate)

                    // Alarm fired (past) and event not yet ended, and not dismissed
                    if alarmDate <= now && now < end && !dismissedEventAlerts.contains(key) {
                        if !newAlerts.contains(where: { $0.eventIdentifier == event.eventIdentifier }) {
                            newAlerts.append(event)
                        }
                        // Play sound + will flash via controller
                        if !soundedEventAlerts.contains(key) {
                            soundedEventAlerts.insert(key)
                            SettingsManager.shared.playCurrentSound()
                        }
                    }
                }
            }
        }

        // Also show events in progress even if no alert (if setting enabled or if no alarms)
        if SettingsManager.shared.showEventsWithoutAlarms {
            for event in nowEvents {
                if !newAlerts.contains(where: { $0.eventIdentifier == event.eventIdentifier }) {
                    newAlerts.append(event)
                }
            }
        }

        activeEventAlerts = newAlerts
        currentEvents = nowEvents
        Log.state.debug("Tick complete — \(newAlerts.count) alerts, \(nowEvents.count) in-progress")

        // Reminders
        if CalendarManager.shared.reminderAccessGranted {
            let reminders = await CalendarManager.shared.fetchIncompleteReminders()
            var dueReminders: [EKReminder] = []

            for reminder in reminders {
                guard !reminder.isCompleted else { continue }

                if reminderIsFired(reminder, now: now) {
                    dueReminders.append(reminder)
                    let rid = reminder.calendarItemIdentifier
                    if !soundedReminderIDs.contains(rid) {
                        soundedReminderIDs.insert(rid)
                        SettingsManager.shared.playCurrentSound()
                    }
                }
            }
            activeReminders = dueReminders
            if !dueReminders.isEmpty {
                Log.state.debug("Active reminders: \(dueReminders.count)")
            }
        }
    }

    // MARK: - Dismiss event alert

    func dismissEventAlert(_ event: EKEvent) {
        Log.state.info("Dismissing event alert: \(event.title ?? "untitled", privacy: .public)")
        guard let alarms = event.alarms else {
            activeEventAlerts.removeAll { $0.eventIdentifier == event.eventIdentifier }
            Log.state.debug("Dismissed event with no alarms")
            return
        }
        let now = Date()
        for alarm in alarms {
            if let alarmDate = alarmTriggerDate(alarm, eventStart: event.startDate),
               alarmDate <= now {
                let key = dismissKey(event: event, alarmDate: alarmDate)
                dismissedEventAlerts.insert(key)
                soundedEventAlerts.remove(key)
            }
        }
        saveDismissed()
        activeEventAlerts.removeAll { $0.eventIdentifier == event.eventIdentifier }
    }

    // Snooze a reminder internally — Reminders.app is NOT modified.
    // The reminder is hidden until the snooze expires, then re-appears on the next tick.
    func snoozeReminder(_ reminder: EKReminder, minutes: Int) {
        let rid = reminder.calendarItemIdentifier
        snoozedReminders[rid] = Date().addingTimeInterval(TimeInterval(minutes * 60))
        saveSnoozed()
        removeReminder(reminder)
        Log.state.info("Snoozed reminder '\(reminder.title ?? "untitled", privacy: .public)' for \(minutes) min")
    }

    // Remove reminder from active list after action (snooze/complete)
    func removeReminder(_ reminder: EKReminder) {
        activeReminders.removeAll { $0.calendarItemIdentifier == reminder.calendarItemIdentifier }
        soundedReminderIDs.remove(reminder.calendarItemIdentifier)
        Log.state.debug("Removed reminder from active list, \(self.activeReminders.count) remaining")
    }

    // MARK: - Helpers

    /// Determines whether a reminder should currently be shown to the user.
    ///
    /// Firing rules (in priority order):
    /// 1. Internal snooze active → never fire, regardless of alarms or due date.
    /// 2. Has at least one alarm that has triggered (past) → fire.
    /// 3. No alarms at all → fall back to due date: fire if overdue.
    private func reminderIsFired(_ reminder: EKReminder, now: Date) -> Bool {
        let rid = reminder.calendarItemIdentifier

        // Internal snooze takes full priority — Reminders.app alarms are not modified
        if let snoozeUntil = snoozedReminders[rid], snoozeUntil > now {
            return false
        }

        let alarms = reminder.alarms ?? []

        if alarms.isEmpty {
            // No alarms — fall back to due date
            guard let comps = reminder.dueDateComponents,
                  let due   = Calendar.current.date(from: comps) else { return false }
            return due <= now
        }

        // Fire if at least one alarm has triggered
        let dueDate: Date? = {
            guard let comps = reminder.dueDateComponents else { return nil }
            return Calendar.current.date(from: comps)
        }()

        for alarm in alarms {
            let triggerDate: Date
            if let abs = alarm.absoluteDate {
                triggerDate = abs
            } else if let due = dueDate {
                triggerDate = due.addingTimeInterval(alarm.relativeOffset)
            } else {
                continue
            }
            if triggerDate <= now { return true }
        }
        return false
    }

    private func alarmTriggerDate(_ alarm: EKAlarm, eventStart: Date) -> Date? {
        if let abs = alarm.absoluteDate { return abs }
        return eventStart.addingTimeInterval(alarm.relativeOffset)
    }

    private func dismissKey(event: EKEvent, alarmDate: Date) -> String {
        "\(event.eventIdentifier ?? "")_\(Int(alarmDate.timeIntervalSince1970))"
    }

    private func saveDismissed() {
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        let before = dismissedEventAlerts.count
        dismissedEventAlerts = dismissedEventAlerts.filter { key in
            let parts = key.split(separator: "_")
            guard let last = parts.last, let ts = Double(last) else {
                Log.state.warning("Malformed dismiss key kept: \(key, privacy: .private)")
                return true // keep entries we can't parse rather than losing them
            }
            return Date(timeIntervalSince1970: ts) > cutoff
        }
        let pruned = before - dismissedEventAlerts.count
        if pruned > 0 {
            Log.state.debug("Pruned \(pruned) old dismissed entries")
        }
        UserDefaults.standard.set(Array(dismissedEventAlerts), forKey: dismissedKey)
    }

    private func loadDismissed() {
        let saved = UserDefaults.standard.array(forKey: dismissedKey) as? [String] ?? []
        dismissedEventAlerts = Set(saved)
    }

    private func saveSnoozed() {
        let now = Date()
        // Prune expired entries before saving
        snoozedReminders = snoozedReminders.filter { $0.value > now }
        let dict = snoozedReminders.mapValues { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(dict, forKey: snoozedRemindersKey)
    }

    private func loadSnoozed() {
        let now = Date()
        let dict = UserDefaults.standard.dictionary(forKey: snoozedRemindersKey) as? [String: Double] ?? [:]
        // Discard already-expired entries on load
        snoozedReminders = dict.compactMapValues { ts -> Date? in
            let date = Date(timeIntervalSince1970: ts)
            return date > now ? date : nil
        }
    }
}
