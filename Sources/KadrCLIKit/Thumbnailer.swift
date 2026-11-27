import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import Kadr
import UniformTypeIdentifiers

/// Writes one frame of a video to an image file.
public enum Thumbnailer {

    /// The image formats `kadr thumb` writes, chosen by the output's extension.
    public static let formats: [String: UTType] = [
        "png": .png, "jpg": .jpeg, "jpeg": .jpeg, "heic": .heic, "tif": .tiff, "tiff": .tiff,
    ]

    /// Writes the frame shown at `seconds` to `output`, upright, at the size it
    /// appears on screen, or scaled to `width` pixels wide. Returns the size written.
    ///
    /// The frame is exact: kadr asks for zero tolerance, where AVFoundation's default
    /// returns the nearest keyframe, which can be seconds away.
    @discardableResult
    public static func writeFrame(
        of input: URL, at seconds: Double, width: Int? = nil, to output: URL
    ) async throws -> MediaReport.Size {
        guard FileManager.default.fileExists(atPath: input.path) else {
            throw CLIError.fileNotFound(input.path)
        }
        let ext = output.pathExtension.lowercased()
        guard let type = formats[ext] else {
            throw CLIError.unsupportedImageFormat(ext)
        }
        let duration = try await AVURLAsset(url: input).load(.duration).seconds
        guard seconds >= 0, seconds < duration else {
            throw CLIError.timeOutOfRange(seconds, duration: duration)
        }

        let image = try await VideoClip(url: input).thumbnail(at: seconds)
        guard var frame = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw CLIError.unreadable(input.path, reason: "no frame at \(Format.duration(seconds))")
        }
        if let width, width != frame.width {
            frame = try scaled(frame, toWidth: width)
        }

        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, type.identifier as CFString, 1, nil) else {
            throw CLIError.cannotWrite(output.path)
        }
        CGImageDestinationAddImage(destination, frame, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CLIError.cannotWrite(output.path)
        }
        return MediaReport.Size(width: frame.width, height: frame.height)
    }

    static func scaled(_ image: CGImage, toWidth width: Int) throws -> CGImage {
        guard width > 0 else { throw CLIError.invalidWidth(width) }
        let height = max(1, Int((Double(width) * Double(image.height) / Double(image.width)).rounded()))
        let space = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw CLIError.invalidWidth(width) }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let result = context.makeImage() else { throw CLIError.invalidWidth(width) }
        return result
    }
}
