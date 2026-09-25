# Security Defaults

## Current implementation boundaries

- The interface exposed to the MCP host is still local `stdio`; between the macOS CLI and the `.app` app agent, a Unix domain socket under the user's temp directory is used. After creation, the socket is tightened to current-user read/write, and no TCP/HTTP port is exposed.
- Every action must explicitly carry the `app` parameter; the runtime does not currently auto-scan and control arbitrary apps in the background.
- The macOS real-app path depends on `Open Computer Use.app` having been granted `Accessibility` and `Screen Recording` permissions; the terminal CLI / Node launcher forwards `mcp`, `doctor`, `call`, `snapshot`, and `list-apps` to the local app agent launched by LaunchServices, so the permission requirements do not fall on iTerm / Terminal.
- The experimental Linux runtime depends on a signed-in desktop user's AT-SPI2 / D-Bus session; coordinate mouse, drag, and keyboard synthesis are best-effort fallbacks and should not be treated as a general background input grant across Wayland compositors.

## Data handling

- For regular apps, screenshots are by default encoded to PNG in memory only and returned directly through the MCP `image` content block; they are not persisted long-term by default.
- Linux runtime screenshots are best-effort; if GNOME Wayland returns a black image, the bridge omits the image block to avoid mistaking an invalid screenshot for a real frame.
- The fixture app's synthetic state is written only to a local temporary JSON file, to support deterministic smoke tests; the current write path uses atomic replacement to reduce read/write races during tests.
- This repository currently introduces no third-party services and does not upload screenshots, AX trees, or input content.

## Authorization and least privilege

- Currently only one layer of password-manager bundle denylist / bundle-id gate is kept:
  - It blocks direct `get_app_state` / action calls against 1Password, Bitwarden, Dashlane, LastPass, NordPass, and Proton Pass.
  - Terminal-style apps, Chrome / Atlas, and system components are no longer built-in block targets.
  - Direct bundle identifier calls return a safety denial; app-name queries do not expose these password managers as resolvable targets by default.
- However, the official closed-source implementation's session approval / dynamic app policy still does not exist here.
- This means the open-source edition's current security boundary is mainly provided by:
  - Explicit tool call parameters
  - The built-in password-manager denylist
  - The system permissions of `Open Computer Use.app`
  - The local use scenario
- `click_method=global` is an explicit system-level pointer path that may move the real mouse, change foreground focus, or hit another window at the coordinates. The call parameters themselves are not considered sufficient authorization; macOS and Linux runtimes that support this mode additionally require `OPEN_COMPUTER_USE_ALLOW_GLOBAL_POINTER_FALLBACKS=1` in the process environment. When it is not set, the request must be rejected before any visible cursor movement or real input event.
- `click_method=app_post`, `sky_click`, and `accessibility` must not silently switch to `global`. This guarantees the non-intrusive boundary chosen by the caller still holds on failure.
- `click_method=sky_click` is an explicit macOS private SPI capability and does not enter `auto`. It does not move the system pointer, does not change the WindowServer frontmost app, and does not raise or switch the target window; internally it only briefly puts the target app into a synthetic-active state, never sends a defocus record to the real foreground app, and after the renderer settles it only undoes the target's synthetic state. The post-click action-result snapshot is forbidden from activating / `AXRaise`-ing for recovery. It still injects real input semantics into the specified PID/window, so it may only use the current snapshot's on-screen, same-PID windows, and fails closed on window identity mismatch, target-focus record failure, or missing private symbols. The first version supports only left single/double clicks within the same Space.
- The SkyLight ABI, raw event fields, and Chromium receive behavior are all not protected by Apple's public compatibility commitments. Failures after a system update must not trigger a silent global fallback; re-verify the symbols and controlled targets first, then decide whether to update the implementation.
- The next phase should prioritize adding:
  - Session-level approval
  - A clearer sensitive-app / system-settings protection policy

## Fixture Bridge constraints

- `FixtureBridge` is for in-repository test fixtures only; it is not a control plane for third-party apps.
- No capability added for real apps should reuse this test-only channel.

Repository-level dependency, SBOM, and provenance defaults are written centrally in `docs/SUPPLY_CHAIN_SECURITY.md`.
