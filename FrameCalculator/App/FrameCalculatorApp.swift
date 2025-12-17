import SwiftUI

@main
struct FrameCalculatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 320, height: 520)
        .windowResizability(.contentSize)
        .commands {
            // Add Edit menu commands for copy/paste
            CommandGroup(after: .pasteboard) {
                Divider()
            }

            // Keyboard shortcuts help
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    // Will open shortcuts window in future sprint
                }
                .keyboardShortcut("?", modifiers: [.command, .shift])
            }
        }
    }
}

/// App delegate to handle window restoration behavior.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable window restoration to prevent size persistence issues
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
