import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Platform Clipboard

/// Cross-platform clipboard abstraction.
enum PlatformClipboard {
    /// Copies a string to the system clipboard.
    static func copy(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    /// Returns the current string from the system clipboard, if any.
    static func paste() -> String? {
        #if os(iOS)
        return UIPasteboard.general.string
        #elseif os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #endif
    }
}

// MARK: - Platform Colors

extension Color {
    /// Cross-platform equivalent of NSColor.controlBackgroundColor / UIColor.secondarySystemBackground.
    static var platformControlBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        Color(NSColor.controlBackgroundColor)
        #endif
    }

    /// Cross-platform equivalent of NSColor.windowBackgroundColor / UIColor.systemBackground.
    static var platformWindowBackground: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #elseif os(macOS)
        Color(NSColor.windowBackgroundColor)
        #endif
    }

    /// Cross-platform equivalent of NSColor.separatorColor / UIColor.separator.
    static var platformSeparator: Color {
        #if os(iOS)
        Color(UIColor.separator)
        #elseif os(macOS)
        Color(NSColor.separatorColor)
        #endif
    }
}

// MARK: - Platform URL

/// Cross-platform URL opening abstraction.
enum PlatformURL {
    /// Opens a URL using the platform's default handler.
    @MainActor
    static func open(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}

// MARK: - Platform Haptics

/// Cross-platform haptic feedback abstraction. No-op on macOS.
enum PlatformHaptics {
    static func lightImpact() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func mediumImpact() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

#if os(iOS)
// MARK: - Platform Layout

/// Layout helpers for responsive iOS sizing.
enum PlatformLayout {
    /// Computes an ideal keypad button size for the available width.
    /// - Parameters:
    ///   - availableWidth: The width of the containing view.
    ///   - spacing: Spacing between buttons (default 8).
    /// - Returns: A button size clamped between 44pt (min touch target) and 72pt.
    static func keypadButtonSize(forWidth availableWidth: CGFloat, spacing: CGFloat = 8) -> CGFloat {
        let size = (availableWidth - spacing * 5) / 4  // 4 cols, 3 gaps + 2 edge paddings
        return min(max(size, 44), 72)
    }
}
#endif
