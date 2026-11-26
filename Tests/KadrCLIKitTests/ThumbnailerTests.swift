import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import KadrCLIKit

struct ThumbnailerTests {

    private func output(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("kadr-cli-thumb-\(UUID().uuidString).\(ext)")
    }

    private func read(_ url: URL) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    /// The left edge of the white bar in the middle row.
    private func barX(in image: CGImage) throws -> Int {
        let context = try #require(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let row = image.height / 2 * image.width * 4
        return try #require((0..<image.width).first { pixels[row + $0 * 4] > 128 })
    }

    /// The exact frame, not the nearest keyframe: H.264 from AVAssetWriter puts
    /// a keyframe only every second or so.
    @Test(arguments: [0.0, 0.5, 1.2, 1.9])
    func frameAtTime(_ seconds: Double) async throws {
        let url = try await Fixtures.movie(times: Fixtures.times(fps: 10, to: 2), duration: 2)
        let out = output("png")
        let size = try await Thumbnailer.writeFrame(of: url, at: seconds, to: out)
        let image = try read(out)

        #expect(size == .init(width: 320, height: 96))
        #expect(image.width == 320 && image.height == 96)
        #expect(abs(try barX(in: image) - Fixtures.barX(at: seconds, duration: 2)) <= 1)
    }

    @Test func rotatedClipGivesUprightFrame() async throws {
        let url = try await Fixtures.movie(times: Fixtures.times(fps: 10, to: 1), duration: 1, transform: Fixtures.rotation(90))
        let out = output("jpg")
        let size = try await Thumbnailer.writeFrame(of: url, at: 0.5, to: out)
        #expect(size == .init(width: 96, height: 320))
        let image = try read(out)
        #expect(image.width == 96 && image.height == 320)
    }

    @Test func scaledToWidth() async throws {
        let url = try await Fixtures.movie(times: Fixtures.times(fps: 10, to: 1), duration: 1)
        let out = output("heic")
        let size = try await Thumbnailer.writeFrame(of: url, at: 0, width: 160, to: out)
        #expect(size == .init(width: 160, height: 48))
        #expect(try read(out).width == 160)
    }

    @Test func timePastTheEnd() async throws {
        let url = try await Fixtures.movie(times: Fixtures.times(fps: 10, to: 1), duration: 1)
        await #expect(throws: CLIError.timeOutOfRange(5, duration: 1)) {
            try await Thumbnailer.writeFrame(of: url, at: 5, to: output("png"))
        }
    }

    @Test func unsupportedFormat() async throws {
        let url = try await Fixtures.movie(times: Fixtures.times(fps: 10, to: 1), duration: 1)
        await #expect(throws: CLIError.unsupportedImageFormat("gif")) {
            try await Thumbnailer.writeFrame(of: url, at: 0, to: output("gif"))
        }
    }

    @Test func zeroWidth() async throws {
        let url = try await Fixtures.movie(times: Fixtures.times(fps: 10, to: 1), duration: 1)
        await #expect(throws: CLIError.invalidWidth(0)) {
            try await Thumbnailer.writeFrame(of: url, at: 0, width: 0, to: output("png"))
        }
    }
}
