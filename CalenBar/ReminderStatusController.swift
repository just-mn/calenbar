import AppKit
import SwiftUI
import EventKit
import Combine
import os

// MARK: - SwiftUI model

@MainActor
class ReminderMenuBarModel: ObservableObject {
    @Published var text:           String = ""
    @Published var iconName:       String = "bell.badge.fill"
    @Published var isCompact:      Bool   = false
    @Published var flashOn:        Bool   = false
    @Published var flashTextColor: Color  = .red
    @Published var flashBgColor:   Color  = .red
}

// MARK: - SwiftUI view

struct ReminderMenuBarView: View {
    @ObservedObject var model: ReminderMenuBarModel

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: model.iconName).imageScale(.small)
            if !model.isCompact {
                Text(" \(model.text)")
            }
        }
        .foregroundStyle(model.flashOn ? model.flashTextColor : Color(nsColor: .labelColor))
        .padding(.horizontal, 6)
        .frame(height: NSStatusBar.system.thickness)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(model.flashOn ? model.flashBgColor.opacity(0.15) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.1), value: model.flashOn)
        .fixedSize()
    }
}

// MARK: - Controller

@MainActor
class ReminderStatusController {
    private var statusItem:    NSStatusItem?
    private var containerView: MenuBarContainerView?
    private let model = ReminderMenuBarModel()
    private let flash = FlashController()

    private var knownReminderIDs: Set<String> = []
    private var cancellables    = Set<AnyCancellable>()
    private let alertState      = AlertStateManager.shared
    private let settings        = SettingsManager.shared
    private let calendarManager = CalendarManager.shared

    private var shouldBeCompact: Bool {
        switch settings.displayMode {
        case .compact:     return true
        case .informative: return false
        case .automatic:   return !alertState.activeEventAlerts.isEmpty || !alertState.currentEvents.isEmpty
        }
    }

    init() {
        flash.onFlashChange = { [weak self] on in self?.model.flashOn = on }

        alertState.$activeReminders
            .combineLatest(alertState.$activeEventAlerts)
            .combineLatest(alertState.$currentEvents)
            .receive(on: RunLoop.main)
            .sink { [weak self] combined, _ in
                self?.handleStateChange(reminders: combined.0)
            }
            .store(in: &cancellables)
    }

    private func reminderID(_ r: EKReminder) -> String {
        let id = r.calendarItemIdentifier
        if !id.isEmpty { return id }
        // Stable fallback instead of UUID which breaks deduplication
        return r.title ?? "unknown_reminder"
    }

    // MARK: - State

    private func handleStateChange(reminders: [EKReminder]) {
        if reminders.isEmpty { hide(); return }

        Log.reminderUI.debug("State change — \(reminders.count) active reminders")
        ensureStatusItem()

        let incomingIDs = Set(reminders.map { reminderID($0) })
        let brandNew    = incomingIDs.subtracting(knownReminderIDs)
        if !brandNew.isEmpty { knownReminderIDs.formUnion(brandNew) }
        knownReminderIDs = knownReminderIDs.intersection(incomingIDs)

        applyDisplay(reminders: reminders)
        containerView?.menuProvider = { [weak self] in
            guard let self else { return NSMenu() }
            return self.buildMenu(reminders: self.alertState.activeReminders)
        }

        if !brandNew.isEmpty && settings.flashEnabled && !flash.isFlashing {
            Log.reminderUI.info("Starting flash for \(brandNew.count) new overdue reminder(s)")
            model.flashTextColor = settings.overdueProfile.textSwiftUIColor
            model.flashBgColor   = settings.overdueProfile.bgSwiftUIColor
            flash.start(profile: settings.overdueProfile)
        }
    }

    private func ensureStatusItem() {
        guard statusItem == nil else { statusItem?.isVisible = true; return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let container = MenuBarContainerView(rootView: ReminderMenuBarView(model: model))
        container.menuProvider = { [weak self] in
            guard let self else { return NSMenu() }
            return self.buildMenu(reminders: self.alertState.activeReminders)
        }
        // NSStatusItem.view is deprecated but necessary for NSHostingView (SwiftUI in menu bar).
        statusItem?.view = container  // swiftlint:disable:this deprecated_in_future
        containerView = container
    }

    private func hide() {
        Log.reminderUI.debug("Hiding reminder status item")
        flash.stop()
        model.flashOn = false
        statusItem?.isVisible = false
        knownReminderIDs.removeAll()
    }

    // MARK: - Display

    private func applyDisplay(reminders: [EKReminder]) {
        model.isCompact      = shouldBeCompact
        model.flashTextColor = settings.overdueProfile.textSwiftUIColor
        model.flashBgColor   = settings.overdueProfile.bgSwiftUIColor

        if reminders.count == 1 {
            let name = reminders[0].title ?? Str.defaultReminderTitle
            model.text     = String(name.prefix(20)) + (name.count > 20 ? "…" : "")
            model.iconName = "bell.badge.fill"
        } else {
            model.text     = Str.reminderCount(reminders.count)
            model.iconName = "bell.badge.fill"
        }

        DispatchQueue.main.async { [weak self] in
            self?.containerView?.resize()
            if let w = self?.containerView?.frame.width {
                self?.statusItem?.length = w
            }
        }
    }

    // MARK: - Menu

    private func buildMenu(reminders: [EKReminder]) -> NSMenu {
        let menu = NSMenu()

        for (i, reminder) in reminders.enumerated() {
            let header = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            header.attributedTitle = NSAttributedString(
                string:     reminder.title ?? Str.defaultReminderTitle,
                attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
            )
            header.isEnabled = false
            menu.addItem(header)

            let due = NSMenuItem(title: dueDateString(for: reminder), action: nil, keyEquivalent: "")
            due.isEnabled = false
            menu.addItem(due)

            let snoozeMenu = NSMenu()
            for mins in settings.snoozeDurations {
                let item = NSMenuItem(
                    title: settings.snoozeLabel(minutes: mins),
                    action: #selector(snoozeReminder(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = ReminderAction(reminder: reminder, minutes: mins)
                snoozeMenu.addItem(item)
            }
            let snoozeParent = NSMenuItem(title: Str.snoozeMenu, action: nil, keyEquivalent: "")
            snoozeParent.submenu = snoozeMenu
            menu.addItem(snoozeParent)

            let complete = NSMenuItem(
                title: Str.markDone,
                action: #selector(completeReminder(_:)),
                keyEquivalent: ""
            )
            complete.target = self; complete.representedObject = reminder
            menu.addItem(complete)

            let open = NSMenuItem(
                title: Str.openInReminders,
                action: #selector(openInReminders(_:)),
                keyEquivalent: ""
            )
            open.target = self; open.representedObject = reminder
            menu.addItem(open)

            if i < reminders.count - 1 { menu.addItem(.separator()) }
        }

        menu.addItem(.separator())
        appendCommonMenuItems(to: menu, showQuit: true)
        return menu
    }

    private func dueDateString(for reminder: EKReminder) -> String {
        guard let comps = reminder.dueDateComponents,
              let due = Calendar.current.date(from: comps) else { return Str.noDueDate }
        let now = Date()
        let f = DateFormatter()
        f.timeStyle = .short
        if Calendar.current.isDateInToday(due) {
            if due < now {
                let elapsed = Int(now.timeIntervalSince(due))
                let m = elapsed / 60; let sec = elapsed % 60
                let elapsed_str = sec > 0 ? String(format: "%d:%02d", m, sec) : Str.durationMinutes(m)
                return Str.overdueBy(elapsed_str, time: f.string(from: due))
            }
            return Str.dueToday(f.string(from: due))
        }
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return Str.dueDate(df.string(from: due))
    }

    // MARK: - Actions

    @objc private func snoozeReminder(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? ReminderAction else { return }
        Log.reminderUI.info("User snoozed reminder for \(action.minutes) min")
        alertState.snoozeReminder(action.reminder, minutes: action.minutes)
    }

    @objc private func completeReminder(_ sender: NSMenuItem) {
        guard let reminder = sender.representedObject as? EKReminder else { return }
        do {
            try calendarManager.complete(reminder)
            alertState.removeReminder(reminder)
        } catch {
            Log.reminderUI.error("Failed to complete reminder: \(error.localizedDescription)")
            NSAlert(error: error).runModal()
        }
    }

    @objc private func openInReminders(_ sender: NSMenuItem) {
        guard let reminder = sender.representedObject as? EKReminder else { return }
        Log.reminderUI.debug("Opening reminder in Reminders.app")
        calendarManager.openInReminders(reminder)
    }
}

private class ReminderAction: NSObject {
    let reminder: EKReminder
    let minutes:  Int
    init(reminder: EKReminder, minutes: Int) {
        self.reminder = reminder; self.minutes = minutes
    }
}
