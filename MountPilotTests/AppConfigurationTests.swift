import XCTest
@testable import MountPilot

final class AppConfigurationTests: XCTestCase {
    func testNormalizedLinesTrimsDropsBlankAndDeduplicates() {
        XCTAssertEqual(
            AppConfiguration.normalizedLines("  smb://nas/Media  \n\nClone\nClone\n"),
            ["smb://nas/Media", "Clone"]
        )
    }

    func testShareValidation() {
        XCTAssertTrue(AppConfiguration.validShare("smb://nas.local/Media"))
        XCTAssertTrue(AppConfiguration.validShare("nfs://server/export"))
        XCTAssertFalse(AppConfiguration.validShare("https://example.com/file"))
        XCTAssertFalse(AppConfiguration.validShare("smb:///missing-host"))
    }

    func testVolumeNamesResolveOnlyBelowVolumes() {
        XCTAssertEqual(AppConfiguration.volumePath(for: "Clone Backup"), "/Volumes/Clone Backup")
        XCTAssertEqual(AppConfiguration.volumePath(for: "/Volumes/Clone Backup"), "/Volumes/Clone Backup")
        XCTAssertNil(AppConfiguration.volumePath(for: "/Users/example"))
        XCTAssertNil(AppConfiguration.volumePath(for: "../Users/example"))
    }

    func testTimeMachineRunningParserFixture() {
        let output = "Backup session status: { Running = 1; }"
        XCTAssertNotNil(output.range(of: #"Running\s*=\s*1"#, options: .regularExpression))
    }
}

