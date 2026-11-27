import ArgumentParser
import Foundation
import KadrCLIKit

@main
struct KadrCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "kadr",
        abstract: "Inspect video files, and export frames, with kadr.",
        version: kadrCLIVersion,
        subcommands: [Inspect.self, Thumb.self]
    )
}

struct Inspect: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show what a player hides: rotation, frame timing, HDR and the tracks.",
        discussion: """
            A player shows a portrait clip upright, plays a variable frame rate smoothly \
            and tone-maps HDR, so none of it is visible by watching. All of it changes what \
            an edit exports. Nothing is decoded, so a long file takes a moment, not a minute.
            """
    )

    @Argument(help: "The video or audio file.", completion: .file())
    var file: String

    @Flag(help: "Print JSON, for scripts and agents. Field names are stable.")
    var json = false

    func run() async throws {
        let report = try await Inspector.inspect(URL(fileURLWithPath: file), as: file)
        print(json ? try report.json() : report.text)
    }
}

struct Thumb: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Save the frame at a time as an image.",
        discussion: """
            The frame is exact, not the nearest keyframe, and upright: a portrait clip \
            gives a portrait image. The format follows the output's extension: \
            .png, .jpg, .heic or .tiff.
            """
    )

    @Argument(help: "The video file.", completion: .file())
    var file: String

    @Option(name: .shortAndLong, help: "Seconds (12.5) or minutes and seconds (1:02.5).")
    var at: String = "0"

    @Option(name: .shortAndLong, help: "Where to write it. Defaults to <name>-<time>.png here.", completion: .file())
    var output: String?

    @Option(name: .shortAndLong, help: "Scale to this many pixels wide, keeping the shape.")
    var width: Int?

    func run() async throws {
        let seconds = try parseTime(at)
        let input = URL(fileURLWithPath: file)
        let path = output ?? defaultName(for: input, at: seconds)
        let size = try await Thumbnailer.writeFrame(of: input, at: seconds, width: width, to: URL(fileURLWithPath: path))
        print("\(path)  \(size)")
    }

    /// `clip-12.5s.png`, in the current directory.
    func defaultName(for input: URL, at seconds: Double) -> String {
        var time = String(format: "%.3f", seconds)
        while time.hasSuffix("0") { time.removeLast() }
        if time.hasSuffix(".") { time.removeLast() }
        return "\(input.deletingPathExtension().lastPathComponent)-\(time)s.png"
    }
}
