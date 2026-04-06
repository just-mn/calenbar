import Foundation
import AppKit
import Combine
import os
import OSLog

/// Manages bug report generation: collects logs, system info, and creates GitHub issue URL.
/// Logs are copied to clipboard — not embedded in the URL — to avoid length limits.
/// Privacy-safe: excludes calendar/reminder titles and other sensitive data.
@MainActor
class BugReportManager: ObservableObject {
    static let shared = BugReportManager()

    @Published var isGenerating = false
    @Published var lastError: String?
    @Published var logFileURL: URL?
    @Published var githubIssueURL: URL?

    private let githubUser = "just-mn"
    private let githubRepo = "calenbar"

    private init() {}

    // MARK: - Public API

    /// Collects logs off main thread and saves them to a temp file.
    /// Does NOT open anything — the sheet handles that via action buttons.
    func createBugReport() async {
        isGenerating = true
        logFileURL = nil
        githubIssueURL = nil
        lastError = nil

        do {
            let report = try await generateReport()

            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("CalenBar-logs.txt")
            try report.logs.write(to: fileURL, atomically: true, encoding: .utf8)

            logFileURL = fileURL
            githubIssueURL = createGitHubIssueURL(report: report)
            isGenerating = false
        } catch {
            lastError = error.localizedDescription
            isGenerating = false
            Log.app.error("Failed to generate bug report: \(error.localizedDescription)")
        }
    }

    func revealLogFile() {
        guard let url = logFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openGitHubIssue() {
        guard let url = githubIssueURL else { return }
        NSWorkspace.shared.open(url)
    }

    func reset() {
        logFileURL = nil
        githubIssueURL = nil
        lastError = nil
    }

    // MARK: - Report Generation

    private func generateReport() async throws -> BugReport {
        let systemInfo = collectSystemInfo()
        let appInfo = collectAppInfo()
        let logs = try await collectRecentLogs()
        return BugReport(systemInfo: systemInfo, appInfo: appInfo, logs: logs)
    }

    private func collectSystemInfo() -> SystemInfo {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return SystemInfo(
            osVersion: "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)",
            architecture: ProcessInfo.processInfo.machineHardwareName ?? "unknown",
            locale: Locale.current.identifier,
            preferredLanguages: Locale.preferredLanguages.prefix(3).joined(separator: ", ")
        )
    }

    private func collectAppInfo() -> AppInfo {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let settings   = SettingsManager.shared
        let calendarMgr = CalendarManager.shared
        return AppInfo(
            version: version,
            build: build,
            flashEnabled: settings.flashEnabled,
            soundEnabled: settings.soundEnabled,
            displayMode: settings.displayMode.rawValue,
            trackedCalendarsCount: settings.selectedCalendarIDs.isEmpty ? "all" : "\(settings.selectedCalendarIDs.count)",
            trackedReminderListsCount: settings.selectedReminderListIDs.isEmpty ? "all" : "\(settings.selectedReminderListIDs.count)",
            calendarAccessGranted: calendarMgr.calendarAccessGranted,
            reminderAccessGranted: calendarMgr.reminderAccessGranted
        )
    }

    /// Runs on a background thread to avoid blocking the main thread.
    private func collectRecentLogs() async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(date: Date().addingTimeInterval(-5 * 60))
            let formatter = ISO8601DateFormatter()

            let lines = try store.getEntries(at: position)
                .compactMap { $0 as? OSLogEntryLog }
                .filter { [.notice, .error, .fault].contains($0.level) }
                .map { entry -> String in
                    let level: String
                    switch entry.level {
                    case .debug:  level = "DEBUG"
                    case .info:   level = "INFO"
                    case .notice: level = "NOTICE"
                    case .error:  level = "ERROR"
                    case .fault:  level = "FAULT"
                    default:      level = "LOG"
                    }
                    return "[\(formatter.string(from: entry.date))] [\(level)] \(entry.composedMessage)"
                }

            let output = lines.joined(separator: "\n")
            return Self.sanitizeLogs(output.isEmpty ? "No recent logs found." : output)
        }.value
    }

    /// Pure string processing — nonisolated so it can run on any thread.
    private nonisolated static func sanitizeLogs(_ logs: String) -> String {
        var s = logs
        s = s.replacingOccurrences(
            of: #"title[=:]\s*"[^"]*""#,
            with: "title=\"[REDACTED]\"",
            options: .regularExpression
        )
        s = s.replacingOccurrences(
            of: #"calendar[=:]\s*"[^"]*""#,
            with: "calendar=\"[REDACTED]\"",
            options: .regularExpression
        )
        return s
    }

    // MARK: - GitHub Issue URL

    private func createGitHubIssueURL(report: BugReport) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = "/\(githubUser)/\(githubRepo)/issues/new"
        components.queryItems = [
            URLQueryItem(name: "title", value: "Bug Report: "),
            URLQueryItem(name: "body",  value: formatIssueBody(report: report)),
            URLQueryItem(name: "labels", value: "bug")
        ]
        return components.url ?? URL(string: "https://github.com/\(githubUser)/\(githubRepo)/issues/new")!
    }

    private func formatIssueBody(report: BugReport) -> String {
        """
        ## Description
        <!-- Please describe the bug you encountered -->



        ## Steps to Reproduce
        <!-- How can we reproduce this issue? -->
        1.
        2.
        3.

        ## Expected Behavior
        <!-- What did you expect to happen? -->



        ## Actual Behavior
        <!-- What actually happened? -->



        ---

        ## System Information

        - **macOS Version:** \(report.systemInfo.osVersion)
        - **Architecture:** \(report.systemInfo.architecture)
        - **Locale:** \(report.systemInfo.locale)
        - **Languages:** \(report.systemInfo.preferredLanguages)

        ## App Information

        - **Version:** \(report.appInfo.version) (build \(report.appInfo.build))
        - **Flash Enabled:** \(report.appInfo.flashEnabled)
        - **Sound Enabled:** \(report.appInfo.soundEnabled)
        - **Display Mode:** \(report.appInfo.displayMode)
        - **Tracked Calendars:** \(report.appInfo.trackedCalendarsCount)
        - **Tracked Reminder Lists:** \(report.appInfo.trackedReminderListsCount)
        - **Calendar Access:** \(report.appInfo.calendarAccessGranted)
        - **Reminder Access:** \(report.appInfo.reminderAccessGranted)

        <details>
        <summary>Recent Logs</summary>

        <!-- A log file was opened on your Mac — drag and drop it here -->

        </details>
        """
    }
}

// MARK: - Data Models

struct BugReport {
    let systemInfo: SystemInfo
    let appInfo: AppInfo
    let logs: String
}

struct SystemInfo {
    let osVersion: String
    let architecture: String
    let locale: String
    let preferredLanguages: String
}

struct AppInfo {
    let version: String
    let build: String
    let flashEnabled: Bool
    let soundEnabled: Bool
    let displayMode: String
    let trackedCalendarsCount: String
    let trackedReminderListsCount: String
    let calendarAccessGranted: Bool
    let reminderAccessGranted: Bool
}

// MARK: - Hardware Name Extension

private extension ProcessInfo {
    var machineHardwareName: String? {
        var sysinfo = utsname()
        guard uname(&sysinfo) == EXIT_SUCCESS else { return nil }
        let data = Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN))
        return String(bytes: data, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
    }
}
