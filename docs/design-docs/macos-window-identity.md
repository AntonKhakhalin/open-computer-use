# macOS window identity: same-bounds matching and closed-window ghosts

PR #3's window2 surface has two correctness issues that need closing out. This document records the investigation findings, the scheme, and the verification evidence; the implementation lives in `WindowManagement.swift`, `AccessibilitySnapshot.swift`, and the new `AXWindowIdentitySPI.swift`.

## Issue 1: AX tree mismatch for same-bounds windows

**Symptom (before the fix).** `WindowDirectory.matchAXWindow` matched the app's AX window list to CGWindowIDs only by frame geometry. Two windows with exactly the same bounds both hit; the tie-break chain was title → focused → **first candidate**. When the title was also identical (or the title was unavailable, e.g. no Screen Recording grant), the first candidate was returned — i.e. `get_window_state` could pair window A's screenshot (captured by CGWindowID, itself correct) with window B's AX tree (wrong window at the root).

**Fix.** Reliable identity resolution comes first; on failure, report ambiguity explicitly instead of guessing:

1. Added `AXWindowIdentitySPI`: the runtime resolves the private symbol `_AXUIElementGetWindow` (exported by ApplicationServices/HIServices, `OSStatus (AXUIElement, CGWindowID*)`) via `dlopen`/`dlsym`, following the same pattern as the existing `SkyLightSPI` — all undisclosed ABIs are converged into one file as a review boundary, and a missing symbol degrades the capability rather than crashing.
2. `matchAXWindow` returns an `AXWindowMatch` enum:
   - `.matched(element)`: exact identity hit (the SPI is available and some candidate's `_AXUIElementGetWindow` == the target CGWindowID) → unique frame hit → existing title/focused tie-break → unique-title fallback.
   - `.ambiguous(count)`: multiple frame hits with no unique tie-break. **Only reachable when the identity mapping is unavailable/incomplete** — when the mapping is available and all hits fail, it goes straight to `.notFound`.
   - `.notFound`.
3. `SnapshotBuilder.buildWindow` (`get_window_state`) throws an explicit error on `.ambiguous`, with no best-effort recovery:
   `ambiguousWindow(<id>): <count> windows of <app> share the same bounds; the accessibility tree cannot be matched to this window. Move or resize one of them and re-observe with list_windows.`
4. `activate_window` throws the same error on `.ambiguous` (raise/focus cannot be done against just any same-bounds window); `unminimizeIfNeeded` no-ops on ambiguity.

**Guarantee.** When `_AXUIElementGetWindow` is resolvable (verified present on this machine's macOS 27 with an accurate mapping), identity resolves exactly by CGWindowID, and the tree root returned by `get_window_state` necessarily carries the captured CGWindowID. When the symbol is unavailable, same-bounds requests fail explicitly instead of mismatching.

## Issue 2: closed-window ghosts (leftover CGWindow entries)

**Symptom (before the fix).** `WindowDirectory.resolve` judged liveness against the full (`optionAll`) CGWindow list. After a window closes, its entry lingers in the list: measured locally, about 350ms during the close animation (alpha 1.0 → 0.003 → cleared), and TextEdit-style phantom shells can linger long-term (alpha 1.0). `get_window` therefore echoed closed windows as live refs. The content paths (`get_window_state`/`activate_window`/action tools) previously each relied on their own failure fallbacks, but `get_window` claimed stale windows to be live.

**Fix.** Added an AX-identity liveness check in `resolve` (resolution order: stale-list → process exit → denylist → **AX identity**):

- Three states of `WindowIdentity`:
  - `.confirmed`: the host app's AX window list contains a window that maps to this CGWindowID;
  - `.absent`: the AX window list was **read fully** and every window mapped successfully, with no hits — this CG entry has no live AX identity;
  - `.indeterminate`: the SPI is unavailable, the app does not expose an AX window list, or any candidate mapping failed — no conclusion is drawn.
- `.absent` → throws the official stale error (the same string as "not in the list", since the window is indeed closed):
  `staleWindowHandle(<id>): the window is no longer open; re-observe with list_windows.`
- `.indeterminate` **never rejects**. No list-level heuristics such as alpha / layer / bounds are used (they would wrongly kill real windows other than legitimate low-opacity, fade-in, and off-screen helpers; measured locally, AppKit creates several off-screen, AX-identity-less helper CG entries per app, which should never be targetable in the first place).
- Minimize is unaffected: measured, a minimized window is still in the AX window list and `_AXUIElementGetWindow` maps it as usual (probe: after minimizing, AX-mapped=true).

**Guarantee (written into the docs).** `get_window` reports a CGWindowID live only when all of the following hold: (a) it is in the full window list; (b) the host process is alive; (c) it is not on the denylist; (d) the AX-identity check is `.confirmed` or `.indeterminate`. When (d) is deterministically falsified (`.absent`), it reports stale. When the check is unavailable (`.indeterminate`), the old behavior is kept and labeled honestly — it does not claim an unverifiable window is live, nor does it reject an unverifiable window.

## Verification (2026-09-22, dev machine macOS 27.0, all measured and passing)

- Unit tests (fixture-dedicated windows, never touching user windows; `swift test --filter WindowManagementTests` 53 cases / 0 failures):
  - Same-bounds: the fixture's new command `open_window fixture-second-same-bounds` opens a second window at exactly the same frame as the main window (possibly with the same title); asserts `matchAXWindow` returns, by CGWindowID, the element with the correct `AXIdentifier` (`fixture-window` / `fixture-second-window`); asserts `.ambiguous` when the SPI is unavailable.
  - Ghost: the fixture opens a second window → closes it via a fixture command → immediately polls `get_window`: it must always fail with the official stale string and never succeed; records whether the CG entry was still lingering when the rejection happened (evidence, not a flaky hard assertion). This run observed **rejected while CG entry lingering: true**.
  - Minimize guard: a minimized fixture window must still be resolvable (minimize/restore via the AX `kAXMinimizedAttribute`).
  - Pure resolve logic: the identity seam injects the three states `.absent`/`.confirmed`/`.indeterminate`, each pinned separately.
- Smoke: `make smoke` all pass; under `OPEN_COMPUTER_USE_SMOKE_WINDOW2=1`, W1–W12 all pass (W11: two same-bounds windows resolve/activate independently; W12: a closed window's id goes stale immediately).
- Real-MCP e2e (stdio JSON-RPC, all 28 checks passed; all windows are fixture-dedicated, and the Finder/Safari/TextEdit window sets compared id-by-id before and after are unchanged):
  - Same-bounds + same-title pair: `get_window` echoes each id correctly in both directions, `get_window_state` succeeds in both directions (no ambiguity error, with screenshot);
  - Same-bounds + different titles: `activate_window` switches in both directions, using the fixture state file's `keyWindowTitle` as an **independent** oracle to verify the keyed window is correct;
  - Ghost: polling immediately after closing, measured that at `t=0.158s` **the CG entry was still in the full list (cghas=yes both times, before and after) while `get_window` already returned the exact stale string** — this rejection can only come from the AX-identity check (the old list check would echo the leftover entry as live); `activate_window`/`click` are likewise exactly stale;
  - Minimize guard: after minimizing via the fixture command `minimize_window`, `get_window` still succeeds.
  - Environment note: this e2e round was run from an interactive shell context (this machine's shell context process holds a valid AX attribution for the debug binary, verified with a functional Finder snapshot preflight); the launchd context is unusable — after rebuilding within the session, the launchd attribution's TCC grant no longer matches the debug binary's cdhash, and a launchd-started server silently loses AX (all identity checks degrade to indeterminate, window-level activation fails and is masked by `isFrontmost`'s app-level short-circuit); measured, and this context has been abandoned.
