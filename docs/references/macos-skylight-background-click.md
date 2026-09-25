# macOS SkyLight Background Click Reference

## Purpose

This note records the external research, pinned source versions, and the boundaries OCU adopted for `click_method=sky_click`. SkyLight is macOS private SPI; what is described here is a compatibility implementation cross-verified against source, not a public API Apple commits to keeping stable.

## Reference sources

- Cua article: [Inside macOS Window Internals](https://cua.ai/blog/inside-macos-window-internals)
  - Explains the differences between ordinary HID hit-testing, PID-targeted delivery, and SkyLight delivery.
  - Covers the problem areas of Chromium background input, focus-without-raise, and AX remote observers.
- Cua Driver: [trycua/cua](https://github.com/trycua/cua/tree/b8a0f32a06c75225ba24ebb5ab14f6507fa90d15/libs/cua-driver)
  - This implementation is cross-checked against commit `b8a0f32a06c75225ba24ebb5ab14f6507fa90d15`.
  - The event sequence baseline comes from `click_at_xy_chromium` in `rust/crates/platform-macos/src/input/mouse.rs`.
  - The dynamic symbols and private function signature baseline comes from `rust/crates/platform-macos/src/input/skylight.rs`.
- yabai: [asmvik/yabai](https://github.com/asmvik/yabai/tree/dd845723416f5fe92af49fad5ebab00369e07edd)
  - Used to cross-check the engineering practices of SkyLight dynamic loading and the private window APIs; OCU did not copy yabai code.

## The event sequence OCU adopted

`sky_click` uses the current snapshot's PID, `CGWindowID`, in-window coordinates, and screen coordinates, and delivers in the following order:

1. Resolve the target PSN with `GetProcessForPID`, send a focus record only to the target, briefly putting it into a synthetic-active state; the foreground PSN is not queried, and a defocus record is never sent to the real foreground app.
2. `mouseMoved` at the target point, gesture phase `2`.
3. Off-window primer `mouseDown` / `mouseUp` at `(-1, -1)`, phase `1` / `2`.
4. Wait `100ms`, then deliver the real target `mouseDown` / `mouseUp` with phase `3`.
5. For a double click, wait `80ms` before sending the second pair of events, incrementing the click state from `1` to `2`.
6. Wait for the renderer to consume the asynchronous mouse-up, then send a defocus record only to the target, undoing this round's synthetic-active state.

Every event carries the same click-group id and sets the PID, window id, window-under-pointer, and window-local location. Each step goes through both `SLEventPostToPid` and the public `CGEvent.postToPid`: the former covers Chromium/Catalyst, the latter preserves AppKit compatibility. This is a fixed dispatch policy, not a retry after failure.

The old implementation followed Cua / yabai's focus-without-raise pattern: it first sent a defocus to the real foreground app, then sent a focus restore at the end. That sequence, while not changing the WindowServer frontmost PID or z-order, triggers AppKit `resignActive` / `resignKey` and breaks the first responder. Controlled Chrome verification showed synthesizing only the target focus is sufficient, so the current implementation makes "the foreground app never deactivates" a hard constraint.

## Parts OCU explicitly did not adopt

- No call to `SLPSSetFrontProcessWithOptions`, and no use of `NSRunningApplication.activate` or `AXRaise` on the target app. Only the target app's synthetic event-routing state changes; the real foreground app's AppKit active state, key window, and first responder must remain unchanged.
- The post-`sky_click` action-result snapshot uses a read-only recovery policy; when the target AX/window is momentarily unreadable it returns an error, and the snapshot recovery path is not allowed to activate or raise the target.
- `sky_click` is not put into `auto`, and a failed `sky_click` does not fall back to `global`.
- No right click, middle click, triple click, cross-Space, hidden, or minimized windows.
- No promise of usability on Canvas, Unity, Blender, or other surfaces that reject PID-targeted events.

## Compatibility checks

The runtime probes the following symbols via `dlopen` / `dlsym`; any missing one fails closed before delivery:

- `SLEventPostToPid`
- `SLEventSetIntegerValueField`
- `CGEventSetWindowLocation`
- `SLPSPostEventRecordTo`
- `GetProcessForPID`

Before delivery it must also confirm the snapshot's `CGWindowID` is still owned by the same PID and still on-screen. After a macOS update, re-verify the symbols, event fields, the signed app artifact, and a fully occluded Chromium page; the live threshold also includes the foreground fixture's active/key/first-responder state and the transient resign/key-loss counts.

## License

The Cua code is under the MIT License. This repository's attribution and license text for the derived event recipe are in `THIRD_PARTY_NOTICES.md` at the root.
