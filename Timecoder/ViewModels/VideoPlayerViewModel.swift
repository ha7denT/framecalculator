import Foundation
import AVFoundation
import Combine

/// Shuttle playback state for JKL controls.
enum ShuttleState: Int, Equatable {
    case reverse4x = -4
    case reverse2x = -2
    case reverse1x = -1
    case stopped = 0
    case forward1x = 1
    case forward2x = 2
    case forward4x = 4

    var rate: Float {
        Float(rawValue)
    }

    var displayString: String {
        switch self {
        case .reverse4x: return "◀◀ 4×"
        case .reverse2x: return "◀◀ 2×"
        case .reverse1x: return "◀ 1×"
        case .stopped: return "▶"
        case .forward1x: return "▶ 1×"
        case .forward2x: return "▶▶ 2×"
        case .forward4x: return "▶▶ 4×"
        }
    }

    /// Returns the next faster reverse speed.
    var fasterReverse: ShuttleState {
        switch self {
        case .forward4x, .forward2x, .forward1x, .stopped:
            return .reverse1x
        case .reverse1x:
            return .reverse2x
        case .reverse2x, .reverse4x:
            return .reverse4x
        }
    }

    /// Returns the next faster forward speed.
    var fasterForward: ShuttleState {
        switch self {
        case .reverse4x, .reverse2x, .reverse1x, .stopped:
            return .forward1x
        case .forward1x:
            return .forward2x
        case .forward2x, .forward4x:
            return .forward4x
        }
    }
}

/// View model managing video playback state and controls.
@MainActor
final class VideoPlayerViewModel: ObservableObject {

    // MARK: - Published Properties

    /// The current playhead position in frames.
    @Published private(set) var currentFrames: Int = 0

    /// The total duration in frames.
    @Published private(set) var totalFrames: Int = 0

    /// Whether the player is currently playing.
    @Published private(set) var isPlaying: Bool = false

    /// The current shuttle state for JKL controls.
    @Published private(set) var shuttleState: ShuttleState = .stopped

    /// The frame rate of the loaded video.
    @Published private(set) var frameRate: FrameRate = .fps24

    /// Whether the video has embedded timecode.
    @Published private(set) var hasEmbeddedTimecode: Bool = false

    /// The start timecode offset (for videos with embedded TC).
    @Published private(set) var startTimecodeFrames: Int = 0

    /// The In point position in frames (nil if not set).
    @Published private(set) var inPointFrames: Int? = nil

    /// The Out point position in frames (nil if not set).
    @Published private(set) var outPointFrames: Int? = nil

    // MARK: - Private Properties

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    /// Callback for when current timecode changes (for calculator sync).
    var onTimecodeChanged: ((Timecode) -> Void)?

    // MARK: - Computed Properties

    /// The current timecode (accounting for start offset).
    var currentTimecode: Timecode {
        let displayFrames = currentFrames + startTimecodeFrames
        return Timecode(frames: displayFrames, frameRate: frameRate)
    }

    /// The total duration as timecode.
    var durationTimecode: Timecode {
        Timecode(frames: totalFrames, frameRate: frameRate)
    }

    /// Progress from 0.0 to 1.0 for timeline display.
    var progress: Double {
        guard totalFrames > 0 else { return 0 }
        return Double(currentFrames) / Double(totalFrames)
    }

    /// The In point as timecode (nil if not set).
    var inPointTimecode: Timecode? {
        guard let inFrames = inPointFrames else { return nil }
        return Timecode(frames: inFrames + startTimecodeFrames, frameRate: frameRate)
    }

    /// The Out point as timecode (nil if not set).
    var outPointTimecode: Timecode? {
        guard let outFrames = outPointFrames else { return nil }
        return Timecode(frames: outFrames + startTimecodeFrames, frameRate: frameRate)
    }

    /// The duration between In and Out points (nil if either is not set).
    var inOutDuration: Timecode? {
        guard let inFrames = inPointFrames,
              let outFrames = outPointFrames else { return nil }
        let durationFrames = abs(outFrames - inFrames)
        return Timecode(frames: durationFrames, frameRate: frameRate)
    }

    /// In point progress for timeline display (nil if not set).
    var inPointProgress: Double? {
        guard let inFrames = inPointFrames, totalFrames > 0 else { return nil }
        return Double(inFrames) / Double(totalFrames)
    }

    /// Out point progress for timeline display (nil if not set).
    var outPointProgress: Double? {
        guard let outFrames = outPointFrames, totalFrames > 0 else { return nil }
        return Double(outFrames) / Double(totalFrames)
    }

    /// Whether both In and Out points are set.
    var hasInOutPoints: Bool {
        inPointFrames != nil && outPointFrames != nil
    }

    /// The current player time as CMTime.
    var currentTime: CMTime {
        player?.currentTime() ?? .zero
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Player Setup

    /// Configures the view model with a player and metadata.
    func configure(with player: AVPlayer, metadata: VideoMetadata) {
        self.player = player

        // Set frame rate from metadata
        if let detectedRate = FrameRate.from(fps: metadata.detectedFrameRate) {
            self.frameRate = detectedRate
        }

        // Set duration
        let durationSeconds = metadata.duration
        self.totalFrames = Int(durationSeconds * frameRate.framesPerSecond)

        // Set embedded timecode info
        self.hasEmbeddedTimecode = metadata.hasEmbeddedTimecode
        self.startTimecodeFrames = metadata.startTimecodeFrames ?? 0

        // Set up time observer
        setupTimeObserver()

        // Observe player status
        observePlayerStatus()
    }

    /// Removes the current player configuration.
    func reset() {
        removeTimeObserver()
        player = nil
        currentFrames = 0
        totalFrames = 0
        isPlaying = false
        shuttleState = .stopped
        inPointFrames = nil
        outPointFrames = nil
        cancellables.removeAll()
    }

    // MARK: - Playback Controls

    /// Toggles play/pause state.
    func togglePlayPause() {
        guard let player = player else { return }

        if isPlaying {
            pause()
        } else {
            // Resume at 1x forward
            shuttleState = .forward1x
            player.rate = 1.0
            isPlaying = true
        }
    }

    /// Pauses playback.
    func pause() {
        player?.pause()
        isPlaying = false
        shuttleState = .stopped
    }

    /// Handles J key press (reverse shuttle).
    func handleJ() {
        guard let player = player else { return }

        shuttleState = shuttleState.fasterReverse
        player.rate = shuttleState.rate
        isPlaying = shuttleState != .stopped
    }

    /// Handles K key press (stop).
    func handleK() {
        pause()
    }

    /// Handles L key press (forward shuttle).
    func handleL() {
        guard let player = player else { return }

        shuttleState = shuttleState.fasterForward
        player.rate = shuttleState.rate
        isPlaying = shuttleState != .stopped
    }

    /// Steps forward by one frame.
    func stepForward() {
        guard player != nil else { return }

        // Pause if playing
        if isPlaying {
            pause()
        }

        let newFrames = min(currentFrames + 1, totalFrames - 1)
        seek(toFrame: newFrames)
    }

    /// Steps backward by one frame.
    func stepBackward() {
        guard player != nil else { return }

        // Pause if playing
        if isPlaying {
            pause()
        }

        let newFrames = max(currentFrames - 1, 0)
        seek(toFrame: newFrames)
    }

    // MARK: - Seeking

    /// Seeks to a specific frame with frame-accurate positioning.
    func seek(toFrame frame: Int) {
        guard let player = player else { return }

        let clampedFrame = max(0, min(frame, totalFrames - 1))
        let time = CMTime(
            value: CMTimeValue(clampedFrame),
            timescale: CMTimeScale(frameRate.framesPerSecond)
        )

        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                self?.currentFrames = clampedFrame
                self?.notifyTimecodeChanged()
            }
        }
    }

    /// Seeks to a specific progress value (0.0 to 1.0).
    func seek(toProgress progress: Double) {
        let frame = Int(progress * Double(totalFrames))
        seek(toFrame: frame)
    }

    /// Seeks to a specific timecode.
    func seek(to timecode: Timecode) {
        // Convert timecode to elapsed frames (accounting for start offset)
        let targetFrames = timecode.frames - startTimecodeFrames
        seek(toFrame: targetFrames)
    }

    // MARK: - In/Out Points

    /// Sets the In point at the current playhead position.
    func setInPoint() {
        inPointFrames = currentFrames

        // If Out point is before In point, swap them
        if let outFrames = outPointFrames, outFrames < currentFrames {
            outPointFrames = inPointFrames
            inPointFrames = outFrames
        }
    }

    /// Sets the Out point at the current playhead position.
    func setOutPoint() {
        outPointFrames = currentFrames

        // If In point is after Out point, swap them
        if let inFrames = inPointFrames, inFrames > currentFrames {
            inPointFrames = outPointFrames
            outPointFrames = inFrames
        }
    }

    /// Clears both In and Out points.
    func clearInOutPoints() {
        inPointFrames = nil
        outPointFrames = nil
    }

    /// Seeks to the In point.
    func seekToInPoint() {
        guard let inFrames = inPointFrames else { return }
        seek(toFrame: inFrames)
    }

    /// Seeks to the Out point.
    func seekToOutPoint() {
        guard let outFrames = outPointFrames else { return }
        seek(toFrame: outFrames)
    }

    /// Seeks to a specific CMTime.
    func seek(to time: CMTime) {
        guard let player = player else { return }

        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                // Update current frames from the time
                let seconds = CMTimeGetSeconds(time)
                self.currentFrames = Int(seconds * self.frameRate.framesPerSecond)
                self.notifyTimecodeChanged()
            }
        }
    }

    /// Restores In/Out points from stored values (used for session restoration).
    func restoreInOutPoints(inFrames: Int?, outFrames: Int?) {
        self.inPointFrames = inFrames
        self.outPointFrames = outFrames
    }

    // MARK: - Private Methods

    private func setupTimeObserver() {
        guard let player = player else { return }

        removeTimeObserver()

        // Update at frame-rate interval for smooth display
        let interval = CMTime(value: 1, timescale: CMTimeScale(frameRate.framesPerSecond))

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.handleTimeUpdate(time)
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func handleTimeUpdate(_ time: CMTime) {
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite else { return }

        let frames = Int(seconds * frameRate.framesPerSecond)

        // Only update if changed
        if frames != currentFrames {
            currentFrames = frames
            notifyTimecodeChanged()
        }
    }

    private func notifyTimecodeChanged() {
        onTimecodeChanged?(currentTimecode)
    }

    private func observePlayerStatus() {
        guard let player = player else { return }

        // Observe rate changes to track play/pause state
        player.publisher(for: \.rate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                self?.isPlaying = rate != 0
                if rate == 0 {
                    self?.shuttleState = .stopped
                }
            }
            .store(in: &cancellables)

        // Observe when playback reaches the end
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isPlaying = false
                self?.shuttleState = .stopped
            }
            .store(in: &cancellables)
    }
}

// MARK: - FrameRate Extension

extension FrameRate {
    /// Creates a FrameRate from a detected FPS value.
    static func from(fps: Double) -> FrameRate? {
        // Match common frame rates with tolerance
        let tolerance = 0.01

        if abs(fps - 23.976) < tolerance { return .fps23_976 }
        if abs(fps - 24.0) < tolerance { return .fps24 }
        if abs(fps - 25.0) < tolerance { return .fps25 }
        if abs(fps - 29.97) < tolerance { return .fps29_97_ndf } // Default to NDF
        if abs(fps - 30.0) < tolerance { return .fps30 }
        if abs(fps - 50.0) < tolerance { return .fps50 }
        if abs(fps - 59.94) < tolerance { return .fps59_94 }
        if abs(fps - 60.0) < tolerance { return .fps60 }

        // For non-standard rates, use custom
        if fps > 0 {
            return .custom(fps)
        }

        return nil
    }
}
