import XCTest
@testable import FrameCalculator

final class FrameRateTests: XCTestCase {

    // MARK: - Frames Per Second

    func testFramesPerSecond() {
        // Verify exact values for NTSC rates (must use fractional calculation)
        XCTAssertEqual(FrameRate.fps23_976.framesPerSecond, 24000.0 / 1001.0, accuracy: 0.0001)
        XCTAssertEqual(FrameRate.fps29_97_df.framesPerSecond, 30000.0 / 1001.0, accuracy: 0.0001)
        XCTAssertEqual(FrameRate.fps29_97_ndf.framesPerSecond, 30000.0 / 1001.0, accuracy: 0.0001)
        XCTAssertEqual(FrameRate.fps59_94.framesPerSecond, 60000.0 / 1001.0, accuracy: 0.0001)

        // Integer rates
        XCTAssertEqual(FrameRate.fps24.framesPerSecond, 24.0)
        XCTAssertEqual(FrameRate.fps25.framesPerSecond, 25.0)
        XCTAssertEqual(FrameRate.fps30.framesPerSecond, 30.0)
        XCTAssertEqual(FrameRate.fps50.framesPerSecond, 50.0)
        XCTAssertEqual(FrameRate.fps60.framesPerSecond, 60.0)

        // Custom rate
        XCTAssertEqual(FrameRate.custom(48.0).framesPerSecond, 48.0)
    }

    // MARK: - Drop Frame

    func testIsDropFrame() {
        XCTAssertTrue(FrameRate.fps29_97_df.isDropFrame)

        XCTAssertFalse(FrameRate.fps23_976.isDropFrame)
        XCTAssertFalse(FrameRate.fps24.isDropFrame)
        XCTAssertFalse(FrameRate.fps25.isDropFrame)
        XCTAssertFalse(FrameRate.fps29_97_ndf.isDropFrame)
        XCTAssertFalse(FrameRate.fps30.isDropFrame)
        XCTAssertFalse(FrameRate.fps50.isDropFrame)
        XCTAssertFalse(FrameRate.fps59_94.isDropFrame)
        XCTAssertFalse(FrameRate.fps60.isDropFrame)
        XCTAssertFalse(FrameRate.custom(29.97).isDropFrame)
    }

    // MARK: - Nominal Frame Rate

    func testNominalFrameRate() {
        XCTAssertEqual(FrameRate.fps23_976.nominalFrameRate, 24)
        XCTAssertEqual(FrameRate.fps24.nominalFrameRate, 24)
        XCTAssertEqual(FrameRate.fps25.nominalFrameRate, 25)
        XCTAssertEqual(FrameRate.fps29_97_df.nominalFrameRate, 30)
        XCTAssertEqual(FrameRate.fps29_97_ndf.nominalFrameRate, 30)
        XCTAssertEqual(FrameRate.fps30.nominalFrameRate, 30)
        XCTAssertEqual(FrameRate.fps50.nominalFrameRate, 50)
        XCTAssertEqual(FrameRate.fps59_94.nominalFrameRate, 60)
        XCTAssertEqual(FrameRate.fps60.nominalFrameRate, 60)
        XCTAssertEqual(FrameRate.custom(48.5).nominalFrameRate, 49)
    }

    // MARK: - Display Name

    func testDisplayName() {
        XCTAssertEqual(FrameRate.fps23_976.displayName, "23.976")
        XCTAssertEqual(FrameRate.fps24.displayName, "24")
        XCTAssertEqual(FrameRate.fps25.displayName, "25")
        XCTAssertEqual(FrameRate.fps29_97_df.displayName, "29.97 DF")
        XCTAssertEqual(FrameRate.fps29_97_ndf.displayName, "29.97 NDF")
        XCTAssertEqual(FrameRate.fps30.displayName, "30")
        XCTAssertEqual(FrameRate.fps50.displayName, "50")
        XCTAssertEqual(FrameRate.fps59_94.displayName, "59.94")
        XCTAssertEqual(FrameRate.fps60.displayName, "60")
    }

    // MARK: - All Standard Rates

    func testAllStandardRates() {
        let rates = FrameRate.allStandardRates
        XCTAssertEqual(rates.count, 9)
        XCTAssertTrue(rates.contains(.fps23_976))
        XCTAssertTrue(rates.contains(.fps24))
        XCTAssertTrue(rates.contains(.fps25))
        XCTAssertTrue(rates.contains(.fps29_97_df))
        XCTAssertTrue(rates.contains(.fps29_97_ndf))
        XCTAssertTrue(rates.contains(.fps30))
        XCTAssertTrue(rates.contains(.fps50))
        XCTAssertTrue(rates.contains(.fps59_94))
        XCTAssertTrue(rates.contains(.fps60))
    }

    // MARK: - Hashable & Equatable

    func testEquatable() {
        XCTAssertEqual(FrameRate.fps24, FrameRate.fps24)
        XCTAssertNotEqual(FrameRate.fps24, FrameRate.fps25)
        XCTAssertEqual(FrameRate.custom(48.0), FrameRate.custom(48.0))
        XCTAssertNotEqual(FrameRate.custom(48.0), FrameRate.custom(50.0))
    }

    func testHashable() {
        var set: Set<FrameRate> = [.fps24, .fps24, .fps30]
        XCTAssertEqual(set.count, 2)

        set.insert(.custom(48.0))
        XCTAssertEqual(set.count, 3)
    }

    // MARK: - Codable

    func testCodableStandardRates() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for rate in FrameRate.allStandardRates {
            let data = try encoder.encode(rate)
            let decoded = try decoder.decode(FrameRate.self, from: data)
            XCTAssertEqual(rate, decoded, "Round-trip failed for \(rate.displayName)")
        }
    }

    func testCodableCustomRate() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let customRate = FrameRate.custom(47.952)
        let data = try encoder.encode(customRate)
        let decoded = try decoder.decode(FrameRate.self, from: data)

        XCTAssertEqual(customRate, decoded)
        if case .custom(let value) = decoded {
            XCTAssertEqual(value, 47.952, accuracy: 0.0001)
        } else {
            XCTFail("Expected custom rate")
        }
    }
}
