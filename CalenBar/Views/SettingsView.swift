import SwiftUI
import Combine
import EventKit
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - Shared tab navigation

@MainActor
class SettingsNavigation: ObservableObject {
    static let shared = SettingsNavigation()
    @Published var selectedTab = "general"
}

struct SettingsView: View {
    @ObservedObject private var nav = SettingsNavigation.shared

    var body: some View {
        TabView(selection: $nav.selectedTab) {
            GeneralTab()
                .tabItem { Label(Str.tabGeneral, systemImage: "gear") }
                .tag("general")

            AppearanceTab()
                .tabItem { Label(Str.tabAppearance, systemImage: "paintpalette") }
                .tag("appearance")

            CalendarsTab()
                .tabItem { Label(Str.tabCalendars, systemImage: "calendar") }
                .tag("calendars")

            RemindersTab()
                .tabItem { Label(Str.tabReminders, systemImage: "checklist") }
                .tag("reminders")

            SnoozeTab()
                .tabItem { Label(Str.tabSnooze, systemImage: "clock.arrow.circlepath") }
                .tag("snooze")

            AboutTab()
                .tabItem { Label(Str.tabAbout, systemImage: "info.circle") }
                .tag("about")
        }
        .padding(20)
        .frame(width: 500, height: 500)
    }
}

// MARK: - General tab

private struct GeneralTab: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section(Str.sectionFlash) {
                Toggle(Str.flashEnabled, isOn: $settings.flashEnabled)

                if settings.flashEnabled {
                    HStack {
                        Text(Str.flashDuration)
                        Picker("", selection: $settings.flashDurationSeconds) {
                            ForEach(SettingsManager.flashDurationOptions, id: \.seconds) { opt in
                                Text(opt.label).tag(opt.seconds)
                            }
                        }
                        .labelsHidden().frame(width: 140)
                    }

                    HStack(spacing: 10) {
                        Text(Str.flashSpeed)
                        Slider(value: $settings.flashInterval, in: 0.15...1.0, step: 0.05)
                        Text(Str.flashSpeedLabel(settings.flashInterval))
                            .foregroundColor(.secondary).frame(width: 65, alignment: .leading)
                    }

                    FlashPreviewStrip()
                }
            }

            Section(Str.sectionSound) {
                Toggle(Str.soundEnabled, isOn: $settings.soundEnabled)
                if settings.soundEnabled {
                    if !settings.useCustomSound {
                        HStack {
                            Picker(Str.soundLabel, selection: $settings.soundName) {
                                ForEach(SettingsManager.availableSounds, id: \.self) { Text($0).tag($0) }
                            }
                            Button(Str.soundTest) { settings.playCurrentSound() }
                        }
                    }

                    Toggle(Str.customSound, isOn: $settings.useCustomSound)
                    if settings.useCustomSound {
                        HStack {
                            Image(systemName: "music.note").foregroundColor(.accentColor)
                            Text(settings.customSoundName.isEmpty ? Str.noFileSelected : settings.customSoundName)
                                .foregroundColor(.secondary).lineLimit(1)
                            Spacer()
                            Button(Str.chooseFile) { settings.pickCustomSound() }
                            if !settings.customSoundName.isEmpty {
                                Button(Str.soundTest) { settings.playCurrentSound() }
                            }
                        }
                    }
                }
            }

            Section(Str.sectionEvents) {
                Toggle(Str.showNoAlarmEvents,
                       isOn: $settings.showEventsWithoutAlarms)
            }

            Section(Str.sectionLaunch) {
                LaunchAtLoginToggle()
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Appearance tab

private struct AppearanceTab: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section(Str.displayModeSection) {
                Picker("", selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                Text(settings.displayMode.note)
                    .font(.caption).foregroundColor(.secondary)
            }

            Section(Str.colorUpcoming) {
                ColorProfileEditor(
                    preset: $settings.upcomingPreset,
                    custTextR: $settings.upcomingCustTextR,
                    custTextG: $settings.upcomingCustTextG,
                    custTextB: $settings.upcomingCustTextB,
                    custBgR:   $settings.upcomingCustBgR,
                    custBgG:   $settings.upcomingCustBgG,
                    custBgB:   $settings.upcomingCustBgB
                )
            }

            Section(Str.colorOverdue) {
                ColorProfileEditor(
                    preset: $settings.overduePreset,
                    custTextR: $settings.overdueCustTextR,
                    custTextG: $settings.overdueCustTextG,
                    custTextB: $settings.overdueCustTextB,
                    custBgR:   $settings.overdueCustBgR,
                    custBgG:   $settings.overdueCustBgG,
                    custBgB:   $settings.overdueCustBgB
                )
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Color profile editor component

private struct ColorProfileEditor: View {
    @Binding var preset: AlertColorProfile.Preset

    @Binding var custTextR: Double
    @Binding var custTextG: Double
    @Binding var custTextB: Double
    @Binding var custBgR:   Double
    @Binding var custBgG:   Double
    @Binding var custBgB:   Double

    private var custTextColor: Binding<Color> {
        Binding(
            get: { Color(red: custTextR, green: custTextG, blue: custTextB) },
            set: { c in
                let ns = NSColor(c).usingColorSpace(.sRGB) ?? NSColor(c)
                custTextR = ns.redComponent; custTextG = ns.greenComponent; custTextB = ns.blueComponent
            }
        )
    }

    private var custBgColor: Binding<Color> {
        Binding(
            get: { Color(red: custBgR, green: custBgG, blue: custBgB) },
            set: { c in
                let ns = NSColor(c).usingColorSpace(.sRGB) ?? NSColor(c)
                custBgR = ns.redComponent; custBgG = ns.greenComponent; custBgB = ns.blueComponent
            }
        )
    }

    var body: some View {
        // Preset swatches
        HStack(spacing: 8) {
            ForEach(AlertColorProfile.Preset.allCases.filter { $0 != .custom }, id: \.self) { p in
                Circle()
                    .fill(Color(nsColor: p.baseColor))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle().stroke(Color.primary, lineWidth: preset == p ? 2.5 : 0).padding(2)
                    )
                    .onTapGesture { preset = p }
            }

            // Custom button
            ZStack {
                Circle()
                    .fill(AngularGradient(
                        colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                        center: .center
                    ))
                    .frame(width: 22, height: 22)
                if preset == .custom {
                    Circle().stroke(Color.primary, lineWidth: 2.5).padding(2).frame(width: 22, height: 22)
                }
            }
            .onTapGesture { preset = .custom }

            Text(preset.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        // Custom color pickers
        if preset == .custom {
            HStack(spacing: 16) {
                HStack {
                    Text(Str.colorText).font(.caption).foregroundColor(.secondary)
                    ColorPicker("", selection: custTextColor).labelsHidden().frame(width: 36)
                }
                HStack {
                    Text(Str.colorBg).font(.caption).foregroundColor(.secondary)
                    ColorPicker("", selection: custBgColor).labelsHidden().frame(width: 36)
                }
                // Live swatch
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.exclamationmark").imageScale(.small)
                    Text(Str.colorExample)
                }
                .font(.system(size: 12))
                .foregroundColor(custTextColor.wrappedValue)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(custBgColor.wrappedValue.opacity(0.15)))
            }
        } else {
            // Preset swatch preview
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.exclamationmark").imageScale(.small)
                Text(Str.colorExample)
            }
            .font(.system(size: 12))
            .foregroundColor(Color(nsColor: preset.baseColor))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: preset.baseColor).opacity(0.15)))
        }
    }
}

// MARK: - Flash preview strip

private struct FlashPreviewStrip: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var isOn = false
    @State private var displayedSeconds = 754
    @State private var flashPhase: Timer?
    @State private var tickPhase:  Timer?

    private var profile: AlertColorProfile { settings.upcomingProfile }

    var body: some View {
        HStack(spacing: 6) {
            Text(Str.previewLabel).foregroundColor(.secondary)
            HStack(spacing: 0) {
                Image(systemName: isOn ? "calendar.badge.exclamationmark" : "calendar")
                    .imageScale(.small)
                Text(" \(Str.exampleEventName) · ")
                Text(formatSec(displayedSeconds))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeInOut(duration: 0.12), value: displayedSeconds)
            }
            .font(.system(size: 13))
            .foregroundStyle(isOn ? profile.textSwiftUIColor : Color(nsColor: .labelColor))
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isOn ? profile.bgSwiftUIColor.opacity(0.15) : Color.clear)
            )
            .animation(.easeInOut(duration: 0.1), value: isOn)
        }
        .onAppear { startTimers() }
        .onDisappear { stopTimers() }
        .onChange(of: settings.flashInterval)  { _, _ in startTimers() }
        .onChange(of: settings.upcomingPreset) { _, _ in }  // triggers redraw via profile
    }

    private func formatSec(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }

    private func startTimers() {
        stopTimers()
        flashPhase = Timer.scheduledTimer(withTimeInterval: settings.flashInterval, repeats: true) { _ in
            isOn.toggle()
        }
        tickPhase = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if displayedSeconds > 0 { displayedSeconds -= 1 }
        }
    }

    private func stopTimers() {
        flashPhase?.invalidate(); flashPhase = nil
        tickPhase?.invalidate();  tickPhase  = nil
    }
}

// MARK: - Launch at login

private struct LaunchAtLoginToggle: View {
    @State private var isEnabled = false

    var body: some View {
        Toggle(Str.launchAtLogin, isOn: $isEnabled)
            .onChange(of: isEnabled) { _, newValue in
                do {
                    if newValue { try SMAppService.mainApp.register() }
                    else        { try SMAppService.mainApp.unregister() }
                } catch { /* requires proper bundle ID */ }
            }
            .onAppear {
                isEnabled = SMAppService.mainApp.status == .enabled
            }
    }
}

// MARK: - Calendars tab

private struct CalendarsTab: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var calendars: [EKCalendar] = []

    var body: some View {
        CalendarListPicker(
            title: Str.calendarsTrack,
            hint: Str.calendarsHint,
            emptyMessage: Str.noCalendarsMsg,
            items: calendars,
            selection: $settings.selectedCalendarIDs
        )
        .onAppear { calendars = CalendarManager.shared.allCalendars() }
    }
}

// MARK: - Reminders tab

private struct RemindersTab: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var lists: [EKCalendar] = []

    var body: some View {
        CalendarListPicker(
            title: Str.remindersTrack,
            hint: Str.remindersHint,
            emptyMessage: Str.noRemindersMsg,
            items: lists,
            selection: $settings.selectedReminderListIDs
        )
        .onAppear { lists = CalendarManager.shared.allReminderLists() }
    }
}

// MARK: - Shared calendar/reminder list picker

private struct CalendarListPicker: View {
    let title: String
    let hint: String
    let emptyMessage: String
    let items: [EKCalendar]
    @Binding var selection: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(hint).foregroundColor(.secondary).font(.caption)

            if items.isEmpty {
                emptyView(message: emptyMessage)
            } else {
                List(items, id: \.calendarIdentifier) { item in
                    let id = item.calendarIdentifier
                    let on = selection.contains(id)
                    HStack {
                        Image(systemName: on ? "checkmark.square.fill" : "square")
                            .foregroundColor(on ? .accentColor : .secondary)
                        Circle().fill(Color(cgColor: item.cgColor)).frame(width: 10, height: 10)
                        Text(item.title)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if on { selection.remove(id) }
                        else  { selection.insert(id) }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Snooze tab

private struct SnoozeTab: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var newMinutes = ""
    @State private var errorMsg   = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Str.snoozeSectionTitle).font(.headline)
            Text(Str.snoozeHint)
                .foregroundColor(.secondary).font(.caption)

            List {
                ForEach(settings.snoozeDurations.indices, id: \.self) { i in
                    HStack {
                        Text(settings.snoozeLabel(minutes: settings.snoozeDurations[i]))
                        Spacer()
                        Text(Str.durationMinutes(settings.snoozeDurations[i]))
                            .foregroundColor(.secondary).font(.caption)
                        Button {
                            settings.snoozeDurations.remove(at: i)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 200)

            HStack {
                TextField(Str.snoozeAddPlaceholder, text: $newMinutes)
                    .frame(width: 80).textFieldStyle(.roundedBorder)
                Button(Str.snoozeAdd) {
                    guard let mins = Int(newMinutes), mins > 0 else {
                        errorMsg = Str.snoozeErrorNotNum; return
                    }
                    if !settings.snoozeDurations.contains(mins) {
                        settings.snoozeDurations.append(mins)
                        settings.snoozeDurations.sort()
                    }
                    newMinutes = ""; errorMsg = ""
                }
                if !errorMsg.isEmpty {
                    Text(errorMsg).foregroundColor(.red).font(.caption)
                }
            }
        }
        .padding()
    }
}

// MARK: - About Tab

private struct AboutTab: View {
    @ObservedObject private var bugReportManager = BugReportManager.shared
    @State private var showBugReportSheet = false

    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 16) {
            // App Icon & Title
            VStack(spacing: 8) {
                if let icon = NSImage(named: "AppIcon") {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .cornerRadius(14)
                }

                Text("CalenBar")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("v\(version) (\(build))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: openWebsite) {
                    Text("by just-mn")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .underline()
            }

            // Description
            Text(Str.aboutDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer()

            // Buttons
            VStack(spacing: 10) {
                Button(action: { showBugReportSheet = true }) {
                    Label(Str.reportBug, systemImage: "ladybug")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                HStack(spacing: 12) {
                    Button(action: openWebsite) {
                        Label(Str.visitWebsite, systemImage: "globe")
                            .frame(maxWidth: .infinity)
                    }
                    Button(action: openGitHub) {
                        Label(Str.viewOnGitHub, systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showBugReportSheet) {
            BugReportSheet(isPresented: $showBugReportSheet)
        }
    }

    private func openWebsite() {
        if let url = URL(string: "https://just-mn.dev") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openGitHub() {
        if let url = URL(string: "https://github.com/just-mn/calenbar") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Bug Report Sheet

private struct BugReportSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var manager = BugReportManager.shared
    @State private var logStartDate = Date().addingTimeInterval(-5 * 60)
    @State private var logEndDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            if manager.logFileURL != nil {
                successView
            } else {
                prepareView
            }
        }
        .frame(width: 450, height: 300)
        .onDisappear { manager.reset() }
    }

    // MARK: Initial / generating state

    private var prepareView: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "ladybug.fill").font(.title).foregroundColor(.red)
                Text(Str.bugReportTitle).font(.title2).fontWeight(.semibold)
            }
            .padding(.top, 20)

            Text(Str.bugReportDesc)
                .font(.body).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                DatePicker(Str.logsFrom, selection: $logStartDate)
                    .datePickerStyle(.field)
                DatePicker(Str.logsTo, selection: $logEndDate)
                    .datePickerStyle(.field)
            }
            .padding(.horizontal, 40)

            Spacer()

            if manager.isGenerating {
                VStack(spacing: 10) {
                    ProgressView().scaleEffect(1.2)
                    Text(Str.generating).foregroundColor(.secondary)
                }
            } else if let error = manager.lastError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle).foregroundColor(.orange)
                    Text(Str.bugReportError).font(.headline)
                    Text(error).font(.caption).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button(Str.cancel) { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .disabled(manager.isGenerating)

                Button(Str.generate) {
                    Task { await manager.createBugReport(from: logStartDate, to: logEndDate) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(manager.isGenerating)
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: Success state

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48)).foregroundColor(.green)
                .padding(.top, 24)

            Text(Str.bugReportReady).font(.title3).fontWeight(.semibold)

            Text(Str.bugReportReadyDesc)
                .font(.body).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 8) {
                Button(action: { manager.revealLogFile() }) {
                    Label(Str.revealLogFile, systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                Button(action: {
                    manager.openGitHubIssue()
                    isPresented = false
                }) {
                    Label(Str.openGitHubIssue, systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)

            Button(Str.close) { isPresented = false }
                .buttonStyle(.plain).foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
    }
}

// MARK: - Helpers

private func emptyView(message: String) -> some View {
    Text(message)
        .foregroundColor(.secondary).font(.caption)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
}
