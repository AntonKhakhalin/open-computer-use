import AppKit
import XCTest

@testable import OpenComputerUseKit

/// Pure regressions for the fixture list-identity resolution. A bare-exec fixture
/// launched under an app-style parent (agent shells) inherits the parent's
/// LaunchServices identity (localizedName and bundleIdentifier), which previously
/// made the fixture disappear from `list_apps`.
final class AppDiscoveryIdentityTests: XCTestCase {
    func testFixtureListBundleIdentifierIsPinnedByteForByte() {
        XCTAssertEqual(AppDiscovery.fixtureListBundleIdentifier, "dev.opencodex.opencomputeruse.fixture")
    }

    func testFixtureInheritingParentIdentityStillResolvesToFixtureID() {
        // Observed shape: launched under an agent host, NSRunningApplication reports
        // the parent's name and bundle id while the executable is the fixture.
        XCTAssertEqual(
            AppDiscovery.listBundleIdentifier(
                name: "OpenCode",
                executableName: "OpenComputerUseFixture",
                bundleIdentifier: "ai.opencode.desktop"
            ),
            AppDiscovery.fixtureListBundleIdentifier
        )
    }

    func testFixtureBareIdentityWithoutBundleStillResolvesToFixtureID() {
        XCTAssertEqual(
            AppDiscovery.listBundleIdentifier(
                name: "OpenComputerUseFixture",
                executableName: "OpenComputerUseFixture",
                bundleIdentifier: nil
            ),
            AppDiscovery.fixtureListBundleIdentifier
        )
    }

    func testOrdinaryAppsKeepTheirOwnIdentity() {
        XCTAssertEqual(
            AppDiscovery.listBundleIdentifier(name: "Safari", executableName: "Safari", bundleIdentifier: "com.apple.Safari"),
            "com.apple.Safari"
        )
        XCTAssertNil(AppDiscovery.listBundleIdentifier(name: "helper", executableName: "helper", bundleIdentifier: nil))
        XCTAssertNil(AppDiscovery.listBundleIdentifier(name: "helper", executableName: nil, bundleIdentifier: ""))
    }

    func testFixtureRemainsUserFacingUnderAccessoryPolicyAndInheritedName() {
        XCTAssertTrue(
            AppDiscovery.isUserFacingListApp(
                name: "OpenCode",
                executableName: "OpenComputerUseFixture",
                activationPolicy: .accessory
            )
        )
        XCTAssertTrue(
            AppDiscovery.isUserFacingListApp(
                name: "OpenComputerUseFixture",
                executableName: nil,
                activationPolicy: .regular
            )
        )
    }

    func testOrdinaryAccessoryAppsStayHidden() {
        XCTAssertFalse(
            AppDiscovery.isUserFacingListApp(
                name: "Agent Helper",
                executableName: "agent-helper",
                activationPolicy: .accessory
            )
        )
        XCTAssertTrue(
            AppDiscovery.isUserFacingListApp(
                name: "Safari",
                executableName: "Safari",
                activationPolicy: .regular
            )
        )
    }
}
