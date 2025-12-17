import SwiftUI

@main
struct FrameCalculatorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 320, height: 520)
        .windowResizability(.contentMinSize)
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
