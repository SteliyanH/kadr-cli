import Foundation

/// What `kadr inspect` reports about a file: the facts that decide how it looks
/// once it is edited, which a player hides.
///
/// A player shows a portrait clip upright, plays a variable frame rate smoothly
/// and tone-maps HDR, so none of that is visible by watching. All of it changes
/// what an export produces. This is the `--json` output, so field names are
/// part of the tool's interface: they are added to, not renamed.
public struct MediaReport: Codable, Sendable, Equatable {
    /// The path as given on the command line.
    public var file: String
    /// Size on disk, in bytes.
    public var bytes: Int64
    /// Duration of the file, in seconds.
    public var duration: Double
    public var video: [VideoTrack]
    public var audio: [AudioTrack]

    public init(file: String, bytes: Int64, duration: Double, video: [VideoTrack], audio: [AudioTrack]) {
        self.file = file
        self.bytes = bytes
        self.duration = duration
        self.video = video
        self.audio = audio
    }

    public struct Size: Codable, Sendable, Equatable, CustomStringConvertible {
        public var width: Int
        public var height: Int

        public init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }

        public var description: String { "\(width)×\(height)" }
    }

    public struct VideoTrack: Codable, Sendable, Equatable {
        /// The four-character code, such as `avc1`, `hvc1` or `apcn`.
        public var codec: String
        /// `H.264`, `HEVC`, `ProRes 422` and so on, or the code when it is not one kadr names.
        public var codecName: String
        /// Pixels as stored. A portrait iPhone recording is stored landscape.
        public var storedSize: Size
        /// Pixels as shown, with the rotation applied: the size kadr fits into the frame.
        public var displaySize: Size
        /// The clockwise rotation a player applies, in degrees: 0, 90, 180 or 270.
        /// When ``mirrored``, the rotation after the left-right flip.
        public var rotation: Int
        /// Whether the track's transform flips the picture left to right, as a
        /// front camera can.
        public var mirrored: Bool
        /// The frame rate the file declares.
        public var nominalFrameRate: Double
        /// The frame rate measured from every frame's timestamp, or `nil` when the
        /// file's samples can't be read without decoding.
        public var frameTiming: FrameTiming?
        public var color: Color
        /// Estimated, in bits per second.
        public var bitRate: Double

        public init(
            codec: String, codecName: String, storedSize: Size, displaySize: Size, rotation: Int,
            mirrored: Bool, nominalFrameRate: Double, frameTiming: FrameTiming?, color: Color, bitRate: Double
        ) {
            self.codec = codec
            self.codecName = codecName
            self.storedSize = storedSize
            self.displaySize = displaySize
            self.rotation = rotation
            self.mirrored = mirrored
            self.nominalFrameRate = nominalFrameRate
            self.frameTiming = frameTiming
            self.color = color
            self.bitRate = bitRate
        }
    }

    /// Frame timing measured from the timestamps, not the declared rate.
    ///
    /// Phones record a variable frame rate: in low light an iPhone drops from 30
    /// to 24 fps or lower while still declaring 30. Editing at the declared rate
    /// either duplicates or drops frames, which shows as judder.
    public struct FrameTiming: Codable, Sendable, Equatable {
        public var frames: Int
        /// Frames over the span from the first timestamp to the last.
        public var averageFrameRate: Double
        /// The rate of the longest frames, at the 95th percentile, so one dropped
        /// frame doesn't count.
        public var slowestFrameRate: Double
        /// The rate of the shortest frames, at the 5th percentile.
        public var fastestFrameRate: Double
        /// Whether the fastest rate is more than 10% above the slowest. Rounding
        /// a 29.97 fps file to its timescale varies by less than that.
        public var isVariable: Bool

        public init(frames: Int, averageFrameRate: Double, slowestFrameRate: Double, fastestFrameRate: Double, isVariable: Bool) {
            self.frames = frames
            self.averageFrameRate = averageFrameRate
            self.slowestFrameRate = slowestFrameRate
            self.fastestFrameRate = fastestFrameRate
            self.isVariable = isVariable
        }
    }

    /// The colour tags on the track. Each is `nil` when the file doesn't say, and
    /// an untagged file is shown as BT.709 by most players.
    public struct Color: Codable, Sendable, Equatable {
        /// `BT.709`, `BT.2020`, `Display P3`, or the tag as written.
        public var primaries: String?
        /// `BT.709`, `HLG`, `PQ`, `sRGB`, or the tag as written.
        public var transferFunction: String?
        /// `BT.709`, `BT.601`, `BT.2020`, or the tag as written.
        public var matrix: String?
        /// Bits per colour component, when the file records it.
        public var bitsPerComponent: Int?
        /// `HLG` or `PQ` for HDR video, `HDR` when the file is marked HDR some
        /// other way (Dolby Vision without a transfer tag), and `nil` for SDR.
        public var hdr: String?

        public init(primaries: String? = nil, transferFunction: String? = nil, matrix: String? = nil, bitsPerComponent: Int? = nil, hdr: String? = nil) {
            self.primaries = primaries
            self.transferFunction = transferFunction
            self.matrix = matrix
            self.bitsPerComponent = bitsPerComponent
            self.hdr = hdr
        }
    }

    public struct AudioTrack: Codable, Sendable, Equatable {
        /// The four-character code, such as `aac ` or `lpcm`.
        public var codec: String
        /// `AAC`, `PCM`, `Apple Lossless` and so on, or the code.
        public var codecName: String
        public var sampleRate: Double
        public var channels: Int
        /// Estimated, in bits per second.
        public var bitRate: Double

        public init(codec: String, codecName: String, sampleRate: Double, channels: Int, bitRate: Double) {
            self.codec = codec
            self.codecName = codecName
            self.sampleRate = sampleRate
            self.channels = channels
            self.bitRate = bitRate
        }
    }
}

extension MediaReport {
    /// The report as JSON: sorted keys, so the same file always prints the same text.
    public func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
}
