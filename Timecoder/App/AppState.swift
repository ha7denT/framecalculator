import Foundation
import SwiftUI
import AVFoundation

/// Represents the current mode of the application.
public enum AppMode: Equatable {
    /// Standalone calculator mode (no video loaded).
    case calculator

    /// Video inspection mode (video loaded with calculator attached).
    case videoInspector
}

/// Represents video orientation for layout purposes.
/// Videos are categorized into two modes for predictable UI layout.
public enum VideoOrientation: Equatable {
    /// Landscape orientation (aspect ratio >= 1.0)
    /// Includes: 16:9, 4:3, 2.35:1, 1:1, etc.
    case landscape

    /// Portrait orientation (aspect ratio < 1.0)
    /// Includes: 9:16, 3:4, etc.
    case portrait

    /// Determines orientation from aspect ratio.
    /// - Parameter aspectRatio: Width divided by height
    /// - Returns: `.landscape` if ratio >= 1.0, otherwise `.portrait`
    static func from(aspectRatio: CGFloat) -> VideoOrientation {
        aspectRatio >= 1.0 ? .landscape : .portrait
    }

    /// Height for timeline and transport controls below the video
    static let controlsHeight: CGFloat = 110

    /// Fixed frame size for the video player area in this orientation.
    var videoFrameSize: CGSize {
        switch self {
        case .landscape:
            return CGSize(width: 960, height: 540)  // 16:9 proportions (qHD)
        case .portrait:
            return CGSize(width: 394, height: 700)  // 9:16 proportions
        }
    }

    /// Total height of video area (video frame + timeline + transport controls)
    var videoAreaHeight: CGFloat {
        videoFrameSize.height + Self.controlsHeight
    }

    /// Target window size for this orientation.
    /// Height is based on video area - right panel scrolls within this height.
    var windowSize: NSSize {
        let contentHeight = videoAreaHeight + 28  // Add title bar
        let contentWidth = videoFrameSize.width + 320 + 16  // video + right panel + divider/padding
        return NSSize(width: contentWidth, height: contentHeight)
    }
}

/// Represents the state of video loading.
public enum VideoLoadingState: Equatable {
    case idle
    case loading
    case loaded(VideoMetadata)
    case error(String)

    public static func == (lhs: VideoLoadingState, rhs: VideoLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading, .loading):
            return true
        case (.loaded(let lhsMetadata), .loaded(let rhsMetadata)):
            return lhsMetadata == rhsMetadata
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

/// Stores video session data for restoration when switching between modes.
struct StoredVideoSession {
    let url: URL
    let metadata: VideoMetadata
    let player: AVPlayer
    let playerTime: CMTime
    let inPointFrames: Int?
    let outPointFrames: Int?
    let markers: [Marker]
}

/// Global application state managing mode and video.
@MainActor
public final class AppState: ObservableObject {

    // MARK: - Published Properties

    /// The current application mode.
    @Published public private(set) var mode: AppMode = .calculator

    /// The current video loading state.
    @Published public private(set) var videoState: VideoLoadingState = .idle

    /// The AVPlayer for video playback (nil when no video loaded).
    @Published public private(set) var player: AVPlayer?

    /// Whether there's a stored session that can be restored.
    @Published public private(set) var hasStoredSession: Bool = false

    // MARK: - Private Properties

    private let videoLoader = VideoLoader()

    /// Stored session for restoration when switching back to logger mode.
    private var storedSession: StoredVideoSession?

    // MARK: - Computed Properties

    /// The currently loaded video metadata, if any.
    public var currentMetadata: VideoMetadata? {
        if case .loaded(let metadata) = videoState {
            return metadata
        }
        return nil
    }

    /// Whether a video is currently loaded.
    public var hasVideo: Bool {
        currentMetadata != nil
    }

    /// Whether video is currently loading.
    public var isLoading: Bool {
        if case .loading = videoState {
            return true
        }
        return false
    }

    /// Error message if loading failed.
    public var errorMessage: String? {
        if case .error(let message) = videoState {
            return message
        }
        return nil
    }

    // MARK: - Public Methods

    /// Loads a video from the given URL.
    /// - Parameter url: The URL of the video file.
    public func loadVideo(from url: URL) async {
        // Clear any stored session when loading a new video
        clearStoredSession()

        videoState = .loading

        do {
            let metadata = try await videoLoader.loadVideo(from: url)
            player = await videoLoader.createPlayer(for: url)
            videoState = .loaded(metadata)
            mode = .videoInspector
        } catch let error as VideoLoadError {
            videoState = .error(error.localizedDescription)
        } catch {
            videoState = .error("An unexpected error occurred: \(error.localizedDescription)")
        }
    }

    /// Closes the current video and returns to calculator mode.
    /// Also clears any stored session.
    public func closeVideo() {
        player?.pause()
        player = nil
        videoState = .idle
        storedSession = nil
        hasStoredSession = false
        mode = .calculator
    }

    /// Switches to calculator mode, storing the current session for later restoration.
    /// Call this when the user wants to temporarily use the calculator.
    /// - Parameters:
    ///   - playerTime: Current player position
    ///   - inPointFrames: In point frame number (nil if not set)
    ///   - outPointFrames: Out point frame number (nil if not set)
    ///   - markers: Current list of markers
    func switchToCalculatorMode(
        playerTime: CMTime,
        inPointFrames: Int?,
        outPointFrames: Int?,
        markers: [Marker]
    ) {
        // Store current session
        if case .loaded(let metadata) = videoState,
           let player = player,
           let url = (player.currentItem?.asset as? AVURLAsset)?.url {
            player.pause()
            storedSession = StoredVideoSession(
                url: url,
                metadata: metadata,
                player: player,
                playerTime: playerTime,
                inPointFrames: inPointFrames,
                outPointFrames: outPointFrames,
                markers: markers
            )
            hasStoredSession = true
        }

        mode = .calculator
    }

    /// Attempts to restore a stored session.
    /// - Returns: The stored session if one exists, nil otherwise.
    /// The caller is responsible for configuring the player and marker view models.
    func restoreSession() -> StoredVideoSession? {
        guard let session = storedSession else { return nil }

        // Restore player and metadata
        player = session.player
        videoState = .loaded(session.metadata)
        mode = .videoInspector

        return session
    }

    /// Clears the stored session without switching modes.
    /// Called when loading a new video to clear the old session.
    func clearStoredSession() {
        storedSession = nil
        hasStoredSession = false
    }

    /// Clears any error state.
    public func clearError() {
        if case .error = videoState {
            videoState = .idle
        }
    }

    /// Handles files dropped onto the application.
    /// - Parameter providers: The item providers from the drop.
    /// - Returns: Whether the drop was handled.
    public func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // Check if provider can load a file URL
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, error in
                guard let url = url, error == nil else { return }
                Task { @MainActor in
                    await self?.loadVideo(from: url)
                }
            }
            return true
        }

        // Also handle file representations
        if provider.hasItemConformingToTypeIdentifier("public.movie") ||
           provider.hasItemConformingToTypeIdentifier("public.video") ||
           provider.hasItemConformingToTypeIdentifier("com.apple.quicktime-movie") {
            provider.loadFileRepresentation(forTypeIdentifier: "public.movie") { [weak self] url, error in
                guard let url = url, error == nil else { return }
                // Copy to temp location since the provided URL is temporary
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tempURL)
                try? FileManager.default.copyItem(at: url, to: tempURL)
                Task { @MainActor in
                    await self?.loadVideo(from: tempURL)
                }
            }
            return true
        }

        return false
    }
}

// MARK: - User Preferences

/// Global user preferences stored in UserDefaults.
@MainActor
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    /// Default frame rate for new sessions.
    @Published var defaultFrameRate: FrameRate {
        didSet {
            if let encoded = try? JSONEncoder().encode(defaultFrameRate) {
                UserDefaults.standard.set(encoded, forKey: "defaultFrameRate")
            }
        }
    }

    /// Default color for new markers.
    @Published var defaultMarkerColor: MarkerColor {
        didSet {
            UserDefaults.standard.set(defaultMarkerColor.rawValue, forKey: "defaultMarkerColor")
        }
    }

    /// Whether to remember window position.
    @Published var rememberWindowPosition: Bool {
        didSet {
            UserDefaults.standard.set(rememberWindowPosition, forKey: "rememberWindowPosition")
        }
    }

    /// Preferred color scheme (nil = system, true = dark, false = light).
    @Published var preferDarkMode: Bool? {
        didSet {
            if let value = preferDarkMode {
                UserDefaults.standard.set(value, forKey: "preferDarkMode")
                UserDefaults.standard.set(false, forKey: "useSystemAppearance")
            } else {
                UserDefaults.standard.removeObject(forKey: "preferDarkMode")
                UserDefaults.standard.set(true, forKey: "useSystemAppearance")
            }
        }
    }

    private init() {
        // Load default frame rate
        if let data = UserDefaults.standard.data(forKey: "defaultFrameRate"),
           let frameRate = try? JSONDecoder().decode(FrameRate.self, from: data) {
            self.defaultFrameRate = frameRate
        } else {
            self.defaultFrameRate = .fps24
        }

        // Load default marker color
        if let colorRaw = UserDefaults.standard.string(forKey: "defaultMarkerColor"),
           let color = MarkerColor(rawValue: colorRaw) {
            self.defaultMarkerColor = color
        } else {
            self.defaultMarkerColor = .blue
        }

        // Load window restoration preference
        self.rememberWindowPosition = UserDefaults.standard.bool(forKey: "rememberWindowPosition")

        // Load appearance preference
        if UserDefaults.standard.bool(forKey: "useSystemAppearance") {
            self.preferDarkMode = nil
        } else if UserDefaults.standard.object(forKey: "preferDarkMode") != nil {
            self.preferDarkMode = UserDefaults.standard.bool(forKey: "preferDarkMode")
        } else {
            // Default to dark mode
            self.preferDarkMode = true
        }
    }
}

// MARK: - Font Extension

extension Font {
    /// Space Mono font for timecode display.
    /// Falls back to system monospace if Space Mono isn't available.
    static func spaceMono(size: CGFloat, weight: Weight = .regular) -> Font {
        let fontName = weight == .bold ? "SpaceMono-Bold" : "SpaceMono-Regular"

        // Check if Space Mono is available
        if let _ = NSFont(name: fontName, size: size) {
            return .custom(fontName, size: size)
        }

        // Fallback to system monospace
        return .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Timecoder Color Theme

extension Color {
    /// Teal accent color - primary accent for buttons, selections, highlights
    /// Hex: #65DEF1
    static let timecoderTeal = Color(red: 0.396, green: 0.871, blue: 0.945)

    /// Orange accent color - secondary accent for operations, warnings, In/Out points
    /// Hex: #F96900
    static let timecoderOrange = Color(red: 0.976, green: 0.412, blue: 0.0)

    /// Dark button background color
    static let timecoderButtonBackground = Color(red: 0.2, green: 0.2, blue: 0.21)
}
