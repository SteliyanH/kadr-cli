import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

/// Movies written for the tests, so each one is exactly the case it tests: a
/// rotation, a variable frame rate, an audio format, HDR tags.
///
/// Every frame is black with a white bar whose left edge sits at `time / duration`
/// of the way across, so a frame read back says which time it came from.
enum Fixtures {

    static let width = 320, height = 96
    static let barWidth = 8
    static let sampleRate = 44_100.0

    struct Failure: Error, CustomStringConvertible {
        var description: String
    }

    /// The clockwise rotations a camera records, as the transform it stores.
    static func rotation(_ degrees: Int) -> CGAffineTransform {
        let (w, h) = (CGFloat(width), CGFloat(height))
        switch degrees {
        case 90: return CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: h, ty: 0)
        case 180: return CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: w, ty: h)
        case 270: return CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: w)
        default: return .identity
        }
    }

    /// Mirrored left to right, as a front camera can store it.
    static let mirror = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: CGFloat(width), ty: 0)

    static func times(fps: Double, from start: Double = 0, to end: Double) -> [Double] {
        stride(from: start, to: end - 1e-9, by: 1 / fps).map { $0 }
    }

    /// H.264 frames at `times`, the last lasting until `duration`. With
    /// `audioChannels`, a silent 16-bit PCM track as well.
    static func movie(
        times: [Double], duration: Double, transform: CGAffineTransform = .identity, audioChannels: Int? = nil
    ) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kadr-cli-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = false
        input.transform = transform
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)

        var audio: (input: AVAssetWriterInput, chunks: [CMSampleBuffer])?
        if let audioChannels {
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: audioChannels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ])
            audioInput.expectsMediaDataInRealTime = false
            writer.add(audioInput)
            audio = (audioInput, try silence(seconds: duration, channels: audioChannels))
        }

        guard writer.startWriting() else { throw writer.error ?? Failure(description: "could not start writing") }
        writer.startSession(atSourceTime: .zero)

        // Feed both inputs as each becomes ready: the writer interleaves, and
        // writing one to the end first can stall waiting for the other.
        var nextFrame = 0, nextChunk = 0
        while nextFrame < times.count || nextChunk < (audio?.chunks.count ?? 0) {
            var progressed = false
            if nextFrame < times.count, input.isReadyForMoreMediaData {
                let time = times[nextFrame]
                let buffer = try frame(showing: time, duration: duration, pool: adaptor.pixelBufferPool)
                guard adaptor.append(buffer, withPresentationTime: CMTime(seconds: time, preferredTimescale: 6000)) else {
                    throw writer.error ?? Failure(description: "could not append a frame")
                }
                nextFrame += 1
                if nextFrame == times.count { input.markAsFinished() }
                progressed = true
            }
            if let audio, nextChunk < audio.chunks.count, audio.input.isReadyForMoreMediaData {
                guard audio.input.append(audio.chunks[nextChunk]) else {
                    throw writer.error ?? Failure(description: "could not append audio")
                }
                nextChunk += 1
                if nextChunk == audio.chunks.count { audio.input.markAsFinished() }
                progressed = true
            }
            if !progressed { try await Task.sleep(nanoseconds: 1_000_000) }
        }
        writer.endSession(atSourceTime: CMTime(seconds: duration, preferredTimescale: 6000))
        await writer.finishWriting()
        if let error = writer.error { throw error }
        return url
    }

    /// One second of 10-bit HEVC tagged BT.2020 and HLG, as an iPhone records HDR.
    static func hlgMovie() async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kadr-cli-hlg-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                kVTCompressionPropertyKey_ProfileLevel as String: kVTProfileLevel_HEVC_Main10_AutoLevel as String,
            ],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
            ],
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? Failure(description: "could not start writing") }
        writer.startSession(atSourceTime: .zero)

        for index in 0..<30 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
            var made: CVPixelBuffer?
            if let pool = adaptor.pixelBufferPool { CVPixelBufferPoolCreatePixelBuffer(nil, pool, &made) }
            guard let buffer = made else { throw Failure(description: "no pixel buffer") }
            CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_2020, .shouldPropagate)
            CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_2100_HLG, .shouldPropagate)
            CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_2020, .shouldPropagate)
            // Mid grey: 10-bit video-range luma, neutral chroma, in the top bits of 16.
            CVPixelBufferLockBaseAddress(buffer, [])
            for plane in 0..<2 {
                let base = CVPixelBufferGetBaseAddressOfPlane(buffer, plane)!.assumingMemoryBound(to: UInt16.self)
                let stride = CVPixelBufferGetBytesPerRowOfPlane(buffer, plane) / 2
                let rows = plane == 0 ? height : height / 2
                for i in 0..<(rows * stride) { base[i] = UInt16(plane == 0 ? 502 : 512) << 6 }
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: 30)) else {
                throw writer.error ?? Failure(description: "could not append a frame")
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        if let error = writer.error { throw error }
        return url
    }

    /// A file AVFoundation can open but that holds no tracks it would call media.
    static func textFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kadr-cli-\(UUID().uuidString).txt")
        try Data("not a movie".utf8).write(to: url)
        return url
    }

    /// The bar's left edge in a frame showing `time`, in pixels.
    static func barX(at time: Double, duration: Double) -> Int {
        Int((time / duration * Double(width - barWidth)).rounded())
    }

    private static func frame(showing time: Double, duration: Double, pool: CVPixelBufferPool?) throws -> CVPixelBuffer {
        var made: CVPixelBuffer?
        if let pool { CVPixelBufferPoolCreatePixelBuffer(nil, pool, &made) }
        if made == nil { CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &made) }
        guard let buffer = made else { throw Failure(description: "no pixel buffer") }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        let pixels = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
        let bar = barX(at: time, duration: duration)..<(barX(at: time, duration: duration) + barWidth)
        for y in 0..<height {
            let row = pixels + y * rowBytes
            for x in 0..<width {
                let value: UInt8 = bar.contains(x) ? 255 : 0
                row[x * 4] = value; row[x * 4 + 1] = value; row[x * 4 + 2] = value; row[x * 4 + 3] = 255
            }
        }
        return buffer
    }

    private static func silence(seconds: Double, channels: Int) throws -> [CMSampleBuffer] {
        var description = AudioStreamBasicDescription(
            mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: UInt32(2 * channels), mFramesPerPacket: 1, mBytesPerFrame: UInt32(2 * channels),
            mChannelsPerFrame: UInt32(channels), mBitsPerChannel: 16, mReserved: 0
        )
        var format: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(
            allocator: nil, asbd: &description, layoutSize: 0, layout: nil,
            magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format
        )
        guard let format else { throw Failure(description: "no audio format") }

        let total = Int(seconds * sampleRate), chunk = Int(sampleRate / 10)
        return try stride(from: 0, to: total, by: chunk).map { start in
            let count = min(chunk, total - start), bytes = count * 2 * channels
            var block: CMBlockBuffer?
            CMBlockBufferCreateWithMemoryBlock(
                allocator: nil, memoryBlock: nil, blockLength: bytes, blockAllocator: nil,
                customBlockSource: nil, offsetToData: 0, dataLength: bytes,
                flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block
            )
            guard let block else { throw Failure(description: "no audio block") }
            CMBlockBufferFillDataBytes(with: 0, blockBuffer: block, offsetIntoDestination: 0, dataLength: bytes)
            var buffer: CMSampleBuffer?
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                allocator: nil, dataBuffer: block, formatDescription: format, sampleCount: count,
                presentationTimeStamp: CMTime(value: CMTimeValue(start), timescale: CMTimeScale(sampleRate)),
                packetDescriptions: nil, sampleBufferOut: &buffer
            )
            guard let buffer else { throw Failure(description: "no audio buffer") }
            return buffer
        }
    }
}
