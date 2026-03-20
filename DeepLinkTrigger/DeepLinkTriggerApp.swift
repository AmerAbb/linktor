import SwiftUI

@main
struct DeepLinkTriggerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No window — menu bar only
        Settings { EmptyView() }
    }
}
