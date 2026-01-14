import Foundation
import Combine

/// View model for managing video markers.
@MainActor
final class MarkerListViewModel: ObservableObject {
    // MARK: - Published Properties

    /// All markers in the current session.
    @Published private(set) var markers: [Marker] = []

    /// Currently selected marker ID (for keyboard navigation and deletion).
    @Published var selectedMarkerID: UUID?

    /// Whether the marker editor sheet is presented.
    @Published var isEditorPresented: Bool = false

    /// The marker currently being edited (nil when creating new or not editing).
    @Published var editingMarker: Marker?

    // MARK: - Computed Properties

    /// Markers sorted by timecode position (ascending).
    var sortedMarkers: [Marker] {
        markers.sorted { $0.timecodeFrames < $1.timecodeFrames }
    }

    /// The currently selected marker, if any.
    var selectedMarker: Marker? {
        guard let id = selectedMarkerID else { return nil }
        return markers.first { $0.id == id }
    }

    /// Whether any markers exist.
    var hasMarkers: Bool {
        !markers.isEmpty
    }

    // MARK: - CRUD Operations

    /// Adds a new marker at the specified frame position.
    /// - Parameters:
    ///   - frames: Frame position in the video.
    ///   - color: Marker color (defaults to blue).
    ///   - note: Note text (defaults to empty).
    /// - Returns: The newly created marker.
    @discardableResult
    func addMarker(at frames: Int, color: MarkerColor = .blue, note: String = "") -> Marker {
        let marker = Marker(timecodeFrames: frames, color: color, note: note)
        markers.append(marker)
        selectedMarkerID = marker.id
        return marker
    }

    /// Updates an existing marker with new values.
    /// - Parameter marker: The marker with updated values.
    func updateMarker(_ marker: Marker) {
        guard let index = markers.firstIndex(where: { $0.id == marker.id }) else { return }
        markers[index] = marker
    }

    /// Deletes a marker by ID.
    /// - Parameter id: The ID of the marker to delete.
    func deleteMarker(id: UUID) {
        markers.removeAll { $0.id == id }

        // Clear selection if deleted marker was selected
        if selectedMarkerID == id {
            selectedMarkerID = nil
        }
    }

    /// Deletes the currently selected marker.
    func deleteSelectedMarker() {
        guard let id = selectedMarkerID else { return }
        deleteMarker(id: id)
    }

    /// Restores markers from a stored session.
    /// - Parameter storedMarkers: The markers to restore.
    func restoreMarkers(_ storedMarkers: [Marker]) {
        markers = storedMarkers
        selectedMarkerID = nil
        editingMarker = nil
        isEditorPresented = false
    }

    /// Removes all markers (e.g., when video is closed).
    func clearAllMarkers() {
        markers.removeAll()
        selectedMarkerID = nil
        editingMarker = nil
        isEditorPresented = false
    }

    // MARK: - Editor Control

    /// Opens the editor for an existing marker.
    /// - Parameter marker: The marker to edit.
    func openEditor(for marker: Marker) {
        editingMarker = marker
        isEditorPresented = true
    }

    /// Opens the editor for a new marker at the specified frame position.
    /// Note: This creates the marker immediately with default values.
    /// - Parameter frames: Frame position for the new marker.
    func openEditorForNewMarker(at frames: Int) {
        let marker = addMarker(at: frames)
        editingMarker = marker
        isEditorPresented = true
    }

    /// Closes the editor without saving (changes are discarded).
    func closeEditor() {
        editingMarker = nil
        isEditorPresented = false
    }

    /// Saves changes from the editor and closes it.
    func saveAndCloseEditor() {
        if let marker = editingMarker {
            updateMarker(marker)
        }
        closeEditor()
    }

    // MARK: - Selection

    /// Selects a marker by ID.
    /// - Parameter id: The ID of the marker to select.
    func selectMarker(id: UUID) {
        selectedMarkerID = id
    }

    /// Clears the current selection.
    func clearSelection() {
        selectedMarkerID = nil
    }

    /// Selects the next marker in the sorted list.
    func selectNextMarker() {
        let sorted = sortedMarkers
        guard !sorted.isEmpty else { return }

        if let currentID = selectedMarkerID,
           let currentIndex = sorted.firstIndex(where: { $0.id == currentID }) {
            let nextIndex = min(currentIndex + 1, sorted.count - 1)
            selectedMarkerID = sorted[nextIndex].id
        } else {
            selectedMarkerID = sorted.first?.id
        }
    }

    /// Selects the previous marker in the sorted list.
    func selectPreviousMarker() {
        let sorted = sortedMarkers
        guard !sorted.isEmpty else { return }

        if let currentID = selectedMarkerID,
           let currentIndex = sorted.firstIndex(where: { $0.id == currentID }) {
            let previousIndex = max(currentIndex - 1, 0)
            selectedMarkerID = sorted[previousIndex].id
        } else {
            selectedMarkerID = sorted.last?.id
        }
    }

    // MARK: - Helpers

    /// Finds a marker at or near the specified frame position.
    /// - Parameters:
    ///   - frames: The frame position to search.
    ///   - tolerance: Frame tolerance for matching (defaults to 0).
    /// - Returns: The marker if found, nil otherwise.
    func marker(at frames: Int, tolerance: Int = 0) -> Marker? {
        markers.first { marker in
            abs(marker.timecodeFrames - frames) <= tolerance
        }
    }

    /// Calculates the progress (0.0 to 1.0) of a marker on the timeline.
    /// - Parameters:
    ///   - marker: The marker to calculate progress for.
    ///   - totalFrames: Total frames in the video.
    /// - Returns: Progress value between 0.0 and 1.0.
    func markerProgress(for marker: Marker, totalFrames: Int) -> Double {
        guard totalFrames > 0 else { return 0 }
        return Double(marker.timecodeFrames) / Double(totalFrames)
    }

    // MARK: - Marker Navigation

    /// Finds the next marker after the specified frame position.
    /// - Parameter currentFrames: The current playhead position in frames.
    /// - Returns: The next marker if one exists, nil otherwise.
    func nextMarker(after currentFrames: Int) -> Marker? {
        sortedMarkers.first { $0.timecodeFrames > currentFrames }
    }

    /// Finds the previous marker before the specified frame position.
    /// - Parameter currentFrames: The current playhead position in frames.
    /// - Returns: The previous marker if one exists, nil otherwise.
    func previousMarker(before currentFrames: Int) -> Marker? {
        sortedMarkers.last { $0.timecodeFrames < currentFrames }
    }

    /// Returns the frame position of the next marker, or nil if none exists.
    /// - Parameter currentFrames: The current playhead position in frames.
    /// - Returns: Frame position of the next marker, or nil.
    func nextMarkerFrames(after currentFrames: Int) -> Int? {
        nextMarker(after: currentFrames)?.timecodeFrames
    }

    /// Returns the frame position of the previous marker, or nil if none exists.
    /// - Parameter currentFrames: The current playhead position in frames.
    /// - Returns: Frame position of the previous marker, or nil.
    func previousMarkerFrames(before currentFrames: Int) -> Int? {
        previousMarker(before: currentFrames)?.timecodeFrames
    }
}
