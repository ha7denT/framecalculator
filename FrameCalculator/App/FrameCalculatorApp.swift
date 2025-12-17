import SwiftUI

@main
struct FrameCalculatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 320, height: 520)
        .windowResizability(.contentSize)
        .commands {
            // Add Edit menu commands for copy/paste
            CommandGroup(after: .pasteboard) {
                Divider()
            }

            // File menu - Export Markers
            CommandGroup(after: .importExport) {
                Button("Export Markers...") {
                    NotificationCenter.default.post(name: .showExportDialog, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Button("Frame Calculator Help") {
                    if let url = URL(string: "https://github.com") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Divider()

                Button("Keyboard Shortcuts") {
                    showKeyboardShortcutsWindow()
                }
                .keyboardShortcut("?", modifiers: [.command, .shift])
            }
        }

        // Preferences window
        Settings {
            PreferencesView()
        }
    }

    private var colorScheme: ColorScheme? {
        switch preferences.preferDarkMode {
        case true: return .dark
        case false: return .light
        case nil: return nil
        }
    }

    private func showKeyboardShortcutsWindow() {
        let shortcuts = """
        Calculator Mode:
        0-9         Enter digits
        + - × =     Operations
        Delete      Remove last digit
        C           Clear entry
        AC          Clear all
        Enter       Execute operation

        Video Mode:
        Space       Play/Pause
        J/K/L       Shuttle reverse/stop/forward
        ←/→         Step one frame
        I           Set In point
        O           Set Out point
        ⇧I / ⇧O     Go to In/Out point
        ⌥X          Clear In/Out points
        M           Add/edit marker
        Delete      Delete selected marker
        ⌘E          Export markers
        ⌘C/⌘V       Copy/paste timecode
        """

        let alert = NSAlert()
        alert.messageText = "Keyboard Shortcuts"
        alert.informativeText = shortcuts
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Preferences View

struct PreferencesView: View {
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        Form {
            // Defaults section
            Section("Defaults") {
                Picker("Default Frame Rate", selection: $preferences.defaultFrameRate) {
                    ForEach(FrameRate.allStandardRates, id: \.self) { rate in
                        Text(rate.displayName).tag(rate)
                    }
                }
                .pickerStyle(.menu)

                Picker("Default Marker Color", selection: $preferences.defaultMarkerColor) {
                    ForEach(MarkerColor.allCases, id: \.self) { color in
                        HStack {
                            Circle()
                                .fill(color.displayColor)
                                .frame(width: 12, height: 12)
                            Text(color.displayName)
                        }
                        .tag(color)
                    }
                }
                .pickerStyle(.menu)
            }

            // Appearance section
            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { preferences.preferDarkMode },
                    set: { preferences.preferDarkMode = $0 }
                )) {
                    Text("System").tag(nil as Bool?)
                    Text("Light").tag(false as Bool?)
                    Text("Dark").tag(true as Bool?)
                }
                .pickerStyle(.segmented)
            }

            // Window section
            Section("Window") {
                Toggle("Remember window position", isOn: $preferences.rememberWindowPosition)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400, height: 280)
    }
}

// MARK: - App Delegate

/// App delegate to handle window restoration behavior.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Respect user preference for window restoration
        let shouldRestore = UserPreferences.shared.rememberWindowPosition
        UserDefaults.standard.set(shouldRestore, forKey: "NSQuitAlwaysKeepsWindows")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
