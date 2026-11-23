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

    func testShareURLEncodesSpacesAndKeepsExistingEncoding() {
        XCTAssertEqual(
            AppConfiguration.shareURL(for: "smb://DS420/Mac Studio Time Machine")?.absoluteString,
            "smb://DS420/Mac%20Studio%20Time%20Machine"
        )
        XCTAssertEqual(
            AppConfiguration.shareURL(for: "smb://user@nas.local/Time%20Machine")?.absoluteString,
            "smb://user@nas.local/Time%20Machine"
        )
        XCTAssertEqual(AppConfiguration.shareURL(for: "afp://nas/Share")?.host, "nas")
        XCTAssertNil(AppConfiguration.shareURL(for: "ftp://nas/Share"))
        XCTAssertNil(AppConfiguration.shareURL(for: "   "))
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

    func testDecodingOlderSettingsKeepsValuesAndDefaultsRecheck() throws {
        let json = #"{"networkShares":["smb://nas/Media"],"cloneVolumes":["Clone"],"backupProcessTerms":[],"startupDelaySeconds":30,"runAtLogin":true}"#
        let value = try JSONDecoder().decode(AppConfiguration.self, from: Data(json.utf8))
        XCTAssertEqual(value.networkShares, ["smb://nas/Media"])
        XCTAssertEqual(value.startupDelaySeconds, 30)
        XCTAssertEqual(value.recheckIntervalMinutes, 5)
    }

    func testShareKeyMatchesMountSources() {
        XCTAssertEqual(
            AppConfiguration.shareKey(for: "smb://DS420/Mac Studio Time Machine"),
            AppConfiguration.shareKey(for: "//DomBett@DS420/Mac%20Studio%20Time%20Machine")
        )
        XCTAssertEqual(
            AppConfiguration.shareKey(for: "smb://user@ds1525.local:445/SQPN/"),
            "ds1525.local/sqpn"
        )
        XCTAssertEqual(AppConfiguration.shareKey(for: "nfs://server/export/data"), "server/export/data")
        XCTAssertEqual(AppConfiguration.shareKey(for: "server:/export/data"), "server/export/data")
        XCTAssertNotEqual(
            AppConfiguration.shareKey(for: "smb://DS420/Media"),
            AppConfiguration.shareKey(for: "//DomBett@DS420/video")
        )
    }
}
