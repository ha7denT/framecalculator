# Timecoder

A native macOS and iOS timecode calculator and video logging tool for post-production professionals.

## Project Overview

Timecoder operates in two modes:
1. **Standalone Calculator** — Compact timecode calculator (add, subtract, multiply, frame↔TC conversion)
2. **Video Inspection** — Video player + calculator with metadata display and marker export

Target: App Store distribution (macOS + iOS universal purchase). One-time purchase, no subscriptions.

## Tech Stack

- **Language:** Swift 5.9+
- **UI:** SwiftUI (AppKit integration on macOS, UIKit on iOS where needed)
- **Video:** AVFoundation / AVKit
- **Minimum OS:** macOS 26.0, iOS 26.0
- **Architecture:** MVVM
- **Multiplatform:** Single target with `#if os(macOS)` / `#if os(iOS)` conditional compilation

## Project Structure

```
Timecoder/
├── App/                    # App entry point, global state
├── Models/                 # Timecode, FrameRate, Marker, VideoMetadata
├── ViewModels/             # CalculatorVM, VideoPlayerVM, MarkerListVM
├── Views/
│   ├── Calculator/         # Timecode display, keypad, frame rate picker
│   ├── VideoPlayer/        # Player, transport controls, timeline
│   ├── Markers/            # Marker list, editor sheet
│   ├── Export/             # Export dialog with NSSavePanel/UIActivityViewController
│   └── Main/               # ContentView, iOSContentView, VideoInspectorView (macOS), iOSVideoInspectorView
├── Services/               # VideoLoader, TimecodeEngine, MarkerExporter
└── Utilities/              # PlatformServices.swift, extensions, helpers
```

## Commands

```bash
# Build macOS
xcodebuild -scheme Timecoder -destination 'platform=macOS' -configuration Debug build

# Build iOS Simulator
xcodebuild -scheme Timecoder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build

# Test
xcodebuild -scheme Timecoder test

# Run SwiftLint (if installed)
swiftlint

# Clean build folder
xcodebuild clean
```

## Code Style

- Use Swift's native types. `Timecode` is a value type storing frame count + frame rate.
- Prefer `async/await` over completion handlers.
- Use `@Observable` (macOS 14+) or `@ObservableObject` for view models.
- Keep views small. Extract subviews when a view exceeds ~100 lines.
- Name files after their primary type: `Timecode.swift`, `CalculatorViewModel.swift`.

## Key Design Decisions

### Timecode Storage
Store timecode as frame count internally. All display/parsing happens at the boundary.
```swift
struct Timecode {
    let frames: Int
    let frameRate: FrameRate
}
```

### Frame Rate Enum
Use enum with associated value for custom rates:
```swift
enum FrameRate {
    case fps23_976, fps24, fps25, fps29_97_df, fps29_97_ndf, fps30, fps50, fps59_94, fps60
    case custom(Double)
}
```

### Drop Frame Handling
29.97 DF skips frame numbers 0 and 1 at the start of each minute, except every 10th minute. Implement this in `Timecode` conversion methods.

### Video Playback
- Use `AVPlayer` with `seek(to:toleranceBefore:toleranceAfter:)` using `.zero` tolerance for frame-accurate seeking.
- Update timecode display via `addPeriodicTimeObserver` at frame-rate interval.
- JKL shuttle uses `AVPlayer.rate` for variable speed.
- macOS: `AVPlayerView` via `NSViewRepresentable`
- iOS: `AVPlayerViewController` via `UIViewControllerRepresentable`

### Multiplatform Architecture
- **Platform abstraction layer:** `Timecoder/Utilities/PlatformServices.swift`
  - `PlatformClipboard` — clipboard (NSPasteboard ↔ UIPasteboard)
  - `PlatformURL` — URL opening (NSWorkspace ↔ UIApplication)
  - `PlatformHaptics` — haptic feedback (UIImpactFeedbackGenerator on iOS, no-op on macOS)
  - `Color.platformControlBackground`, `.platformWindowBackground`, `.platformSeparator`
- **Guard pattern:** `#if os(macOS)` / `#if os(iOS)` with small, localized blocks
- **macOS-only types wrapped in `#if os(macOS)`:** `KeyboardCaptureView`, `VideoKeyboardCaptureView`, `AppDelegate`, `VideoDropDelegate`, `VideoInspectorView`
- **iOS keyboard input:** `.onKeyPress()` handlers on container views (`iOSContentView` for calculator, `iOSVideoInspectorView` for video) with `@FocusState` for hardware keyboard focus
- **Shared struct name pattern:** `CustomVideoPlayerView` has both NSViewRepresentable (macOS) and UIViewControllerRepresentable (iOS) behind `#if os()` — same name, no conditionals at call sites
- **iOS file import:** `.fileImporter()` modifier replaces `NSOpenPanel`
- **iOS marker export:** `UIActivityViewController` replaces `NSSavePanel`
- **iOS-specific view files:**
  - `iOSContentView.swift` — iOS app structure with `horizontalSizeClass`-based adaptive layout
  - `iOSVideoInspectorView.swift` — iOS video inspection (stacked on iPhone, side-by-side on iPad)
- **ContentView dispatch pattern:** `ContentView.body` uses `#if os(iOS)` / `#if os(macOS)` to dispatch to `iOSBody` or `macOSBody`
- **Shared cross-platform views:** `InOutPanel`, `CalculatorView`, `TransportControls`, `TimelineWithTimecode`, `MetadataPanel`, `MarkerEditorPopover`, `MarkerRowView`, `MarkerOverlayView`
- **iOS sizing:** Uses `GeometryReader` and `aspectRatio` (NOT fixed pixel sizes from `VideoOrientation`)
- **Configurable shared views:** `KeypadView`, `TimecodeDisplayView`, `CalculatorView` accept optional size params with defaults — macOS uses defaults, iOS containers compute from geometry
- **`PlatformLayout`** — iOS-only enum in PlatformServices.swift: `keypadButtonSize(forWidth:spacing:)` computes responsive button sizes
- **`AppState.shared`** — Singleton for `iOSAppDelegate` orientation lock access
- **`iOSAppDelegate`** — Mode-aware orientation: portrait-only for calculator, portrait + landscape for video mode
- **`TransportControls.isCompact`** — Hides shuttle indicator, reduces spacing on compact layouts
- **`GlassTransportButton`** — Internal access (not private), used directly by iPhone portrait layout for decomposed transport rows
- **iPhone portrait video layout** — Decomposed single-screen: video → timeline → 2 transport rows → full-width timecode → HStack(keypad left, metadata+in/out right). No TabView/panelPicker.
- **`compactPanelWidth`** — Shared constant (160pt) for metadata and in/out panel widths in iPhone portrait
- **`TimecodeDisplayView.showSecondaryDisplay`** — Bool parameter (default true), set false in iPhone portrait video to hide frames count
- **iPad orientation detection:** `geometry.size.width > geometry.size.height` (NOT device orientation)
- **iPhone landscape video mode** — In video mode, iPhone allows landscape rotation for fullscreen video with `OverlayTransportControls` (auto-hiding glass overlay). Calculator mode remains portrait-only.
- **`PlatformOrientation.requestOrientationUpdate()`** — Calls `setNeedsUpdateOfSupportedInterfaceOrientations()` on all root view controllers to notify UIKit of orientation changes when switching modes
- **`MarkerOverlayView`** — Cross-platform view showing marker text/color on video when playhead is on a marker frame. Driven by `VideoPlayerViewModel.activeMarker`.
- **`OverlayTransportControls`** — iOS-only auto-hiding glass transport overlay for landscape video. 3s auto-hide timer, tap to show/hide.
- **⌘C Copy Timecode** — macOS uses ⌘C in `.commands {}`, iOS uses ⌘⇧C to avoid conflict with system Copy command
- **iPad video mode** — On hold; shipping iPhone + macOS first

## Marker Export Formats

### DaVinci Resolve
Export as EDL. Resolve imports via "Timeline > Import > Timeline Markers from EDL".

### Avid Media Composer
Tab-delimited text: `[User]\t[Timecode]\t[Track]\t[Color]\t[Comment]`
```
Timecoder    01:02:15:08    V1    red    Note text here
```

### CSV
Standard columns: `Timecode In,Timecode Out,Color,Name,Duration`

## App Sandbox Entitlements

Required for App Store:
- `com.apple.security.files.user-selected.read-write` — drag/drop video files + save panel for export
- `com.apple.security.files.downloads.read-write` — marker export

## UI Guidelines

- **Dark mode first** — most video pros work in dark environments
- Follow Apple HIG for native feel
- Monospace font (Space Mono) for timecode display, SF Pro for UI text
- Minimal chrome, focus on content
- Liquid Glass design on macOS 26 and iOS 26

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Space | Play/Pause |
| J/K/L | Shuttle reverse/stop/forward |
| ←/→ | Step frame |
| I/O | Set In/Out point |
| M | Add marker |
| ⌘C/⌘V | Copy/paste timecode |

## Testing Notes

- Test drop frame calculations thoroughly (edge cases at minute boundaries)
- Test all supported frame rates
- Test timecode parsing with various input formats (with/without colons, semicolons for DF)
- Verify marker export imports correctly in Resolve and Avid

## Reference Documentation

- PRD: See `docs/Timecoder_PRD.md` for full requirements
- iOS Sprint Plan: See `docs/ios_sprint_plan.md` for iOS expansion sprints
- Sprint History: See `docs/sprint_plans.md` for all completed sprints
- Apple docs: AVFoundation, AVKit, SwiftUI

## Common Pitfalls

- Don't use floating point for frame counts — accumulates errors
- Drop frame is a *display* format, not a different frame rate (29.97 DF and NDF are the same rate)
- AVPlayer time is in seconds (CMTime), convert to frames using frame rate
- Timecode display must handle negative durations (show as `-HH:MM:SS:FF`)

### Multiplatform Pitfalls

- **`Color(.separator)` is NOT cross-platform** — Use `Color.platformSeparator` from PlatformServices.swift
- **`NSColor` leaks via transitive imports** — Files that don't `import AppKit` directly can still use `NSColor` if another import brings it in. Always search the whole codebase for `NSColor`, `NSFont`, etc. after making platform changes
- **`@State` in `#if` blocks** — `@State` properties must be declared at the struct level, not inside conditional method blocks. Use `#if os(iOS) @State private var foo = false #endif` at struct scope
- **Xcode project settings need both levels** — Set `SDKROOT`, `SUPPORTED_PLATFORMS`, deployment targets in both project-level AND target-level build configurations (Debug + Release = 4 places total)
- **Test both platforms after every change** — An edit that fixes iOS can break macOS (e.g., `Color(.separator)` worked on iOS but not macOS)
- **Marker property is `timecodeFrames`** — NOT `frameNumber`. Wrong name causes cascading type inference errors in `ForEach` that are misleading (e.g., "requires class type", "cannot convert Binding")
- **`#Preview` must match platform guards** — If a struct is behind `#if os(macOS)`, its `#Preview` block needs the same guard
- **`VideoOrientation.videoFrameSize` is macOS-only** — iOS uses `GeometryReader` for responsive sizing. Don't reference these fixed-pixel properties from iOS code
- **Separate view files over complex `#if` branching** — For fundamentally different layouts (macOS fixed-frame HStack vs iOS adaptive stacked/side-by-side), create separate files (e.g., `iOSVideoInspectorView.swift`) rather than interleaving `#if` blocks in the same view body
- **iOS security-scoped URLs** — `.fileImporter()` returns security-scoped URLs. Must call `url.startAccessingSecurityScopedResource()` before use and `url.stopAccessingSecurityScopedResource()` after
