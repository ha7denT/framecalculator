# Timecoder

A native macOS timecode calculator and video logging tool for post-production professionals.

## Project Overview

Timecoder operates in two modes:
1. **Standalone Calculator** — Compact timecode calculator (add, subtract, multiply, frame↔TC conversion)
2. **Video Inspection** — Video player + calculator with metadata display and marker export

Target: Mac App Store distribution. One-time purchase, no subscriptions.

## Tech Stack

- **Language:** Swift 5.9+
- **UI:** SwiftUI (AppKit integration where needed)
- **Video:** AVFoundation / AVKit
- **Minimum OS:** macOS 13.0 (Ventura)
- **Architecture:** MVVM

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
│   └── Main/               # ContentView, mode-switching layouts
├── Services/               # VideoLoader, TimecodeEngine, MarkerExporter
└── Utilities/              # Extensions, helpers
```

## Commands

```bash
# Build
xcodebuild -scheme Timecoder -configuration Debug build

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
- Monospace font (SF Mono) for timecode display
- SF Pro for UI text
- Minimal chrome, focus on content

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
- Apple docs: AVFoundation, AVKit, SwiftUI

## Common Pitfalls

- Don't use floating point for frame counts — accumulates errors
- Drop frame is a *display* format, not a different frame rate (29.97 DF and NDF are the same rate)
- AVPlayer time is in seconds (CMTime), convert to frames using frame rate
- Timecode display must handle negative durations (show as `-HH:MM:SS:FF`)
