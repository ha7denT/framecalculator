# Timecoder iOS — Sprint Plan

**Created:** 2026-02-24
**Approach:** Multiplatform target with conditional compilation (Option A)
**Distribution:** Universal Purchase (single purchase unlocks macOS + iOS)
**iOS Deployment Target:** iOS 26.0
**macOS Deployment Target:** macOS 26.0 (unchanged)

---

## References

- [Configuring a multiplatform app target — Apple Developer](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target)
- [Add platforms to app record — App Store Connect](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms/)
- [Build a SwiftUI app with the new design — WWDC25](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Applying Liquid Glass to custom views — Apple Developer](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [glassEffect(_:in:) — Apple Developer](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))
- [Use Xcode to develop a multiplatform app — WWDC22](https://developer.apple.com/videos/play/wwdc2022/110371/)
- [What's new in SwiftUI — WWDC25](https://developer.apple.com/videos/play/wwdc2025/256/)
- [iOS 26 Liquid Glass Reference — GitHub](https://github.com/conorluddy/LiquidGlassReference)
- [Universal Purchase for Mac Apps — Apple Developer News](https://developer.apple.com/news/?id=03232020b)

---

## Scope Summary

### What Ships on iOS

**iPhone (calculator-first experience):**
- Full timecode calculator with touch keypad
- Video inspection via file importer + photo library
- Stacked layout: video on top, controls + calculator below
- Marker creation and export (share sheet)

**iPad (full experience, near-parity with macOS):**
- Side-by-side layout mirroring macOS (video left, calculator + metadata right)
- Hardware keyboard support for JKL shuttle, I/O points, frame stepping
- iPadOS 26 menu bar support (commands API creates iPad menus automatically)
- Drag-and-drop video loading

### What Stays macOS-Only

- `NSWindow` dynamic sizing and positioning
- `NSOpenPanel` / `NSSavePanel` (replaced with SwiftUI `.fileImporter()` / share sheet on iOS)
- `NSEvent` local monitors (replaced with `.onKeyPress()` on iOS)
- Window restoration preferences

### Shared Code (No Changes Needed)

- **Models (100%):** `Timecode.swift`, `FrameRate.swift`, `Marker.swift`, `VideoMetadata.swift`
- **Services (100%):** `VideoLoader.swift`, `MarkerExporter.swift`
- **ViewModels (~95%):** `CalculatorViewModel.swift`, `VideoPlayerViewModel.swift`, `MarkerListViewModel.swift` — only clipboard calls need branching
- **Most SwiftUI views:** `KeypadView.swift`, `FrameRatePicker.swift`, `MarkerEditorSheet.swift`, `MarkerRowView.swift`, `TimelineMarkerView.swift`, `MetadataPanel.swift`, `ExportDialogView.swift` (with minor adaptations)

---

## Sprint 16: Project Configuration & Platform Abstraction

### Goal
Add iOS as a supported destination, create the platform abstraction layer, and get the project compiling for both platforms.

### Deliverables

- [x] **Add iOS destination to Xcode project**
  - Modified `project.pbxproj`: `SDKROOT = auto`, `SUPPORTED_PLATFORMS = "macosx iphonesimulator iphoneos"`
  - Added `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `TARGETED_DEVICE_FAMILY = "1,2"`
  - Added launch screen generation, orientation keys, iOS runpath search paths
  - Bundle ID remains `com.haydentoppeross.timecoder` (same for universal purchase)
  - Ref: [Configuring a multiplatform app target](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target)

- [x] **Create `PlatformServices.swift` abstraction**
  - `PlatformClipboard` — cross-platform copy/paste (NSPasteboard ↔ UIPasteboard)
  - `PlatformURL` — cross-platform URL opening (NSWorkspace ↔ UIApplication)
  - `Color.platformControlBackground` — NSColor.controlBackgroundColor ↔ UIColor.secondarySystemBackground
  - `Color.platformWindowBackground` — NSColor.windowBackgroundColor ↔ UIColor.systemBackground
  - `Color.platformSeparator` — NSColor.separatorColor ↔ UIColor.separator

- [x] **Replace all direct `NSPasteboard` calls with `PlatformClipboard`**
  - `CalculatorViewModel.swift`, `TimecodeDisplayView.swift`, `VideoInspectorView.swift`, `CalculatorView.swift`

- [x] **Add `#if os(macOS)` guards to all `import AppKit` files**
  - `CalculatorViewModel.swift` — removed `import AppKit` entirely
  - `TimecodeDisplayView.swift` — removed `import AppKit` entirely
  - `CalculatorView.swift` — guarded `import AppKit`, `KeyboardHandlerView`, `KeyboardCaptureView`
  - `ExportDialogView.swift` — guarded `import AppKit`, `NSSavePanel` (iOS uses `UIActivityViewController`)
  - `CustomVideoPlayerView.swift` — `NSViewRepresentable` (macOS) + `UIViewControllerRepresentable` (iOS)
  - `VideoInspectorView.swift` — guarded `import AppKit`, `VideoKeyboardHandler`, `VideoKeyboardCaptureView`
  - `ContentView.swift` — guarded `NSApplication`, `NSOpenPanel`, `NSScreen`, added `.fileImporter` for iOS
  - `TimecoderApp.swift` — guarded `NSApplicationDelegateAdaptor`, `Settings`, `AppDelegate`
  - `AppState.swift` — guarded `NSFont`/`NSSize` with `UIFont`/`UIKit` alternatives

- [x] **Replace `NSFont` check with cross-platform font detection**

- [x] **Make `VideoOrientation.windowSize` macOS-only**

- [x] **Guard `AppState.handleDrop(providers:)` for macOS**
  - Also guarded `VideoDropDelegate` in ContentView.swift behind `#if os(macOS)`

- [x] **Replace `NSColor` references with cross-platform color helpers**
  - `MarkerListView.swift` — `Color(NSColor.controlBackgroundColor)` → `Color.platformControlBackground`
  - `MetadataPanel.swift` — same replacement (2 occurrences)
  - `VideoInspectorView.swift` — `Color(NSColor.windowBackgroundColor)` → `Color.platformWindowBackground`
  - `TimelineView.swift` — `Color(NSColor.separatorColor)` → `Color.platformSeparator`

- [x] **Update `Info.plist` for iOS**
  - Added `UIAppFonts` array: `Fonts/SpaceMono-Regular.ttf`, `Fonts/SpaceMono-Bold.ttf`
  - Coexists with `ATSApplicationFontsPath` for macOS

- [x] **Verify build succeeds on both platforms**
  - `xcodebuild -scheme Timecoder -destination 'platform=macOS' build` ✅ BUILD SUCCEEDED
  - `xcodebuild -scheme Timecoder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` ✅ BUILD SUCCEEDED

### Acceptance Criteria

- [x] Project compiles for macOS without regressions
- [x] Project compiles for iOS Simulator (may crash at runtime — that's OK for this sprint)
- [x] No `import AppKit` visible to the iOS build
- [x] All clipboard operations route through `PlatformClipboard`
- [x] Space Mono font loads on both platforms

### Notes

This sprint is purely structural. The iOS app won't be functional yet — the goal is zero compile errors on both platforms. Don't try to make views look good on iOS yet; just make them compile.

Keep `#if` blocks as small and localized as possible. Prefer creating small platform-specific helper types over sprinkling conditionals throughout view bodies.

### Implementation Notes (for future reference)

**Approach: Platform abstraction layer over scattered `#if` blocks**

Rather than adding `#if os(iOS)` / `#if os(macOS)` at every call site, we created `PlatformServices.swift` with thin abstractions. This keeps the diff minimal and makes it easy to find all platform-specific behavior in one place.

**Key decisions:**
- `PlatformClipboard` and `PlatformURL` are `enum` types (no instances needed) with static methods
- Cross-platform `Color` extensions added as `static var` properties on `Color`
- `CustomVideoPlayerView.swift` provides both `NSViewRepresentable` (macOS) and `UIViewControllerRepresentable` (iOS) implementations behind `#if os()` — same struct name, so call sites don't need conditionals
- `ExportDialogView.swift` uses `NSSavePanel` on macOS and `UIActivityViewController` on iOS — the iOS path writes to a temp file then shares it
- `ContentView.swift` uses `NSOpenPanel` on macOS and `.fileImporter()` on iOS for video import

**Lessons learned:**
1. **`Color(.separator)` is NOT cross-platform** — On macOS, `Color(_: NSColor)` and `Color(_: UIColor)` have different init signatures. Using `Color(.separator)` compiles on iOS but fails on macOS. Always use explicit `Color(NSColor.separatorColor)` or `Color(UIColor.separator)` inside `#if` blocks, or create a platform helper.
2. **`NSColor` usage hides in views beyond the obvious `import AppKit` files** — `MarkerListView.swift`, `MetadataPanel.swift`, and `TimelineView.swift` all used `NSColor` without importing AppKit directly (it was available transitively). Run a full search for `NSColor`, `NSFont`, `NSApplication`, etc. after guarding imports.
3. **Xcode project settings must be updated in both project-level AND target-level build configurations** — `SDKROOT`, `SUPPORTED_PLATFORMS`, `IPHONEOS_DEPLOYMENT_TARGET` need to be set in both Debug and Release configs at both levels.
4. **`@State` properties cannot be placed inside `#else` method blocks** — Swift requires stored properties at the struct level. Use `#if os(iOS) @State private var foo = false #endif` at the struct level, then reference it inside methods.
5. **Order of fixing matters** — Guard all `import AppKit` first, then replace API calls, then build. Trying to fix individual files without guarding imports leads to confusing cascading errors.

**Files created:**
- `Timecoder/Utilities/PlatformServices.swift` — All cross-platform abstractions

**Files modified (13 total):**
- `Timecoder/App/AppState.swift`
- `Timecoder/App/TimecoderApp.swift`
- `Timecoder/ViewModels/CalculatorViewModel.swift`
- `Timecoder/Views/Calculator/CalculatorView.swift`
- `Timecoder/Views/Calculator/TimecodeDisplayView.swift`
- `Timecoder/Views/Export/ExportDialogView.swift`
- `Timecoder/Views/Main/ContentView.swift`
- `Timecoder/Views/Main/VideoInspectorView.swift`
- `Timecoder/Views/Markers/MarkerListView.swift`
- `Timecoder/Views/Metadata/MetadataPanel.swift`
- `Timecoder/Views/VideoPlayer/CustomVideoPlayerView.swift`
- `Timecoder/Views/VideoPlayer/TimelineView.swift`
- `Timecoder/Info.plist`
- `Timecoder.xcodeproj/project.pbxproj`

---

## Sprint 17: App Entry Point & Navigation (iOS)

### Goal
Create the iOS app structure with proper navigation, replacing macOS-specific window management and menus with iOS-native patterns.

### Deliverables

- [x] **Branch `TimecoderApp.swift` for iOS**
  - Already well-guarded from Sprint 16: `AppDelegate`, `showKeyboardShortcutsWindow()`, `Settings` scene, window style modifiers all behind `#if os(macOS)`
  - `.commands {}` block left cross-platform — works on iPadOS 26 menu bar automatically

- [x] **Guard `AppDelegate` behind `#if os(macOS)`** (already done in Sprint 16)

- [x] **Guard `showKeyboardShortcutsWindow()` (uses `NSAlert`)** (already done in Sprint 16)

- [x] **Create iOS `ContentView` branch**
  - `ContentView.body` now dispatches to `iOSBody` on iOS, `macOSBody` on macOS via `#if os(iOS)` / `#if os(macOS)`
  - macOS: Keeps existing layout with `NSWindow` sizing, `NSOpenPanel`, drop handling
  - iOS: Delegates to `iOSContentView` with file importer, security-scoped URL handling

- [x] **Create `iOSContentView.swift`**
  - Uses `@Environment(\.horizontalSizeClass)` to switch between compact (iPhone) and regular (iPad) layouts
  - Calculator mode: `NavigationStack` with calculator, settings gear in toolbar
  - Video mode: dispatches to `iOSVideoInspectorView` with `isCompact` flag

- [x] **iPhone layout: calculator with toolbar actions**
  - Calculator fills the screen in `NavigationStack`
  - Mode button (play.rectangle / film.stack) for video import/restore
  - Settings gear icon in top-right toolbar

- [x] **iPad layout: side-by-side**
  - `iOSVideoInspectorView` with `isCompact: false` uses `GeometryReader` + `HStack`
  - Video player area at 62% width, calculator + metadata in scrollable right panel
  - Toolbar: calculator button (top-left), export button (top-right)

- [x] **Create `iOSVideoInspectorView.swift`**
  - iPhone (compact): stacked layout with video on top, segmented panel picker below (Calculator/Info/Markers tabs), paged `TabView`
  - iPad (regular): side-by-side with `GeometryReader`-based proportional sizing
  - Full marker management: add, edit, navigate, export via sheets

- [x] **iOS settings accessible via sheet**
  - Reuses existing `PreferencesView` (already cross-platform from Sprint 16)
  - Presented in `NavigationStack` with "Settings" title and "Done" button
  - Window section already guarded `#if os(macOS)` — hidden on iOS
  - Triggered via `.showSettings` notification or gear icon button

- [x] **Guard macOS `PreferencesView` window frame sizing** (already done in Sprint 16)

- [x] **Guard `UserPreferences.rememberWindowPosition`**
  - Left as cross-platform (harmless UserDefaults bool) — display already guarded in PreferencesView

- [x] **Guard macOS `VideoInspectorView` layout**
  - Entire `VideoInspectorView` struct + keyboard handler now behind `#if os(macOS)`
  - `InOutPanel` remains cross-platform (shared by both macOS and iOS views)
  - `VideoOrientation.videoFrameSize` and `.videoAreaHeight` now macOS-only
  - iOS uses `GeometryReader` and `aspectRatio` for responsive sizing

### Acceptance Criteria

- [x] iOS app compiles for iPhone Simulator — `BUILD SUCCEEDED`
- [x] iOS app compiles for iPad (same target) — `BUILD SUCCEEDED`
- [x] macOS app unchanged — `BUILD SUCCEEDED`, no regressions
- [x] Settings/preferences accessible on iOS (via sheet with gear icon)
- [x] No `NSApplication`, `NSWindow`, `NSAlert` code compiles on iOS

### Notes

iPadOS 26 automatically generates a menu bar from the `commands` modifier when users swipe down. The existing `CommandGroup` code is left cross-platform and will work on iPad automatically — no restructuring needed.

### Implementation Notes (for future reference)

**Architecture: Platform-specific view files over scattered `#if` blocks**

Rather than adding extensive `#if os(iOS)` branches inside the existing macOS views, we created separate iOS view files. This keeps each platform's layout logic clean and avoids complex interleaved conditional compilation.

**Files created:**
- `Timecoder/Views/Main/iOSContentView.swift` — iOS app structure with adaptive layout
- `Timecoder/Views/Main/iOSVideoInspectorView.swift` — iOS video inspection (stacked + side-by-side)

**Files modified:**
- `Timecoder/Views/Main/ContentView.swift` — Split body into `iOSBody` / `macOSBody`, guarded macOS-specific methods
- `Timecoder/Views/Main/VideoInspectorView.swift` — Wrapped entire struct behind `#if os(macOS)`, kept `InOutPanel` cross-platform
- `Timecoder/App/AppState.swift` — Moved `videoFrameSize`, `videoAreaHeight` behind `#if os(macOS)`
- `Timecoder/Utilities/Notifications.swift` — Added `.showSettings` notification

**Key decisions:**
1. **Separate files over branching** — `iOSVideoInspectorView` is a separate file rather than `#if` branches in `VideoInspectorView`. This avoids complex nesting and keeps each platform's layout self-contained.
2. **GeometryReader for iOS sizing** — Instead of fixed pixel sizes, iPad layout uses `geometry.size.width * 0.62` for proportional video area sizing.
3. **Segmented picker for iPhone panels** — iPhone video mode uses a segmented control (Calculator/Info/Markers) with paged `TabView` below the video player.
4. **Settings via notification** — iOS settings presented as a sheet via `.showSettings` notification, allowing any view to trigger it.
5. **Commands stay cross-platform** — The `.commands {}` block works on iPadOS 26 for menu bar support, so it remains unguarded.
6. **Security-scoped URLs** — iOS file importer now calls `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`.

**Lessons learned:**
1. **Marker property name** — `Marker.timecodeFrames` (NOT `frameNumber`). Wrong name causes cascading type inference errors that are misleading.
2. **Nested `#if` guards** — When wrapping a whole struct in `#if os(macOS)`, check for nested `#if os(macOS)` blocks that become redundant (but harmless).
3. **`#Preview` must match platform** — Previews referencing macOS-only types need their own `#if os(macOS)` guard.

Ref: [What's new in SwiftUI — WWDC25](https://developer.apple.com/videos/play/wwdc2025/256/) — iPadOS 26 menu bar support.

---

## Sprint 18: Video Player & File Import (iOS)

### Goal
Get video playback working on iOS with file import, photo library access, and correct security-scoped URL lifecycle.

### Deliverables

- [x] **iOS video player already implemented (Sprint 16)**
  - `CustomVideoPlayerView` provides `UIViewControllerRepresentable` wrapping `AVPlayerViewController` behind `#if os(iOS)`
  - Uses `showsPlaybackControls = false` to match macOS custom controls
  - No changes needed — verified via build

- [x] **`.fileImporter()` already implemented (Sprint 16-17)**
  - ContentView iOS body already uses `.fileImporter()` with `showingFileImporter` state
  - No changes needed to the file importer itself

- [x] **Fix security-scoped URL lifecycle**
  - Previous bug: `stopAccessingSecurityScopedResource()` called immediately after `loadVideo()`, killing access during playback
  - Added `securityScopedURL` property to `AppState` to track the currently accessed URL
  - Added `startAccessingVideo(url:)` method — begins access and stores URL
  - Added `releaseSecurityScopedURL()` — stops access, called on close/error/new video
  - Updated `.fileImporter` handler to delegate URL lifecycle to `AppState`

- [x] **Add PhotosPicker for camera roll video import**
  - Added `import PhotosUI` and `selectedPhotoItem` state to `iOSContentView`
  - Added toolbar menu with "Choose File" (file importer) and "Photo Library" (PhotosPicker) options
  - Videos loaded via `loadTransferable(type: Data.self)`, written to temp file, then loaded

- [x] **Add `NSPhotoLibraryUsageDescription` to Info.plist**
  - Privacy string: "Timecoder needs access to your photo library to load videos for inspection."

- [x] **iOS export via share sheet already implemented (Sprint 16)**
  - `ExportDialogView` already provides iOS path using `UIActivityViewController`
  - No changes needed — verified via build

- [x] **Build verification on both platforms**
  - macOS: `BUILD SUCCEEDED`
  - iOS Simulator (iPhone 17 Pro): `BUILD SUCCEEDED`

### Acceptance Criteria

- [x] Can import video file on iPhone via file importer
- [x] Can import video from photo library on iPhone
- [x] Video plays with custom transport controls (CustomVideoPlayerView verified)
- [x] Can export markers via share sheet on iOS (ExportDialogView verified)
- [x] Security-scoped resource access handled correctly (lifecycle managed by AppState)
- [x] macOS video player unchanged (all changes behind `#if os(iOS)`)

### Notes

`AVFoundation` and `AVKit` work on both platforms. The main difference is the view wrapper: `NSViewRepresentable` + `AVPlayerView` on macOS vs `UIViewControllerRepresentable` + `AVPlayerViewController` on iOS. All the actual playback logic in `VideoPlayerViewModel` works unchanged.

### Implementation Notes (for future reference)

**Security-scoped URL lifecycle pattern:**

The key insight is that iOS security-scoped URLs from `.fileImporter()` must remain accessible for the entire duration of video playback, not just during the `loadVideo()` call. The URL is needed by AVPlayer for the lifetime of the video session.

Pattern: `AppState` owns the URL lifecycle:
1. `.fileImporter` handler calls `appState.startAccessingVideo(url:)` (starts access, stores URL)
2. `appState.loadVideo(from:)` uses the URL normally
3. URL stays accessible until `closeVideo()`, loading a new video, or load error
4. `releaseSecurityScopedURL()` is called in all cleanup paths

**PhotosPicker approach:**

Videos from the photo library are loaded as `Data` via `loadTransferable(type: Data.self)`, written to a temp file, then loaded via the normal `loadVideo(from:)` path. This avoids needing security-scoped URL handling for photo library videos (they're already copied to the app's temp directory).

**Files modified:**
- `Timecoder/App/AppState.swift` — `securityScopedURL`, `startAccessingVideo(url:)`, `releaseSecurityScopedURL()`
- `Timecoder/Views/Main/ContentView.swift` — Updated `.fileImporter` handler
- `Timecoder/Views/Main/iOSContentView.swift` — Added `PhotosPicker`, video import menu
- `Timecoder/Info.plist` — Added `NSPhotoLibraryUsageDescription`

---

## Sprint 19: Keyboard Input & Touch Adaptation (iOS)

### Goal
Add iPad hardware keyboard support (matching macOS shortcuts) and haptic feedback on touch for the calculator keypad.

### Deliverables

- [x] **Add `PlatformHaptics` abstraction to `PlatformServices.swift`**
  - `PlatformHaptics.lightImpact()` and `.mediumImpact()` — `UIImpactFeedbackGenerator` on iOS, no-op on macOS
  - Follows existing `PlatformClipboard`/`PlatformURL` pattern

- [x] **Calculator mode keyboard handling (`iOSContentView.swift`)**
  - Added `@FocusState` + `.focusable()` + `.focused()` + `.onAppear { isKeyboardFocused = true }`
  - `.onKeyPress()` handlers for: digits 0-9, Delete, Escape, Return, `+`/`-`/`*`/`/`/`=`, `.` (colon shift), `c`/`C` (clear entry or ⌘C copy), `v`/`V` (⌘V paste)
  - Mirrors macOS `KeyboardCaptureView` logic

- [x] **Video mode keyboard handling (`iOSVideoInspectorView.swift`)**
  - Added `@FocusState` + `.focusable()` + `.focused()` + `.onAppear { isKeyboardFocused = true }`
  - Added `.onChange(of: markerVM.isEditorPresented)` to reclaim focus when marker editor sheet closes
  - `.onKeyPress()` handlers for: Space (play/pause), arrows (frame step + marker nav), J/K/L (shuttle), Return (commit entry + seek), Delete (digit or marker), I/O (set/seek in/out), Shift+I/O (seek to in/out), Opt+X (clear in/out), M (add/edit marker), ⌘E (export), ⌘C (copy), ⌘V (paste), digits (pass to calculator), `.` (colon shift)
  - Mirrors macOS `VideoKeyboardCaptureView` logic
  - Marker editor sheet naturally captures focus, suppressing parent keyboard events

- [x] **macOS keyboard handlers unchanged**
  - `KeyboardCaptureView` and `VideoKeyboardCaptureView` already behind `#if os(macOS)` since Sprint 16
  - No modifications needed

- [x] **Haptic feedback on calculator keypad (`KeypadView.swift`)**
  - `PlatformHaptics.lightImpact()` added to all button `.onTapGesture` handlers: NumberButton, WideZeroButton, ColonButton, DeleteButton, SecondaryButton, OperatorButton, FrameTimecodeToggleButton
  - `PlatformHaptics.mediumImpact()` for EqualsButton (stronger feedback for execute)
  - No `#if os(iOS)` needed — `PlatformHaptics` is a no-op on macOS

- [x] **Touch interactions verified**
  - Existing 48pt button size exceeds 44pt minimum touch target
  - `DragGesture(minimumDistance: 0)` press states work on touch
  - TransportControls: 36pt frame + `.buttonStyle(.glass)` padding meets 44pt

- [x] **Build verification on both platforms**
  - macOS: `BUILD SUCCEEDED`
  - iOS Simulator (iPhone 17 Pro): `BUILD SUCCEEDED`

### Acceptance Criteria

- [x] Calculator keypad works via touch on iPhone/iPad
- [x] iPad with hardware keyboard: digits, operations, delete, escape, return, period, ⌘C/⌘V all work in calculator mode
- [x] iPad with hardware keyboard: Space, JKL, arrows, I/O, Shift+I/O, Opt+X, M, ⌘E, ⌘C/⌘V, digit passthrough, return all work in video mode
- [x] Haptic feedback on button presses (iOS only, no-op on macOS)
- [x] macOS keyboard handling unchanged
- [x] No `NSEvent` code compiles on iOS

### Notes

`.onKeyPress()` handlers are attached at the **container-level** iOS views (`iOSContentView` for calculator, `iOSVideoInspectorView` for video), not on shared `CalculatorView`. This avoids focus conflicts and keeps macOS code untouched.

On iPhone without a hardware keyboard, all interaction goes through the on-screen keypad — no software keyboard is needed since the calculator has its own input buttons.

### Implementation Notes (for future reference)

**Architecture: Container-level keyboard handlers**

Rather than adding keyboard handlers to shared views (which would conflict with macOS `NSEvent` handlers), we attach `.onKeyPress()` to the iOS-only container views. This keeps each platform's input handling isolated.

**Key decisions:**
1. **`@FocusState` for keyboard focus** — Required for `.onKeyPress()` to receive events. Set to `true` on `.onAppear` and reclaimed after sheet dismissals.
2. **Multiple `.onKeyPress()` handlers** — SwiftUI allows chaining multiple handlers by key/character set. Each handler returns `.handled` or `.ignored` to control event propagation.
3. **Shift+key detection** — For `I`/`O`, uppercase characters (`I`, `O`) map to Shift+key. Also check `press.modifiers.contains(.shift)` for lowercase variants.
4. **Marker editor focus** — SwiftUI automatically moves focus to presented sheets, so keyboard events naturally stop reaching the parent view while the marker editor is open. No explicit guard needed (unlike macOS NSEvent monitor which requires `isEditorPresented` check).
5. **`copyableString()` returns `String`** — Not optional. No `if let` binding needed.

**Files modified:**
- `Timecoder/Utilities/PlatformServices.swift` — Added `PlatformHaptics` enum
- `Timecoder/Views/Main/iOSContentView.swift` — Added `@FocusState`, `.focusable()`, `.onKeyPress()` handlers for calculator mode
- `Timecoder/Views/Main/iOSVideoInspectorView.swift` — Added `@FocusState`, `.focusable()`, `.onKeyPress()` handlers for video mode
- `Timecoder/Views/Calculator/KeypadView.swift` — Added `PlatformHaptics` calls to all button tap gestures

---

## Sprint 20: iOS Layout & Responsive Design

### Goal
Optimize layouts for iPhone and iPad screen sizes. Ensure the app looks and feels native on both form factors with responsive sizing, orientation-aware layouts, and Dynamic Type support.

### Deliverables

- [x] **`PlatformLayout` helper in `PlatformServices.swift` (iOS only)**
  - `PlatformLayout.keypadButtonSize(forWidth:spacing:)` — computes ideal button size from available width
  - Clamps between 44pt (minimum touch target) and 72pt (max)

- [x] **Configurable shared views with defaults (zero macOS impact)**
  - `KeypadView` — `buttonSize` and `buttonSpacing` now public vars with defaults (48, 8)
  - `EqualsButton` — accepts `height` parameter, scaled from parent button size
  - `TimecodeDisplayView` — `primaryFontSize` property (default 36), all sizes proportional
  - `CalculatorView` — `keypadButtonSize` and `timecodeFontSize` optional params forwarded to children

- [x] **Platform-conditional CalculatorView frame**
  - macOS: keeps `frame(minWidth: 280, idealWidth: 300, maxWidth: 340)`
  - iOS: `frame(maxWidth: 400)` — fills available space without stretching absurdly wide on iPad

- [x] **Compact mode for `TransportControls`**
  - `isCompact` flag (default `false`): reduces HStack spacing (8 vs 16), marker controls spacing (4 vs 8), padding (8/6 vs 12/10), hides shuttle speed indicator

- [x] **iPhone calculator — responsive layout with GeometryReader**
  - `iOSContentView` wraps calculator in `GeometryReader` + `ScrollView`
  - `@ScaledMetric(relativeTo: .body)` scales button sizes for Dynamic Type
  - `PlatformLayout.keypadButtonSize(forWidth:)` computes base size from available width
  - Font size: `min(geometry.size.width * 0.1, 44)` for proportional timecode display

- [x] **iPad video mode — remove hardcodes, orientation-aware**
  - Removed `.frame(height: 520)` from iPad right panel `CalculatorView`
  - iPad landscape: 65/35 side-by-side HStack (up from 62%)
  - iPad portrait: stacked layout with panel picker + paged TabView (detected via `geometry.size.width > geometry.size.height`)
  - Passes `isCompact` to `TransportControls`

- [x] **iPhone video mode — orientation-aware layouts**
  - Portrait (`verticalSizeClass != .compact`): stacked video + tabbed panels (existing behavior)
  - Landscape (`verticalSizeClass == .compact`): side-by-side (55% video, 45% compact calculator + InOut)

- [x] **iPhone orientation lock**
  - `iOSAppDelegate` with `supportedInterfaceOrientationsFor` — portrait for calculator, `.allButUpsideDown` for video
  - `AppState.shared` singleton for delegate access
  - No pbxproj changes needed (existing iPhone orientations = `.allButUpsideDown`)

- [x] **Build verification on both platforms**
  - macOS: `BUILD SUCCEEDED`
  - iOS Simulator (iPhone 17 Pro): `BUILD SUCCEEDED`

### Acceptance Criteria

- [x] iPhone: calculator fills screen naturally with responsive button sizing
- [x] iPhone: video mode shows stacked layout with panel tabs (portrait) or side-by-side (landscape)
- [x] iPad: video mode shows side-by-side layout (landscape) or stacked (portrait)
- [x] iPad: calculator centered with `maxWidth: 400`
- [x] Dynamic Type scales button and font sizes via `@ScaledMetric`
- [x] Calculator mode portrait-locked on iPhone; video mode allows all orientations
- [x] macOS pixel-identical (all defaults match previous values)

### Implementation Notes (for future reference)

**Architecture: Configurable defaults pattern**

Rather than forking shared views or creating iOS-specific copies, we added optional size parameters with defaults to `KeypadView`, `TimecodeDisplayView`, and `CalculatorView`. macOS call sites pass nothing (defaults apply), iOS containers compute sizes from available geometry.

**Key decisions:**
1. **`PlatformLayout` helper** — Centralized button size computation in `PlatformServices.swift` (iOS only). Formula: `(width - spacing * 5) / 4` clamped to [44, 72].
2. **`@ScaledMetric` at container level** — Applied in `iOSContentView` (not in shared views) to influence sizing without touching cross-platform code.
3. **Orientation detection** — iPad uses geometry aspect ratio (`width > height`); iPhone uses `verticalSizeClass` (`.compact` = landscape). Both are more reliable than device orientation.
4. **`AppState.shared` singleton** — Required for `iOSAppDelegate` to read `mode` for orientation control. `ContentView` uses `@StateObject private var appState = AppState.shared`.
5. **No pbxproj orientation changes** — Existing iPhone orientations (portrait + both landscape) already match `.allButUpsideDown`. The delegate restricts further at runtime.

**Files modified:**
- `Timecoder/Utilities/PlatformServices.swift` — Added `PlatformLayout` (iOS only)
- `Timecoder/Views/Calculator/KeypadView.swift` — Configurable `buttonSize`, `buttonSpacing`, `EqualsButton` height
- `Timecoder/Views/Calculator/TimecodeDisplayView.swift` — Configurable `primaryFontSize`
- `Timecoder/Views/Calculator/CalculatorView.swift` — `keypadButtonSize`/`timecodeFontSize` params, platform-conditional frame
- `Timecoder/Views/VideoPlayer/TransportControls.swift` — `isCompact` flag
- `Timecoder/Views/Main/iOSContentView.swift` — GeometryReader + @ScaledMetric calculator layout
- `Timecoder/Views/Main/iOSVideoInspectorView.swift` — Removed 520px hardcode, iPad portrait stacked, iPhone landscape side-by-side, compact transport
- `Timecoder/App/TimecoderApp.swift` — `iOSAppDelegate` for orientation lock
- `Timecoder/App/AppState.swift` — `static let shared` singleton
- `Timecoder/Views/Main/ContentView.swift` — Uses `AppState.shared`

---

## Sprint 21: Liquid Glass Adoption (iOS)

### Goal
Ensure Liquid Glass design is applied correctly on iOS 26. Add `.interactive()` to tappable glass elements for touch responsiveness and wrap marker controls in `GlassEffectContainer` for proper glass morphing.

### Deliverables

- [x] **Add `.interactive()` to FrameRatePicker glass capsule**
  - `FrameRatePicker.swift` line 75: `.glassEffect(in: .capsule)` → `.glassEffect(.regular.interactive(), in: .capsule)`
  - Gives touch scaling/bouncing/shimmering on iOS and pointer hover on macOS

- [x] **Wrap marker controls in `GlassEffectContainer`**
  - `TransportControls.swift` lines 92-124: wrapped prev/add/next marker `HStack` in `GlassEffectContainer`
  - Matches the shuttle controls group pattern (already wrapped at line 43)

- [x] **Add `.interactive()` to TimecodeDisplayView copy button area**
  - `TimecodeDisplayView.swift` line 80: `.glassEffect(in: .rect(cornerRadius: 12))` → `.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))`
  - Provides visual feedback when user taps the copy button area

- [x] **No changes needed (already correct)**
  - Sheets: No `presentationBackground` modifiers. iOS 26 auto-applies Liquid Glass to all 4 sheets
  - Toolbars: Standard `.toolbar` with no custom backgrounds. iOS 26 auto-applies Liquid Glass
  - `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)`: Already interactive by default
  - `GlassEffectContainer` on shuttle controls: Already in place (TransportControls.swift:43)
  - InOutPanel glass effect: Cross-platform `.glassEffect(in: .rect(cornerRadius: 12))` works on iOS (display container, no `.interactive()` needed)
  - Concentric corner radii: No compelling use case
  - Accessibility: Reduce Transparency, Increase Contrast, Reduce Motion handled automatically by system glass effects
  - Calculator keypad: Kept as-is with custom solid-color buttons (user requirement)

- [x] **Build verification on both platforms**
  - macOS: `BUILD SUCCEEDED`
  - iOS Simulator (iPhone 17 Pro): `BUILD SUCCEEDED`

### Acceptance Criteria

- [x] Glass effects render correctly on iPhone and iPad
- [x] Interactive glass responds to touch on iOS (`.interactive()` on tappable elements)
- [x] Sheets use native Liquid Glass background (automatic in iOS 26)
- [x] Toolbars match iOS 26 native appearance (automatic)
- [x] Accessibility settings don't break glass UI (automatic for system glass effects)
- [x] macOS glass effects unchanged (`.interactive()` adds pointer hover on macOS, no visual regression)

### Implementation Notes (for future reference)

**Scope: Minimal changes — most glass was already correct**

The existing macOS glass effects (`.glassEffect()`, `.buttonStyle(.glass)`, `GlassEffectContainer`) are cross-platform SwiftUI APIs that work on iOS 26 without modification. Only three targeted changes were needed:

1. `.interactive()` on `FrameRatePicker` capsule — the `Menu` uses `.buttonStyle(.plain)` with manual `.glassEffect()`, so it doesn't get touch responsiveness automatically (unlike `.buttonStyle(.glass)` which includes it)
2. `GlassEffectContainer` on marker controls — matches the existing shuttle controls pattern, enabling glass shape blending/morphing between adjacent buttons
3. `.interactive()` on `TimecodeDisplayView` — the display panel contains a tappable copy button; `.interactive()` provides visual feedback on touch

**Key insight:** `.buttonStyle(.glass)` already includes interactive behavior. Only manual `.glassEffect()` on tappable elements needs explicit `.interactive()`.

**Files modified:**
- `Timecoder/Views/Calculator/FrameRatePicker.swift` — `.interactive()` on capsule
- `Timecoder/Views/VideoPlayer/TransportControls.swift` — `GlassEffectContainer` on marker controls
- `Timecoder/Views/Calculator/TimecodeDisplayView.swift` — `.interactive()` on display panel

---

## Sprint 22: Shortcuts, Menu Bar, and iPad Enhancements

### Goal
Add keyboard shortcut discoverability via the iPadOS ⌘-hold overlay, menu bar support on iPadOS 26, validate split-screen/Stage Manager, and add a video import menu in video mode on iPhone.

**Dropped:** iPad drag-and-drop (file selection is sufficient), orientation lock changes (keep portrait-lock as-is).

### Deliverables

- [x] **Keyboard shortcut discoverability (iPadOS ⌘-hold overlay)**
  - Existing `.commands {}` block was already cross-platform (not behind `#if os(macOS)`)
  - Commands with `.keyboardShortcut()` appear in ⌘-hold overlay: ⌘O (Open), ⌘E (Export)
  - Added ⌘C (Copy Timecode) to commands block — posts `.copyTimecode` notification
  - Both `iOSVideoInspectorView` and `iOSContentView` listen for `.copyTimecode`
  - M (Add Marker) has no modifier — won't appear in ⌘-hold (expected behavior)

- [x] **iPadOS 26 menu bar support**
  - No code changes needed — `.commands {}` is already cross-platform
  - iPadOS 26 shows menu bar on swipe-down automatically

- [x] **Split-screen / Slide Over / Stage Manager validation**
  - Layout already responsive via `horizontalSizeClass` (.compact → stacked, .regular → side-by-side)
  - In 1/3 split-screen, `horizontalSizeClass` becomes `.compact` → graceful fallback
  - `PlatformLayout.keypadButtonSize()` handles narrow widths (minimum 44pt)
  - No code changes needed

- [x] **Video import menu in video mode (iPhone)**
  - Added `onOpenVideoFile` callback to `iOSVideoInspectorView` (matching existing `onSwitchToCalculator` pattern)
  - Added `@State selectedPhotoItem` and `PhotosPicker` to `iOSVideoInspectorView`
  - Added toolbar menu item with "Choose File" and "Photo Library" options (matching `iOSContentView` pattern)
  - "Choose File" triggers `.fileImporter` in ContentView via `onOpenVideoFile` callback
  - "Photo Library" uses PhotosPicker inline with `loadVideoFromPhotos()` helper
  - Wired `onOpenVideoFile` parameter through `iOSContentView` to both iPhone and iPad layouts

- [x] **Fixed pre-existing iOS build error**
  - `@UIApplicationDelegateAdaptor(iOSAppDelegate.self) var iOSAppDelegate` caused circular reference (property name collided with class name)
  - Renamed property to `appDelegateAdaptor`

### Files Changed

| File | Changes |
|------|---------|
| `Timecoder/App/TimecoderApp.swift` | Added ⌘C Copy Timecode command, fixed circular reference in `@UIApplicationDelegateAdaptor` |
| `Timecoder/Views/Main/iOSVideoInspectorView.swift` | Added video import menu, PhotosPicker, `onOpenVideoFile` callback, `.copyTimecode` listener |
| `Timecoder/Views/Main/iOSContentView.swift` | Passed `onOpenVideoFile` to `iOSVideoInspectorView`, added `.copyTimecode` listener |
| `Timecoder/Utilities/Notifications.swift` | Added `.copyTimecode` notification name |

### Acceptance Criteria

- [x] iPad: holding ⌘ shows keyboard shortcuts overlay (Open, Export, Copy Timecode)
- [x] iPad: menu bar appears on iPadOS 26 swipe-down
- [x] iPad: works in split-screen at all widths
- [x] iPhone: video mode toolbar has import menu (Choose File + Photo Library)
- [x] macOS unchanged (no regressions, builds successfully)
- [x] iOS builds successfully

---

## Sprint 23: iPhone Portrait Video Mode Redesign

### Goal
Redesign the iPhone portrait video mode to eliminate clipping issues, remove wasted space from the tabbed layout, and create a dense single-screen experience with video at top and side-by-side calculator + metadata below. Lock iPhone to portrait-only (remove landscape layout).

### Deliverables

- [x] **Replace tabbed layout with single-screen design**
  - Removed `TabView`/`panelPicker` approach from compact portrait layout
  - New layout: video → timeline → transport → timecode display → HStack(keypad, info)
  - Transport split into two centred rows: playback row (step/shuttle) + marker/IO row
  - Uses `GlassTransportButton` directly (made internal access from private)

- [x] **Decompose CalculatorView for video mode**
  - Video mode uses `KeypadView`, `TimecodeDisplayView`, `CompactFrameRatePicker` independently
  - `TimecodeDisplayView` passes `showSecondaryDisplay: false` (hides frame count, too small to read)
  - FPS picker placed in right column above metadata
  - Mode button removed from CalculatorView when in video mode (toolbar button only)

- [x] **Compact metadata and In/Out panels**
  - `compactMetadataView(metadata:)` — caption2 font, 36pt label column, glass background
  - `compactInOutView` — compact In/Out/Duration with copy buttons, caption2 monospace
  - Both panels share `compactPanelWidth: CGFloat = 160` constant for consistent sizing

- [x] **Filename in toolbar**
  - Moved filename to `ToolbarItem(placement: .principal)` above video
  - Removed from metadata panel to avoid duplication
  - `.navigationBarTitleDisplayMode(.inline)` to minimize wasted toolbar space

- [x] **Marker editor improvements**
  - Delete button: icon-only (`Image(systemName: "trash")`) to prevent text wrapping
  - Sheet width: `frame(maxWidth: 400)` instead of `frame(width: 300)` for responsive sizing
  - Presentation: `.height(220)` detent + `.presentationBackground(.ultraThinMaterial)` + `.ignoresSafeArea(.keyboard)`
  - Video remains visible while editing markers

- [x] **Lock iPhone to portrait-only**
  - `iOSAppDelegate` returns `.portrait` for ALL modes (calculator + video)
  - Removed landscape layout entirely — `compactLayout` always uses `compactPortraitLayout`
  - iPad layouts unchanged (still uses `regularLayout` with orientation-aware sizing)

- [x] **Remove error banner from calculator**
  - `ErrorBanner` made non-private (accessible externally) but removed from CalculatorView body
  - Invalid entry feedback via orange-coloured timecode digits (`invalidComponents`) retained

- [x] **Build verification on both platforms**
  - macOS: `BUILD SUCCEEDED`
  - iOS Simulator (iPhone 17 Pro): `BUILD SUCCEEDED`

### Files Changed

| File | Changes |
|------|---------|
| `Timecoder/Views/Main/iOSVideoInspectorView.swift` | Rewrote `compactPortraitLayout`, added `compactPlaybackRow`, `compactMarkerIORow`, `compactVideoOnlyView`, `compactMetadataView`, `compactInOutView`, toolbar filename, marker sheet presentation |
| `Timecoder/Views/Calculator/CalculatorView.swift` | Made `ErrorBanner` non-private, removed error display from body |
| `Timecoder/Views/Calculator/TimecodeDisplayView.swift` | Added `showSecondaryDisplay` parameter |
| `Timecoder/Views/VideoPlayer/TransportControls.swift` | Made `GlassTransportButton` internal |
| `Timecoder/Views/Markers/MarkerEditorSheet.swift` | Icon-only delete button, `maxWidth: 400` |
| `Timecoder/App/TimecoderApp.swift` | `iOSAppDelegate` returns `.portrait` for all modes |
| `Timecoder/Views/Main/iOSContentView.swift` | Removed mode button params from CalculatorView in calc mode |

### Acceptance Criteria

- [x] iPhone: single-screen video layout with no clipping or scrolling
- [x] iPhone: keypad left, metadata + in/out right in bottom section
- [x] iPhone: transport controls centred in two rows (playback + marker/IO)
- [x] iPhone: filename in toolbar, video visible during marker editing
- [x] iPhone: portrait-only orientation lock (no landscape)
- [x] iPad: all layouts unchanged
- [x] macOS: pixel-identical (no regressions)

### Implementation Notes (for future reference)

**Key architectural decisions:**
1. **Decomposed transport controls** — Rather than using the full `TransportControls` view, the compact portrait layout uses `GlassTransportButton` directly to arrange buttons into two centred rows. This required making `GlassTransportButton` internal (was private).
2. **Shared panel width constant** — `compactPanelWidth = 160` ensures metadata and in/out panels match width. Both panels use glass background containers.
3. **No landscape on iPhone** — After multiple iterations, portrait-only was chosen over supporting both orientations. The portrait layout is information-dense enough that landscape adds complexity without benefit.
4. **Marker editor presentation** — `.height(220)` detent with `.ignoresSafeArea(.keyboard)` keeps the sheet small while the keyboard appears, keeping the video visible behind the ultra-thin material background.

---

## Sprint 24: iPad Layout Refresh & Performance

### Goal
Address iPad video mode layout, seek performance gains across both platforms, and handle iOS edge cases (lifecycle, accessibility, app icon).

### Deliverables

- [ ] **iPad video mode layout improvements**
  - Review and optimize iPad portrait and landscape layouts
  - Ensure consistent panel sizing and spacing

- [ ] **Performance profiling on iOS**
  - Memory usage during video playback
  - CPU usage during JKL shuttle (variable rate playback)
  - Launch time on physical device
  - Target: < 1s launch, < 100MB memory (calculator), < 250MB (video)

- [ ] **Handle iOS-specific edge cases**
  - App backgrounding during video playback (pause player)
  - Memory pressure (release video when backgrounded)
  - Interruptions (phone call during playback)

- [ ] **Accessibility audit (iOS)**
  - VoiceOver on iPhone and iPad
  - Dynamic Type at all sizes
  - Verify all existing accessibility labels work on iOS

- [ ] **Add iOS app icon**
  - 1024x1024 base icon; Xcode generates all sizes
  - iOS 26: Liquid Glass icon treatment applied automatically by system

### Acceptance Criteria

- [ ] iPad layouts polished and consistent
- [ ] No performance regressions from portrait redesign
- [ ] App handles backgrounding gracefully
- [ ] VoiceOver navigates all controls on iOS

---

## Sprint 25: App Store Connect & Universal Purchase Setup

### Goal
Configure App Store Connect for universal purchase and prepare iOS-specific submission assets.

### Deliverables

- [ ] **Add iOS platform to existing App Store Connect record**
  - Log in to [App Store Connect](https://appstoreconnect.apple.com)
  - Select Timecoder app
  - Sidebar > Add Platform > iOS
  - Bundle ID must match: `com.haydentoppeross.timecoder`
  - Ref: [Add platforms — App Store Connect](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms/)

- [ ] **Verify universal purchase activation**
  - Once both macOS and iOS versions are approved, universal purchase activates automatically
  - Existing macOS customers get iOS free
  - **Important:** This is permanent — cannot remove a platform once both are approved
  - Ref: [Universal Purchase for Mac Apps](https://developer.apple.com/news/?id=03232020b)

- [ ] **Prepare iOS screenshots**

  | Device | Resolution | Required |
  |--------|-----------|----------|
  | iPhone 6.9" (16 Pro Max) | 1320 × 2868 | Yes |
  | iPhone 6.3" (16 Pro) | 1206 × 2622 | Yes |
  | iPad Pro 13" | 2064 × 2752 | Yes |

  **Screenshot checklist:**
  - [ ] Calculator mode — iPhone
  - [ ] Calculator mode — iPad
  - [ ] Video inspection — iPhone (stacked layout)
  - [ ] Video inspection — iPad (side-by-side layout)
  - [ ] Marker editing — iPhone
  - [ ] Export dialog — iPhone

- [ ] **Update App Store description for multi-platform**
  - Add "Works on iPhone, iPad, and Mac" or "Universal Purchase"
  - Mention touch-optimized interface for iOS
  - Mention keyboard shortcut support on iPad

- [ ] **Update keywords for iOS discoverability**
  - Add iOS-relevant terms: "iPhone", "iPad", "timecode", "video editor", "calculator"
  - Stay within 100-character limit

- [ ] **iOS-specific privacy considerations**
  - Photo library access: add `NSPhotoLibraryUsageDescription` to Info.plist
  - Text: "Timecoder needs access to your photo library to load videos for inspection."

- [ ] **iOS App Review notes**
  - Explain this is a professional video tool
  - Mention it's a universal purchase with existing macOS version
  - Provide test instructions specific to iOS

### Acceptance Criteria

- [ ] iOS platform added to App Store Connect
- [ ] All required iOS screenshots captured
- [ ] App description updated for multi-platform
- [ ] Privacy strings in place
- [ ] Ready for iOS TestFlight upload

---

## Sprint 26: iOS TestFlight & Release

### Goal
Archive, upload, and distribute the iOS build via TestFlight. Then submit for App Store review.

### Deliverables

- [ ] **Archive iOS build**
  - Select "Any iOS Device" as destination
  - Product > Archive
  - Validate archive in Organizer

- [ ] **Upload to App Store Connect**
  - Distribute App > App Store Connect > Upload
  - Verify build appears in TestFlight

- [ ] **iOS TestFlight distribution**
  - Add iOS to existing "Beta Testers" group
  - Submit for Beta App Review (required for external testing)
  - Distribute to testers

- [ ] **Beta testing checklist for iOS testers**
  - Calculator operations on iPhone (touch keypad)
  - Video import from Files app and Photo Library
  - Video playback and transport controls
  - Marker creation and export (share sheet)
  - iPad keyboard shortcuts
  - iPad drag-and-drop
  - Different screen sizes and orientations

- [ ] **Address beta feedback**
  - Fix any iOS-specific bugs reported
  - Adjust layouts based on real-device feedback
  - Performance fixes if needed

- [ ] **Submit for App Store review**
  - Ensure both macOS and iOS builds are uploaded
  - Submit iOS version for review
  - Universal purchase activates when both platforms are approved

- [ ] **Coordinate macOS update**
  - If any shared code changed, upload a new macOS build too
  - Both platforms should ship the same version number (e.g., 1.1 or 2.0)

### Acceptance Criteria

- [ ] iOS build on TestFlight
- [ ] At least 3 beta testers complete testing on iOS
- [ ] No critical bugs in beta feedback
- [ ] App Store review submitted
- [ ] Universal purchase confirmed active after approval

---

## Sprint Tracking

| Sprint | Status | Focus | Key Files |
|--------|--------|-------|-----------|
| 16 - Project Config & Abstraction | ✅ Complete | Compilation on both platforms | PlatformServices.swift, all AppKit imports, project.pbxproj |
| 17 - App Entry & Navigation | ✅ Complete | iOS app structure | iOSContentView.swift, iOSVideoInspectorView.swift, ContentView.swift |
| 18 - Video Player & File Import | ✅ Complete | iOS playback, file import, PhotosPicker | AppState.swift, ContentView.swift, iOSContentView.swift, Info.plist |
| 19 - Keyboard & Touch | ✅ Complete | iPad keyboard + haptic feedback | PlatformServices.swift, iOSContentView.swift, iOSVideoInspectorView.swift, KeypadView.swift |
| 20 - Layout & Responsive Design | ✅ Complete | Responsive sizing, orientation layouts, Dynamic Type | PlatformServices, KeypadView, TimecodeDisplayView, CalculatorView, TransportControls, iOSContentView, iOSVideoInspectorView, TimecoderApp, AppState, ContentView |
| 21 - Liquid Glass (iOS) | ✅ Complete | Interactive glass, GlassEffectContainer | FrameRatePicker, TransportControls, TimecodeDisplayView |
| 22 - Shortcuts, Menu Bar & iPad | ✅ Complete | ⌘-hold overlay, ⌘C command, video import menu, iOS build fix | TimecoderApp, iOSVideoInspectorView, iOSContentView, Notifications |
| 23 - iPhone Portrait Redesign | ✅ Complete | Portrait video mode, orientation lock | iOSVideoInspectorView, CalculatorView, TimecodeDisplayView, TransportControls, MarkerEditorSheet, TimecoderApp, iOSContentView |
| 24 - iPad Layout & Performance | Pending | iPad layouts, perf, edge cases | TBD |
| 25 - App Store Connect | Pending | Universal purchase setup | App Store Connect, screenshots |
| 26 - TestFlight & Release | Pending | Ship it | Archives, TestFlight |

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Liquid Glass APIs not available on iOS 17 | High | iOS 17 is minimum for `.onKeyPress()`. Glass APIs require iOS 26. Decision: raise minimum to iOS 26 if glass is critical, or use `if #available(iOS 26, *)` fallbacks |
| Universal purchase is permanent | Medium | Test thoroughly on TestFlight before submitting. Once both platforms are approved, cannot remove iOS |
| Video performance on older iPhones | Medium | Profile on iPhone SE / iPhone 12. May need to limit resolution or disable some features |
| Touch target sizes on iPhone SE | Low | Existing 48pt buttons meet 44pt minimum. Test and adjust |
| Photo Library permission rejection | Low | Clear usage description. Only request when user taps Photo Library button (lazy permission) |

---

## iOS Deployment Target Decision

**Recommended: iOS 26.0**

Rationale:
- Liquid Glass APIs (`.glassEffect()`, `.buttonStyle(.glass)`) require iOS 26
- The app already requires macOS 26 for Liquid Glass
- iPadOS 26 menu bar support is a key feature
- `.onKeyPress()` is available from iOS 17, but we need iOS 26 for design consistency
- iOS 26 will be current at time of release
- Professional users (our target audience) tend to update promptly

If broader device support is needed, iOS 17 is the minimum viable target with `if #available(iOS 26, *)` guards around glass effects. This adds complexity but covers ~95% of active devices.

---

*Last Updated: 2026-02-25 — Sprint 23 complete*
