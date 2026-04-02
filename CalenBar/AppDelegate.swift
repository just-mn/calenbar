import AppKit
import SwiftUI
import os

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private var baseStatusItem: BaseStatusItem?
    private var eventController: EventStatusController?
    private var reminderController: ReminderStatusController?
    private var pollTimer: Timer?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("App launched")
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)
        baseStatusItem = BaseStatusItem()

        Task {
            let cm = CalendarManager.shared
            let calOk = await cm.requestCalendarAccess()
            let remOk = await cm.requestReminderAccess()
            Log.app.info("Permissions — calendars: \(calOk), reminders: \(remOk)")

            startMonitoring()
            if !SettingsManager.shared.hasCompletedOnboarding {
                Log.app.info("Showing onboarding (first launch)")
                showOnboarding()
            }
        }
    }

    // MARK: - Monitoring

    func startMonitoring() {
        Log.app.info("Starting monitoring — 30s poll interval")
        eventController = EventStatusController()
        reminderController = ReminderStatusController()

        Task {
            await AlertStateManager.shared.tick()
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                await AlertStateManager.shared.tick()
            }
        }
    }

    // MARK: - Settings window

    @objc func showSettings() {
        Log.app.debug("Opening settings window")
        if let w = settingsWindow, w.isVisible {
            bringWindowToFront(w)
            return
        }
        let view = SettingsView()
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = Str.settingsTitle
        window.setContentSize(NSSize(width: 480, height: 520))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        settingsWindow = window
        bringWindowToFront(window)
    }

    // MARK: - Onboarding

    func showOnboarding() {
        let view = OnboardingView {
            SettingsManager.shared.hasCompletedOnboarding = true
            TestModeManager.shared.clearState()
            Task { @MainActor in
                self.onboardingWindow?.close()
                self.onboardingWindow = nil
                NSApp.setActivationPolicy(.accessory)
            }
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = Str.welcomeTitle
        window.setContentSize(NSSize(width: 520, height: 460))
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        onboardingWindow = window
        bringWindowToFront(window)
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        let w = notification.object as? NSWindow
        guard w === settingsWindow || w === onboardingWindow else { return }
        
        // Switch back to accessory only when no other managed windows remain visible
        Task { @MainActor in
            let hasVisibleWindows = NSApp.windows.contains { window in
                window.isVisible &&
                window != w &&
                (window === self.settingsWindow || window === self.onboardingWindow)
            }
            if !hasVisibleWindows {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

// MARK: - Private helpers

private extension AppDelegate {
    func bringWindowToFront(_ window: NSWindow) {
        // Activation policy must be set before makeKeyAndOrderFront to ensure the window appears in front
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
