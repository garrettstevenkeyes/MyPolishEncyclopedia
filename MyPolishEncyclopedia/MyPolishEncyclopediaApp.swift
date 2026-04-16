import SwiftUI

@main
struct MyPolishEncyclopediaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No window — the app lives entirely in the menubar popover.
        // LSUIElement = YES (set in Build Settings) suppresses the Dock icon.
        Settings { EmptyView() }
    }
}
