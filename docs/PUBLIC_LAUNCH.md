# Public launch copy

Reusable, factual copy for announcing the `AntonKhakhalin/open-computer-use` fork.
Everything here is verified against the current build; do not add claims that are not
in the repository (no endorsements, no universal-compatibility promises).

## One-line pitch

Native desktop computer use for AI agents, with advanced macOS window targeting.

## Short GitHub description

Local Computer Use for Codex, Claude Code, OpenCode, Gemini, Cursor, and other MCP-capable
AI agents — a fork of opensymph/open-computer-use with native macOS window management.

## Short link

<https://github.com/AntonKhakhalin/ocu> — alias repository for this project
(README + install pointer only; no code).

## 3-sentence announcement

Open Computer Use gives AI agents eyes and hands on your desktop: a local MCP server that
reads app interfaces and performs clicks, typing, scrolling, and dragging through the
accessibility layer — without taking over your real mouse and keyboard.
This fork adds native macOS window management on top of the upstream tool surface: agents
can list real windows, read a specific window's accessibility tree and screenshot, activate
one exact window, and perform window-targeted actions — all with CGWindowID-precise
identity, including same-bounds windows and minimized windows.
It works with any agent that speaks MCP over stdio (Codex, Claude Code, OpenCode, Gemini
CLI, Cursor, and more), ships as an installable agent skill, and runs entirely on your
machine.

## Detailed launch announcement

**Open Computer Use — Enhanced macOS Window Control** is a fork of the open-source
[opensymph/open-computer-use](https://github.com/opensymph/open-computer-use) project,
extended with the macOS window-management work currently proposed upstream
([PR #2](https://github.com/opensymph/open-computer-use/pull/2),
[PR #3](https://github.com/opensymph/open-computer-use/pull/3)).

The upstream project already delivers a solid, accessibility-first computer-use runtime
for macOS, Windows, and Linux: nine core tools (`list_apps`, `get_app_state`, `click`,
`perform_secondary_action`, `scroll`, `drag`, `type_text`, `press_key`, `set_value`) that
let agents observe and drive desktop apps in the background, without moving your real
pointer or stealing focus.

This fork builds on that foundation and focuses on **window-level precision on macOS**:

- `list_windows` enumerates real windows with exact **CGWindowID**s.
- `get_window` / `get_window_state` return one specific window's accessibility tree and a
  window-specific screenshot, with `screenshotId` lifecycle management (stale ids are
  rejected before acting).
- `activate_window` raises one exact window and verifies the result.
- All seven action tools accept an optional `window` target plus `screenshotId` coordinate
  gating, so actions land in the window you observed — not in a same-bounds window that
  happens to match first.
- `launch_app` starts macOS apps in the background (no focus steal), reuses running
  instances, and returns the `pid` and `windows[]`.
- Minimized windows are discoverable in `list_windows`, resolvable, and observable
  (when the private macOS window-identity capability is available; `ocu doctor` reports it).
- Windows with identical frames are resolved by AX identity, never by "first match";
  closed/ghost windows are rejected instead of being echoed as live.

Distribution is set up so the fork is independently installable and discoverable: a fork
npm package path (`@antonkhakhalin/open-computer-use`), fork GitHub Releases with bundled
cross-platform runtimes, a `scripts/install-local-runtime.sh` build-from-source installer,
per-agent MCP installers (`install-codex-mcp`, `install-claude-mcp`, `install-gemini-mcp`,
`install-opencode-mcp`, `install-cursor-mcp`), an installable agent skill
(`npx skills add AntonKhakhalin/open-computer-use ...`), and MCP Registry metadata prepared
under `io.github.AntonKhakhalin/open-computer-use`.

The project remains MIT licensed, with the upstream copyright notice preserved. The
original architecture and core implementation belong to the upstream project; this
repository is not an official upstream release and no endorsement by upstream maintainers
is implied. If you want the upstream stable release, use
[opensymph/open-computer-use](https://github.com/opensymph/open-computer-use).

## Feature bullets

- Local MCP server for desktop computer use — no cloud dependency for any control operation
- Works with Codex, Claude Code, OpenCode, Gemini CLI, Cursor, ZCode, and any stdio MCP host
- Nine core tools identical across macOS, Windows, and Linux (accessibility-first, background-first)
- Native macOS window management: `list_windows`, `get_window`, `get_window_state`, `activate_window`, `launch_app`
- Exact CGWindowID window identity; same-bounds disambiguation; closed/ghost-window rejection
- Window-targeted actions with `screenshotId` observation gating on macOS and Windows
- Background and minimized-window observation without stealing focus (minimized windows are discoverable in `list_windows` when the private window-identity capability is available)
- Password-manager deny list; global input gated behind explicit opt-in env vars (default off)
- Installable agent skill (`skills` CLI) + per-agent MCP installers, all idempotent
- Display-level desktop commands (`screenshot`, `cursor-position`, `record ...`) on all three platforms

## Supported-agent list

Verified install paths:

- **All detected agents at once** — `ocu setup` (non-interactive, idempotent, never overwrites existing entries)
- **Codex CLI & Codex App** — `ocu install-codex-mcp` / `ocu install-codex-plugin`
- **Claude Code** — `ocu install-claude-mcp`
- **OpenCode** — `ocu install-opencode-mcp`
- **Gemini CLI** — `ocu install-gemini-mcp`
- **Cursor** — `ocu install-cursor-mcp` (standard `mcp.json` format)
- **ZCode** — repository plugin (skill + auto-connected MCP server)
- **Any stdio MCP host** — generic `mcpServers` JSON / TOML configuration

## Installation snippet

```bash
# Runtime (fork npm tarball from GitHub Releases; bundles all platform runtimes)
npm i -g https://github.com/AntonKhakhalin/open-computer-use/releases/download/v1.2.1-anton.1/antonkhakhalin-open-computer-use-1.2.1-anton.1.tgz

# Verify
ocu doctor
ocu call list_apps

# Connect your agent
# One pass for every agent installed on this machine (non-interactive, idempotent):
ocu setup
# ...or configure one agent explicitly:
ocu install-codex-mcp
ocu install-claude-mcp
ocu install-gemini-mcp
ocu install-opencode-mcp
ocu install-cursor-mcp

# Optional: install the agent skill
npx skills add AntonKhakhalin/open-computer-use -g -a claude-code --skill open-computer-use -y
```

Generic MCP configuration for any other client:

```json
{
  "mcpServers": {
    "open-computer-use": {
      "command": "open-computer-use",
      "args": ["mcp"]
    }
  }
}
```

## Upstream attribution statement

This project is a fork of [opensymph/open-computer-use](https://github.com/opensymph/open-computer-use).
The original project, architecture, and core implementation belong to the upstream project
and its contributors. This fork adds the macOS window-management work currently proposed
upstream in [PR #2](https://github.com/opensymph/open-computer-use/pull/2) and
[PR #3](https://github.com/opensymph/open-computer-use/pull/3), plus fork-specific
distribution (packaging, installers, releases, skill URLs). It is released under the MIT
license with the upstream copyright notice preserved. Nothing in this fork implies review
or endorsement by upstream maintainers.

## Known limitations

- Linux window2 tools (`list_windows` et al.) return an explicit "not supported yet" error;
  the nine core tools work on Linux via AT-SPI2.
- Windows `launch_app` / `activate_window` are behind environment gates (upstream behavior);
  the macOS implementations in this fork are not gated the same way.
- Fork release artifacts are ad-hoc signed (no Developer ID / notarization); macOS TCC
  grants are tied to the exact binary, so re-grant via `ocu doctor` after replacing it.
- Minimized windows are observable and accept value writes, but restore them to visible
  before relying on key-event input. Their discovery in `list_windows` depends on a private
  macOS window-identity capability; when it is unavailable, `list_windows` lists on-screen
  windows only (check the capability line in `ocu doctor`).
- Unmodified `press_key` events are dropped while the user is actively typing on macOS
  (delivered when input is quiet); prefer `type_text` / AX paths — see the skill reference
  `macos-input.md`.
- `list_windows` window titles require Screen Recording permission on macOS; window ids
  work without it.
- The MCP Registry entry and the npm package publication require the maintainer's
  credentials and are not yet published; GitHub Releases and the skill URL work today.
