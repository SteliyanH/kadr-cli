import Foundation
import Testing
@testable import KadrCLIKit

struct ParseTimeTests {

    @Test(arguments: [
        ("0", 0.0), ("12", 12), ("12.5", 12.5), ("1:02.5", 62.5), ("1:02:03.25", 3723.25), ("90", 90), ("0:00", 0),
    ])
    func valid(_ text: String, _ seconds: Double) throws {
        #expect(try parseTime(text) == seconds)
    }

    @Test(arguments: ["", "abc", "-1", "1:60", "1:2:3:4", "1.5:00", "1::2", "inf", "nan"])
    func invalid(_ text: String) {
        #expect(throws: CLIError.invalidTime(text)) { try parseTime(text) }
    }
}

struct FormatTests {

    @Test func durations() {
        #expect(Format.duration(0) == "0:00.00")
        #expect(Format.duration(12.48) == "0:12.48")
        #expect(Format.duration(59.999) == "1:00.00")
        #expect(Format.duration(3723.25) == "1:02:03.25")
        #expect(Format.duration(.nan) == "unknown duration")
    }

    @Test func sizes() {
        #expect(Format.bytes(512) == "512 bytes")
        #expect(Format.bytes(12_400_000) == "12.4 MB")
        #expect(Format.bytes(2_500_000_000) == "2.50 GB")
    }

    @Test func rates() {
        #expect(Format.rate(30) == "30")
        #expect(Format.rate(29.97002997) == "29.97")
        #expect(Format.rate(44.1) == "44.1")
        #expect(Format.bitRate(9_600_000) == "9.6 Mbit/s")
        #expect(Format.bitRate(128_000) == "128 kbit/s")
    }
}

struct VersionTests {

    /// The newest release in CHANGELOG.md, or before the first release, a `-dev`
    /// version. kadr-photos printed `0.1.0-dev` for eleven releases because
    /// nothing compared the two.
    @Test func versionMatchesChangelog() throws {
        let changelog = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("CHANGELOG.md")
        let text = try String(contentsOf: changelog, encoding: .utf8)
        let newest = text.split(separator: "\n").lazy
            .compactMap { $0.wholeMatch(of: /## \[(\d+\.\d+\.\d+)\].*/)?.1 }
            .first
        if let newest {
            #expect(kadrCLIVersion == String(newest))
        } else {
            #expect(kadrCLIVersion.hasSuffix("-dev"))
        }
    }
}
