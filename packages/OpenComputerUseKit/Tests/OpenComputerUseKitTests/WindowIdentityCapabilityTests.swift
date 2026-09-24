import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import XCTest
@testable import OpenComputerUseKit

/// Pure unit tests for the private-API resilience contract of the macOS
/// window2 surface. Every test here runs in CI: they exercise the decision
/// core (`WindowDirectory.matchWindowCandidates`) over synthetic candidates
/// instead of a live accessibility tree, plus the runtime capability probe.
///
/// Contract under test (see AXWindowIdentitySPI / WindowManagement):
/// - `_AXUIElementGetWindow` available  → exact CGWindowID identity
/// - symbol missing                      → safe degradation (frame matching,
///                                          explicit ambiguity, never a guess)
/// - same-bounds windows + no identity   → explicit `.ambiguous`, never the
///                                          first candidate
/// - closed-window liveness indeterminate → never a false rejection
final class WindowIdentityCapabilityTests: XCTestCase {
    private let entryBounds = CGRect(x: 100, y: 120, width: 640, height: 480)

    private func entry(id: CGWindowID, title: String? = nil) -> CGWindowEntry {
        CGWindowEntry(
            windowID: id,
            ownerPID: 4242,
            layer: 0,
            bounds: entryBounds,
            title: title,
            frontToBackIndex: 0
        )
    }

    /// Distinct dummy AX elements; the decision core only returns them,
    /// never dereferences them, so real windows are not required.
    private let elementA = AXUIElementCreateSystemWide()
    private let elementB = AXUIElementCreateApplication(getpid())

    private func candidate(
        _ element: AXUIElement,
        frame: CGRect? = nil,
        title: String? = nil,
        focused: Bool = false,
        mapped: CGWindowID? = nil
    ) -> WindowDirectory.AXWindowCandidate {
        WindowDirectory.AXWindowCandidate(
            element: element,
            frame: frame ?? entryBounds,
            title: title,
            isFocused: focused,
            mappedWindowID: mapped
        )
    }

    // MARK: - Same-bounds resolution with identity available

    func testSameBoundsResolveExactlyWhenIdentityAvailable() {
        let candidates = [
            candidate(elementA, title: "Same", focused: true, mapped: 10),
            candidate(elementB, title: "Same", mapped: 11),
        ]

        // Each entry resolves to its own AX window regardless of which one
        // is focused or listed first: identity beats geometry.
        switch WindowDirectory.matchWindowCandidates(candidates: candidates, entry: entry(id: 11), identityAvailable: true) {
        case .matched(let element):
            XCTAssertTrue(CFEqual(element, elementB), "The entry's id must select its own mapped window, not the first same-bounds candidate")
        default:
            XCTFail("Same-bounds windows must not be ambiguous while the identity mapping is available")
        }

        switch WindowDirectory.matchWindowCandidates(candidates: candidates, entry: entry(id: 10), identityAvailable: true) {
        case .matched(let element):
            XCTAssertTrue(CFEqual(element, elementA))
        default:
            XCTFail("The focused window's own entry must still resolve by identity")
        }
    }

    func testIdentityMatchIsIndependentOfBounds() {
        // The entry's bounds do not even need to match: the CGWindowID is
        // authoritative when the mapping is available.
        let candidates = [candidate(elementA, mapped: 21)]

        guard case .matched(let element) = WindowDirectory.matchWindowCandidates(
            candidates: candidates,
            entry: entry(id: 21).with(bounds: entryBounds.offsetBy(dx: 400, dy: 0)),
            identityAvailable: true
        ) else {
            return XCTFail("A mapped identity must match regardless of bounds")
        }
        XCTAssertTrue(CFEqual(element, elementA))
    }

    // MARK: - Same-bounds without identity: explicit ambiguity, never a guess

    func testSameBoundsNeverGuessWhenIdentityUnavailable() {
        let candidates = [
            candidate(elementA, title: "Same"),
            candidate(elementB, title: "Same"),
        ]

        for id in [31, 32] {
            guard case .ambiguous(let count) = WindowDirectory.matchWindowCandidates(
                candidates: candidates,
                entry: entry(id: CGWindowID(id)),
                identityAvailable: false
            ) else {
                return XCTFail("Same-bounds windows without the identity mapping must be ambiguous, never a first-match guess")
            }
            XCTAssertEqual(count, 2)
        }
    }

    func testSingleSameBoundsCandidateMatchesWithoutIdentity() {
        let candidates = [candidate(elementA, title: "Only")]

        guard case .matched(let element) = WindowDirectory.matchWindowCandidates(
            candidates: candidates,
            entry: entry(id: 41, title: "Only"),
            identityAvailable: false
        ) else {
            return XCTFail("A unique same-bounds candidate must match without identity")
        }
        XCTAssertTrue(CFEqual(element, elementA))
    }

    func testPartialMappingFallsBackToFrameInsteadOfAbsence() {
        // Identity is available but one candidate cannot be mapped: the
        // check must not conclude `.notFound` (that would false-reject a
        // live window); it falls back to frame geometry and reports the
        // ambiguity.
        let candidates = [
            candidate(elementA, title: "Same", mapped: 999),
            candidate(elementB, title: "Same", mapped: nil),
        ]

        guard case .ambiguous = WindowDirectory.matchWindowCandidates(
            candidates: candidates,
            entry: entry(id: 51),
            identityAvailable: true
        ) else {
            return XCTFail("A partially unmappable window list must fall back to frame matching, not report absence")
        }
    }

    // MARK: - Closed-window liveness (identity present)

    func testIdentityAvailableAllMappedNoneMatchIsNotFound() {
        // Every accessibility window mapped to a different id: the CG entry
        // lingers after close and must be reported not found (stale), while
        // `.indeterminate` outcomes (partial mapping) never do.
        let candidates = [
            candidate(elementA, title: "Other", mapped: 61),
            candidate(elementB, title: "Other", mapped: 62),
        ]

        guard case .notFound = WindowDirectory.matchWindowCandidates(
            candidates: candidates,
            entry: entry(id: 900),
            identityAvailable: true
        ) else {
            return XCTFail("A fully mapped list without the entry's id must report notFound")
        }
    }

    func testIndeterminateIdentityNeverRejectsInResolve() throws {
        // The documented guarantee: when the liveness verdict is
        // indeterminate (symbol missing, no AX window list, partial
        // mapping), resolution must not reject the window.
        let resolved = try WindowDirectory.resolve(
            id: 71,
            entries: [entry(id: 71, title: "Live")],
            runningApps: [
                RunningAppDescriptor(
                    name: "Example",
                    bundleIdentifier: "com.example.app",
                    pid: 4242,
                    runningApplication: NSRunningApplication.current
                ),
            ],
            identity: { _, _ in .indeterminate }
        )

        XCTAssertEqual(resolved.ref, WindowRef(app: "Example", id: 71, title: "Live"))
    }

    // MARK: - Frame-geometry tie-breakers (identity degraded)

    func testTitledTieBreakBeatsFocused() {
        let candidates = [
            candidate(elementA, title: "Wrong", focused: true),
            candidate(elementB, title: "Right", focused: false),
        ]

        guard case .matched(let element) = WindowDirectory.matchWindowCandidates(
            candidates: candidates,
            entry: entry(id: 81, title: "Right"),
            identityAvailable: false
        ) else {
            return XCTFail("A titled same-bounds candidate must resolve via the title tie-break")
        }
        XCTAssertTrue(CFEqual(element, elementB), "The title tie-break must win over focus")
    }

    func testFocusedTieBreakWithoutEntryTitle() {
        let candidates = [
            candidate(elementA, title: "A", focused: false),
            candidate(elementB, title: "B", focused: true),
        ]

        guard case .matched(let element) = WindowDirectory.matchWindowCandidates(
            candidates: candidates,
            entry: entry(id: 82),
            identityAvailable: false
        ) else {
            return XCTFail("A focused same-bounds candidate must resolve via the focus tie-break")
        }
        XCTAssertTrue(CFEqual(element, elementB))
    }

    func testUniqueTitleLastResortWhenFramesDiffer() {
        let candidates = [
            candidate(elementA, frame: entryBounds.offsetBy(dx: 100, dy: 0), title: "Unique"),
            candidate(elementB, frame: entryBounds.offsetBy(dx: 200, dy: 0), title: "Other"),
        ]

        guard case .matched(let element) = WindowDirectory.matchWindowCandidates(
            candidates: candidates,
            entry: entry(id: 83, title: "Unique"),
            identityAvailable: false
        ) else {
            return XCTFail("A uniquely titled window must resolve as a last resort")
        }
        XCTAssertTrue(CFEqual(element, elementA))
    }

    func testDuplicateTitleLastResortNeverGuesses() {
        let candidates = [
            candidate(elementA, frame: entryBounds.offsetBy(dx: 100, dy: 0), title: "Shared"),
            candidate(elementB, frame: entryBounds.offsetBy(dx: 200, dy: 0), title: "Shared"),
        ]

        guard case .notFound = WindowDirectory.matchWindowCandidates(
            candidates: candidates,
            entry: entry(id: 84, title: "Shared"),
            identityAvailable: false
        ) else {
            return XCTFail("Title alone must never select between differently framed windows")
        }
    }

    // MARK: - Runtime capability probe (CI-safe: no TCC prompt, own process)

    func testWindowIdentityDegradesToIndeterminateWhenSymbolUnavailable() {
        // Pins the degradation contract against whatever the runtime
        // provides: without the private symbol the verdict is always
        // indeterminate (never a false rejection); with it, a bogus id can
        // never come back `.confirmed`.
        guard !AXWindowIdentitySPI.shared.isAvailable else {
            let verdict = WindowDirectory.windowIdentity(pid: getpid(), windowID: 1)
            XCTAssertNotEqual(
                verdict,
                .confirmed,
                "A bogus window id must never be confirmed by the identity mapping"
            )
            return
        }

        XCTAssertEqual(
            WindowDirectory.windowIdentity(pid: getpid(), windowID: 1),
            .indeterminate,
            "Without the private symbol the liveness check must degrade to indeterminate, never absent/confirmed"
        )
    }

    func testCapabilitySummaryReflectsSymbolAvailability() {
        let summary = AXWindowIdentitySPI.shared.capabilitySummary

        if AXWindowIdentitySPI.shared.isAvailable {
            XCTAssertTrue(summary.contains("_AXUIElementGetWindow resolved"), "summary: \(summary)")
        } else {
            XCTAssertTrue(summary.contains("_AXUIElementGetWindow unavailable"), "summary: \(summary)")
        }
    }

    func testDoctorSummaryReportsWindowIdentityCapability() {
        // `ocu doctor` is the developer-facing diagnostic surface: it must
        // report whether exact AX↔CGWindowID mapping is available.
        let summary = PermissionDiagnostics.current().summary
        XCTAssertTrue(summary.contains("windowIdentity="), "doctor summary must report the window identity capability: \(summary)")
    }

    // MARK: - Minimized-window discovery (pure)

    private func syntheticMinimizedEntry(id: CGWindowID, title: String? = nil) -> CGWindowEntry {
        // getpid(): a real running process, so the owning-process check in
        // listMinimizedWindowRefs passes for synthetic entries.
        CGWindowEntry(
            windowID: id,
            ownerPID: getpid(),
            layer: 0,
            bounds: entryBounds,
            title: title,
            frontToBackIndex: 0
        )
    }

    func testMinimizedCandidatesExcludeBaseEntries() {
        let base = [entry(id: 1)]
        let full = [entry(id: 1), entry(id: 2)]

        XCTAssertEqual(
            WindowDirectory.minimizedDiscoveryCandidates(base: base, full: full).map(\.windowID),
            [2]
        )
    }

    func testMinimizedCandidatesFilterLayerAndSize() {
        let withLayer25 = CGWindowEntry(
            windowID: 4,
            ownerPID: 4242,
            layer: 25,
            bounds: entryBounds,
            title: nil,
            frontToBackIndex: 1
        )
        let zeroSize = CGWindowEntry(
            windowID: 5,
            ownerPID: 4242,
            layer: 0,
            bounds: .zero,
            title: nil,
            frontToBackIndex: 2
        )

        let candidates = WindowDirectory.minimizedDiscoveryCandidates(
            base: [],
            full: [entry(id: 3), withLayer25, zeroSize]
        )
        XCTAssertEqual(candidates.map(\.windowID), [3])
    }

    func testMinimizedCandidatesDeduplicateIDs() {
        let full = [entry(id: 6), entry(id: 6), entry(id: 7)]

        XCTAssertEqual(
            WindowDirectory.minimizedDiscoveryCandidates(base: [], full: full).map(\.windowID),
            [6, 7]
        )
    }

    func testListMinimizedWindowRefsOnlyIncludesConfirmedMinimized() {
        let base: [CGWindowEntry] = []
        let full = [
            syntheticMinimizedEntry(id: 11, title: "Confirmed Minimized"),
            syntheticMinimizedEntry(id: 12),
            syntheticMinimizedEntry(id: 13),
        ]

        // The injected predicate stands in for the identity-verified
        // "live and minimized" check: only id 11 passes.
        let refs = WindowDirectory.listMinimizedWindowRefs(
            base: base,
            full: full,
            isConfirmedMinimized: { $0.windowID == 11 }
        )

        XCTAssertEqual(refs.map(\.id), [11])
        XCTAssertEqual(refs.first?.title, "Confirmed Minimized")
    }

    func testListMinimizedWindowRefsNeverDuplicatesBaseEntries() {
        // Even if the full list repeats an on-screen id, the base entry is
        // never re-emitted by the discovery path.
        let baseEntry = syntheticMinimizedEntry(id: 21)
        let refs = WindowDirectory.listMinimizedWindowRefs(
            base: [baseEntry],
            full: [baseEntry, baseEntry],
            isConfirmedMinimized: { _ in true }
        )

        XCTAssertTrue(refs.isEmpty)
    }

    func testListMinimizedWindowRefsDropsRejectedCandidates() {
        // The predicate rejects everything (e.g. identity mapping
        // unavailable, or no AX window reports minimized): the discovery
        // path adds nothing — the on-screen list is left untouched.
        let refs = WindowDirectory.listMinimizedWindowRefs(
            base: [],
            full: [syntheticMinimizedEntry(id: 31), syntheticMinimizedEntry(id: 32)],
            isConfirmedMinimized: { _ in false }
        )

        XCTAssertTrue(refs.isEmpty)
    }
}

private extension CGWindowEntry {
    func with(bounds: CGRect) -> CGWindowEntry {
        CGWindowEntry(
            windowID: windowID,
            ownerPID: ownerPID,
            layer: layer,
            bounds: bounds,
            title: title,
            frontToBackIndex: frontToBackIndex
        )
    }
}
