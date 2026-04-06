import AppKit
import SwiftUI
import EventKit
import Combine
import os

// MARK: - SwiftUI model

@MainActor
class EventMenuBarModel: ObservableObject {
    @Published var title      = ""
    @Published var targetDate = Date().addingTimeInterval(600)
    @Published var iconName   = "calendar.badge.exclamationmark"
    @Published var isCompact  = false
    @Published var flashOn    = false
    @Published var shouldFlash = true   // false for in-progress events
    @Published var flashTextColor: Color = .orange
    @Published var flashBgColor:   Color = .orange
    /// Incremented on each event cycle — triggers the cross-fade transition animation.
    @Published var cycleKey   = 0
}

// MARK: - SwiftUI view

struct EventMenuBarView: View {
    @ObservedObject var model: EventMenuBarModel
    @State private var displayedSeconds = 0
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: model.iconName).imageScale(.small)
            if !model.isCompact {
                HStack(spacing: 0) {
                    Text(" \(model.title) · ")
                        .contentTransition(.opacity)
                    Text(formatSeconds(displayedSeconds))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.easeInOut(duration: 0.12), value: displayedSeconds)
                }
                .id(model.cycleKey)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.cycleKey)
        .foregroundStyle(model.flashOn && model.shouldFlash ? model.flashTextColor : Color(nsColor: .labelColor))
        .padding(.horizontal, 6)
        .frame(height: NSStatusBar.system.thickness)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(model.flashOn && model.shouldFlash ? model.flashBgColor.opacity(0.15) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.1), value: model.flashOn)
        .fixedSize()
        .onReceive(ticker)           { _ in refreshSeconds() }
        .onAppear                    { refreshSeconds() }
        .onChange(of: model.targetDate) { _, _ in refreshSeconds() }
    }

    private func refreshSeconds() {
        displayedSeconds = max(0, Int(model.targetDate.timeIntervalSince(Date())))
    }

    private func formatSeconds(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}

// MARK: - Controller

@MainActor
class EventStatusController {
    private var statusItem:    NSStatusItem?
    private var containerView: MenuBarContainerView?
    private let model = EventMenuBarModel()
    private let flash = FlashController()

    private var cycleTimer: Timer?
    private var cycleIndex = 0
    private var knownAlertIDs: Set<String> = []

    private var cancellables = Set<AnyCancellable>()
    private let alertState = AlertStateManager.shared
    private let settings   = SettingsManager.shared

    private var shouldBeCompact: Bool {
        switch settings.displayMode {
        case .compact:     return true
        case .informative: return false
        case .automatic:   return !alertState.activeReminders.isEmpty
        }
    }

    init() {
        flash.onFlashChange = { [weak self] on in self?.model.flashOn = on }

        alertState.$activeEventAlerts
            .combineLatest(alertState.$activeReminders)
            .combineLatest(alertState.$currentEvents)
            .receive(on: RunLoop.main)
            .sink { [weak self] combined, _ in
                let (alerts, _) = combined
                self?.handleStateChange(alerts: alerts)
            }
            .store(in: &cancellables)
    }

    // MARK: - State

    private func handleStateChange(alerts: [EKEvent]) {
        let all = merged(alerts: alerts, current: alertState.currentEvents)
        if all.isEmpty { hide(); return }

        Log.eventUI.debug("State change — \(alerts.count) alert(s), \(self.alertState.currentEvents.count) in-progress")
        ensureStatusItem()

        let incomingIDs = Set(alerts.map { eventID($0) })
        let brandNew    = incomingIDs.subtracting(knownAlertIDs)
        if !brandNew.isEmpty { knownAlertIDs.formUnion(brandNew) }
        knownAlertIDs = knownAlertIDs.intersection(incomingIDs)

        setupCycleTimer(count: all.count)
        applyDisplay()
        containerView?.menuProvider = { [weak self] in
            guard let self else { return NSMenu() }
            return self.buildMenu(alerts: self.alertState.activeEventAlerts,
                                  current: self.alertState.currentEvents)
        }

        let hasUpcomingAlerts = alerts.contains {
            guard let start = $0.startDate else { return false }
            return start > Date()
        }

        if !brandNew.isEmpty && settings.flashEnabled && hasUpcomingAlerts && !flash.isFlashing {
            Log.eventUI.info("Starting flash for \(brandNew.count) new upcoming event(s)")
            model.flashTextColor = settings.upcomingProfile.textSwiftUIColor
            model.flashBgColor   = settings.upcomingProfile.bgSwiftUIColor
            flash.start(profile: settings.upcomingProfile)
        } else if flash.isFlashing && !hasUpcomingAlerts {
            Log.eventUI.debug("Stopping flash — no upcoming alerts")
            flash.stop()
        }
    }

    private func eventID(_ e: EKEvent) -> String {
        if let id = e.eventIdentifier, !id.isEmpty { return id }
        // Stable fallback: title + start date avoids UUID breaking deduplication
        let title = e.title ?? ""
        let start = e.startDate.map { String($0.timeIntervalSince1970) } ?? ""
        return "\(title)_\(start)"
    }

    /// Merges alert events with currently-running events, deduplicating by eventID.
    /// Alerts take priority; currentEvents already present in alerts are skipped.
    private func merged(alerts: [EKEvent], current: [EKEvent]) -> [EKEvent] {
        let alertIDs = Set(alerts.map { eventID($0) })
        return alerts + current.filter { !alertIDs.contains(eventID($0)) }
    }

    // MARK: - Status item lifecycle

    private func ensureStatusItem() {
        guard statusItem == nil else { statusItem?.isVisible = true; return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let container = MenuBarContainerView(rootView: EventMenuBarView(model: model))
        container.menuProvider = { [weak self] in
            guard let self else { return NSMenu() }
            return self.buildMenu(alerts: self.alertState.activeEventAlerts,
                                  current: self.alertState.currentEvents)
        }
        // NSStatusItem.view is deprecated but necessary for NSHostingView (SwiftUI in menu bar).
        // The button-based API doesn't support custom subviews with live SwiftUI animations.
        statusItem?.view = container  // swiftlint:disable:this deprecated_in_future
        containerView = container
    }

    private func hide() {
        Log.eventUI.debug("Hiding event status item")
        flash.stop()
        stopCycleTimer()
        model.flashOn = false
        knownAlertIDs.removeAll()
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        containerView = nil
    }

    // MARK: - Display

    private func applyDisplay(animated: Bool = false) {
        let all = merged(alerts: alertState.activeEventAlerts, current: alertState.currentEvents)
        guard !all.isEmpty else { return }

        let safeIndex = min(cycleIndex, all.count - 1)
        let event = all[safeIndex]
        let now   = Date()
        let name  = event.title ?? Str.defaultEventTitle
        let title = String(name.prefix(18)) + (name.count > 18 ? "…" : "")

        model.isCompact = shouldBeCompact

        if let start = event.startDate, now < start {
            // Upcoming: count down to start, flash allowed
            model.targetDate  = start
            model.iconName    = "calendar.badge.exclamationmark"
            model.shouldFlash = true
        } else if let end = event.endDate {
            // In-progress: count down to end, no flash
            model.targetDate  = end
            model.iconName    = "calendar.badge.clock"
            model.shouldFlash = false
        }

        if animated && title != model.title {
            withAnimation(.easeInOut(duration: 0.35)) {
                model.cycleKey += 1
                model.title     = title
            }
        } else {
            model.title = title
        }

        DispatchQueue.main.async { [weak self] in
            self?.containerView?.resize()
            if let w = self?.containerView?.frame.width {
                self?.statusItem?.length = w
            }
        }
    }

    // MARK: - Menu

    private func buildMenu(alerts: [EKEvent], current: [EKEvent]) -> NSMenu {
        let menu = NSMenu()
        let all  = merged(alerts: alerts, current: current)

        for (i, event) in all.enumerated() {
            let header = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            header.attributedTitle = NSAttributedString(
                string:     event.title ?? Str.defaultEventTitle,
                attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
            )
            header.isEnabled = false
            menu.addItem(header)

            let timeItem = NSMenuItem(title: timeRangeString(for: event), action: nil, keyEquivalent: "")
            timeItem.isEnabled = false
            menu.addItem(timeItem)

            let statusMenuItem = NSMenuItem(title: statusString(for: event), action: nil, keyEquivalent: "")
            statusMenuItem.isEnabled = false
            menu.addItem(statusMenuItem)

            if alerts.contains(where: { eventID($0) == eventID(event) }) {
                let d = NSMenuItem(
                    title: Str.dismissNotification,
                    action: #selector(dismissAlert(_:)),
                    keyEquivalent: ""
                )
                d.target = self; d.representedObject = event
                menu.addItem(d)
            }

            let o = NSMenuItem(
                title: Str.openInCalendar,
                action: #selector(openInCalendar(_:)),
                keyEquivalent: ""
            )
            o.target = self; o.representedObject = event
            menu.addItem(o)

            if i < all.count - 1 { menu.addItem(.separator()) }
        }

        menu.addItem(.separator())
        let showQuit = !alertState.activeEventAlerts.isEmpty || !alertState.activeReminders.isEmpty
        appendCommonMenuItems(to: menu, showQuit: showQuit)
        return menu
    }

    private func timeRangeString(for event: EKEvent) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        let dur = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
        return "\(f.string(from: event.startDate)) – \(f.string(from: event.endDate)) (\(Str.durationMinutes(dur)))"
    }

    private func statusString(for event: EKEvent) -> String {
        let now = Date()
        if let start = event.startDate, now < start {
            return Str.startsIn(formatSeconds(Int(start.timeIntervalSince(now))))
        } else if let end = event.endDate, now < end {
            return Str.runningEndsIn(formatSeconds(Int(end.timeIntervalSince(now))))
        }
        return Str.eventEnded
    }

    private func formatSeconds(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    // MARK: - Actions

    @objc private func dismissAlert(_ sender: NSMenuItem) {
        guard let event = sender.representedObject as? EKEvent else { return }
        Log.eventUI.info("User dismissed event: \(event.title ?? "untitled", privacy: .public)")
        alertState.dismissEventAlert(event)
    }

    @objc private func openInCalendar(_ sender: NSMenuItem) {
        guard let event = sender.representedObject as? EKEvent else { return }
        Log.eventUI.debug("Opening event in Calendar.app")
        CalendarManager.shared.openInCalendar(event: event)
    }

    // MARK: - Cycle timer

    private func setupCycleTimer(count: Int) {
        if count <= 1 { stopCycleTimer(); cycleIndex = 0; return }
        cycleIndex = min(cycleIndex, count - 1)
        guard cycleTimer == nil else { return }
        cycleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let all = self.merged(
                    alerts:  self.alertState.activeEventAlerts,
                    current: self.alertState.currentEvents
                )
                guard !all.isEmpty else { return }
                self.cycleIndex = (self.cycleIndex + 1) % all.count
                self.applyDisplay(animated: true)
            }
        }
    }

    private func stopCycleTimer() { cycleTimer?.invalidate(); cycleTimer = nil }
}
