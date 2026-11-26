import AVFoundation
import CoreMedia
import Foundation

/// Reads a ``MediaReport`` from a file. Nothing is decoded: sizes, tags and
/// timestamps all come from the container.
public enum Inspector {

    public static func inspect(_ url: URL, as path: String? = nil) async throws -> MediaReport {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CLIError.fileNotFound(path ?? url.path)
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0

        let asset = AVURLAsset(url: url)
        let videoTracks: [AVAssetTrack]
        let audioTracks: [AVAssetTrack]
        do {
            videoTracks = try await asset.loadTracks(withMediaType: .video)
            audioTracks = try await asset.loadTracks(withMediaType: .audio)
        } catch {
            throw CLIError.unreadable(path ?? url.path, reason: error.localizedDescription)
        }
        guard !videoTracks.isEmpty || !audioTracks.isEmpty else {
            throw CLIError.noMedia(path ?? url.path)
        }

        var video: [MediaReport.VideoTrack] = []
        for track in videoTracks { video.append(try await videoReport(track)) }
        var audio: [MediaReport.AudioTrack] = []
        for track in audioTracks { audio.append(try await audioReport(track)) }

        // An indefinite duration is NaN, which JSON can't hold.
        let duration = try await asset.load(.duration).seconds
        return MediaReport(
            file: path ?? url.path,
            bytes: bytes,
            duration: duration.isFinite ? duration : 0,
            video: video,
            audio: audio
        )
    }

    // MARK: - Video

    static func videoReport(_ track: AVAssetTrack) async throws -> MediaReport.VideoTrack {
        let (size, transform, nominal, rate, descriptions, characteristics) = try await track.load(
            .naturalSize, .preferredTransform, .nominalFrameRate, .estimatedDataRate,
            .formatDescriptions, .mediaCharacteristics
        )
        let shown = CGRect(origin: .zero, size: size).applying(transform).size
        // A mirrored transform is read as a left-right flip followed by a rotation,
        // so a plain mirror is "mirrored", not "rotated 180°" (which a flip of both
        // axes would also be).
        let mirrored = transform.a * transform.d - transform.b * transform.c < 0
        let (cos, sin) = mirrored ? (-transform.a, -transform.b) : (transform.a, transform.b)
        let degrees = atan2(sin, cos) * 180 / .pi
        let rotation = (Int((degrees / 90).rounded()) * 90 % 360 + 360) % 360

        let description = descriptions.first
        let code = description.map { fourCC(CMFormatDescriptionGetMediaSubType($0)) } ?? "????"
        return MediaReport.VideoTrack(
            codec: code,
            codecName: Names.videoCodec[code] ?? code,
            storedSize: .init(width: Int(size.width.rounded()), height: Int(size.height.rounded())),
            displaySize: .init(width: Int(abs(shown.width).rounded()), height: Int(abs(shown.height).rounded())),
            rotation: rotation,
            mirrored: mirrored,
            nominalFrameRate: Double(nominal),
            frameTiming: try await frameTiming(of: track),
            color: color(of: description, characteristics: characteristics),
            bitRate: Double(rate)
        )
    }

    /// Every frame's presentation time, read with a sample cursor, which walks the
    /// container's sample table without loading any frame data.
    static func frameTiming(of track: AVAssetTrack) async throws -> MediaReport.FrameTiming? {
        guard try await track.load(.canProvideSampleCursors),
              let cursor = track.makeSampleCursorAtFirstSampleInDecodeOrder() else { return nil }
        var times: [Double] = []
        repeat {
            let time = cursor.presentationTimeStamp
            if time.isNumeric { times.append(time.seconds) }
        } while cursor.stepInDecodeOrder(byCount: 1) == 1
        return frameTiming(presentationTimes: times)
    }

    /// Timing from presentation timestamps in any order. Needs at least three
    /// frames, so there are two intervals to compare.
    public static func frameTiming(presentationTimes: [Double]) -> MediaReport.FrameTiming? {
        let times = presentationTimes.sorted()
        guard times.count >= 3, let first = times.first, let last = times.last, last > first else { return nil }
        let intervals = zip(times.dropFirst(), times).map { $0 - $1 }.filter { $0 > 0 }.sorted()
        guard !intervals.isEmpty else { return nil }
        let shortest = intervals[Int(Double(intervals.count - 1) * 0.05)]
        let longest = intervals[Int(Double(intervals.count - 1) * 0.95)]
        return MediaReport.FrameTiming(
            frames: times.count,
            averageFrameRate: Double(times.count - 1) / (last - first),
            slowestFrameRate: 1 / longest,
            fastestFrameRate: 1 / shortest,
            isVariable: longest / shortest > 1.1
        )
    }

    static func color(of description: CMFormatDescription?, characteristics: [AVMediaCharacteristic]) -> MediaReport.Color {
        func tag(_ key: CFString) -> String? {
            guard let description else { return nil }
            return CMFormatDescriptionGetExtension(description, extensionKey: key) as? String
        }
        let transfer = tag(kCMFormatDescriptionExtension_TransferFunction)
        let bits = description.flatMap {
            CMFormatDescriptionGetExtension($0, extensionKey: kCMFormatDescriptionExtension_BitsPerComponent) as? NSNumber
        }
        let hdr: String? = switch transfer {
        case let t? where t == kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG as String: "HLG"
        case let t? where t == kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ as String: "PQ"
        default: characteristics.contains(.containsHDRVideo) ? "HDR" : nil
        }
        return MediaReport.Color(
            primaries: tag(kCMFormatDescriptionExtension_ColorPrimaries).map { Names.primaries[$0] ?? $0 },
            transferFunction: transfer.map { Names.transferFunction[$0] ?? $0 },
            matrix: tag(kCMFormatDescriptionExtension_YCbCrMatrix).map { Names.matrix[$0] ?? $0 },
            bitsPerComponent: bits?.intValue,
            hdr: hdr
        )
    }

    // MARK: - Audio

    static func audioReport(_ track: AVAssetTrack) async throws -> MediaReport.AudioTrack {
        let (descriptions, rate) = try await track.load(.formatDescriptions, .estimatedDataRate)
        let stream = descriptions.first.flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee }
        let code = stream.map { fourCC($0.mFormatID) } ?? "????"
        return MediaReport.AudioTrack(
            codec: code,
            codecName: Names.audioCodec[code] ?? code,
            sampleRate: stream?.mSampleRate ?? 0,
            channels: Int(stream?.mChannelsPerFrame ?? 0),
            bitRate: Double(rate)
        )
    }

    /// `avc1` from 0x61766331. Unprintable bytes become `?`.
    static func fourCC(_ code: FourCharCode) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((code >> $0) & 0xFF) }
        return String(bytes.map { (0x20...0x7E).contains($0) ? Character(UnicodeScalar($0)) : "?" })
    }
}
