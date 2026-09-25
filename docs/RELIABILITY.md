# Stability and Operability

## Current minimum verification line

- Build: `swift build`
- Unit tests: `swift test`
- End-to-end smoke: `./scripts/run-tool-smoke-tests.sh`
- macOS SkyLight live regression: `OPEN_COMPUTER_USE_RUN_SKY_CLICK_LIVE_TEST=1 swift test --filter SkyClickLiveTests`
- Linux runtime: `(cd apps/OpenComputerUseLinux && go test ./...)`, `./scripts/build-open-computer-use-linux.sh --arch arm64`
- Local diagnostics:
  - `open-computer-use doctor`
  - `open-computer-use snapshot <app>`

## Known critical dependencies

- On macOS, `Open Computer Use.app` must be granted `Accessibility` and `Screen Recording`; the terminal itself should no longer be a required authorization target.
- macOS `click_method=sky_click` additionally depends on the SkyLight / ApplicationServices private symbols `SLEventPostToPid`, `SLEventSetIntegerValueField`, `CGEventSetWindowLocation`, `SLPSPostEventRecordTo`, and `GetProcessForPID`. The runtime probes them dynamically and fails closed, but macOS updates, signing changes, or target app input-policy changes can still break background delivery. The controlled live regression must verify, beyond DOM, foreground PID, mouse, and z-order, the foreground AppKit active state, key window, first responder, and the resign/key-loss counts.
- The smoke suite depends on a local GUI session; it must not be treated as a headless-environment command.
- `get_app_state` results for regular apps depend on the AX tree and window screenshots; output varies across complex apps. Electron/WebView apps usually have very deep AX trees; the current implementation compresses empty wrappers and relaxes traversal depth to prioritize keeping actionable text, buttons, and input fields.
- The Linux runtime depends on a signed-in desktop user session; when `XDG_RUNTIME_DIR`, `DBUS_SESSION_BUS_ADDRESS`, or the display environment is missing, it tries to auto-discover the current user's session env from `/run/user/<uid>` and common desktop processes. A pure SSH tty that cannot find a desktop session still cannot directly access the AT-SPI GUI tree.
- GNOME Wayland screenshots may be restricted by the compositor; the current Linux bridge treats a black image as an invalid screenshot and omits the image block.

## Current troubleshooting order

1. Run `open-computer-use doctor` first to confirm the permission state; if permissions are missing, the command brings up the permission onboarding window via the `.app` app agent. If everything is already granted, it only prints the state and exits.
2. Use `open-computer-use list-apps` to confirm the target app is discovered.
3. Use `open-computer-use snapshot <app>` to tell whether it is a transport problem or a snapshot / action problem.
4. If only `sky_click` fails, re-run `get_app_state` first and confirm the window is still on-screen, not hidden/minimized, and no Space switch happened. When the error contains `missing SkyLight symbols`, do not switch to an implicit fallback; re-verify the private SPI against the current macOS version. If an occluded Chromium page still has no effect, then use a controlled page to distinguish a renderer policy change from a coordinate/window-local mapping problem.
5. If you only want to verify the repository baseline, run fixture + smoke directly; do not start troubleshooting on complex third-party apps first.
6. When troubleshooting the Linux runtime, first confirm the target command is run by the desktop user, then use `open-computer-use call list_apps` and `open-computer-use snapshot <app>` to distinguish session/env problems from AT-SPI tree/action problems. If it is Codex MCP, re-run `open-computer-use install-codex-mcp`, restart Codex, and confirm the configuration is still `open-computer-use mcp`.

## Future hardening directions

- Add structured logging and failure-reason classification.
- Continue adding failure context and regular-app regression samples for screenshot capture / AX traversal.
- Add more regular-app regression samples instead of only covering the fixture.

The CI/CD pipeline structure and the default plan for release automation are written centrally in `docs/CICD.md`.
