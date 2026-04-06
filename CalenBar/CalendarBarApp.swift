import SwiftUI

@main
struct CalenBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — menu bar only
        Settings {
            EmptyView()
        }
    }
}
