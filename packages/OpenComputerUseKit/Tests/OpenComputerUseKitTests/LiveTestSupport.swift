import Foundation
import XCTest

/// Gate for tests that operate on real windows, apps, or the GUI session.
///
/// These tests need a logged-in GUI session and, for some assertions,
/// pre-granted Accessibility / Screen Recording TCC permissions. CI runners
/// (including GitHub-hosted macOS runners) do not have those grants, and a
/// TCC prompt would hang the build, so live tests are skipped by default.
/// Run them locally with:
///
///   OCU_RUN_LIVE_TESTS=1 swift test
///
/// Pure/unit tests never call this gate and run everywhere, including CI.
func requireLiveTestEnvironment(_ reason: String, file: StaticString = #filePath, line: UInt = #line) throws {
    guard ProcessInfo.processInfo.environment["OCU_RUN_LIVE_TESTS"] == "1" else {
        throw XCTSkip("Live test skipped (set OCU_RUN_LIVE_TESTS=1 to run): \(reason)", file: file, line: line)
    }
}
