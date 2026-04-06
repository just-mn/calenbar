import SwiftUI
import EventKit

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var step = 0
    @State private var calGranted = false
    @State private var remGranted = false
    @State private var eventDismissed = false
    @State private var reminderActioned = false

    private let totalSteps = 9
    private let cm = CalendarManager.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: step)
                }
            }
            .padding(.top, 24)

            Spacer()

            Group {
                switch step {
                case 0: WelcomeStep()
                case 1: PermissionStep(
                    icon: "calendar",
                    title: Str.calendarPermTitle,
                    description: Str.calendarPermDesc,
                    granted: calGranted,
                    onRequest: {
                        Task {
                            let result = await cm.requestCalendarAccess()
                            await MainActor.run {
                                calGranted = result
                                // Re-activate the window after the system permission dialog dismisses
                                NSApp.activate(ignoringOtherApps: true)
                            }
                        }
                    }
                )
                case 2: PermissionStep(
                    icon: "checklist",
                    title: Str.reminderPermTitle,
                    description: Str.reminderPermDesc,
                    granted: remGranted,
                    onRequest: {
                        Task {
                            let result = await cm.requestReminderAccess()
                            await MainActor.run {
                                remGranted = result
                                // Re-activate the window after the system permission dialog dismisses
                                NSApp.activate(ignoringOtherApps: true)
                            }
                        }
                    }
                )
                case 3: CalendarPickerStep()
                case 4: AlertStyleStep()
                case 5: InProgressStep()
                case 6: DemoEventStep(dismissed: $eventDismissed)
                case 7: DemoReminderStep(actioned: $reminderActioned, remGranted: remGranted)
                case 8: AllDoneStep()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: .trailing),
                                    removal: .move(edge: .leading)).combined(with: .opacity))
            .id(step)

            Spacer()

            HStack {
                if step > 0 {
                    Button(Str.back) { withAnimation { step -= 1 } }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                let isDisabled = step == 1 && !calGranted
                Button(step == totalSteps - 1 ? Str.done : Str.next) {
                    if step == totalSteps - 1 {
                        onComplete()
                    } else {
                        withAnimation { step += 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.5 : 1.0)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 540, height: 480)
        .onAppear {
            cm.checkCurrentAccess()
            calGranted = cm.calendarAccessGranted
            remGranted = cm.reminderAccessGranted
        }
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            Text(Str.welcomeTitle)
                .font(.largeTitle).bold()
            Text(Str.onboardingSubtitle)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 380)
        }
        .padding()
    }
}

private struct PermissionStep: View {
    let icon: String
    let title: String
    let description: String
    let granted: Bool
    let onRequest: () -> Void
    
    @State private var isRequesting = false
    @State private var showDeniedMessage = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: granted ? "checkmark.circle.fill" : icon)
                .font(.system(size: 56))
                .foregroundColor(granted ? .green : .accentColor)
                .animation(.default, value: granted)
            Text(title).font(.title2).bold()
            Text(description)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 360)
            
            if granted {
                Label(Str.accessGranted, systemImage: "checkmark").foregroundColor(.green)
            } else {
                VStack(spacing: 12) {
                    Button(action: {
                        isRequesting = true
                        onRequest()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isRequesting = false
                            if !granted {
                                showDeniedMessage = true
                            }
                        }
                    }) {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                            }
                            Text(Str.allowAccess)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequesting)
                    
                    if showDeniedMessage {
                        VStack(spacing: 8) {
                            Text(Str.permissionManualHint)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)

                            Button(Str.openSystemSettings) {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                        .frame(maxWidth: 360)
                        .transition(.opacity)
                    }
                }
            }
        }
        .padding()
        .animation(.default, value: showDeniedMessage)
    }
}

private struct CalendarPickerStep: View {
    @ObservedObject private var settings = SettingsManager.shared
    private let calendars = CalendarManager.shared.allCalendars()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Str.pickCalendarsTitle).font(.title2).bold()
            Text(Str.pickCalendarsHint)
                .foregroundColor(.secondary).font(.caption)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(calendars, id: \.calendarIdentifier) { cal in
                        let id = cal.calendarIdentifier
                        let on = settings.selectedCalendarIDs.contains(id)
                        HStack {
                            Image(systemName: on ? "checkmark.square.fill" : "square")
                                .foregroundColor(on ? .accentColor : .secondary)
                            Circle().fill(Color(cgColor: cal.cgColor)).frame(width: 10, height: 10)
                            Text(cal.title)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if on { settings.selectedCalendarIDs.remove(id) }
                            else  { settings.selectedCalendarIDs.insert(id) }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 220)
        }
        .padding(.horizontal, 32)
    }
}

private struct AlertStyleStep: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 52))
                .foregroundColor(.accentColor)
            Text(Str.alertStyleTitle).font(.title2).bold()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Toggle(Str.soundToggleShort, isOn: $settings.soundEnabled).frame(width: 140)
                    if settings.soundEnabled {
                        Picker("", selection: $settings.soundName) {
                            ForEach(SettingsManager.availableSounds, id: \.self) { Text($0).tag($0) }
                        }
                        .frame(width: 110)
                        Button(Str.soundTest) { settings.playCurrentSound() }
                    }
                }

                Toggle(Str.flashEnabled, isOn: $settings.flashEnabled)

                if settings.flashEnabled {
                    HStack {
                        Text(Str.flashDuration).foregroundColor(.secondary)
                        Picker("", selection: $settings.flashDurationSeconds) {
                            ForEach(SettingsManager.flashDurationOptions, id: \.seconds) { opt in
                                Text(opt.label).tag(opt.seconds)
                            }
                        }
                        .labelsHidden().frame(width: 140)
                    }

                    HStack {
                        Text(Str.flashSpeed).foregroundColor(.secondary)
                        Slider(value: $settings.flashInterval, in: 0.15...1.0, step: 0.05)
                            .frame(width: 160)
                        Text(Str.flashSpeedLabel(settings.flashInterval))
                            .foregroundColor(.secondary).frame(width: 65, alignment: .leading)
                    }

                    Text(Str.alertColorsNote)
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: 380)
        }
        .padding()
    }
}

private struct InProgressStep: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 52))
                .foregroundColor(.accentColor)

            Text(Str.inProgressTitle).font(.title2).bold()

            Text(Str.inProgressDesc)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 380)

            Toggle(Str.inProgressToggle, isOn: $settings.showEventsWithoutAlarms)
                .frame(maxWidth: 380)
        }
        .padding()
    }
}

// MARK: - Demo: event

private struct DemoEventStep: View {
    @Binding var dismissed: Bool
    @ObservedObject private var alertState = AlertStateManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: dismissed ? "checkmark.circle.fill" : "cursorarrow.click.2")
                .font(.system(size: 52))
                .foregroundColor(dismissed ? .green : .accentColor)
                .animation(.default, value: dismissed)

            Text(Str.demoEventTitle).font(.title2).bold()

            if dismissed {
                Text(Str.demoEventDone)
                    .foregroundColor(.green).bold()
            } else {
                Text(Str.demoEventDesc)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 380)

                Text(Str.demoEventHint)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 360)
            }
        }
        .padding()
        .onAppear {
            if !dismissed {
                TestModeManager.shared.isEnabled = true
                TestModeManager.shared.applyScenario(.upcomingAlert)
            }
        }
        .onChange(of: alertState.activeEventAlerts.count) { oldCount, newCount in
            if oldCount > 0 && newCount == 0 {
                withAnimation { dismissed = true }
            }
        }
    }
}

// MARK: - Demo: reminder

private struct DemoReminderStep: View {
    @Binding var actioned: Bool
    let remGranted: Bool
    @ObservedObject private var alertState = AlertStateManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: actioned ? "checkmark.circle.fill" : "bell.badge.fill")
                .font(.system(size: 52))
                .foregroundColor(actioned ? .green : .accentColor)
                .animation(.default, value: actioned)

            Text(Str.demoReminderTitle).font(.title2).bold()

            if !remGranted {
                Text(Str.demoReminderSkip)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            } else if actioned {
                Text(Str.demoReminderDone)
                    .foregroundColor(.green).bold()
            } else {
                Text(Str.demoReminderDesc)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 380)

                Text(Str.demoReminderHint)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 360)
            }
        }
        .padding()
        .onAppear {
            if remGranted && !actioned {
                alertState.activeEventAlerts = []
                alertState.currentEvents = []
                TestModeManager.shared.applyScenario(.singleReminder)
            }
        }
        .onChange(of: alertState.activeReminders.count) { oldCount, newCount in
            if oldCount > 0 && newCount == 0 {
                withAnimation { actioned = true }
            }
        }
    }
}

// MARK: - All done

private struct AllDoneStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text(Str.allDoneTitle).font(.largeTitle).bold()

            Text(Str.allDoneDesc)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 380)
        }
        .padding()
    }
}
