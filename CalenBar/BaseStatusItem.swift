import AppKit
import Combine

/// Permanent menu bar icon providing Settings and Quit.
/// Hides automatically when event or reminder icons are active.
@MainActor
class BaseStatusItem {
    private var statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "calendar", accessibilityDescription: "CalenBar")
            img?.isTemplate = true
            button.image = img
        }
        buildMenu()
        observeAlertState()
    }

    private func buildMenu() {
        let menu = NSMenu()
        let settings = NSMenuItem(title: Str.settingsMenuItem, action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: Str.quit, action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func observeAlertState() {
        AlertStateManager.shared.$activeEventAlerts
            .combineLatest(AlertStateManager.shared.$activeReminders)
            .combineLatest(AlertStateManager.shared.$currentEvents)
            .receive(on: RunLoop.main)
            .sink { [weak self] combined, current in
                let (alerts, reminders) = combined
                // Hide the base icon while event or reminder status items are visible
                self?.statusItem.isVisible = alerts.isEmpty && reminders.isEmpty
            }
            .store(in: &cancellables)
    }

    @objc private func openSettings() { AppDelegate.shared?.showSettings() }
    @objc private func quitApp()      { NSApp.terminate(nil) }
}
