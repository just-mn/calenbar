import SwiftUI

@main
struct CalenBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            // App menu: replace About with our custom About tab
            CommandGroup(replacing: .appInfo) {
                Button(Str.aboutCalenBar) {
                    AppDelegate.shared?.showAbout()
                }
            }
            // App menu: replace Settings to use our window
            CommandGroup(replacing: .appSettings) {
                Button(Str.settingsMenuItem) {
                    AppDelegate.shared?.showSettings()
                }
                .keyboardShortcut(",")
            }
            // Remove File menu
            CommandGroup(replacing: .newItem) { }
            // Remove View menu
            CommandGroup(replacing: .sidebar) { }
            CommandGroup(replacing: .toolbar) { }
            // Remove Window menu
            CommandGroup(replacing: .windowList) { }
            CommandGroup(replacing: .windowArrangement) { }
            CommandGroup(replacing: .windowSize) { }
            CommandGroup(replacing: .singleWindowList) { }
            // Remove Help menu
            CommandGroup(replacing: .help) { }
        }
    }
}
