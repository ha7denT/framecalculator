import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@main
struct TimecoderApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(iOS)
    @UIApplicationDelegateAdaptor(iOSAppDelegate.self) var iOSAppDelegate
    #endif
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 320, height: 520)
        .windowResizability(.contentSize)
        #endif
        .commands {
            // File menu - Open
            CommandGroup(after: .newItem) {
                Button("Open...") {
                    NotificationCenter.default.post(name: .openVideoFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            // File menu - Export Markers
            CommandGroup(after: .importExport) {
                Button("Export Markers...") {
                    NotificationCenter.default.post(name: .showExportDialog, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
            }

            // Edit menu - Add Marker
            CommandGroup(after: .pasteboard) {
                Divider()

                Button("Add Marker") {
                    NotificationCenter.default.post(name: .addMarkerAtPlayhead, object: nil)
                }
                .keyboardShortcut("m", modifiers: [])
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Button("Timecoder Help") {
                    if let url = URL(string: "https://github.com") {
                        PlatformURL.open(url)
                    }
                }

                #if os(macOS)
                Divider()

                Button("Keyboard Shortcuts") {
                    showKeyboardShortcutsWindow()
                }
                .keyboardShortcut("?", modifiers: [.command, .shift])
                #endif
            }
        }

        #if os(macOS)
        // Preferences window (macOS only — iOS uses in-app settings)
        Settings {
            PreferencesView()
        }
        #endif
    }

    private var colorScheme: ColorScheme? {
        switch preferences.preferDarkMode {
        case true: return .dark
        case false: return .light
        case nil: return nil
        }
    }

    #if os(macOS)
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
    #endif
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
                #if os(macOS)
                .pickerStyle(.menu)
                #endif

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
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
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

            #if os(macOS)
            // Window section (macOS only)
            Section("Window") {
                Toggle("Remember window position", isOn: $preferences.rememberWindowPosition)
            }
            #endif
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        .frame(width: 400, height: 280)
        #endif
    }
}

#if os(iOS)
// MARK: - iOS App Delegate

/// iOS app delegate for dynamic orientation control.
/// Calculator mode is portrait-locked; video mode allows all orientations.
class iOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if AppState.shared.mode == .calculator {
            return .portrait
        }
        return .allButUpsideDown
    }
}
#endif

#if os(macOS)
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
#endif
