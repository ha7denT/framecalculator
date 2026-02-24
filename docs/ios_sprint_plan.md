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

- [ ] **Branch `TimecoderApp.swift` for iOS**
  ```swift
  @main
  struct TimecoderApp: App {
      #if os(macOS)
      @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
          .commands { /* existing menu commands */ }

          Settings {
              PreferencesView()
          }
          #endif
      }
  }
  ```

- [ ] **Guard `AppDelegate` behind `#if os(macOS)`**

- [ ] **Guard `showKeyboardShortcutsWindow()` (uses `NSAlert`)**

- [ ] **Create iOS `ContentView` branch**
  - macOS: Keep existing `ContentView` with `NSWindow` sizing, `NSOpenPanel`, etc.
  - iOS: New layout using `NavigationStack` or `TabView` depending on device
  - iPhone: Single-column stacked layout
  - iPad: `NavigationSplitView` or `HStack` mirroring macOS layout

- [ ] **Create `iOSContentView.swift`**
  ```swift
  #if os(iOS)
  struct iOSContentView: View {
      @StateObject private var appState = AppState()
      @Environment(\.horizontalSizeClass) var sizeClass

      var body: some View {
          Group {
              if sizeClass == .compact {
                  iPhoneLayout()
              } else {
                  iPadLayout()
              }
          }
      }
  }
  #endif
  ```

- [ ] **iPhone layout: calculator with toolbar actions**
  - Calculator fills the screen
  - Toolbar button to import video (uses `.fileImporter()`)
  - Settings accessible via gear icon or navigation
  - When video loaded: push to video inspection view

- [ ] **iPad layout: side-by-side**
  - Reuse macOS `VideoInspectorView` concept with iOS adaptations
  - Video player on left, calculator + metadata on right
  - Toolbar for import/export actions

- [ ] **Create iOS-specific preferences view**
  - Use `NavigationStack` with `Form` (iOS-native settings pattern)
  - Remove "Window" section (not applicable on iOS)
  - Remove "Remember window position" toggle

- [ ] **Guard macOS `PreferencesView` window frame sizing**
  - `.frame(width: 400, height: 280)` is macOS-specific

- [ ] **Guard `UserPreferences.rememberWindowPosition`**
  - Only relevant on macOS

### Acceptance Criteria

- [ ] iOS app launches and shows calculator on iPhone Simulator
- [ ] iOS app launches and shows appropriate layout on iPad Simulator
- [ ] macOS app unchanged — no regressions
- [ ] Settings/preferences accessible on iOS
- [ ] No `NSApplication`, `NSWindow`, `NSAlert` code compiles on iOS

### Notes

iPadOS 26 automatically generates a menu bar from the `commands` modifier when users swipe down. The existing `CommandGroup` code will work on iPad without changes once the `#if os(macOS)` guard is restructured to include iPadOS. Consider using `#if os(iOS) || os(macOS)` for command groups that should appear on both.

Ref: [What's new in SwiftUI — WWDC25](https://developer.apple.com/videos/play/wwdc2025/256/) — iPadOS 26 menu bar support.

---

## Sprint 18: Video Player & File Import (iOS)

### Goal
Get video playback working on iOS with file import, photo library access, and the iOS video player.

### Deliverables

- [ ] **Create `iOSVideoPlayerView.swift`**
  - Option A: SwiftUI `VideoPlayer` view (simplest, less control)
  - Option B: `UIViewControllerRepresentable` wrapping `AVPlayerViewController` (more control over chrome)
  - Recommendation: Use Option B with `showsPlaybackControls = false` to match macOS custom controls
  ```swift
  #if os(iOS)
  struct iOSVideoPlayerView: UIViewControllerRepresentable {
      let player: AVPlayer

      func makeUIViewController(context: Context) -> AVPlayerViewController {
          let vc = AVPlayerViewController()
          vc.player = player
          vc.showsPlaybackControls = false
          return vc
      }

      func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
          vc.player = player
      }
  }
  #endif
  ```

- [ ] **Replace `NSOpenPanel` with `.fileImporter()` on iOS**
  ```swift
  .fileImporter(
      isPresented: $showingFileImporter,
      allowedContentTypes: [.movie, .video, .quickTimeMovie, .mpeg4Movie],
      allowsMultipleSelection: false
  ) { result in
      // Handle selected URL
  }
  ```

- [ ] **Add photo library picker for iOS**
  - `PhotosPicker` from PhotosUI framework for selecting videos from camera roll
  - Common workflow on iPhone — users record video then want to inspect it
  ```swift
  import PhotosUI

  PhotosPicker(selection: $selectedItem, matching: .videos) {
      Label("Photo Library", systemImage: "photo.on.rectangle")
  }
  ```

- [ ] **Handle security-scoped URLs on iOS**
  - `.fileImporter()` returns security-scoped URLs
  - Must call `url.startAccessingSecurityScopedResource()` before loading
  - Must call `url.stopAccessingSecurityScopedResource()` when done
  - Bookmark URL for session persistence if needed

- [ ] **Replace `NSSavePanel` with share sheet on iOS**
  - `ExportDialogView` currently uses `NSSavePanel` — macOS only
  - iOS: Use `ShareLink` or `UIActivityViewController` to share exported file
  ```swift
  #if os(iOS)
  ShareLink(item: exportedFileURL) {
      Label("Share", systemImage: "square.and.arrow.up")
  }
  #else
  // existing NSSavePanel code
  #endif
  ```

- [ ] **Adapt `ExportDialogView` for iOS**
  - Replace save panel with share sheet flow
  - Export to temp file, then present share sheet
  - User can save to Files, AirDrop, email, etc.

- [ ] **Test video playback on iOS Simulator**
  - Load video via file importer
  - Verify playback, pause, seek work
  - Verify metadata extraction works (AVFoundation is cross-platform)

### Acceptance Criteria

- [ ] Can import video file on iPhone via file importer
- [ ] Can import video from photo library on iPhone
- [ ] Video plays with custom transport controls
- [ ] Can export markers via share sheet on iOS
- [ ] Security-scoped resource access handled correctly
- [ ] macOS video player unchanged

### Notes

`AVFoundation` and `AVKit` work on both platforms. The main difference is the view wrapper: `NSViewRepresentable` + `AVPlayerView` on macOS vs `UIViewControllerRepresentable` + `AVPlayerViewController` on iOS. All the actual playback logic in `VideoPlayerViewModel` works unchanged.

---

## Sprint 19: Keyboard Input & Touch Adaptation (iOS)

### Goal
Replace macOS `NSEvent` keyboard handling with iOS-compatible input, and ensure touch interactions work well on the calculator keypad.

### Deliverables

- [ ] **Replace `KeyboardCaptureView` (NSView) on iOS**
  - macOS: Keep existing `NSViewRepresentable` keyboard handler
  - iOS: Use `.onKeyPress()` modifier (iOS 17+) for hardware keyboard support
  ```swift
  #if os(iOS)
  .onKeyPress(keys: [.return, .delete, .space], phases: .down) { keyPress in
      handleKeyPress(keyPress)
      return .handled
  }
  .onKeyPress(characters: .alphanumerics, phases: .down) { keyPress in
      handleCharacter(keyPress.characters)
      return .handled
  }
  #endif
  ```

- [ ] **Replace `VideoKeyboardCaptureView` (NSView) on iOS**
  - Same approach: `.onKeyPress()` for hardware keyboard (iPad with keyboard)
  - JKL shuttle, I/O, M, arrow keys — all via `.onKeyPress()`

- [ ] **Remove keyboard handler views from iOS build**
  - Guard `KeyboardHandlerView`, `KeyboardCaptureView` behind `#if os(macOS)`
  - Guard `VideoKeyboardHandler`, `VideoKeyboardCaptureView` behind `#if os(macOS)`

- [ ] **Ensure touch interactions on calculator keypad**
  - The existing `KeypadView` uses button actions — should work on iOS out of the box
  - Verify press states (`DragGesture(minimumDistance: 0)`) work on touch
  - Test button sizes are comfortable for finger taps (minimum 44pt)
  - Current button size is 48pt — good for touch

- [ ] **Add haptic feedback on iOS**
  ```swift
  #if os(iOS)
  let impact = UIImpactFeedbackGenerator(style: .light)
  impact.impactOccurred()
  #endif
  ```
  - Light haptic on number button tap
  - Medium haptic on operation execution (equals)

- [ ] **Adapt transport controls for touch**
  - Existing SF Symbol buttons should work for touch
  - Ensure minimum 44pt touch targets
  - Consider swipe gestures for frame stepping on iPhone (swipe left/right on video)

- [ ] **iPad hardware keyboard: full shortcut support**
  - JKL shuttle, Space play/pause, arrow frame step
  - I/O for in/out points, M for markers
  - ⌘C/⌘V for copy/paste
  - Use `.keyboardShortcut()` where appropriate for discoverability

### Acceptance Criteria

- [ ] Calculator keypad works via touch on iPhone/iPad
- [ ] iPad with hardware keyboard: JKL, Space, arrows, I/O, M all work
- [ ] Haptic feedback on button presses (iOS only)
- [ ] macOS keyboard handling unchanged
- [ ] No `NSEvent` code compiles on iOS

### Notes

`.onKeyPress()` requires iOS 17+, which aligns with our deployment target. This modifier handles hardware keyboard input on iPad. On iPhone without a hardware keyboard, all interaction goes through the on-screen keypad — no software keyboard is needed since the calculator has its own input buttons.

The existing `CalculatorView` keyboard handler on macOS uses NSEvent key codes (e.g., 49 for Space, 123 for left arrow). On iOS, `.onKeyPress()` uses `KeyEquivalent` values instead — a cleaner API.

---

## Sprint 20: iOS Layout & Responsive Design

### Goal
Optimize layouts for iPhone and iPad screen sizes. Ensure the app looks and feels native on both form factors.

### Deliverables

- [ ] **iPhone calculator layout**
  - Full-width calculator filling the screen
  - Timecode display at top with glass effect
  - Frame rate picker below display
  - Keypad centered with appropriate sizing for phone width
  - Toolbar with video import button and settings gear

- [ ] **iPhone video inspection layout (stacked)**
  - Video player filling width, aspect-ratio constrained height
  - Transport controls directly below video
  - Timeline with markers below transport
  - Swipe-up sheet or tab for: Calculator, Metadata, Markers, In/Out
  - Use `TabView` or segmented control to switch between panels
  ```swift
  // iPhone video layout
  VStack(spacing: 0) {
      iOSVideoPlayerView(player: player)
          .aspectRatio(videoAspectRatio, contentMode: .fit)
      TransportControls(...)
      TimelineView(...)

      // Bottom panels as tabs
      TabView(selection: $selectedPanel) {
          CalculatorView(...).tag(Panel.calculator)
          MetadataPanel(...).tag(Panel.metadata)
          MarkerListView(...).tag(Panel.markers)
      }
      .tabViewStyle(.page)
  }
  ```

- [ ] **iPad video inspection layout (side-by-side)**
  - Mirror macOS layout using `HStack`
  - Video + timeline on left (~65% width)
  - Calculator + metadata + markers on right (~35% width) in `ScrollView`
  - Adapt to available width using `GeometryReader`

- [ ] **Safe area handling**
  - Respect Dynamic Island / notch on iPhone
  - Respect home indicator area
  - Use `.safeAreaInset()` where needed

- [ ] **Support Dynamic Type (accessibility text sizes)**
  - Timecode display should scale with system text size preference
  - Keypad buttons should remain usable at large text sizes
  - Use `@ScaledMetric` for dimensions that should scale:
    ```swift
    @ScaledMetric(relativeTo: .title) var buttonSize: CGFloat = 48
    ```

- [ ] **Support both orientations on iPad**
  - Landscape: side-by-side (preferred for video work)
  - Portrait: stacked layout (similar to iPhone but wider)

- [ ] **iPhone landscape mode**
  - Decision: Lock to portrait for calculator mode
  - Allow landscape in video inspection mode
  - Use `Info.plist` `UISupportedInterfaceOrientations` or per-view orientation control

### Acceptance Criteria

- [ ] iPhone: calculator fills screen naturally, buttons are comfortable to tap
- [ ] iPhone: video mode shows stacked layout with panel tabs
- [ ] iPad: calculator centered with comfortable sizing
- [ ] iPad: video mode shows side-by-side layout
- [ ] iPad landscape and portrait both work
- [ ] Dynamic Type at all sizes doesn't break layout
- [ ] Safe areas respected on all iPhone models

### Notes

The existing macOS calculator window is 300x540, which maps well to an iPhone screen. The main adaptation is making the video inspection mode work in a stacked layout on the smaller phone screen.

For iPad, the macOS `VideoInspectorView` layout (HStack with video left, panel right) can be reused with minor width adjustments. The fixed video frame sizes in `VideoOrientation` can be replaced with geometry-based proportional sizing.

---

## Sprint 21: Liquid Glass Adoption (iOS)

### Goal
Ensure Liquid Glass design is applied correctly on iOS 26, following Apple's platform-specific guidelines. Review and adapt existing macOS glass effects for iOS.

### Deliverables

- [ ] **Audit existing `.glassEffect()` usage for iOS compatibility**
  - `TimecodeDisplayView` — `.glassEffect(in: .rect(cornerRadius: 12))`
  - `FrameRatePicker` — `.glassEffect(in: .capsule)`
  - `VideoInspectorView` In/Out panel — `.glassEffect(in: .rect(cornerRadius: 12))`
  - All should work cross-platform — verify rendering on iOS

- [ ] **Add `.interactive()` to glass effects on iOS**
  - iOS-specific: enables scaling, bouncing, shimmering on touch
  - Apply to interactive controls (buttons, pickers)
  ```swift
  .glassEffect(.regular.interactive(), in: .capsule)
  ```
  - Ref: [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)

- [ ] **Wrap glass toolbar items in `GlassEffectContainer`**
  - Prevents glass-sampling-glass rendering issues
  - Apply to transport controls bar, toolbar items
  ```swift
  GlassEffectContainer {
      HStack {
          // transport buttons
      }
  }
  ```
  - Ref: [glassEffect(_:in:)](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))

- [ ] **iOS toolbar styling**
  - iOS 26 toolbars automatically get Liquid Glass treatment
  - Remove any custom backgrounds or overlays that conflict
  - Ensure toolbar items use monochrome icons (Apple recommendation)
  - Tint icons only to convey meaning (e.g., record = red)
  - Ref: [Build a SwiftUI app with the new design — WWDC25](https://developer.apple.com/videos/play/wwdc2025/323/)

- [ ] **Sheet presentations on iOS**
  - iOS 26 partial-height sheets use Liquid Glass background by default
  - Remove any custom `presentationBackground` modifiers
  - Marker editor sheet, export dialog, custom FPS dialog — all benefit automatically
  - Ref: [Build a SwiftUI app with the new design — WWDC25](https://developer.apple.com/videos/play/wwdc2025/323/)

- [ ] **Use `.containerConcentric` for nested corner radii**
  - Controls inside glass containers align corners automatically
  ```swift
  .clipShape(.containerConcentric(in: .rect(cornerRadius: 20)))
  ```

- [ ] **Verify button styles on iOS**
  - `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` should render correctly
  - Custom button components (NumberButton, OperatorButton, etc.) may need adjustment
  - Default button shape on iOS is capsule — verify this matches design intent
  - Ref: WWDC25 Session 323: buttons default to capsule on iOS, rounded rect on macOS small/medium

- [ ] **Test Liquid Glass accessibility modes**
  - Reduce Transparency: glass becomes more opaque automatically
  - Increase Contrast: enhanced visibility automatically
  - Reduce Motion: toned-down animations
  - Verify no content becomes unreadable in these modes

### Acceptance Criteria

- [ ] Glass effects render correctly on iPhone and iPad
- [ ] Interactive glass responds to touch on iOS
- [ ] Sheets use native Liquid Glass background
- [ ] Toolbars match iOS 26 native appearance
- [ ] Accessibility settings don't break glass UI
- [ ] macOS glass effects unchanged

### Design Principles (from Apple)

1. **Navigation layer only** — never apply glass to content (lists, tables, media)
2. **Use sparingly** — highlight key UI elements, not everything
3. **Tint for meaning** — only tint glass to convey semantic information
4. **Content is primary** — controls provide functional overlay, content stays prominent
5. **System tokens** — use system-provided materials so the app respects light/dark and accessibility

---

## Sprint 22: Drag & Drop, Shortcuts, and iPad Enhancements

### Goal
Add iPad-specific power features: drag-and-drop video loading, keyboard shortcuts discoverability, and split-screen multitasking support.

### Deliverables

- [ ] **iPad drag-and-drop video loading**
  - Receive dropped video files from Files app or other apps
  - Use `.dropDestination(for:)` (iOS 16+) or `.onDrop(of:)`
  ```swift
  .dropDestination(for: URL.self) { urls, _ in
      guard let url = urls.first else { return false }
      Task { await appState.loadVideo(from: url) }
      return true
  }
  ```

- [ ] **Keyboard shortcut discoverability on iPad**
  - iPadOS shows keyboard shortcuts overlay when holding ⌘ key
  - Register shortcuts via `.keyboardShortcut()` on buttons
  - Map existing shortcuts: ⌘O (open), ⌘E (export), ⌘C (copy), ⌘V (paste)

- [ ] **iPadOS 26 menu bar support**
  - iPadOS 26: apps display a menu bar on swipe-down
  - The `commands` API used on macOS creates the same menu on iPad
  - Move `CommandGroup` definitions outside the `#if os(macOS)` guard
  - Ref: [What's new in SwiftUI — WWDC25](https://developer.apple.com/videos/play/wwdc2025/256/)

- [ ] **Split-screen / Slide Over support on iPad**
  - App should work in compact width (1/3 screen) and regular width (1/2 or full)
  - Use `@Environment(\.horizontalSizeClass)` to adapt layout
  - Compact width on iPad → iPhone-like stacked layout
  - Regular width on iPad → side-by-side layout

- [ ] **Stage Manager support on iPad**
  - Flexible window sizing — test at various window sizes
  - Minimum size constraints via `UISceneDelegate.scene(_:willConnectTo:options:)`

- [ ] **iPhone: add video import action menu**
  - Group import options: "Choose File" (file importer) and "Photo Library" (PhotosPicker)
  - Present as action sheet or menu button in toolbar

### Acceptance Criteria

- [ ] iPad: can drag video from Files app into Timecoder
- [ ] iPad: holding ⌘ shows keyboard shortcuts overlay
- [ ] iPad: menu bar appears on iPadOS 26 swipe-down
- [ ] iPad: works in split-screen at all widths
- [ ] iPhone: can import video from file picker or photo library
- [ ] macOS unchanged

---

## Sprint 23: Polish, Testing & Platform Edge Cases

### Goal
Fix platform-specific bugs, handle edge cases, and polish the iOS experience.

### Deliverables

- [ ] **iOS-specific testing matrix**
  - iPhone SE (small screen) — verify calculator fits
  - iPhone 16 Pro Max (large screen) — verify spacing
  - iPad mini — verify touch targets
  - iPad Pro 13" — verify side-by-side layout
  - iPad with Magic Keyboard — verify all shortcuts

- [ ] **Fix platform-specific issues**
  - Font rendering differences (Space Mono at various sizes)
  - Glass effect differences between macOS and iOS
  - Dark/light mode consistency across platforms
  - Color contrast in both modes on OLED iPhone displays

- [ ] **Handle iOS-specific edge cases**
  - App backgrounding during video playback (pause player)
  - Memory pressure (release video when backgrounded)
  - Interruptions (phone call during playback)
  - Low Power Mode (reduce animation)

- [ ] **Add iOS app lifecycle handlers**
  ```swift
  #if os(iOS)
  .onChange(of: scenePhase) { phase in
      switch phase {
      case .background:
          appState.player?.pause()
      case .active:
          // Resume if was playing
      default: break
      }
  }
  #endif
  ```

- [ ] **Accessibility audit (iOS)**
  - VoiceOver on iPhone and iPad
  - Dynamic Type at all sizes
  - Switch Control compatibility
  - Verify all existing accessibility labels work on iOS

- [ ] **Performance profiling on iOS**
  - Memory usage during video playback
  - CPU usage during JKL shuttle (variable rate playback)
  - Launch time on physical device
  - Target: < 1s launch, < 100MB memory (calculator), < 250MB (video)

- [ ] **Add iOS app icon**
  - iOS requires multiple sizes in Asset Catalog
  - Design should match macOS icon but follow iOS conventions
  - iOS 26: Liquid Glass icon treatment applied automatically by system
  - Provide 1024x1024 base icon; Xcode generates all sizes

### Acceptance Criteria

- [ ] No crashes on any tested device configuration
- [ ] VoiceOver navigates all controls on iOS
- [ ] Dynamic Type doesn't break layout at any size
- [ ] App handles backgrounding and interruptions gracefully
- [ ] Performance within targets on physical devices
- [ ] App icon displays correctly on iOS home screen

---

## Sprint 24: App Store Connect & Universal Purchase Setup

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

## Sprint 25: iOS TestFlight & Release

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
| 17 - App Entry & Navigation | Pending | iOS app structure | TimecoderApp.swift, iOSContentView.swift |
| 18 - Video Player & File Import | Pending | iOS playback and file access | iOSVideoPlayerView.swift, ExportDialogView.swift |
| 19 - Keyboard & Touch | Pending | Input handling per platform | CalculatorView.swift, VideoInspectorView.swift |
| 20 - Layout & Responsive Design | Pending | iPhone/iPad layouts | All view files |
| 21 - Liquid Glass (iOS) | Pending | Glass effects on iOS | KeypadView, TransportControls, toolbars |
| 22 - iPad Power Features | Pending | Drag-drop, shortcuts, menus | ContentView, CommandGroups |
| 23 - Polish & Testing | Pending | Bug fixes, accessibility, perf | All files |
| 24 - App Store Connect | Pending | Universal purchase setup | App Store Connect, screenshots |
| 25 - TestFlight & Release | Pending | Ship it | Archives, TestFlight |

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

*Last Updated: 2026-02-24 — Sprint 16 complete*
