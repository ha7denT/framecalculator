# Frame Calculator

## Product Requirements Document

**Version:** 1.0  
**Date:** December 2025

*A professional timecode calculator and video logging tool for macOS*

---

## 1. Executive Summary

Frame Calculator is a native macOS application designed for video and post-production professionals. It combines a timecode calculator with video inspection and logging capabilities, allowing editors, colorists, and post-production supervisors to quickly calculate durations, inspect media files, and create exportable marker lists for import into professional NLE systems.

The application prioritizes a clean, native Apple aesthetic with a dark-mode-first design to match the working environment of most video professionals.

---

## 2. Product Vision

### 2.1 Target Users

- Video Editors
- Colorists
- Post-Production Supervisors
- Assistant Editors
- Dailies Operators
- QC Technicians

### 2.2 Business Model

**Distribution:** Apple App Store (macOS)

**Pricing:** One-time purchase (no subscription, no ads, no in-app purchases)

**Philosophy:** A professional tool that respects users—no dark patterns, no telemetry beyond basic App Store analytics.

---

## 3. Core Features

### 3.1 Application Modes

The application operates in two distinct modes:

**Standalone Calculator Mode:** Compact calculator interface for timecode operations. No video loaded.

**Video Inspection Mode:** Video player with calculator attached to the right side. Activated when a video file is dropped onto the application.

---

### 3.2 Timecode Calculator

#### 3.2.1 Main Display

1. Primary timecode display field showing `HH:MM:SS:FF` format
2. Selectable text field allowing copy/paste operations (⌘C, ⌘V)
3. In Video Mode, displays current playhead timecode
4. Support for manual timecode entry via keyboard

#### 3.2.2 Supported Frame Rates

| Frame Rate | Type | Common Use |
|------------|------|------------|
| 23.976 | Non-Drop | Film / Cinema |
| 24 | Non-Drop | True Film |
| 25 | Non-Drop | PAL / EU Broadcast |
| 29.97 DF | Drop Frame | NTSC Broadcast |
| 29.97 NDF | Non-Drop Frame | NTSC Alternative |
| 30 | Non-Drop | Web / Digital |
| 50 | Non-Drop | PAL HFR |
| 59.94 | Non-Drop | NTSC HFR |
| 60 | Non-Drop | Gaming / Web HFR |
| Custom | User-defined | Specialty / VFX |

#### 3.2.3 Calculator Operations

**Timecode Addition:** Add two timecodes together (TC1 + TC2 = Result)

**Timecode Subtraction:** Subtract timecodes (TC1 − TC2 = Result)

**Frame Number to Timecode:** Convert absolute frame count to timecode at selected frame rate

**Timecode to Frame Number:** Convert timecode to absolute frame count

**Duration Multiplication:** Multiply a duration by a factor (e.g., `00:00:30:00 × 4 = 00:02:00:00`)

---

### 3.3 Video Inspection Features

#### 3.3.1 File Drop & Metadata Display

When a video file is dragged and dropped onto the application, the interface transforms to Video Inspection Mode and displays the following metadata:

1. **Duration** — Total length in timecode format
2. **Codec** — Video codec (e.g., ProRes 422, H.264, DNxHD)
3. **Bitrate** — Video bitrate in Mbps
4. **Resolution** — Frame dimensions (e.g., 1920×1080, 3840×2160)
5. **Frame Rate** — Detected frame rate (auto-sets calculator)
6. **Color Space** — Color profile (e.g., Rec.709, Rec.2020, DCI-P3)
7. **Audio Channels** — Number and configuration of audio tracks
8. **File Size** — Total file size in appropriate units

#### 3.3.2 Video Player Controls

**J-K-L Shuttle:** Industry-standard shuttle controls
- J — Reverse playback (multiple presses increase speed)
- K — Stop/Pause
- L — Forward playback (multiple presses increase speed)

**Scrubbing:** Click and drag on timeline or video frame to scrub through footage

**Frame Stepping:** Arrow keys for single-frame navigation

**Timecode Display:** Current playhead position shown in main calculator display

#### 3.3.3 In/Out Points

- Set In point (I key)
- Set Out point (O key)
- Duration between In/Out automatically calculated and displayed
- Clear In/Out points (⌥X)
- Go to In point (⇧I)
- Go to Out point (⇧O)

---

### 3.4 Marker System

#### 3.4.1 Marker Creation

1. Add marker at current playhead position (M key)
2. Each marker captures: Timecode, Color, Note text
3. Edit existing markers by double-clicking in marker list
4. Delete markers (select + Delete key)
5. Navigate to marker by clicking in marker list

#### 3.4.2 Marker Colors

The following colors are available for markers, selected for compatibility with both DaVinci Resolve and Avid Media Composer:

| Color | Hex | Resolve | Avid |
|-------|-----|---------|------|
| Red | #FF4444 | Red | red |
| Orange | #FFB347 | Orange | — |
| Yellow | #FFEE55 | Yellow | yellow |
| Green | #55CC55 | Green | green |
| Cyan | #55CCCC | Cyan | cyan |
| Blue | #5588EE | Blue | blue |
| Purple | #AA55CC | Purple | — |
| Pink | #FF88AA | Pink | magenta |

#### 3.4.3 Export Formats

**DaVinci Resolve (EDL Format)**

Markers are exported as an EDL file compatible with Resolve's "Import Timeline Markers from EDL" function. The EDL includes timecode and marker notes, which Resolve interprets as timeline markers.

**Avid Media Composer (Text Format)**

Markers are exported as a tab-delimited text file using Avid's marker import format:

```
[Username]    [Timecode]    [Track]    [Color]    [Comment]
```

Example:
```
FrameCalc    01:02:15:08    V1    red    VFX shot - needs cleanup
```

**Generic CSV Format**

A universal CSV export for spreadsheet applications or other NLEs, containing columns:

```csv
Timecode In,Timecode Out,Color,Name,Duration
01:00:00:00,,Red,Scene 1 Start,
01:02:15:08,,Green,VFX shot - needs cleanup,
```

---

## 4. User Interface Design

### 4.1 Design Principles

- **Native macOS Aesthetic:** Follow Apple's Human Interface Guidelines
- **Dark Mode First:** Primary design for dark mode (matching professional video environments)
- **Light Mode Support:** Full light mode support for accessibility
- **Minimal Chrome:** Focus on content, reduce visual clutter
- **Professional Typography:** Monospace for timecode display, SF Pro for UI

### 4.2 Standalone Calculator Mode Layout

Compact window (approximately 320×480pt) containing:

- Large timecode display (selectable/copyable)
- Frame rate selector (dropdown or segmented control)
- Calculator keypad or direct keyboard entry
- Operation mode selector (+, −, ×, Frame↔TC)
- Secondary display for operand/result
- Drop zone indicator (subtle, becomes prominent on drag-over)

### 4.3 Video Inspection Mode Layout

Expanded window with responsive layout:

**Left Side (Primary):** Video player with playback controls and timeline scrubber

**Right Side (Secondary):** Calculator panel + metadata display + marker list

**Bottom (Optional):** Collapsible detailed metadata panel

---

## 5. Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Space` | Play/Pause |
| `J` / `K` / `L` | Reverse / Stop / Forward shuttle |
| `←` / `→` | Step one frame back/forward |
| `I` | Set In point |
| `O` | Set Out point |
| `⇧I` / `⇧O` | Go to In/Out point |
| `⌥X` | Clear In/Out points |
| `M` | Add marker at current position |
| `⌘C` / `⌘V` | Copy/Paste timecode |
| `⌘E` | Export markers |
| `⌘,` | Preferences |

---

## 6. Architecture & Technical Design

### 6.1 Platform & Language

| Component | Choice |
|-----------|--------|
| Language | Swift 5.9+ |
| Minimum OS | macOS 13.0 (Ventura) |
| UI Framework | SwiftUI (primary) with AppKit integration |
| Video | AVFoundation / AVKit |
| Distribution | Mac App Store |

### 6.2 Architecture Pattern

**Recommended: MVVM with Swift Concurrency**

The app should follow Model-View-ViewModel architecture with clear separation of concerns:

```
FrameCalculator/
├── App/
│   ├── FrameCalculatorApp.swift          # @main entry point
│   └── AppState.swift                     # Global app state (mode, preferences)
│
├── Models/
│   ├── Timecode.swift                     # Timecode value type & calculations
│   ├── FrameRate.swift                    # Frame rate definitions & conversions
│   ├── Marker.swift                       # Marker model
│   ├── VideoMetadata.swift                # Extracted media metadata
│   └── ExportFormat.swift                 # Export format definitions
│
├── ViewModels/
│   ├── CalculatorViewModel.swift          # Calculator logic & state
│   ├── VideoPlayerViewModel.swift         # Playback control & state
│   ├── MarkerListViewModel.swift          # Marker management
│   └── MetadataViewModel.swift            # Media inspection
│
├── Views/
│   ├── Calculator/
│   │   ├── CalculatorView.swift           # Main calculator interface
│   │   ├── TimecodeDisplayView.swift      # Large TC display
│   │   ├── FrameRatePicker.swift          # Frame rate selector
│   │   └── KeypadView.swift               # Optional on-screen keypad
│   │
│   ├── VideoPlayer/
│   │   ├── VideoPlayerView.swift          # AVKit player wrapper
│   │   ├── TransportControls.swift        # Play/pause, JKL
│   │   ├── TimelineView.swift             # Scrubber with In/Out
│   │   └── InOutOverlay.swift             # Visual In/Out indicators
│   │
│   ├── Markers/
│   │   ├── MarkerListView.swift           # Marker table/list
│   │   ├── MarkerRowView.swift            # Individual marker row
│   │   └── MarkerEditorSheet.swift        # Edit marker popover
│   │
│   ├── Metadata/
│   │   └── MetadataPanel.swift            # File info display
│   │
│   └── Main/
│       ├── ContentView.swift              # Mode-switching container
│       ├── StandaloneCalculatorView.swift # Calculator-only layout
│       └── VideoInspectorView.swift       # Full video + calculator layout
│
├── Services/
│   ├── VideoLoader.swift                  # AVAsset loading & metadata extraction
│   ├── TimecodeEngine.swift               # Core TC math (stateless)
│   ├── MarkerExporter.swift               # EDL/Avid/CSV generation
│   └── KeyboardHandler.swift              # Global keyboard shortcut handling
│
├── Utilities/
│   ├── Timecode+Formatting.swift          # String parsing & display
│   ├── AVAsset+Metadata.swift             # AVFoundation extensions
│   └── Color+MarkerColors.swift           # Marker color definitions
│
└── Resources/
    └── Assets.xcassets                    # App icons, colors
```

### 6.3 Key Technical Decisions

#### Timecode as Value Type

```swift
struct Timecode: Equatable, Hashable, Codable {
    let frames: Int
    let frameRate: FrameRate
    
    var hours: Int { /* calculated */ }
    var minutes: Int { /* calculated */ }
    var seconds: Int { /* calculated */ }
    var frameComponent: Int { /* calculated */ }
    
    static func + (lhs: Timecode, rhs: Timecode) -> Timecode
    static func - (lhs: Timecode, rhs: Timecode) -> Timecode
    func multiplied(by factor: Double) -> Timecode
}
```

Timecode should be stored internally as a frame count with an associated frame rate. This makes arithmetic simple and accurate.

#### Frame Rate Handling

```swift
enum FrameRate: Codable, CaseIterable {
    case fps23_976
    case fps24
    case fps25
    case fps29_97_df
    case fps29_97_ndf
    case fps30
    case fps50
    case fps59_94
    case fps60
    case custom(Double)
    
    var isDropFrame: Bool { /* ... */ }
    var framesPerSecond: Double { /* ... */ }
}
```

#### Video Playback with AVKit

Use `AVPlayer` wrapped in a SwiftUI-compatible view. Key considerations:

- Use `addPeriodicTimeObserver` for timecode display updates (recommend 1/frame-rate interval)
- Seek with `seek(to:toleranceBefore:toleranceAfter:)` using `.zero` tolerance for frame-accurate positioning
- Extract metadata via `AVAsset.loadMetadata(for:)` using async/await

#### JKL Shuttle Implementation

```swift
class ShuttleController: ObservableObject {
    @Published var shuttleSpeed: Double = 0  // -4x to 4x
    
    func handleJ() { shuttleSpeed = max(shuttleSpeed - 1, -4) }
    func handleK() { shuttleSpeed = 0; player.pause() }
    func handleL() { shuttleSpeed = min(shuttleSpeed + 1, 4) }
}
```

Implement variable-speed playback using `AVPlayer.rate`.

#### Keyboard Handling

For global shortcuts (working even when specific views aren't focused), use:

```swift
.onKeyPress { keyPress in
    switch keyPress.key {
    case .space: // play/pause
    case "j", "J": // reverse
    // etc.
    }
}
```

Or for more complex scenarios, implement an `NSEvent` local monitor.

### 6.4 App Sandbox & Entitlements

Required entitlements for App Store submission:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
</dict>
</plist>
```

- **User-selected files (read-only):** Required for drag-and-drop video loading
- **Downloads (read-write):** Required for marker export to Downloads folder

### 6.5 Supported Video Formats

Support for all formats playable by AVFoundation:

- QuickTime (.mov) — ProRes, DNxHD/HR, H.264, HEVC
- MP4 (.mp4, .m4v) — H.264, HEVC
- MXF — OP1a with supported codecs (via system QuickTime components)

### 6.6 Performance Targets

| Metric | Target |
|--------|--------|
| App launch to interactive | < 1 second |
| Video file load (1GB ProRes) | < 2 seconds |
| Timecode display update latency | < 1 frame |
| Memory footprint (calculator mode) | < 50 MB |
| Memory footprint (video mode) | < 200 MB + video buffer |

---

## 7. Technical Requirements Summary

### 7.1 Platform Requirements

1. macOS 13.0 (Ventura) or later
2. Native Apple Silicon support (Universal Binary)
3. App Sandbox compliant for App Store distribution
4. Hardened Runtime enabled

### 7.2 Dependencies

Prefer zero external dependencies. Use only Apple frameworks:

- **SwiftUI** — UI layer
- **AVFoundation / AVKit** — Video playback and metadata
- **CoreMedia** — Timecode handling primitives
- **UniformTypeIdentifiers** — File type handling for drag/drop

If absolutely necessary, consider:
- **swift-collections** (Apple) — For OrderedDictionary in marker management

---

## 8. Future Considerations

The following features are explicitly out of scope for v1.0 but may be considered for future releases:

1. Frame rate conversion calculations
2. Multiple simultaneous In/Out ranges
3. Multiple video windows
4. Adobe Premiere Pro marker export (XML format)
5. Final Cut Pro marker export (FCPXML format)
6. Audio waveform display
7. Batch file processing
8. iOS/iPadOS companion app
9. Touch Bar support (legacy)
10. Timecode burn-in export

---

## 9. Success Metrics

- **App Store Rating:** Maintain 4.5+ star average
- **Crash-Free Rate:** > 99.5% sessions without crashes
- **Launch Time:** < 1 second to interactive calculator
- **Video Load Time:** < 2 seconds for typical broadcast files
- **User Retention:** Qualitative feedback from professional community

---

*— End of Document —*
