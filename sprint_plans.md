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

- [ ] `CalculatorViewModel` with operation state management
- [ ] `TimecodeDisplayView` — large, selectable timecode field
- [ ] `FrameRatePicker` — dropdown or segmented control
- [ ] `CalculatorView` — main calculator layout
- [ ] Operation mode selector (Add, Subtract, Multiply, Frame↔TC)
- [ ] Keyboard input for timecode entry
- [ ] Copy/paste support (⌘C, ⌘V) for timecode field
- [ ] Basic app window with calculator as default view

### Acceptance Criteria

- Can enter timecode via keyboard (numeric keys + colons)
- Can switch between all supported frame rates
- Addition: `01:00:00:00 + 00:30:00:00 = 01:30:00:00`
- Subtraction: `01:00:00:00 - 00:00:30:00 = 00:59:30:00`
- Multiplication: `00:00:30:00 × 4 = 00:02:00:00`
- Frame→TC: `86400 frames @ 24fps = 01:00:00:00`
- TC→Frame: `01:00:00:00 @ 24fps = 86400 frames`
- Copy timecode to clipboard, paste from clipboard
- Frame rate change recalculates displayed timecode

### Notes

Keep the window compact (~320×480pt). This is the "calculator app" mode users will use daily.

---

## Sprint 3: Video Loading & Metadata

### Goal
Implement drag-and-drop video loading and metadata extraction.

### Deliverables

- [ ] `VideoMetadata` model (duration, codec, bitrate, resolution, frame rate, color space, audio channels, file size)
- [ ] `VideoLoader` service using AVFoundation
- [ ] Drag-and-drop handler on main window
- [ ] `MetadataPanel` view displaying extracted info
- [ ] Auto-detect frame rate and set calculator accordingly
- [ ] `AppState` to track current mode (calculator vs video)
- [ ] Basic mode switching (calculator → video inspector)

### Acceptance Criteria

- Drop .mov, .mp4, .m4v files onto window
- Metadata panel shows all 8 metadata fields
- Frame rate auto-populates calculator's frame rate selector
- Unsupported files show appropriate error
- Can return to calculator-only mode (close video)

### Notes

Use `AVAsset.load(_:)` with async/await for metadata extraction. Handle files without embedded timecode gracefully (default to 00:00:00:00 start).

---

## Sprint 4: Video Player & Transport

### Goal
Full video playback with professional transport controls.

### Deliverables

- [ ] `VideoPlayerViewModel` managing AVPlayer state
- [ ] `VideoPlayerView` wrapping AVKit player
- [ ] `TransportControls` — play/pause, JKL shuttle
- [ ] `TimelineView` — scrubber/timeline with playhead
- [ ] Frame-accurate seeking (zero tolerance)
- [ ] Periodic timecode update to calculator display
- [ ] Frame stepping (←/→ arrow keys)
- [ ] Shuttle speed indicator (1×, 2×, 4×, etc.)
- [ ] `VideoInspectorView` — combined layout (player left, calculator right)

### Acceptance Criteria

- Space bar toggles play/pause
- J = reverse (stacks: 1×, 2×, 4×)
- K = stop
- L = forward (stacks: 1×, 2×, 4×)
- K+J or K+L = slow motion (optional, nice-to-have)
- Arrow keys step exactly one frame
- Timeline scrubbing is frame-accurate
- Calculator display updates in real-time during playback
- Responsive layout adapts to window resize

### Notes

Use `addPeriodicTimeObserver` with interval of `CMTime(value: 1, timescale: frameRate)` for smooth updates. Test with various codecs (ProRes, H.264, HEVC).

---

## Sprint 5: In/Out Points

### Goal
Mark in/out points on video and calculate durations.

### Deliverables

- [ ] In/Out point state in `VideoPlayerViewModel`
- [ ] `InOutOverlay` visual indicators on timeline
- [ ] Keyboard shortcuts: I (in), O (out), ⌥X (clear)
- [ ] Navigation: ⇧I (go to in), ⇧O (go to out)
- [ ] Duration display (out minus in)
- [ ] Visual feedback when points are set
- [ ] In/Out timecode display in UI

### Acceptance Criteria

- I key sets in point at current playhead
- O key sets out point at current playhead
- Duration auto-calculates and displays
- ⇧I jumps to in point
- ⇧O jumps to out point
- ⌥X clears both points
- In/Out points visible on timeline as markers/overlay
- Setting out before in shows warning or swaps automatically

### Notes

Store in/out as frame numbers, not CMTime, to avoid floating point drift. Display in current frame rate format.

---

## Sprint 6: Marker System

### Goal
Create, edit, and manage markers with colors and notes.

### Deliverables

- [ ] `Marker` model (id, timecode, color, note, created timestamp)
- [ ] `MarkerListViewModel` for marker management
- [ ] `MarkerListView` — table/list of all markers
- [ ] `MarkerRowView` — individual marker display
- [ ] `MarkerEditorSheet` — edit marker popover/sheet
- [ ] Add marker: M key at current playhead
- [ ] Edit marker: double-click in list
- [ ] Delete marker: select + Delete key
- [ ] Navigate to marker: click in list
- [ ] Color picker with 8 predefined colors
- [ ] Markers visible on timeline

### Acceptance Criteria

- M key creates marker at playhead with default color
- New marker opens editor for note entry
- Can change marker color from 8 options
- Markers sorted by timecode in list
- Clicking marker seeks player to that timecode
- Delete removes marker with confirmation (or undo)
- Markers persist during session (not saved to file yet)
- Timeline shows marker indicators at correct positions

### Notes

Consider keyboard shortcuts for quick color assignment (1-8 keys after M?). Marker colors should match the NLE-compatible palette from PRD.

---

## Sprint 7: Marker Export

### Goal
Export markers in formats compatible with Resolve, Avid, and generic CSV.

### Deliverables

- [ ] `MarkerExporter` service with format-specific methods
- [ ] EDL export for DaVinci Resolve
- [ ] Tab-delimited text export for Avid Media Composer
- [ ] CSV export for spreadsheets/other NLEs
- [ ] Export dialog with format selection
- [ ] File save panel integration
- [ ] ⌘E keyboard shortcut for export
- [ ] Include source filename in export metadata

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

---

## Sprint 8: Polish & App Store Prep

### Goal
Final polish, accessibility, and App Store submission preparation.

### Deliverables

- [ ] Dark mode refinement (colors, contrast, vibrancy)
- [ ] Light mode support and testing
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
| 2 - Calculator UI | Not Started | | | |
| 3 - Video Loading | Not Started | | | |
| 4 - Video Player | Not Started | | | |
| 5 - In/Out Points | Not Started | | | |
| 6 - Markers | Not Started | | | |
| 7 - Export | Not Started | | | |
| 8 - Polish | Not Started | | | |

---

*Last Updated: 2025-12-17*
