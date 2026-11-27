import Foundation

/// The tool's version, which `kadr --version` prints. A test keeps it equal to
/// the newest release in CHANGELOG.md.
public let kadrCLIVersion = "0.1.0-dev"

/// Failures the commands report in a sentence, without a stack of framework errors.
public enum CLIError: Error, Equatable, CustomStringConvertible {
    case fileNotFound(String)
    case unreadable(String, reason: String)
    case noMedia(String)
    case invalidTime(String)
    case timeOutOfRange(Double, duration: Double)
    case unsupportedImageFormat(String)
    case invalidWidth(Int)
    case cannotWrite(String)

    public var description: String {
        switch self {
        case .fileNotFound(let path):
            "No file at \(path)."
        case .unreadable(let path, let reason):
            "Could not read \(path): \(reason)"
        case .noMedia(let path):
            "\(path) has no audio or video tracks."
        case .invalidTime(let text):
            "\"\(text)\" is not a time. Use seconds (12.5) or minutes and seconds (1:02.5)."
        case .timeOutOfRange(let seconds, let duration):
            "\(Format.duration(seconds)) is past the end of the video, which is \(Format.duration(duration)) long."
        case .unsupportedImageFormat(let ext):
            "Can't write a .\(ext) image. Use " + Thumbnailer.formats.keys.sorted().map { ".\($0)" }.joined(separator: ", ") + "."
        case .invalidWidth(let width):
            "\(width) is not a usable width."
        case .cannotWrite(let path):
            "Could not write \(path)."
        }
    }
}

/// Parses `12`, `12.5`, `1:02.5` or `1:02:03.25` into seconds.
public func parseTime(_ text: String) throws -> Double {
    let parts = text.split(separator: ":", omittingEmptySubsequences: false)
    guard (1...3).contains(parts.count) else { throw CLIError.invalidTime(text) }
    var seconds = 0.0
    for (index, part) in parts.enumerated() {
        let isLast = index == parts.count - 1
        // Only the last component may have a fraction; minutes and seconds below an
        // hour or minute must be under 60.
        guard let value = isLast ? Double(part) : Int(part).map(Double.init),
              value >= 0, value.isFinite,
              index == 0 || value < 60 else { throw CLIError.invalidTime(text) }
        seconds = seconds * 60 + value
    }
    return seconds
}
