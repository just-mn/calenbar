import Combine
import EventKit
import Foundation
import os

/// Manages test mode: injects fake events/reminders directly into AlertStateManager
/// without touching the real calendar. All objects are created in-memory (never saved).
@MainActor
class TestModeManager: ObservableObject {
    static let shared = TestModeManager()

    @Published var isEnabled = false {
        didSet {
            if isEnabled {
                Log.test.info("Test mode enabled")
                applyScenario(currentScenario)
            } else {
                Log.test.info("Test mode disabled")
                clearState()
            }
        }
    }

    @Published var currentScenario: Scenario = .upcomingAlert {
        didSet {
            if isEnabled {
                Log.test.info("Scenario changed to: \(self.currentScenario.rawValue)")
                applyScenario(currentScenario)
            }
        }
    }

    enum Scenario: String, CaseIterable, Identifiable {
        case upcomingAlert, inProgress, overlapping, singleReminder, multiReminder, everything

        var id: String { rawValue }

        var label: String {
            switch self {
            case .upcomingAlert:  return Str.testScenarioUpcoming
            case .inProgress:     return Str.testScenarioInProgress
            case .overlapping:    return Str.testScenarioOverlap
            case .singleReminder: return Str.testScenarioReminder
            case .multiReminder:  return Str.testScenarioMultiRem
            case .everything:     return Str.testScenarioEverything
            }
        }
    }

    private let store = CalendarManager.shared.store
    private var fakeReminders: [FakeReminder] = []

    private init() {}

    // MARK: - Apply

    func applyScenario(_ scenario: Scenario) {
        let state = AlertStateManager.shared
        fakeReminders = []

        switch scenario {
        case .upcomingAlert:
            let event = makeEvent(
                title: Str.demoEventTeamCall,
                startOffset: 10 * 60,
                duration: 30 * 60,
                alarmOffset: -15 * 60
            )
            state.activeEventAlerts = [event]
            state.currentEvents = []
            state.activeReminders = []

        case .inProgress:
            let event = makeEvent(
                title: Str.demoEventDesignSync,
                startOffset: -10 * 60,
                duration: 45 * 60
            )
            state.activeEventAlerts = []
            state.currentEvents = [event]
            state.activeReminders = []

        case .overlapping:
            let e1 = makeEvent(title: Str.demoEventDailyStandup, startOffset: -5 * 60, duration: 30 * 60)
            let e2 = makeEvent(title: Str.demoEventOneOnOne, startOffset: -2 * 60, duration: 60 * 60)
            state.activeEventAlerts = []
            state.currentEvents = [e1, e2]
            state.activeReminders = []

        case .singleReminder:
            let r = FakeReminder(title: Str.demoReminderCallBank, overdueMinutes: 5)
            fakeReminders = [r]
            state.activeEventAlerts = []
            state.currentEvents = []
            state.activeReminders = r.asEKReminders(store: store)

        case .multiReminder:
            let r1 = FakeReminder(title: Str.demoReminderPayBill, overdueMinutes: 20)
            let r2 = FakeReminder(title: Str.demoReminderBuyGroceries, overdueMinutes: 5)
            let r3 = FakeReminder(title: Str.demoReminderWriteReport, overdueMinutes: 0)
            fakeReminders = [r1, r2, r3]
            state.activeEventAlerts = []
            state.currentEvents = []
            state.activeReminders = fakeReminders.flatMap { $0.asEKReminders(store: store) }

        case .everything:
            let event = makeEvent(
                title: Str.demoEventClientMeeting,
                startOffset: 7 * 60,
                duration: 60 * 60,
                alarmOffset: -10 * 60
            )
            let r = FakeReminder(title: Str.demoReminderPreparePresentation, overdueMinutes: 10)
            fakeReminders = [r]
            state.activeEventAlerts = [event]
            state.currentEvents = []
            state.activeReminders = r.asEKReminders(store: store)
        }
    }

    func clearState() {
        let state = AlertStateManager.shared
        state.activeEventAlerts = []
        state.currentEvents = []
        state.activeReminders = []
        fakeReminders = []
    }

    // MARK: - Fake object builders

    private func makeEvent(
        title: String,
        startOffset: TimeInterval,
        duration: TimeInterval,
        alarmOffset: TimeInterval? = nil
    ) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = Date().addingTimeInterval(startOffset)
        event.endDate = Date().addingTimeInterval(startOffset + duration)
        if let offset = alarmOffset {
            event.addAlarm(EKAlarm(relativeOffset: offset))
        }
        return event
    }
}

// MARK: - FakeReminder wrapper

/// EKReminder can't be created without a store and needs calendar set.
/// We wrap it and inject into AlertStateManager by building real (unsaved) EKReminder objects.
private struct FakeReminder {
    let title: String
    let overdueMinutes: Int

    func asEKReminders(store: EKEventStore) -> [EKReminder] {
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        let dueDate = Calendar.current.date(
            byAdding: .minute, value: -overdueMinutes, to: Date()
        )!
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: dueDate
        )
        reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
        return [reminder]
    }
}
