import AppKit
import SwiftUI
import os

// MARK: - Generic menu bar container view

/// Хостит любой SwiftUI-View внутри NSView для статус-бара.
/// Обрабатывает клик для отображения меню и динамическое изменение ширины.
class MenuBarContainerView: NSView {
    private let hosting: NSHostingView<AnyView>
    var menuProvider: (() -> NSMenu)?

    init<V: View>(rootView: V) {
        hosting = NSHostingView(rootView: AnyView(rootView))
        super.init(frame: NSRect(x: 0, y: 0, width: 40, height: Int(NSStatusBar.system.thickness)))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        if let menu = menuProvider?() {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
    }

    func resize() {
        let w = max(24, hosting.intrinsicContentSize.width)
        frame = NSRect(x: 0, y: 0, width: w, height: NSStatusBar.system.thickness)
    }
}

// MARK: - Общий контроллер мигания

/// Управляет таймером мигания. Используется в EventStatusController и ReminderStatusController.
@MainActor
final class FlashController {
    private var flashTimer: Timer?
    private(set) var isFlashing = false

    /// Вызывается на каждом такте: true = подсветка включена, false = выключена.
    var onFlashChange: ((Bool) -> Void)?

    deinit {
        flashTimer?.invalidate()
    }

    func start(profile: AlertColorProfile) {
        stop()
        isFlashing = true
        Log.eventUI.debug("Flash started (interval: \(SettingsManager.shared.flashInterval)s, duration: \(SettingsManager.shared.flashDurationSeconds)s)")
        let settings   = SettingsManager.shared
        var tick       = 0
        let interval   = settings.flashInterval
        let totalTicks = settings.flashDurationSeconds > 0
            ? Int(Double(settings.flashDurationSeconds) / interval)
            : Int.max

        flashTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                tick += 1
                self.onFlashChange?(tick % 2 == 1)
                if tick >= totalTicks {
                    self.onFlashChange?(false)
                    self.stop()
                }
            }
        }
    }

    func stop() {
        flashTimer?.invalidate()
        flashTimer = nil
        isFlashing = false
        onFlashChange?(false)
    }
}

// MARK: - Общие пункты меню

/// Добавляет стандартные пункты «Настройки…» и «Выйти» в конец меню.
/// Настройки направляются напрямую в AppDelegate, чтобы контроллерам не нужен @objc-селектор.
@MainActor
func appendCommonMenuItems(to menu: NSMenu, showQuit: Bool) {
    let s = NSMenuItem(title: Str.settingsMenuItem, action: #selector(AppDelegate.showSettings), keyEquivalent: "")
    s.target = AppDelegate.shared
    s.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
    menu.addItem(s)

    if showQuit {
        let q = NSMenuItem(title: Str.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        q.target = NSApp
        menu.addItem(q)
    }
}
