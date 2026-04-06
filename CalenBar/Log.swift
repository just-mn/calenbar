import os

/// Unified logging for CalenBar.
///
/// Uses Apple's `os.Logger` — logs are captured by Console.app, `log stream`,
/// and on-device diagnostics (sysdiagnose). Privacy-safe for App Store.
///
/// Usage:  `Log.calendar.info("Fetched \(count) events")`
///
/// Subsystem matches the bundle identifier so logs are easy to filter:
///   `log stream --predicate 'subsystem == "dev.just-mn.calenbar"'`
enum Log {
    private static let subsystem = "dev.just-mn.calenbar"

    /// App lifecycle: launch, terminate, activation policy changes.
    static let app = Logger(subsystem: subsystem, category: "app")

    /// Calendar/Reminder access and EventKit data fetching.
    static let calendar = Logger(subsystem: subsystem, category: "calendar")

    /// Alert state machine: tick, active alerts, dismiss, snooze.
    static let state = Logger(subsystem: subsystem, category: "state")

    /// Event status bar item: show/hide, cycle, flash.
    static let eventUI = Logger(subsystem: subsystem, category: "eventUI")

    /// Reminder status bar item: show/hide, flash.
    static let reminderUI = Logger(subsystem: subsystem, category: "reminderUI")

    /// Settings and user preferences.
    static let settings = Logger(subsystem: subsystem, category: "settings")

    /// Test mode scenarios.
    static let test = Logger(subsystem: subsystem, category: "test")
}
