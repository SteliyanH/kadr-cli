import Foundation
import Kadr
import Testing
@testable import KadrCLIKit

struct InspectorTests {

    @Test func constantFrameRateClip() async throws {
        let url = try await Fixtures.movie(times: Fixtures.times(fps: 30, to: 1), duration: 1)
        let report = try await Inspector.inspect(url)
        let video = try #require(report.video.first)

        #expect(report.video.count == 1)
        #expect(report.audio.isEmpty)
        #expect(abs(report.duration - 1) < 0.01)
        #expect(report.bytes > 0)
        #expect(video.codec == "avc1")
        #expect(video.codecName == "H.264")
        #expect(video.storedSize == .init(width: 320, height: 96))
        #expect(video.displaySize == .init(width: 320, height: 96))
        #expect(video.rotation == 0)
        #expect(!video.mirrored)
        #expect(abs(video.nominalFrameRate - 30) < 0.1)
        let timing = try #require(video.frameTiming)
        #expect(timing.frames == 30)
        #expect(!timing.isVariable)
        #expect(abs(timing.averageFrameRate - 30) < 0.01)
        #expect(video.color.hdr == nil)
    }

    /// The sizes a camera's rotations produce, and the same on-screen size kadr
    /// itself reports, since that is the size it fits into the frame.
    @Test(arguments: [0, 90, 180, 270])
    func rotation(_ degrees: Int) async throws {
        let url = try await Fixtures.movie(
            times: Fixtures.times(fps: 10, to: 0.5), duration: 0.5, transform: Fixtures.rotation(degrees)
        )
        let video = try #require(try await Inspector.inspect(url).video.first)
        let upright = degrees % 180 == 0

        #expect(video.rotation == degrees)
        #expect(!video.mirrored)
        #expect(video.storedSize == .init(width: 320, height: 96))
        #expect(video.displaySize == (upright ? .init(width: 320, height: 96) : .init(width: 96, height: 320)))

        let kadr = try await VideoClip(url: url).metadata.displaySize
        #expect(video.displaySize == .init(width: Int(kadr.width), height: Int(kadr.height)))
    }

    /// A flip, alone and then rotated as a front camera held upright stores it.
    @Test(arguments: [0, 90])
    func mirroredClip(rotatedBy degrees: Int) async throws {
        let transform = Fixtures.mirror.concatenating(Fixtures.rotation(degrees))
        let url = try await Fixtures.movie(times: Fixtures.times(fps: 10, to: 0.5), duration: 0.5, transform: transform)
        let video = try #require(try await Inspector.inspect(url).video.first)
        #expect(video.mirrored)
        #expect(video.rotation == degrees)
        #expect(video.lines[0].contains("mirrored"))
    }

    /// A phone in low light: 30 fps for a second, then 20.
    @Test func variableFrameRateClip() async throws {
        let times = Fixtures.times(fps: 30, to: 1) + Fixtures.times(fps: 20, from: 1, to: 2)
        let url = try await Fixtures.movie(times: times, duration: 2)
        let video = try #require(try await Inspector.inspect(url).video.first)
        let timing = try #require(video.frameTiming)

        #expect(timing.frames == 50)
        #expect(timing.isVariable)
        #expect(abs(timing.slowestFrameRate - 20) < 0.1)
        #expect(abs(timing.fastestFrameRate - 30) < 0.1)
        #expect(video.lines[1].contains("20–30 fps measured: variable"))
    }

    @Test(arguments: [1, 2])
    func audioTrack(channels: Int) async throws {
        let url = try await Fixtures.movie(times: Fixtures.times(fps: 10, to: 1), duration: 1, audioChannels: channels)
        let audio = try #require(try await Inspector.inspect(url).audio.first)
        #expect(audio.codec == "lpcm")
        #expect(audio.codecName == "PCM")
        #expect(audio.sampleRate == Fixtures.sampleRate)
        #expect(audio.channels == channels)
    }

    @Test func hlgClip() async throws {
        let url = try await Fixtures.hlgMovie()
        let video = try #require(try await Inspector.inspect(url).video.first)
        #expect(video.codecName == "HEVC")
        #expect(video.color.hdr == "HLG")
        #expect(video.color.transferFunction == "HLG")
        #expect(video.color.primaries == "BT.2020")
        #expect(video.color.matrix == "BT.2020")
        #expect(video.color.line.hasPrefix("HDR (HLG), BT.2020 primaries"))
    }

    @Test func sdrClipIsTaggedAsSuch() async throws {
        let url = try await Fixtures.movie(times: Fixtures.times(fps: 10, to: 0.5), duration: 0.5)
        let color = try #require(try await Inspector.inspect(url).video.first).color
        #expect(color.hdr == nil)
        #expect(color.line.hasPrefix("SDR"))
    }

    @Test func missingFile() async throws {
        await #expect(throws: CLIError.fileNotFound("nope.mov")) {
            try await Inspector.inspect(URL(fileURLWithPath: "/nonexistent/nope.mov"), as: "nope.mov")
        }
    }

    @Test func fileThatIsNotMedia() async throws {
        let url = try Fixtures.textFile()
        do {
            _ = try await Inspector.inspect(url, as: "notes.txt")
            Issue.record("a text file was read as media")
        } catch let error as CLIError {
            #expect(error.description.contains("notes.txt"))
        }
    }

    @Test func jsonRoundTrips() async throws {
        let url = try await Fixtures.movie(
            times: Fixtures.times(fps: 10, to: 1), duration: 1, transform: Fixtures.rotation(90), audioChannels: 2
        )
        let report = try await Inspector.inspect(url, as: "clip.mov")
        let json = try report.json()

        #expect(try JSONDecoder().decode(MediaReport.self, from: Data(json.utf8)) == report)
        #expect(json.contains(#""file" : "clip.mov""#))
        #expect(json.contains(#""displaySize""#))
        #expect(json.contains(#""rotation" : 90"#))
    }

    @Test func textReport() async throws {
        let url = try await Fixtures.movie(
            times: Fixtures.times(fps: 10, to: 1), duration: 1, transform: Fixtures.rotation(90), audioChannels: 2
        )
        let text = try await Inspector.inspect(url, as: "clip.mov").text
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines[0].hasPrefix("clip.mov  "))
        #expect(lines[0].hasSuffix("  0:01.00"))
        #expect(lines[2] == "Video     H.264, 96×320 on screen, stored 320×96 and rotated 90°")
        #expect(lines[3] == "          10 fps declared, constant (10 frames)")
        #expect(lines.contains { $0.hasPrefix("Audio     PCM, 44.1 kHz, stereo, ") })
    }
}

struct FrameTimingTests {

    /// 29.97 fps in a 600 timescale alternates 20- and 21-tick frames, a 5%
    /// swing that is rounding, not a variable frame rate.
    @Test func timescaleRoundingIsConstant() throws {
        let times = (0..<300).map { (Double($0) * 1001 / 30000 * 600).rounded() / 600 }
        let timing = try #require(Inspector.frameTiming(presentationTimes: times))
        #expect(!timing.isVariable)
        #expect(abs(timing.averageFrameRate - 29.97) < 0.01)
    }

    @Test func oneDroppedFrameIsConstant() throws {
        var times = Fixtures.times(fps: 30, to: 4)
        times.remove(at: 60)
        let timing = try #require(Inspector.frameTiming(presentationTimes: times))
        #expect(!timing.isVariable)
    }

    @Test func decodeOrderIsSorted() throws {
        // B-frames: presentation times arrive out of order.
        let times = [0, 3, 1, 2, 6, 4, 5, 9, 7, 8].map { Double($0) / 30 }
        let timing = try #require(Inspector.frameTiming(presentationTimes: times))
        #expect(!timing.isVariable)
        #expect(abs(timing.averageFrameRate - 30) < 0.001)
    }

    @Test func tooFewFrames() {
        #expect(Inspector.frameTiming(presentationTimes: [0, 0.1]) == nil)
        #expect(Inspector.frameTiming(presentationTimes: [0, 0, 0]) == nil)
    }
}
