import Foundation
import AVFoundation

/// Errors that can occur during video loading.
public enum VideoLoadError: LocalizedError {
    case fileNotFound
    case invalidVideoFile
    case noVideoTrack
    case loadingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The video file could not be found."
        case .invalidVideoFile:
            return "The file is not a valid video format."
        case .noVideoTrack:
            return "No video track found in the file."
        case .loadingFailed(let error):
            return "Failed to load video: \(error.localizedDescription)"
        }
    }
}

/// Service for loading video files and extracting metadata using AVFoundation.
public actor VideoLoader {

    public init() {}

    /// Loads a video file and extracts its metadata.
    /// - Parameter url: The URL of the video file.
    /// - Returns: The extracted metadata.
    /// - Throws: VideoLoadError if the file cannot be loaded.
    public func loadVideo(from url: URL) async throws -> VideoMetadata {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VideoLoadError.fileNotFound
        }

        let asset = AVURLAsset(url: url)

        // Load required properties asynchronously
        let isPlayable: Bool
        let duration: CMTime
        let tracks: [AVAssetTrack]

        do {
            isPlayable = try await asset.load(.isPlayable)
            duration = try await asset.load(.duration)
            tracks = try await asset.load(.tracks)
        } catch {
            throw VideoLoadError.loadingFailed(error)
        }

        guard isPlayable else {
            throw VideoLoadError.invalidVideoFile
        }

        // Find video track
        guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
            throw VideoLoadError.noVideoTrack
        }

        // Load video track properties
        let naturalSize: CGSize
        let nominalFrameRate: Float
        let formatDescriptions: [CMFormatDescription]
        let estimatedDataRate: Float

        do {
            naturalSize = try await videoTrack.load(.naturalSize)
            nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
            formatDescriptions = try await videoTrack.load(.formatDescriptions)
            estimatedDataRate = try await videoTrack.load(.estimatedDataRate)
        } catch {
            throw VideoLoadError.loadingFailed(error)
        }

        // Extract codec name from format description
        let codec = extractCodecName(from: formatDescriptions)

        // Extract color space
        let colorSpace = extractColorSpace(from: formatDescriptions)

        // Get audio channel count
        let audioChannels = await extractAudioChannels(from: tracks)

        // Get file size
        let fileSize = getFileSize(for: url)

        // Check for embedded timecode
        let (hasTimecode, startTimecode) = await extractTimecodeInfo(from: asset, tracks: tracks)

        return VideoMetadata(
            url: url,
            duration: CMTimeGetSeconds(duration),
            codec: codec,
            bitrate: estimatedDataRate > 0 ? Int(estimatedDataRate) : nil,
            resolution: naturalSize,
            detectedFrameRate: Double(nominalFrameRate),
            colorSpace: colorSpace,
            audioChannels: audioChannels,
            fileSize: fileSize,
            hasEmbeddedTimecode: hasTimecode,
            startTimecodeFrames: startTimecode
        )
    }

    /// Creates an AVPlayer for the given URL.
    /// - Parameter url: The URL of the video file.
    /// - Returns: An AVPlayer instance.
    public func createPlayer(for url: URL) -> AVPlayer {
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        return AVPlayer(playerItem: playerItem)
    }

    // MARK: - Private Helpers

    private func extractCodecName(from formatDescriptions: [CMFormatDescription]) -> String {
        guard let formatDescription = formatDescriptions.first else {
            return "Unknown"
        }

        let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
        return codecNameFromFourCC(codecType)
    }

    private func codecNameFromFourCC(_ fourCC: FourCharCode) -> String {
        // Common video codec four character codes
        switch fourCC {
        // H.264/AVC
        case kCMVideoCodecType_H264:
            return "H.264"

        // HEVC/H.265
        case kCMVideoCodecType_HEVC:
            return "HEVC"

        // ProRes variants
        case kCMVideoCodecType_AppleProRes4444XQ:
            return "ProRes 4444 XQ"
        case kCMVideoCodecType_AppleProRes4444:
            return "ProRes 4444"
        case kCMVideoCodecType_AppleProRes422HQ:
            return "ProRes 422 HQ"
        case kCMVideoCodecType_AppleProRes422:
            return "ProRes 422"
        case kCMVideoCodecType_AppleProRes422LT:
            return "ProRes 422 LT"
        case kCMVideoCodecType_AppleProRes422Proxy:
            return "ProRes 422 Proxy"
        case kCMVideoCodecType_AppleProResRAW:
            return "ProRes RAW"
        case kCMVideoCodecType_AppleProResRAWHQ:
            return "ProRes RAW HQ"

        // JPEG/Motion JPEG
        case kCMVideoCodecType_JPEG:
            return "JPEG"
        case kCMVideoCodecType_JPEG_OpenDML:
            return "Motion JPEG"

        // DV
        case kCMVideoCodecType_DVCNTSC:
            return "DV NTSC"
        case kCMVideoCodecType_DVCPAL:
            return "DV PAL"
        case kCMVideoCodecType_DVCProPAL:
            return "DVCPro PAL"
        case kCMVideoCodecType_DVCPro50NTSC:
            return "DVCPro50 NTSC"
        case kCMVideoCodecType_DVCPro50PAL:
            return "DVCPro50 PAL"
        case kCMVideoCodecType_DVCPROHD720p60:
            return "DVCProHD 720p60"
        case kCMVideoCodecType_DVCPROHD720p50:
            return "DVCProHD 720p50"
        case kCMVideoCodecType_DVCPROHD1080i60:
            return "DVCProHD 1080i60"
        case kCMVideoCodecType_DVCPROHD1080i50:
            return "DVCProHD 1080i50"
        case kCMVideoCodecType_DVCPROHD1080p30:
            return "DVCProHD 1080p30"
        case kCMVideoCodecType_DVCPROHD1080p25:
            return "DVCProHD 1080p25"

        // Animation
        case kCMVideoCodecType_Animation:
            return "Animation"

        default:
            // Convert FourCC to string for unknown codecs
            var chars: [Character] = []
            for shift in [24, 16, 8, 0] {
                let byte = (fourCC >> shift) & 0xFF
                if let scalar = UnicodeScalar(byte) {
                    chars.append(Character(scalar))
                }
            }
            let result = String(chars).trimmingCharacters(in: .whitespaces)
            return result.isEmpty ? "Unknown" : result
        }
    }

    private func extractColorSpace(from formatDescriptions: [CMFormatDescription]) -> String? {
        guard let formatDescription = formatDescriptions.first else {
            return nil
        }

        // Try to get color primaries
        if let colorPrimaries = CMFormatDescriptionGetExtension(
            formatDescription,
            extensionKey: kCMFormatDescriptionExtension_ColorPrimaries
        ) as? String {
            switch colorPrimaries {
            case String(kCMFormatDescriptionColorPrimaries_ITU_R_709_2):
                return "Rec. 709"
            case String(kCMFormatDescriptionColorPrimaries_ITU_R_2020):
                return "Rec. 2020"
            case String(kCMFormatDescriptionColorPrimaries_DCI_P3):
                return "DCI-P3"
            case String(kCMFormatDescriptionColorPrimaries_P3_D65):
                return "Display P3"
            case String(kCMFormatDescriptionColorPrimaries_SMPTE_C):
                return "SMPTE-C"
            default:
                return colorPrimaries
            }
        }

        return nil
    }

    private func extractAudioChannels(from tracks: [AVAssetTrack]) async -> Int {
        let audioTracks = tracks.filter { $0.mediaType == .audio }

        var totalChannels = 0
        for track in audioTracks {
            if let formatDescriptions = try? await track.load(.formatDescriptions),
               let formatDescription = formatDescriptions.first {
                if let streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
                    totalChannels += Int(streamBasicDescription.pointee.mChannelsPerFrame)
                }
            }
        }

        return totalChannels
    }

    private func getFileSize(for url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }

    private func extractTimecodeInfo(from asset: AVURLAsset, tracks: [AVAssetTrack]) async -> (hasTimecode: Bool, startFrames: Int?) {
        // Look for timecode track
        let timecodeTracks = tracks.filter { $0.mediaType == .timecode }

        guard let timecodeTrack = timecodeTracks.first else {
            return (false, nil)
        }

        // Try to read the first timecode sample
        do {
            let formatDescriptions = try await timecodeTrack.load(.formatDescriptions)
            guard let formatDescription = formatDescriptions.first else {
                return (false, nil)
            }

            // Get timecode format type
            let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)

            // Check if it's a valid timecode format
            let validTimecodeTypes: [FourCharCode] = [
                kCMTimeCodeFormatType_TimeCode32,
                kCMTimeCodeFormatType_TimeCode64,
                kCMTimeCodeFormatType_Counter32,
                kCMTimeCodeFormatType_Counter64
            ]

            if validTimecodeTypes.contains(mediaSubType) {
                // For now, we just detect presence of timecode
                // Reading actual start timecode requires more complex sample reading
                // which we'll implement in Sprint 4 when we have the video player
                return (true, nil)
            }
        } catch {
            // Failed to load timecode track info
        }

        return (false, nil)
    }
}
