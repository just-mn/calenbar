import SwiftUI
import EventKit
import ServiceManagement

struct SettingsView: View {
    @State private var selectedTab = "general"

    var body: some View {
        TabView(selection: $selectedTab) {
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
                        Text(flashSpeedLabel(settings.flashInterval))
                            .foregroundColor(.secondary).frame(width: 65, alignment: .leading)
                    }

                    FlashPreviewStrip()
                }
            }

            Section(Str.sectionSound) {
                Toggle(Str.soundEnabled, isOn: $settings.soundEnabled)
                if settings.soundEnabled {
                    HStack {
                        Picker(Str.soundLabel, selection: $settings.soundName) {
                            ForEach(SettingsManager.availableSounds, id: \.self) { Text($0).tag($0) }
                        }
                        Button(Str.soundTest) { settings.playCurrentSound() }
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

    private func flashSpeedLabel(_ v: Double) -> String {
        switch v {
        case ..<0.25: return Str.flashSpeedFast
        case ..<0.55: return Str.flashSpeedMedium
        default:      return Str.flashSpeedSlow
        }
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

                switch settings.displayMode {
                case .automatic:
                    Text(Str.displayAutoNote)
                        .font(.caption).foregroundColor(.secondary)
                case .informative:
                    Text(Str.displayInfoNote)
                        .font(.caption).foregroundColor(.secondary)
                case .compact:
                    Text(Str.displayCompactNote)
                        .font(.caption).foregroundColor(.secondary)
                }
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
        VStack(alignment: .leading, spacing: 8) {
            Text(Str.calendarsTrack)
                .font(.headline)
            Text(Str.calendarsHint)
                .foregroundColor(.secondary).font(.caption)

            if calendars.isEmpty {
                emptyView(message: Str.noCalendarsMsg)
            } else {
                calendarList
            }
        }
        .padding()
        .onAppear { calendars = CalendarManager.shared.allCalendars() }
    }

    private var calendarList: some View {
        List(calendars, id: \.calendarIdentifier) { cal in
            let id = cal.calendarIdentifier
            let on = settings.selectedCalendarIDs.contains(id)
            HStack {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .foregroundColor(on ? .accentColor : .secondary)
                Circle().fill(Color(cgColor: cal.cgColor)).frame(width: 10, height: 10)
                Text(cal.title)
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if on { settings.selectedCalendarIDs.remove(id) }
                else  { settings.selectedCalendarIDs.insert(id) }
            }
        }
    }
}

// MARK: - Reminders tab

private struct RemindersTab: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var lists: [EKCalendar] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Str.remindersTrack)
                .font(.headline)
            Text(Str.remindersHint)
                .foregroundColor(.secondary).font(.caption)

            if lists.isEmpty {
                emptyView(message: Str.noRemindersMsg)
            } else {
                List(lists, id: \.calendarIdentifier) { list in
                    let id = list.calendarIdentifier
                    let on = settings.selectedReminderListIDs.contains(id)
                    HStack {
                        Image(systemName: on ? "checkmark.square.fill" : "square")
                            .foregroundColor(on ? .accentColor : .secondary)
                        Circle().fill(Color(cgColor: list.cgColor)).frame(width: 10, height: 10)
                        Text(list.title)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if on { settings.selectedReminderListIDs.remove(id) }
                        else  { settings.selectedReminderListIDs.insert(id) }
                    }
                }
            }
        }
        .padding()
        .onAppear { lists = CalendarManager.shared.allReminderLists() }
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

// MARK: - Helpers

private func emptyView(message: String) -> some View {
    Text(message)
        .foregroundColor(.secondary).font(.caption)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
}
