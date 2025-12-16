import XCTest
@testable import FrameCalculator

final class TimecodeTests: XCTestCase {

    // MARK: - Basic Initialization

    func testInitWithFrames() {
        let tc = Timecode(frames: 86400, frameRate: .fps24)
        XCTAssertEqual(tc.frames, 86400)
        XCTAssertEqual(tc.frameRate, .fps24)
    }

    func testInitWithComponents() {
        let tc = Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0, frameRate: .fps24)
        XCTAssertEqual(tc.frames, 86400)
    }

    func testZero() {
        let tc = Timecode.zero(at: .fps24)
        XCTAssertEqual(tc.frames, 0)
        XCTAssertEqual(tc.hours, 0)
        XCTAssertEqual(tc.minutes, 0)
        XCTAssertEqual(tc.seconds, 0)
        XCTAssertEqual(tc.frameComponent, 0)
    }

    // MARK: - Components (Non-Drop Frame)

    func testComponents24fps() {
        // 1 hour = 24 * 60 * 60 = 86400 frames
        let tc = Timecode(frames: 86400, frameRate: .fps24)
        XCTAssertEqual(tc.hours, 1)
        XCTAssertEqual(tc.minutes, 0)
        XCTAssertEqual(tc.seconds, 0)
        XCTAssertEqual(tc.frameComponent, 0)
    }

    func testComponents25fps() {
        // 1 hour = 25 * 60 * 60 = 90000 frames
        let tc = Timecode(frames: 90000, frameRate: .fps25)
        XCTAssertEqual(tc.hours, 1)
        XCTAssertEqual(tc.minutes, 0)
        XCTAssertEqual(tc.seconds, 0)
        XCTAssertEqual(tc.frameComponent, 0)
    }

    func testComponents30fps() {
        // 1 hour = 30 * 60 * 60 = 108000 frames
        let tc = Timecode(frames: 108000, frameRate: .fps30)
        XCTAssertEqual(tc.hours, 1)
        XCTAssertEqual(tc.minutes, 0)
        XCTAssertEqual(tc.seconds, 0)
        XCTAssertEqual(tc.frameComponent, 0)
    }

    func testComponentsArbitrary() {
        // 01:02:03:04 at 24fps
        // = 1*86400 + 2*1440 + 3*24 + 4 = 86400 + 2880 + 72 + 4 = 89356 frames
        let tc = Timecode(hours: 1, minutes: 2, seconds: 3, frames: 4, frameRate: .fps24)
        XCTAssertEqual(tc.frames, 89356)
        XCTAssertEqual(tc.hours, 1)
        XCTAssertEqual(tc.minutes, 2)
        XCTAssertEqual(tc.seconds, 3)
        XCTAssertEqual(tc.frameComponent, 4)
    }

    // MARK: - Drop Frame Calculations

    func testDropFrame_BeforeFirstDrop() {
        // Frame 1799 is the last frame before the first drop (00:00:59;29)
        let tc1799 = Timecode(frames: 1799, frameRate: .fps29_97_df)
        XCTAssertEqual(tc1799.formatted(), "00:00:59;29")
    }

    func testDropFrame_AtFirstDrop() {
        // Frame 1800 is the first frame after the drop, displays as 00:01:00;02
        // (frame numbers 00:01:00;00 and 00:01:00;01 are skipped)
        let tc1800 = Timecode(frames: 1800, frameRate: .fps29_97_df)
        XCTAssertEqual(tc1800.hours, 0)
        XCTAssertEqual(tc1800.minutes, 1)
        XCTAssertEqual(tc1800.seconds, 0)
        XCTAssertEqual(tc1800.frameComponent, 2)  // Skipped 00 and 01
    }

    func testDropFrame_TenMinutes() {
        // Every 10th minute does NOT drop frames
        // At 10 minutes: 9 drops * 2 = 18 frames dropped
        // 30 * 60 * 10 - 18 = 17982 frames
        // Display: 00:10:00;00

        let tc = Timecode(frames: 17982, frameRate: .fps29_97_df)
        XCTAssertEqual(tc.hours, 0)
        XCTAssertEqual(tc.minutes, 10)
        XCTAssertEqual(tc.seconds, 0)
        XCTAssertEqual(tc.frameComponent, 0)  // No skip at 10-minute mark
    }

    func testDropFrame_OneHour() {
        // 1 hour = 6 ten-minute blocks
        // Each 10-min block: 17982 frames
        // Total: 17982 * 6 = 107892 frames
        // Display: 01:00:00;00

        let tc = Timecode(frames: 107892, frameRate: .fps29_97_df)
        XCTAssertEqual(tc.hours, 1)
        XCTAssertEqual(tc.minutes, 0)
        XCTAssertEqual(tc.seconds, 0)
        XCTAssertEqual(tc.frameComponent, 0)
    }

    func testDropFrame_RoundTrip() {
        // Test that components → frames → components gives same result
        let testCases: [(h: Int, m: Int, s: Int, f: Int)] = [
            (0, 0, 0, 0),
            (0, 0, 59, 29),   // Just before first drop
            (0, 1, 0, 2),     // Right after first drop
            (0, 9, 59, 29),   // Just before 10-minute mark
            (0, 10, 0, 0),    // At 10-minute mark (no drop)
            (0, 10, 0, 1),    // Just after 10-minute mark
            (0, 11, 0, 2),    // Drop at minute 11
            (1, 0, 0, 0),     // One hour
            (1, 30, 15, 10),  // Arbitrary time
        ]

        for (h, m, s, f) in testCases {
            let tc1 = Timecode(hours: h, minutes: m, seconds: s, frames: f, frameRate: .fps29_97_df)
            let tc2 = Timecode(frames: tc1.frames, frameRate: .fps29_97_df)

            XCTAssertEqual(tc2.hours, h, "Hours mismatch for \(h):\(m):\(s);\(f)")
            XCTAssertEqual(tc2.minutes, m, "Minutes mismatch for \(h):\(m):\(s);\(f)")
            XCTAssertEqual(tc2.seconds, s, "Seconds mismatch for \(h):\(m):\(s);\(f)")
            XCTAssertEqual(tc2.frameComponent, f, "Frames mismatch for \(h):\(m):\(s);\(f)")
        }
    }

    func testDropFrame_vs_NonDropFrame() {
        // Same frame count displays differently in DF vs NDF
        // Frame 1800 at 30fps NDF = 00:01:00:00
        // Frame 1800 at 29.97 DF = 00:01:00;02 (we've crossed the first drop point)

        let ndf = Timecode(frames: 1800, frameRate: .fps30)
        XCTAssertEqual(ndf.formatted(), "00:01:00:00")

        let df = Timecode(frames: 1800, frameRate: .fps29_97_df)
        XCTAssertEqual(df.formatted(), "00:01:00;02")
    }

    // MARK: - Arithmetic

    func testAddition() {
        let tc1 = Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0, frameRate: .fps24)
        let tc2 = Timecode(hours: 0, minutes: 30, seconds: 0, frames: 0, frameRate: .fps24)
        let result = tc1 + tc2

        XCTAssertEqual(result.hours, 1)
        XCTAssertEqual(result.minutes, 30)
        XCTAssertEqual(result.seconds, 0)
        XCTAssertEqual(result.frameComponent, 0)
    }

    func testSubtraction() {
        let tc1 = Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0, frameRate: .fps24)
        let tc2 = Timecode(hours: 0, minutes: 0, seconds: 30, frames: 0, frameRate: .fps24)
        let result = tc1 - tc2

        XCTAssertEqual(result.hours, 0)
        XCTAssertEqual(result.minutes, 59)
        XCTAssertEqual(result.seconds, 30)
        XCTAssertEqual(result.frameComponent, 0)
    }

    func testMultiplication() {
        let tc = Timecode(hours: 0, minutes: 0, seconds: 30, frames: 0, frameRate: .fps24)
        let result = tc * 4

        XCTAssertEqual(result.hours, 0)
        XCTAssertEqual(result.minutes, 2)
        XCTAssertEqual(result.seconds, 0)
        XCTAssertEqual(result.frameComponent, 0)
    }

    func testNegation() {
        let tc = Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0, frameRate: .fps24)
        let negated = -tc

        XCTAssertEqual(negated.frames, -86400)
        XCTAssertTrue(negated.isNegative)
    }

    func testSubtractionResultingInNegative() {
        let tc1 = Timecode(hours: 0, minutes: 30, seconds: 0, frames: 0, frameRate: .fps24)
        let tc2 = Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0, frameRate: .fps24)
        let result = tc1 - tc2

        XCTAssertTrue(result.isNegative)
        XCTAssertEqual(result.formatted(), "-00:30:00:00")
    }

    // MARK: - Acceptance Criteria Tests

    func testAcceptanceCriteria_Addition() {
        // 01:00:00:00 + 00:00:01:00 @ 24fps = 01:00:01:00
        let tc1 = try! Timecode("01:00:00:00", frameRate: .fps24)
        let tc2 = try! Timecode("00:00:01:00", frameRate: .fps24)
        let result = tc1 + tc2

        XCTAssertEqual(result.formatted(), "01:00:01:00")
    }

    func testAcceptanceCriteria_FrameToTimecode() {
        // 86400 frames @ 24fps = 01:00:00:00
        let tc = Timecode(frames: 86400, frameRate: .fps24)
        XCTAssertEqual(tc.formatted(), "01:00:00:00")
    }

    func testAcceptanceCriteria_TimecodeToFrame() {
        // 01:00:00:00 @ 24fps = 86400 frames
        let tc = try! Timecode("01:00:00:00", frameRate: .fps24)
        XCTAssertEqual(tc.frames, 86400)
    }

    // MARK: - String Formatting

    func testFormattingNonDropFrame() {
        let tc = Timecode(hours: 1, minutes: 2, seconds: 3, frames: 4, frameRate: .fps24)
        XCTAssertEqual(tc.formatted(), "01:02:03:04")
    }

    func testFormattingDropFrame() {
        let tc = Timecode(hours: 1, minutes: 2, seconds: 3, frames: 4, frameRate: .fps29_97_df)
        // Should use semicolon before frames
        XCTAssertTrue(tc.formatted().contains(";"))
    }

    func testFormattingNegative() {
        let tc = Timecode(frames: -86400, frameRate: .fps24)
        XCTAssertEqual(tc.formatted(), "-01:00:00:00")
    }

    func testFormattingWithSign() {
        let positive = Timecode(frames: 86400, frameRate: .fps24)
        let negative = Timecode(frames: -86400, frameRate: .fps24)

        XCTAssertEqual(positive.formatted(alwaysShowSign: true), "+01:00:00:00")
        XCTAssertEqual(negative.formatted(alwaysShowSign: true), "-01:00:00:00")
    }

    // MARK: - String Parsing

    func testParsingStandard() throws {
        let tc = try Timecode("01:02:03:04", frameRate: .fps24)
        XCTAssertEqual(tc.hours, 1)
        XCTAssertEqual(tc.minutes, 2)
        XCTAssertEqual(tc.seconds, 3)
        XCTAssertEqual(tc.frameComponent, 4)
    }

    func testParsingDropFrameSemicolon() throws {
        let tc = try Timecode("01:02:03;04", frameRate: .fps29_97_df)
        XCTAssertEqual(tc.hours, 1)
        XCTAssertEqual(tc.minutes, 2)
        XCTAssertEqual(tc.seconds, 3)
        XCTAssertEqual(tc.frameComponent, 4)
    }

    func testParsingFrameNumber() throws {
        let tc = try Timecode("86400", frameRate: .fps24)
        XCTAssertEqual(tc.frames, 86400)
        XCTAssertEqual(tc.hours, 1)
    }

    func testParsingNegative() throws {
        let tc = try Timecode("-01:00:00:00", frameRate: .fps24)
        XCTAssertTrue(tc.isNegative)
        XCTAssertEqual(tc.frames, -86400)
    }

    func testParsingWithWhitespace() throws {
        let tc = try Timecode("  01:02:03:04  ", frameRate: .fps24)
        XCTAssertEqual(tc.hours, 1)
        XCTAssertEqual(tc.minutes, 2)
    }

    func testParsingInvalidFormat() {
        XCTAssertThrowsError(try Timecode("invalid", frameRate: .fps24)) { error in
            XCTAssertTrue(error is Timecode.ParseError)
        }
    }

    func testParsingMinutesOutOfRange() {
        XCTAssertThrowsError(try Timecode("01:60:00:00", frameRate: .fps24))
    }

    func testParsingSecondsOutOfRange() {
        XCTAssertThrowsError(try Timecode("01:00:60:00", frameRate: .fps24))
    }

    func testParsingFramesOutOfRange() {
        XCTAssertThrowsError(try Timecode("01:00:00:30", frameRate: .fps24))
    }

    // MARK: - Comparable

    func testComparable() {
        let tc1 = Timecode(frames: 100, frameRate: .fps24)
        let tc2 = Timecode(frames: 200, frameRate: .fps24)

        XCTAssertTrue(tc1 < tc2)
        XCTAssertFalse(tc2 < tc1)
        XCTAssertTrue(tc1 <= tc2)
        XCTAssertTrue(tc2 > tc1)
    }

    // MARK: - Duration in Seconds

    func testDurationInSeconds() {
        // 1 hour at 24fps = 3600 seconds
        let tc = Timecode(frames: 86400, frameRate: .fps24)
        XCTAssertEqual(tc.durationInSeconds, 3600.0, accuracy: 0.001)
    }

    func testFromSeconds() {
        // 1 hour = 3600 seconds
        let tc = Timecode.from(seconds: 3600.0, frameRate: .fps24)
        XCTAssertEqual(tc.frames, 86400)
    }

    // MARK: - Frame Rate Conversion

    func testConvertingFrameRate() {
        let tc24 = Timecode(frames: 86400, frameRate: .fps24)
        let tc30 = tc24.converting(to: .fps30)

        // Same frame count, different rate
        XCTAssertEqual(tc30.frames, 86400)
        XCTAssertEqual(tc30.frameRate, .fps30)
        // But different timecode display
        XCTAssertNotEqual(tc30.hours, tc24.hours)
    }

    func testConvertingDuration() {
        let tc24 = Timecode(frames: 86400, frameRate: .fps24)  // 1 hour
        let tc30 = tc24.convertingDuration(to: .fps30)

        // Same real-world duration, different frame count
        XCTAssertEqual(tc30.durationInSeconds, 3600.0, accuracy: 0.01)
        XCTAssertEqual(tc30.frames, 108000)  // 30fps * 3600 sec
    }

    // MARK: - Codable

    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = Timecode(hours: 1, minutes: 2, seconds: 3, frames: 4, frameRate: .fps29_97_df)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Timecode.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - Edge Cases

    func testLargeTimecode() {
        // 99:59:59:23 at 24fps - near maximum practical timecode
        let tc = Timecode(hours: 99, minutes: 59, seconds: 59, frames: 23, frameRate: .fps24)
        XCTAssertEqual(tc.hours, 99)
        XCTAssertEqual(tc.minutes, 59)
        XCTAssertEqual(tc.seconds, 59)
        XCTAssertEqual(tc.frameComponent, 23)
    }

    func testVerySmallFrameCount() {
        let tc = Timecode(frames: 1, frameRate: .fps24)
        XCTAssertEqual(tc.hours, 0)
        XCTAssertEqual(tc.minutes, 0)
        XCTAssertEqual(tc.seconds, 0)
        XCTAssertEqual(tc.frameComponent, 1)
    }
}
