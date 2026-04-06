import Combine
import EventKit
import AppKit
import os

@MainActor
class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    let store = EKEventStore()

    @Published var calendarAccessGranted = false
    @Published var reminderAccessGranted = false

    private init() {}

    // MARK: - Access

    func requestCalendarAccess() async -> Bool {
        let granted = await requestAccess(for: .event) { try await self.store.requestFullAccessToEvents() }
        calendarAccessGranted = granted
        return granted
    }

    func requestReminderAccess() async -> Bool {
        let granted = await requestAccess(for: .reminder) { try await self.store.requestFullAccessToReminders() }
        reminderAccessGranted = granted
        return granted
    }

    private func requestAccess(for type: EKEntityType, requestBlock: @escaping () async throws -> Bool) async -> Bool {
        let label = type == .event ? "Calendar" : "Reminder"
        let status = EKEventStore.authorizationStatus(for: type)
        Log.calendar.info("\(label) auth status: \(String(describing: status))")

        if status == .fullAccess {
            Log.calendar.debug("\(label) access already granted")
            return true
        }
        if status == .denied {
            Log.calendar.warning("\(label) access denied — user must enable in System Settings")
            return false
        }

        do {
            let granted = try await requestBlock()
            Log.calendar.info("\(label) access request result: \(granted)")
            return granted
        } catch {
            Log.calendar.error("\(label) access request failed: \(error.localizedDescription)")
            return false
        }
    }

    func checkCurrentAccess() {
        let calStatus = EKEventStore.authorizationStatus(for: .event)
        calendarAccessGranted = (calStatus == .fullAccess)

        let remStatus = EKEventStore.authorizationStatus(for: .reminder)
        reminderAccessGranted = (remStatus == .fullAccess)

        Log.calendar.debug("Access check — calendars: \(calStatus == .fullAccess), reminders: \(remStatus == .fullAccess)")
    }

    // MARK: - Events

    func fetchEvents(from start: Date, to end: Date) -> [EKEvent] {
        let selectedIDs = SettingsManager.shared.selectedCalendarIDs
        let calendars: [EKCalendar]
        if selectedIDs.isEmpty {
            calendars = store.calendars(for: .event)
        } else {
            calendars = store.calendars(for: .event).filter { selectedIDs.contains($0.calendarIdentifier) }
        }
        guard !calendars.isEmpty else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        Log.calendar.debug("Fetched \(events.count) events from \(calendars.count) calendars")
        return events
    }

    func allCalendars() -> [EKCalendar] {
        store.calendars(for: .event).sorted { $0.title < $1.title }
    }

    // MARK: - Reminders

    func fetchIncompleteReminders() async -> [EKReminder] {
        let selectedIDs = SettingsManager.shared.selectedReminderListIDs
        let lists: [EKCalendar]
        if selectedIDs.isEmpty {
            lists = store.calendars(for: .reminder)
        } else {
            lists = store.calendars(for: .reminder).filter { selectedIDs.contains($0.calendarIdentifier) }
        }
        guard !lists.isEmpty else { return [] }

        return await withCheckedContinuation { continuation in
            let predicate = store.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: lists
            )
            store.fetchReminders(matching: predicate) { reminders in
                let result = reminders ?? []
                Log.calendar.debug("Fetched \(result.count) incomplete reminders from \(lists.count) lists")
                continuation.resume(returning: result)
            }
        }
    }

    func allReminderLists() -> [EKCalendar] {
        store.calendars(for: .reminder).sorted { $0.title < $1.title }
    }

    // MARK: - Actions

    func complete(_ reminder: EKReminder) throws {
        guard reminder.calendar != nil else {
            Log.calendar.warning("Cannot complete reminder — no calendar assigned")
            throw NSError(
                domain: "CalendarManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Cannot complete reminder: no calendar assigned"]
            )
        }
        reminder.isCompleted = true
        try store.save(reminder, commit: true)
        Log.calendar.info("Completed reminder: \(reminder.title ?? "untitled", privacy: .public)")
    }

    func openInCalendar(event: EKEvent) {
        // Open Calendar.app; deep-link not available without entitlements, fallback to open app
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
    }

    func openInReminders(_ reminder: EKReminder) {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
    }
}
