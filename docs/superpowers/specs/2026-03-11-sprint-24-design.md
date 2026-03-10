# Sprint 24: Marker Overlay, iPhone Landscape Video & iPad Tweaks

**Date:** 2026-03-11

---

## 1. Marker Text Overlay (All Platforms)

When the playback head is on a frame that has a marker, a text overlay appears in the top-left corner of the video view.

### Appearance
- Black background at ~50% opacity, rounded corners
- Small coloured dot (matching marker colour) to the left of the marker text
- White text, SF Pro, ~13pt
- Auto-sizes to fit text, max width ~60% of video width, wraps if needed
- Small padding/margin from the top-left edge

### Behavior
- Shows for the exact frame(s) the marker occupies — frame-accurate, no minimum duration
- Appears/disappears instantly (no fade)
- If multiple markers on the same frame, show the first one (ordered by creation)

### Implementation
- SwiftUI overlay on `CustomVideoPlayerView` (not inside the AVPlayer layer)
- `VideoPlayerViewModel` publishes an optional `activeMarker` property, updated in the existing periodic time observer
- On each tick, check if current frame matches any marker's `timecodeFrames` — if so, set `activeMarker`; otherwise nil
- New `MarkerOverlayView` — reads `activeMarker` and renders the overlay box

---

## 2. iPhone Landscape Video Mode

Allow landscape rotation in video mode only. Landscape shows full-screen video with overlay transport controls.

### Behavior
- `iOSAppDelegate` updated: portrait-only for calculator mode, portrait + landscape for video mode
- Landscape: video fills screen, all other UI hidden (metadata, keypad, in/out, timeline)
- Transport controls as Liquid Glass overlay, auto-hide after 3 seconds, tap to show/hide
- Marker overlay stays visible independently of transport controls
- Rotating back to portrait restores the current portrait layout
- System rotation handles transition — no custom animations

### Implementation
- `iOSAppDelegate` tracks current mode via `AppState`, returns appropriate supported orientations
- Landscape layout is a separate view branch in `iOSVideoInspectorView` using geometry width > height detection
- New `OverlayTransportControls` view with opacity animation, tap gesture, and timer-based auto-hide (3s)

---

## 3. iPad Layout Refresh

Move iPad closer to macOS desktop layout with overlay transport controls.

### Approach
- Side-by-side layout: video left, calculator + metadata right (mirroring macOS)
- Replace inline transport controls with `OverlayTransportControls` (shared with iPhone landscape)
- Specific sizing/spacing to be iterated visually once running

---

## Build Order

1. Marker overlay (cross-platform, no layout changes)
2. `OverlayTransportControls` (reusable component)
3. iPhone landscape video mode
4. iPad layout refresh
