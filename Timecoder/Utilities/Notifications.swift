import Foundation

// MARK: - App Notifications

/// Consolidated notification names used throughout the app.
extension Notification.Name {
    /// Posted when the user requests to open a video file (via menu or button).
    static let openVideoFile = Notification.Name("openVideoFile")

    /// Posted when the user requests to add a marker at the current playhead.
    static let addMarkerAtPlayhead = Notification.Name("addMarkerAtPlayhead")

    /// Posted when the user requests to show the export dialog.
    static let showExportDialog = Notification.Name("showExportDialog")
}
