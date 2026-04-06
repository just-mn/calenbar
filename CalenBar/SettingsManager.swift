import Combine
import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import os

enum DisplayMode: String, CaseIterable {
    case automatic   = "automatic"
    case informative = "informative"
    case compact     = "compact"

    var displayName: String {
        switch self {
        case .automatic:   return Str.modeAutomatic
        case .informative: return Str.modeInformative
        case .compact:     return Str.modeCompact
        }
    }

    var note: String {
        switch self {
        case .automatic:   return Str.displayAutoNote
        case .informative: return Str.displayInfoNote
        case .compact:     return Str.displayCompactNote
        }
    }
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Key {
        static let soundEnabled         = "soundEnabled"
        static let soundName            = "soundName"
        static let flashEnabled         = "flashEnabled"
        static let flashInterval        = "flashInterval"
        static let flashDurationSeconds = "flashDurationSeconds"
        static let displayMode          = "displayMode"

        // Upcoming alert color profile
        static let upcomingPreset       = "upcomingPreset"
        static let upcomingCustTextR    = "upcomingCustTextR"
        static let upcomingCustTextG    = "upcomingCustTextG"
        static let upcomingCustTextB    = "upcomingCustTextB"
        static let upcomingCustBgR      = "upcomingCustBgR"
        static let upcomingCustBgG      = "upcomingCustBgG"
        static let upcomingCustBgB      = "upcomingCustBgB"

        // Overdue / reminder color profile
        static let overduePreset        = "overduePreset"
        static let overdueCustTextR     = "overdueCustTextR"
        static let overdueCustTextG     = "overdueCustTextG"
        static let overdueCustTextB     = "overdueCustTextB"
        static let overdueCustBgR       = "overdueCustBgR"
        static let overdueCustBgG       = "overdueCustBgG"
        static let overdueCustBgB       = "overdueCustBgB"

        static let selectedCalendarIDs       = "selectedCalendarIDs"
        static let selectedReminderListIDs   = "selectedReminderListIDs"
        static let snoozeDurations           = "snoozeDurations"
        static let showEventsWithoutAlarms   = "showEventsWithoutAlarms"
        static let hasCompletedOnboarding    = "hasCompletedOnboarding"
        static let useCustomSound            = "useCustomSound"
        static let customSoundName           = "customSoundName"
    }

    // MARK: - Published

    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) }
    }
    @Published var soundName: String {
        didSet { defaults.set(soundName, forKey: Key.soundName) }
    }
    @Published var flashEnabled: Bool {
        didSet { defaults.set(flashEnabled, forKey: Key.flashEnabled) }
    }
    @Published var flashInterval: Double {
        didSet { defaults.set(flashInterval, forKey: Key.flashInterval) }
    }
    /// 0 = flash until dismissed; positive = flash for N seconds then stop.
    @Published var flashDurationSeconds: Int {
        didSet { defaults.set(flashDurationSeconds, forKey: Key.flashDurationSeconds) }
    }
    @Published var displayMode: DisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: Key.displayMode) }
    }

    // Upcoming alert profile
    @Published var upcomingPreset: AlertColorProfile.Preset {
        didSet { defaults.set(upcomingPreset.rawValue, forKey: Key.upcomingPreset) }
    }
    @Published var upcomingCustTextR: Double { didSet { defaults.set(upcomingCustTextR, forKey: Key.upcomingCustTextR) } }
    @Published var upcomingCustTextG: Double { didSet { defaults.set(upcomingCustTextG, forKey: Key.upcomingCustTextG) } }
    @Published var upcomingCustTextB: Double { didSet { defaults.set(upcomingCustTextB, forKey: Key.upcomingCustTextB) } }
    @Published var upcomingCustBgR:   Double { didSet { defaults.set(upcomingCustBgR,   forKey: Key.upcomingCustBgR)   } }
    @Published var upcomingCustBgG:   Double { didSet { defaults.set(upcomingCustBgG,   forKey: Key.upcomingCustBgG)   } }
    @Published var upcomingCustBgB:   Double { didSet { defaults.set(upcomingCustBgB,   forKey: Key.upcomingCustBgB)   } }

    // Overdue / reminder profile
    @Published var overduePreset: AlertColorProfile.Preset {
        didSet { defaults.set(overduePreset.rawValue, forKey: Key.overduePreset) }
    }
    @Published var overdueCustTextR: Double { didSet { defaults.set(overdueCustTextR, forKey: Key.overdueCustTextR) } }
    @Published var overdueCustTextG: Double { didSet { defaults.set(overdueCustTextG, forKey: Key.overdueCustTextG) } }
    @Published var overdueCustTextB: Double { didSet { defaults.set(overdueCustTextB, forKey: Key.overdueCustTextB) } }
    @Published var overdueCustBgR:   Double { didSet { defaults.set(overdueCustBgR,   forKey: Key.overdueCustBgR)   } }
    @Published var overdueCustBgG:   Double { didSet { defaults.set(overdueCustBgG,   forKey: Key.overdueCustBgG)   } }
    @Published var overdueCustBgB:   Double { didSet { defaults.set(overdueCustBgB,   forKey: Key.overdueCustBgB)   } }

    @Published var selectedCalendarIDs: Set<String> {
        didSet { defaults.set(Array(selectedCalendarIDs), forKey: Key.selectedCalendarIDs) }
    }
    @Published var selectedReminderListIDs: Set<String> {
        didSet { defaults.set(Array(selectedReminderListIDs), forKey: Key.selectedReminderListIDs) }
    }
    @Published var snoozeDurations: [Int] {
        didSet { defaults.set(snoozeDurations, forKey: Key.snoozeDurations) }
    }
    @Published var showEventsWithoutAlarms: Bool {
        didSet { defaults.set(showEventsWithoutAlarms, forKey: Key.showEventsWithoutAlarms) }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }
    @Published var useCustomSound: Bool {
        didSet { defaults.set(useCustomSound, forKey: Key.useCustomSound) }
    }
    @Published var customSoundName: String {
        didSet { defaults.set(customSoundName, forKey: Key.customSoundName) }
    }

    // MARK: - Init

    private init() {
        soundEnabled    = defaults.object(forKey: Key.soundEnabled)    as? Bool   ?? true
        soundName       = defaults.string(forKey: Key.soundName)                   ?? "Glass"
        flashEnabled    = defaults.object(forKey: Key.flashEnabled)    as? Bool   ?? true
        flashInterval   = defaults.object(forKey: Key.flashInterval)   as? Double ?? 0.4
        flashDurationSeconds = defaults.object(forKey: Key.flashDurationSeconds) as? Int ?? 0
        displayMode = DisplayMode(rawValue: defaults.string(forKey: Key.displayMode) ?? "") ?? .automatic

        upcomingPreset = AlertColorProfile.Preset(rawValue: defaults.string(forKey: Key.upcomingPreset) ?? "") ?? .orange
        upcomingCustTextR = defaults.object(forKey: Key.upcomingCustTextR) as? Double ?? 1.0
        upcomingCustTextG = defaults.object(forKey: Key.upcomingCustTextG) as? Double ?? 0.5
        upcomingCustTextB = defaults.object(forKey: Key.upcomingCustTextB) as? Double ?? 0.0
        upcomingCustBgR   = defaults.object(forKey: Key.upcomingCustBgR)   as? Double ?? 1.0
        upcomingCustBgG   = defaults.object(forKey: Key.upcomingCustBgG)   as? Double ?? 0.5
        upcomingCustBgB   = defaults.object(forKey: Key.upcomingCustBgB)   as? Double ?? 0.0

        overduePreset = AlertColorProfile.Preset(rawValue: defaults.string(forKey: Key.overduePreset) ?? "") ?? .red
        overdueCustTextR = defaults.object(forKey: Key.overdueCustTextR) as? Double ?? 1.0
        overdueCustTextG = defaults.object(forKey: Key.overdueCustTextG) as? Double ?? 0.2
        overdueCustTextB = defaults.object(forKey: Key.overdueCustTextB) as? Double ?? 0.2
        overdueCustBgR   = defaults.object(forKey: Key.overdueCustBgR)   as? Double ?? 1.0
        overdueCustBgG   = defaults.object(forKey: Key.overdueCustBgG)   as? Double ?? 0.2
        overdueCustBgB   = defaults.object(forKey: Key.overdueCustBgB)   as? Double ?? 0.2

        selectedCalendarIDs    = Set(defaults.array(forKey: Key.selectedCalendarIDs)    as? [String] ?? [])
        selectedReminderListIDs = Set(defaults.array(forKey: Key.selectedReminderListIDs) as? [String] ?? [])
        snoozeDurations = defaults.array(forKey: Key.snoozeDurations)  as? [Int]  ?? [5, 15, 30, 60]
        showEventsWithoutAlarms = defaults.object(forKey: Key.showEventsWithoutAlarms) as? Bool ?? false
        hasCompletedOnboarding  = defaults.bool(forKey: Key.hasCompletedOnboarding)
        useCustomSound  = defaults.bool(forKey: Key.useCustomSound)
        customSoundName = defaults.string(forKey: Key.customSoundName) ?? ""
    }

    // MARK: - Computed color profiles

    var upcomingProfile: AlertColorProfile {
        AlertColorProfile(
            preset: upcomingPreset,
            customTextR: upcomingCustTextR, customTextG: upcomingCustTextG, customTextB: upcomingCustTextB,
            customBgR:   upcomingCustBgR,   customBgG:   upcomingCustBgG,   customBgB:   upcomingCustBgB
        )
    }

    var overdueProfile: AlertColorProfile {
        AlertColorProfile(
            preset: overduePreset,
            customTextR: overdueCustTextR, customTextG: overdueCustTextG, customTextB: overdueCustTextB,
            customBgR:   overdueCustBgR,   customBgG:   overdueCustBgG,   customBgB:   overdueCustBgB
        )
    }

    // MARK: - Sound

    static let availableSounds = ["Glass", "Ping", "Pop", "Tink", "Basso", "Funk"]

    func playCurrentSound() {
        guard soundEnabled else { return }
        if useCustomSound, let url = customSoundURL() {
            NSSound(contentsOf: url, byReference: false)?.play()
        } else {
            NSSound(named: NSSound.Name(soundName))?.play()
        }
    }

    func setCustomSound(url: URL) {
        let dir = customSoundDirectory
        // Remove previous custom sound
        if let old = customSoundURL() { try? FileManager.default.removeItem(at: old) }
        let dest = dir.appendingPathComponent("custom-sound.\(url.pathExtension)")
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            customSoundName = url.deletingPathExtension().lastPathComponent
            useCustomSound = true
            Log.settings.info("Custom sound set: \(self.customSoundName)")
        } catch {
            Log.settings.error("Failed to copy custom sound: \(error.localizedDescription)")
        }
    }

    func clearCustomSound() {
        if let url = customSoundURL() { try? FileManager.default.removeItem(at: url) }
        customSoundName = ""
        useCustomSound = false
    }

    func customSoundURL() -> URL? {
        let dir = customSoundDirectory
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.first { $0.lastPathComponent.hasPrefix("custom-sound") }
    }

    private var customSoundDirectory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CalenBar")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func pickCustomSound() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setCustomSound(url: url)
    }

    // MARK: - Flash duration options

    static var flashDurationOptions: [(label: String, seconds: Int)] {
        [(Str.flashForever, 0), (Str.flash30sec, 30), (Str.flash1min, 60),
         (Str.flash2min, 120), (Str.flash5min, 300)]
    }

    // MARK: - Snooze labels

    func snoozeLabel(minutes: Int) -> String { Str.snoozeLabel(minutes: minutes) }
}
