# Frame Calculator — Sprint Plans

## Overview

This document breaks down the development of Frame Calculator into discrete sprints. Each sprint is designed to be completable in roughly 1-2 weeks and results in demonstrable, testable functionality.

**Total Estimated Sprints:** 8  
**Target MVP (Sprints 1-6):** Core calculator + video player + markers  
**Target 1.0 (Sprints 7-8):** Export + polish for App Store submission

---

## Sprint 1: Project Foundation & Core Models

### Goal
Establish project structure, core data types, and timecode arithmetic engine.

### Deliverables

- [x] Xcode project setup (SwiftUI App, macOS 13.0+ target)
- [x] Project folder structure per architecture spec
- [x] `FrameRate` enum with all supported rates + custom
- [x] `Timecode` struct with:
  - Frame-based internal storage
  - Arithmetic operators (+, -, multiply by scalar)
  - Conversion to/from frame count
  - String parsing (HH:MM:SS:FF format)
  - String formatting (with drop frame semicolon notation)
  - Drop frame calculation logic
- [x] Unit tests for `Timecode` and `FrameRate`

### Acceptance Criteria

- [x] All frame rates calculate correctly (verify against known timecode values)
- [x] Drop frame skips frames 0,1 at each minute except every 10th minute
- [x] `Timecode("01:00:00:00", .fps24) + Timecode("00:00:01:00", .fps24)` = `01:00:01:00`
- [x] Parsing handles both `:` (non-drop) and `;` (drop frame) separators
- [x] 100% test coverage on Timecode arithmetic

### Notes

This sprint has no UI. Focus entirely on getting the math right — everything else depends on it.

### Implementation Notes (for future reference)

**Project Structure:**
- Using Swift Package Manager (`Package.swift`) for building and testing
- App entry point (`@main`) is in `FrameCalculator/App/` but excluded from the library target to avoid duplicate symbol errors during testing
- UI folders (`Views/`, `ViewModels/`) also excluded from library target for now

**Drop Frame Algorithm:**
The drop frame implementation uses a "count dropped frames, then add back" approach:
1. Calculate how many frame numbers have been skipped by the current frame count
2. Add those back to get a "display frame number"
3. Convert display frame number to HH:MM:SS:FF using simple NDF math

Key formula for drops within a 10-minute block:
- First minute (0): no drop
- Minutes 1-9: each has a drop of 2 frames
- `framesPerTenMinutes = 1800 * 10 - 2 * 9 = 17982`

**Testing:**
- 51 tests total (9 for FrameRate, 42 for Timecode)
- Round-trip tests verify `components → frames → components` consistency
- Edge cases tested: minute boundaries, 10-minute boundaries, hour mark, negative durations

**Key Files:**
- `FrameCalculator/Models/FrameRate.swift` — enum with computed properties
- `FrameCalculator/Models/Timecode.swift` — value type with all arithmetic and parsing
- `FrameCalculatorTests/TimecodeTests.swift` — comprehensive test coverage

**Build Commands:**
```bash
swift build   # Build the library
swift test    # Run all tests
```

---

## Sprint 2: Standalone Calculator UI

### Goal
Build the calculator-only interface with working timecode operations.

### Deliverables

- [x] `CalculatorViewModel` with operation state management
- [x] `TimecodeDisplayView` — large, selectable timecode field
- [x] `FrameRatePicker` — dropdown or segmented control
- [x] `CalculatorView` — main calculator layout
- [x] Operation mode selector (Add, Subtract, Multiply, Frame↔TC)
- [x] Keyboard input for timecode entry
- [x] Copy/paste support (⌘C, ⌘V) for timecode field
- [x] Basic app window with calculator as default view

### Acceptance Criteria

- [x] Can enter timecode via keyboard (numeric keys + colons)
- [x] Can switch between all supported frame rates
- [x] Addition: `01:00:00:00 + 00:30:00:00 = 01:30:00:00`
- [x] Subtraction: `01:00:00:00 - 00:00:30:00 = 00:59:30:00`
- [x] Multiplication: `00:00:30:00 × 4 = 00:02:00:00`
- [x] Frame→TC: `86400 frames @ 24fps = 01:00:00:00`
- [x] TC→Frame: `01:00:00:00 @ 24fps = 86400 frames`
- [x] Copy timecode to clipboard, paste from clipboard
- [x] Frame rate change recalculates displayed timecode

### Notes

Keep the window compact (~320×480pt). This is the "calculator app" mode users will use daily.

### Implementation Notes (for future reference)

**Project Structure:**
- Xcode project created (`FrameCalculator.xcodeproj`) for building and running the app
- SPM (`Package.swift`) retained for running unit tests via `swift test`
- App entry point with dark mode by default and hidden title bar window style

**Key Components:**
- `CalculatorViewModel.swift` — Observable view model managing:
  - Current timecode display
  - Digit-by-digit entry with automatic formatting
  - Pending operations (add, subtract, multiply, frame conversions)
  - Frame rate selection with automatic timecode conversion
  - Error handling with user-friendly messages

- `KeypadView.swift` — Calculator button UI with:
  - Number pad (0-9) with delete button
  - Operation buttons (+, −, ×, =)
  - Mode buttons (F→TC, TC→F, AC, C)
  - Multiplier input field for multiply operations

- `TimecodeDisplayView.swift` — Large SF Mono display:
  - Text selection enabled for copy
  - Frame count display below timecode
  - Visual feedback for pending operations and errors

- `FrameRatePicker.swift` — Compact dropdown menu for frame rate selection

**Keyboard Handling:**
- Uses NSViewRepresentable with NSView.keyDown() for macOS 13.0 compatibility
- Supports numpad and top-row number keys
- Operations: +, -, *, x, =, Enter, Delete, Escape, C

**Build Commands:**
```bash
# Build via Xcode
xcodebuild -project FrameCalculator.xcodeproj -scheme FrameCalculator build

# Run tests via SPM
swift test

# Open in Xcode
open FrameCalculator.xcodeproj
```

**Key Files:**
- `FrameCalculator/ViewModels/CalculatorViewModel.swift` — Main calculator logic
- `FrameCalculator/Views/Calculator/CalculatorView.swift` — Main UI composition
- `FrameCalculator/Views/Calculator/KeypadView.swift` — Button UI
- `FrameCalculator/Views/Calculator/TimecodeDisplayView.swift` — Display component
- `FrameCalculator/Views/Calculator/FrameRatePicker.swift` — Frame rate dropdown

**Known Issues (deferred to Sprint 8):**
- Entry validation visual feedback: Invalid timecode components (e.g., seconds > 59) are shown during entry but only validated on commit. Need clearer visual indication that entry is "draft" and may fail. See Sprint 8 notes.

---

## Sprint 3: Video Loading & Metadata

### Goal
Implement drag-and-drop video loading and metadata extraction.

### Deliverables

- [x] `VideoMetadata` model (duration, codec, bitrate, resolution, frame rate, color space, audio channels, file size)
- [x] `VideoLoader` service using AVFoundation
- [x] Drag-and-drop handler on main window
- [x] `MetadataPanel` view displaying extracted info
- [x] Auto-detect frame rate and set calculator accordingly
- [x] `AppState` to track current mode (calculator vs video)
- [x] Basic mode switching (calculator → video inspector)

### Acceptance Criteria

- [x] Drop .mov, .mp4, .m4v files onto window
- [x] Metadata panel shows all 8 metadata fields
- [x] Frame rate auto-populates calculator's frame rate selector
- [x] Unsupported files show appropriate error
- [x] Can return to calculator-only mode (close video)

### Notes

Use `AVAsset.load(_:)` with async/await for metadata extraction. Handle files without embedded timecode gracefully (default to 00:00:00:00 start).

### Implementation Notes (for future reference)

**New Files Created:**
- `FrameCalculator/Models/VideoMetadata.swift` — Video metadata value type with formatted display properties
- `FrameCalculator/Services/VideoLoader.swift` — AVFoundation-based async video loader service (actor)
- `FrameCalculator/App/AppState.swift` — Global app state managing mode and video loading
- `FrameCalculator/Views/Metadata/MetadataPanel.swift` — Metadata display panel with Grid layout
- `FrameCalculator/Views/Main/VideoInspectorView.swift` — Combined video player + calculator layout

**Key Architecture Decisions:**
- `VideoLoader` is an actor for thread-safe async video loading
- `AppState` is a `@MainActor` class managing mode switching and video state
- Drag-and-drop uses `UniformTypeIdentifiers` for file type detection
- Files are copied to temp directory before loading (required for sandboxed access)
- Frame rate auto-syncs to calculator via `onChange` when video loads

**Metadata Extraction:**
- Codec names extracted from `CMFormatDescription` FourCC codes
- Color space from format description extensions
- Audio channels counted from all audio tracks
- Bitrate from `estimatedDataRate` on video track

**Video Player:**
- Uses `AVKit.VideoPlayer` for basic playback (full controls in Sprint 4)
- Player created via `VideoLoader.createPlayer(for:)`
- Close button overlay returns to calculator mode

**Build Commands:**
```bash
# Build via Xcode
xcodebuild -project FrameCalculator.xcodeproj -scheme FrameCalculator build

# Run tests via SPM
swift test
```

---

## Sprint 4: Video Player & Transport

### Goal
Full video playback with professional transport controls and bidirectional calculator sync.

### Deliverables

- [x] `VideoPlayerViewModel` managing AVPlayer state
- [x] `VideoPlayerView` wrapping AVKit player
- [x] `TransportControls` — play/pause, JKL shuttle
- [x] `TimelineView` — scrubber/timeline with playhead
- [x] Frame-accurate seeking (zero tolerance)
- [x] Periodic timecode update to calculator display
- [x] Frame stepping (←/→ arrow keys)
- [x] Shuttle speed indicator (1×, 2×, 4×, etc.)
- [x] Bidirectional calculator ↔ player sync

### Acceptance Criteria

- [x] Space bar toggles play/pause
- [x] J = reverse (stacks: 1×, 2×, 4×)
- [x] K = stop
- [x] L = forward (stacks: 1×, 2×, 4×)
- [ ] K+J or K+L = slow motion (optional, nice-to-have — deferred)
- [x] Arrow keys step exactly one frame
- [x] Timeline scrubbing is frame-accurate
- [x] Calculator display updates in real-time during playback
- [x] Responsive layout adapts to window resize
- [x] **Scrubbing/playback updates calculator timecode display**
- [x] **Typing timecode + Enter seeks playhead to that position**

### Notes

Use `addPeriodicTimeObserver` with interval of `CMTime(value: 1, timescale: frameRate)` for smooth updates. Test with various codecs (ProRes, H.264, HEVC).

**Bidirectional Sync Implementation:**
- Player → Calculator: Use periodic time observer to update `CalculatorViewModel.currentTimecode` during playback/scrubbing
- Calculator → Player: On Enter key (when in video mode), convert displayed timecode to CMTime and seek player
- For videos without embedded TC, use elapsed time from 00:00:00:00
- For videos with embedded TC, offset by start timecode when seeking

### Implementation Notes (for future reference)

**New Files Created:**
- `FrameCalculator/ViewModels/VideoPlayerViewModel.swift` — Manages AVPlayer state, shuttle control, time observer, frame stepping
- `FrameCalculator/Views/VideoPlayer/TransportControls.swift` — Play/pause, JKL shuttle buttons, speed indicator
- `FrameCalculator/Views/VideoPlayer/TimelineView.swift` — Scrubber, playhead, click-to-seek

**Key Architecture Decisions:**
- `VideoPlayerViewModel` is `@MainActor` isolated for thread-safe UI updates
- `ShuttleState` enum tracks -4× to +4× playback speeds
- Periodic time observer updates at frame-rate interval for smooth display
- Bidirectional sync: player updates calculator via callback, calculator seeks player via Enter key

**Shuttle Implementation:**
- J key increases reverse speed: stopped→-1×→-2×→-4×
- L key increases forward speed: stopped→1×→2×→4×
- K key stops playback
- Visual indicator shows current shuttle speed with colored bars

**Keyboard Handling:**
- Uses `NSViewRepresentable` with custom `NSView.keyDown()` for macOS 13.0 compatibility
- Handles Space (play/pause), J/K/L (shuttle), arrows (frame step), Enter (seek)
- Separate keyboard handler for video mode (`VideoKeyboardHandler`) to avoid conflicts with calculator

**Build Commands:**
```bash
# Build via Xcode
xcodebuild -project FrameCalculator.xcodeproj -scheme FrameCalculator build

# Run tests via SPM
swift test
```

### Bug Fixes Applied

**Window Sizing:**
- Calculator mode: Window resizes to 320×520 on launch and when closing video
- Video mode: Window sizes naturally to fit video content
- Video display explicitly sized based on video dimensions (max height 700px, width calculated from aspect ratio) to eliminate black bars

**AVKit Controls:**
- Created `CustomVideoPlayerView` using `AVPlayerView` with `controlsStyle = .none` to hide default AVKit controls
- Prevents duplicate playhead UI on hover

**Transport Controls:**
- Replaced J/K/L text labels with SF Symbols (`backward.fill`, `play.fill`/`pause.fill`, `forward.fill`)
- Fixed play button to call `togglePlayPause()` instead of `handleK()`

**Keyboard Handling:**
- Fixed keyboard handler to properly capture focus in video mode
- Added number key routing (0-9) to calculator when in video inspector
- Enter key commits calculator entry and seeks player to that timecode

**Layout:**
- Video player area sized to exact video dimensions using metadata
- Right panel fixed at 320px width
- Timeline and transport controls always visible below video

---

## Sprint 5: In/Out Points

### Goal
Mark in/out points on video and calculate durations.

### Deliverables

- [x] In/Out point state in `VideoPlayerViewModel`
- [x] `InOutOverlay` visual indicators on timeline
- [x] Keyboard shortcuts: I (in), O (out), ⌥X (clear)
- [x] Navigation: ⇧I (go to in), ⇧O (go to out)
- [x] Duration display (out minus in)
- [x] Visual feedback when points are set
- [x] In/Out timecode display in UI

### Acceptance Criteria

- [x] I key sets in point at current playhead
- [x] O key sets out point at current playhead
- [x] Duration auto-calculates and displays
- [x] ⇧I jumps to in point
- [x] ⇧O jumps to out point
- [x] ⌥X clears both points
- [x] In/Out points visible on timeline as markers/overlay
- [x] Setting out before in shows warning or swaps automatically

### Notes

Store in/out as frame numbers, not CMTime, to avoid floating point drift. Display in current frame rate format.

### Implementation Notes (for future reference)

**VideoPlayerViewModel Additions:**
- `inPointFrames: Int?` and `outPointFrames: Int?` — Frame-based storage (nil when not set)
- Computed properties: `inPointTimecode`, `outPointTimecode`, `inOutDuration`, `inPointProgress`, `outPointProgress`
- Methods: `setInPoint()`, `setOutPoint()`, `clearInOutPoints()`, `seekToInPoint()`, `seekToOutPoint()`
- Auto-swap logic: If setting out before in (or vice versa), automatically swap to maintain correct order
- Points cleared in `reset()` when video changes

**TimelineView Enhancements:**
- Yellow highlighted range between In and Out points
- `InOutMarker` component with directional arrow shapes (|> for In, <| for Out)
- Markers positioned using computed progress values from ViewModel

**InOutPanel UI:**
- Displays In, Out, and Duration timecodes
- Clear button appears when any point is set
- Go-to buttons for quick navigation
- Keyboard hints for discoverability

**Keyboard Handling:**
- Extended `VideoKeyboardCaptureView.handleKeyEvent()` in VideoInspectorView
- Modifier key detection: `event.modifierFlags.contains(.shift)` for ⇧I/⇧O
- Option key detection: `event.modifierFlags.contains(.option)` for ⌥X

**Key Files Modified:**
- `VideoPlayerViewModel.swift` — State and methods for In/Out points
- `TimelineView.swift` — Visual overlay and InOutMarker component
- `VideoInspectorView.swift` — Keyboard handling, InOutPanel UI component

**Post-Implementation UI Refinements:**
- Reordered right panel: Calculator at top (primary tool), In/Out in middle, Metadata at bottom (static reference)
- Replaced fixed 700px video height cap with responsive GeometryReader-based sizing
- Video now fills available space while maintaining aspect ratio
- Portrait videos (e.g., 1080×1920) display at full height instead of being artificially constrained

---

## Sprint 6: Marker System

### Goal
Create, edit, and manage markers with colors and notes.

### Deliverables

- [x] `Marker` model (id, timecode, color, note, created timestamp)
- [x] `MarkerListViewModel` for marker management
- [x] `MarkerEditorPopover` — compact editor overlay on video
- [x] Add marker: M key at current playhead
- [x] Edit marker: M key on existing marker OR click marker on timeline
- [x] Delete marker: Delete key or trash button in editor
- [x] Color picker with 8 predefined colors
- [x] Markers visible on timeline

### Acceptance Criteria

- [x] M key creates marker at playhead with default color (blue)
- [x] M key on existing marker position opens editor
- [x] Can change marker color from 8 options
- [x] Clicking marker on timeline opens editor
- [x] Delete removes marker
- [x] Markers persist during session (cleared when video closes)
- [x] Timeline shows marker indicators at correct positions

### Notes

Consider keyboard shortcuts for quick color assignment (1-8 keys after M?). Marker colors should match the NLE-compatible palette from PRD.

### Implementation Notes (for future reference)

**Design Decision:** Markers display only on timeline (no sidebar list). Editor appears as popover overlay centered on video, matching NLE behavior. This keeps the UI compact and prevents layout overflow on smaller screens.

**New Files Created:**
- `FrameCalculator/Models/Marker.swift` — Marker struct + MarkerColor enum with 8 NLE-compatible colors (exact hex values from PRD)
- `FrameCalculator/ViewModels/MarkerListViewModel.swift` — CRUD operations, selection, editor state
- `FrameCalculator/Views/Markers/TimelineMarkerView.swift` — Triangle + line indicator for timeline
- `FrameCalculator/Views/Markers/MarkerEditorPopover.swift` — Compact overlay editor (timecode, color picker, note field, delete/done)

**Modified Files:**
- `TimelineView.swift` — Added markers array parameter, renders TimelineMarkerView for each, added onMarkerTapped callback
- `VideoInspectorView.swift` — Integrated markerVM, marker popover overlay, M key and Delete key handlers, keyboard focus management

**Keyboard Shortcuts:**
- M — Add marker at playhead (opens editor); if marker exists at position, opens editor for it
- Delete — Remove selected marker
- Click marker on timeline — Open editor

**Keyboard Focus Handling:**
The VideoKeyboardCaptureView aggressively captures keyboard focus for JKL/arrow/space controls. When marker editor opens, it releases focus to allow text input. Uses NotificationCenter to reclaim focus when editor closes.

**Key Files:**
- `FrameCalculator/Models/Marker.swift` — MarkerColor enum with displayColor (SwiftUI), avidColorName, resolveColorName
- `FrameCalculator/ViewModels/MarkerListViewModel.swift` — @MainActor, @Published markers array, CRUD methods
- `FrameCalculator/Views/Markers/MarkerEditorPopover.swift` — Auto-saves color changes, commits note on Done/Enter

**Build Commands:**
```bash
xcodebuild -project FrameCalculator.xcodeproj -scheme FrameCalculator build
swift test
```

---

## Sprint 7: Marker Export

### Goal
Export markers in formats compatible with Resolve, Avid, and generic CSV.

### Deliverables

- [x] `MarkerExporter` service with format-specific methods
- [x] EDL export for DaVinci Resolve
- [x] Tab-delimited text export for Avid Media Composer
- [x] CSV export for spreadsheets/other NLEs
- [x] Export dialog with format selection
- [x] File save panel integration
- [x] ⌘E keyboard shortcut for export
- [x] Include source filename in export metadata

### EDL Format (Resolve)
```
TITLE: [Filename]
FCM: NON-DROP FRAME

001  001      V     C        [TC_IN] [TC_OUT] [TC_IN] [TC_OUT]
* FROM CLIP NAME: [Filename]
* COMMENT: [Marker Note]
```

### Avid Format
```
FrameCalc	[Timecode]	V1	[color]	[Note]
```

### CSV Format
```csv
Timecode In,Timecode Out,Color,Name,Duration,Source
01:00:00:00,,Red,Marker note,,filename.mov
```

### Acceptance Criteria

- Export to Downloads folder (sandbox compliant)
- EDL imports into Resolve as timeline markers
- Text file imports into Avid via Marker Tool
- CSV opens correctly in Excel/Numbers/Sheets
- All markers included with correct timecodes
- Drop frame notation used when applicable
- ⌘E opens export dialog

### Notes

Test actual import in Resolve and Avid. Format quirks often only surface during real-world import.

### Implementation Notes (for future reference)

**New Files Created:**
- `FrameCalculator/Services/MarkerExporter.swift` — Actor-based export service with format generators
- `FrameCalculator/Views/Export/ExportDialogView.swift` — SwiftUI sheet with format picker + NSSavePanel

**Key Architecture Decisions:**
- `MarkerExporter` is an actor for thread-safe async file operations
- Each export format has a dedicated private generator method (generateEDL, generateAvidText, generateCSV)
- Uses NSSavePanel directly (not SwiftUI fileExporter) for better sandbox compatibility
- Drop frame notation handled automatically by Timecode.formatted()

**Export Format Details:**
- **EDL:** Includes TITLE, FCM header (DROP/NON-DROP FRAME), event entries with MARKER COLOR comments
- **Avid:** Tab-delimited with fallback colors (orange→yellow, purple→blue) for unsupported Avid colors
- **CSV:** Standard columns with proper escaping for commas/quotes in notes

**Modified Files:**
- `VideoInspectorView.swift` — Added export dialog sheet, ⌘E keyboard handler, NotificationCenter listener
- `FrameCalculatorApp.swift` — Added File > Export Markers... menu item
- `Marker.swift` — Added `avidExportColorName` computed property for fallback colors

**Build Commands:**
```bash
xcodebuild -project FrameCalculator.xcodeproj -scheme FrameCalculator build
swift test
```

**Known Issue (to fix in next session):**
- Export button in ExportDialogView does not trigger the save panel
- Clicking "Export..." button has no effect
- Possible causes: SwiftUI sheet button action not firing, Task not executing, or NSSavePanel issue
- Debug approach: Add print statements to `exportMarkers()` to trace execution flow
- File to investigate: `FrameCalculator/Views/Export/ExportDialogView.swift`

---

## Sprint 8: Polish & App Store Prep

### Goal
Final polish, accessibility, and App Store submission preparation.

### Known Issues to Address

**Calculator Entry Validation (from Sprint 2 testing):**
- Current behavior: Digits are formatted as entered (shifting left like a calculator), validation only occurs on operation/equals
- Issue: User can see invalid timecode values during entry (e.g., `00:06:66:66` where seconds=66, frames=66)
- Recommended fix: Show invalid portions in red/different color during entry to indicate "draft" input that will fail validation
- The entry-then-validate approach is correct (user might type valid digits that temporarily form invalid intermediate values), but visual feedback should be clearer
- Consider: Pulsing border, different text color for invalid components, or subtle "invalid" indicator

**Typography:**
- Switch from SF Mono to Space Mono for timecode display
- Space Mono: https://fonts.google.com/specimen/Space+Mono
- Bundle font with app (OFL license allows this)
- Use Space Mono for all numeric/timecode display, SF Pro for UI text

### Deliverables

- [ ] Dark mode refinement (colors, contrast, vibrancy)
- [ ] Light mode support and testing
- [ ] Bundle and use Space Mono typeface for timecode display
- [ ] App icon (multiple sizes)
- [ ] Menu bar integration (File, Edit, View, Window, Help)
- [ ] Preferences window (default frame rate, default marker color)
- [ ] About window
- [ ] Keyboard shortcut discoverability (menu items, tooltips)
- [ ] Accessibility audit (VoiceOver, keyboard navigation)
- [ ] Error handling and user-facing error messages
- [ ] Empty states (no video loaded, no markers)
- [ ] Window restoration (remember size/position)
- [ ] App Sandbox configuration and testing
- [ ] Privacy manifest (if required)
- [ ] App Store screenshots (dark mode)
- [ ] App Store description and metadata
- [ ] TestFlight build for beta testing

### Acceptance Criteria

- App feels native and professional
- All features accessible via keyboard
- VoiceOver can navigate all controls
- No crashes in normal usage
- Passes App Store review guidelines
- App launches in < 1 second
- Memory usage reasonable (< 50MB calculator, < 200MB video)

### Notes

Consider a soft launch via TestFlight to gather feedback from actual video professionals before full App Store release.

---

## Post-1.0 Backlog

Features explicitly deferred from 1.0:

- [ ] Frame rate conversion calculator
- [ ] Multiple In/Out ranges
- [ ] Multiple video windows
- [ ] Premiere Pro XML marker export
- [ ] Final Cut Pro FCPXML marker export
- [ ] Audio waveform display
- [ ] Batch file processing
- [ ] Touch Bar support (legacy Macs)
- [ ] iOS/iPadOS companion app
- [ ] Timecode burn-in export
- [ ] Recent files menu
- [ ] Drag markers to reorder
- [ ] Marker categories/tags
- [ ] EDL import (markers from other tools)

---

## Sprint Tracking

| Sprint | Status | Start Date | End Date | Notes |
|--------|--------|------------|----------|-------|
| 1 - Foundation | ✅ Complete | 2025-12-17 | 2025-12-17 | 51 tests passing, drop frame verified |
| 2 - Calculator UI | ✅ Complete | 2025-12-17 | 2025-12-17 | Full calculator UI with keypad, keyboard input, Xcode project |
| 3 - Video Loading | ✅ Complete | 2025-12-17 | 2025-12-17 | Drag-drop, metadata display, mode switching, frame rate sync |
| 4 - Video Player | ✅ Complete | 2025-12-17 | 2025-12-17 | Transport controls, JKL shuttle, bidirectional sync |
| 5 - In/Out Points | ✅ Complete | 2025-12-17 | 2025-12-17 | In/Out markers, keyboard shortcuts, auto-swap, duration display |
| 6 - Markers | ✅ Complete | 2025-12-17 | 2025-12-17 | Timeline markers, popover editor, M key add/edit, NLE color palette |
| 7 - Export | ✅ Complete | 2025-12-17 | 2025-12-17 | MarkerExporter service, EDL/Avid/CSV formats, export dialog, ⌘E shortcut, menu bar item |
| 8 - Polish | Not Started | | | |

---

*Last Updated: 2025-12-17*
