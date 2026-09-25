# Demo plan — background window control (15–30 s)

Reproducible script for the strongest differentiator of this fork: an agent
observes and edits a **background** macOS window — and a **minimized** one —
without ever stealing the user's focus. No fake demo: every step below is a
real `open-computer-use` tool call, and the capture is real screen capture.

## Pre-conditions

- macOS 14+, Accessibility + Screen Recording granted to the installed
  runtime (`ocu doctor`).
- Installed runtime: `ocu --version` (fork ≥ 1.2.1-anton.2).
- Two apps only: **Finder** (or a browser) and **TextEdit**.
- Run the agent session from a terminal; keep the user's own app
  (e.g. a browser) frontmost throughout.

## Setup (manual, ~10 s)

1. Open TextEdit with a document containing the line `DEMO TARGET`.
   Give the window a recognizable title (`DEMO`).
2. Open a second TextEdit document titled `DEMO-BG` with the line `hello`.
3. Bring Finder (or the browser) to the foreground. TextEdit is now a
   **background** app.

## Demo script (agent turns)

The agent (any MCP host) receives these tasks in order. The exact tool
traffic is shown in comments.

**1. "List my windows."** → `list_windows`

Shows the TextEdit windows with real CGWindowID ids while Finder stays
frontmost. *(~2 s on screen: nothing moves, the JSON appears in the chat.)*

**2. "Read the background window DEMO-BG without touching my focus."** →
`get_window_state(window: <DEMO-BG id>, include_text: true, include_screenshot: true)`

Returns the window's own accessibility tree **and a window-specific
screenshot** of a window that is not frontmost. The user's pointer and
foreground app are untouched. *(~3 s)*

**3. "Append ' world' to the text in DEMO-BG."** → `type_text(window: <DEMO-BG id>, text: " world")`

The text changes via the AX value-write path (background-safe). The agent
then re-observes with `get_window_state` and diffs the text — delivery is
verified, not assumed. No focus change on screen. *(~4 s)*

**4. "Minimize DEMO-BG, then confirm you can still see it."** →
`activate_window` is **not** used; instead:

- minimize via the window's AX control (or ask the user to hit
  ⌘M once — this is the only manual input in the demo), then
- `list_windows` again: the minimized window is still listed (identity-
  proven discovery), and
- `get_window_state(window: <DEMO-BG id>, include_text: true)` still reads
  its content while it stays minimized in the Dock. *(~6 s)*

**5. "Now bring that exact window to the front."** →
`activate_window(window: <DEMO-BG id>)`

Only this step changes the foreground — and it is the one the user asked
for. The result is verified against the frontmost app. *(~3 s)*

**6. (Optional closer) "Same-bounds proof."** Open two TextEdit windows at
identical frames and identical titles, then `get_window_state` on each id:
each returns its *own* tree (identity resolution), while the upstream
frame-matching behavior would have returned the first candidate for both.
*(~5 s)*

## Narration / captions (15–30 s cut)

> "This is Open Computer Use. The agent just listed every real window on
> this Mac — by CGWindowID — without moving my pointer."
> *(list_windows result visible)*
> "Here it reads a background TextEdit window: its own accessibility tree
> and its own screenshot, while I keep working in my browser."
> *(get_window_state result; foreground unchanged)*
> "It typed into that background window through the accessibility layer —
> no focus stolen, and it re-read the text to prove the write landed."
> *(type_text + diff)*
> "Now the window is minimized — it's still listed, still readable."
> *(list_windows + get_window_state on the minimized window)*
> "And when I ask, it activates that one exact window."
> *(activate_window)*

Full-length version: add step 6 (same-bounds proof) — it is the strongest
single visual for the identity story.

## Verification checklist (before recording)

- [ ] `ocu doctor` reports accessibility=granted, screenRecording=granted,
      windowIdentity=exact.
- [ ] `list_windows` returns the TextEdit windows with ids.
- [ ] Step 3 diff shows the appended text in the re-read state.
- [ ] Step 4: minimized window id still present in `list_windows` output.
- [ ] Foreground app was the same before and after steps 1–4 (only step 5
      changes it).

## Recording notes

- Record the whole desktop (e.g. `open-computer-use record start --output
  demo.mp4 --polish`) — the polished output adds cursor/key overlays.
- Keep the terminal/agent pane in one corner so both the agent traffic and
  the desktop are visible.
- Do not pre-minimize or pre-arrange windows mid-take: the demo must show
  the agent's observations driving every state change.
