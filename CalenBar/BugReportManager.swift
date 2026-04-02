import Foundation
import AppKit
import EventKit
import Combine
import os

/// Manages bug report generation: collects logs, system info, and creates GitHub issue URL.
/// Privacy-safe: excludes calendar/reminder titles and other sensitive data.
@MainActor
class BugReportManager: ObservableObject {
    static let shared = BugReportManager()
    
    @Published var isGenerating = false
    @Published var lastError: String?
    
    private let githubUser = "just-mn"
    private let githubRepo = "calenbar"
    
    private init() {}
    
    // MARK: - Public API
    
    /// Generates a bug report and opens GitHub issue creation page in browser.
    func createBugReport() async {
        isGenerating = true
        lastError = nil
        
        do {
            let report = try await generateReport()
            let url = createGitHubIssueURL(report: report)
            
            await MainActor.run {
                NSWorkspace.shared.open(url)
                isGenerating = false
            }
        } catch {
            lastError = error.localizedDescription
            isGenerating = false
            Log.app.error("Failed to generate bug report: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Report Generation
    
    private func generateReport() async throws -> BugReport {
        let systemInfo = collectSystemInfo()
        let appInfo = collectAppInfo()
        let logs = try await collectRecentLogs()
        
        return BugReport(
            systemInfo: systemInfo,
            appInfo: appInfo,
            logs: logs
        )
    }
    
    private func collectSystemInfo() -> SystemInfo {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osVersionString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        
        return SystemInfo(
            osVersion: osVersionString,
            architecture: ProcessInfo.processInfo.machineHardwareName ?? "unknown",
            locale: Locale.current.identifier,
            preferredLanguages: Locale.preferredLanguages.prefix(3).joined(separator: ", ")
        )
    }
    
    private func collectAppInfo() -> AppInfo {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        
        let settings = SettingsManager.shared
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
    
    /// Collects recent logs from the unified logging system.
    /// Privacy-safe: filters out event/reminder titles and other sensitive data.
    private func collectRecentLogs() async throws -> String {
        // Collect logs from the last 5 minutes
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = [
            "show",
            "--predicate", "subsystem == 'dev.just-mn.calenbar'",
            "--start", ISO8601DateFormatter().string(from: fiveMinutesAgo),
            "--style", "syslog",
            "--info",
            "--debug"
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return "Failed to decode logs"
        }
        
        // Privacy filter: remove sensitive data
        return sanitizeLogs(output)
    }
    
    /// Removes sensitive information from logs.
    private func sanitizeLogs(_ logs: String) -> String {
        var sanitized = logs
        
        // Remove any event/reminder titles that might appear in logs
        // Pattern: title="..." or title: "..."
        sanitized = sanitized.replacingOccurrences(
            of: #"title[=:]\s*"[^"]*""#,
            with: "title=\"[REDACTED]\"",
            options: .regularExpression
        )
        
        // Remove calendar names
        sanitized = sanitized.replacingOccurrences(
            of: #"calendar[=:]\s*"[^"]*""#,
            with: "calendar=\"[REDACTED]\"",
            options: .regularExpression
        )
        
        // Limit to last 1000 lines to avoid huge issue body
        let lines = sanitized.split(separator: "\n")
        if lines.count > 1000 {
            let truncated = lines.suffix(1000)
            sanitized = truncated.joined(separator: "\n")
            sanitized = "... (truncated, showing last 1000 lines)\n\n" + sanitized
        }
        
        return sanitized
    }
    
    // MARK: - GitHub Issue URL
    
    private func createGitHubIssueURL(report: BugReport) -> URL {
        let title = "Bug Report: "
        let body = formatIssueBody(report: report)
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = "/\(githubUser)/\(githubRepo)/issues/new"
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "body", value: body),
            URLQueryItem(name: "labels", value: "bug")
        ]
        
        return components.url ?? URL(string: "https://github.com/\(githubUser)/\(githubRepo)/issues/new")!
    }
    
    private func formatIssueBody(report: BugReport) -> String {
        return """
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
        <summary>Recent Logs (last 5 minutes)</summary>
        
        ```
        \(report.logs)
        ```
        
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
        let result = uname(&sysinfo)
        guard result == EXIT_SUCCESS else { return nil }
        
        let data = Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN))
        guard let identifier = String(bytes: data, encoding: .ascii) else { return nil }
        return identifier.trimmingCharacters(in: .controlCharacters)
    }
}
