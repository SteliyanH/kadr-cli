import Foundation

extension MediaReport {
    /// The report for people:
    ///
    ///     clip.mov  12.4 MB  0:12.48
    ///
    ///     Video     HEVC, 1080×1920 on screen, stored 1920×1080 and rotated 90°
    ///               30 fps declared, 24–30 fps measured: variable (372 frames)
    ///               HDR (HLG), BT.2020 primaries, BT.2020 matrix, 10-bit
    ///               9.6 Mbit/s
    ///     Audio     AAC, 44.1 kHz, stereo, 128 kbit/s
    public var text: String {
        var lines = ["\(file)  \(Format.bytes(bytes))  \(Format.duration(duration))", ""]
        for (index, track) in video.enumerated() {
            let label = video.count > 1 ? "Video \(index + 1)" : "Video"
            lines += Format.labelled(label, track.lines)
        }
        for (index, track) in audio.enumerated() {
            let label = audio.count > 1 ? "Audio \(index + 1)" : "Audio"
            lines += Format.labelled(label, [track.line])
        }
        return lines.joined(separator: "\n")
    }
}

extension MediaReport.VideoTrack {
    var lines: [String] {
        var size = "\(codecName), \(displaySize)"
        if rotation != 0 || mirrored {
            var how = [String]()
            if rotation != 0 { how.append("rotated \(rotation)°") }
            if mirrored { how.append("mirrored") }
            size += " on screen, stored \(storedSize) and \(how.joined(separator: " and "))"
        }

        var timing = "\(Format.rate(nominalFrameRate)) fps declared"
        if let measured = frameTiming {
            if measured.isVariable {
                timing += ", \(Format.rate(measured.slowestFrameRate))–\(Format.rate(measured.fastestFrameRate)) fps measured: variable"
            } else if Format.rate(measured.averageFrameRate) != Format.rate(nominalFrameRate) {
                // A 29.97 fps file can declare 30; the difference drifts audio by
                // 3.6 s an hour against anything that takes the declared rate.
                timing += ", \(Format.rate(measured.averageFrameRate)) fps measured, constant"
            } else {
                timing += ", constant"
            }
            timing += " (\(measured.frames) frames)"
        }

        return [size, timing, color.line, Format.bitRate(bitRate)]
    }
}

extension MediaReport.Color {
    var line: String {
        var parts = [String]()
        if let hdr {
            parts.append(hdr == "HDR" ? "HDR" : "HDR (\(hdr))")
        } else if let transferFunction {
            parts.append("SDR (\(transferFunction))")
        } else {
            parts.append("SDR, untagged")
        }
        if let primaries { parts.append("\(primaries) primaries") }
        if let matrix { parts.append("\(matrix) matrix") }
        if let bitsPerComponent { parts.append("\(bitsPerComponent)-bit") }
        return parts.joined(separator: ", ")
    }
}

extension MediaReport.AudioTrack {
    var line: String {
        let kHz = Format.rate(sampleRate / 1000)
        return "\(codecName), \(kHz) kHz, \(Format.channels(channels)), \(Format.bitRate(bitRate))"
    }
}

/// Formatting that doesn't depend on the locale: a report pasted into an issue
/// reads the same wherever it was made.
enum Format {
    static func labelled(_ label: String, _ lines: [String]) -> [String] {
        lines.enumerated().map { index, line in
            (index == 0 ? label : "").padding(toLength: 10, withPad: " ", startingAt: 0) + line
        }
    }

    /// Decimal units, as Finder shows them.
    static func bytes(_ count: Int64) -> String {
        let value = Double(count)
        switch value {
        case ..<1_000: return "\(count) bytes"
        case ..<1_000_000: return String(format: "%.1f kB", value / 1_000)
        case ..<1_000_000_000: return String(format: "%.1f MB", value / 1_000_000)
        default: return String(format: "%.2f GB", value / 1_000_000_000)
        }
    }

    /// `0:12.48`, or `1:02:03.00` past an hour.
    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "unknown duration" }
        let hundredths = Int((seconds * 100).rounded())
        let (h, m) = (hundredths / 360_000, hundredths / 6_000 % 60)
        let s = String(format: "%05.2f", Double(hundredths % 6_000) / 100)
        return h > 0 ? String(format: "%d:%02d:", h, m) + s : "\(m):" + s
    }

    /// `30`, `29.97`, `44.1`: at most two decimals, none when whole.
    static func rate(_ value: Double) -> String {
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    static func bitRate(_ bitsPerSecond: Double) -> String {
        bitsPerSecond >= 1_000_000
            ? String(format: "%.1f Mbit/s", bitsPerSecond / 1_000_000)
            : String(format: "%.0f kbit/s", bitsPerSecond / 1_000)
    }

    static func channels(_ count: Int) -> String {
        switch count {
        case 1: "mono"
        case 2: "stereo"
        case 6: "5.1"
        case 8: "7.1"
        default: "\(count) channels"
        }
    }
}
