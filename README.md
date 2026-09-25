<p align="center">
  <img src="./assets/logo/open-computer-use-256.png" width="144" alt="open-computer-use">
</p>

# Open Computer Use — Enhanced macOS Window Control

[![Release](https://img.shields.io/github/v/release/AntonKhakhalin/open-computer-use?label=fork%20release)](https://github.com/AntonKhakhalin/open-computer-use/releases)
[![Fork of opensymph/open-computer-use](https://img.shields.io/badge/fork%20of-opensymph%2Fopen--computer--use-0E7490)](https://github.com/opensymph/open-computer-use)
[![License: MIT](https://img.shields.io/badge/License-MIT-informational)](./LICENSE)

Local computer use for Codex, Claude Code, OpenCode, Gemini, Cursor, and other MCP-capable agents: a local MCP server that gives agents eyes and hands on your desktop — see an app's interface, click, type, scroll, and drag through the accessibility layer, without taking over your real mouse and keyboard. Runs entirely on your machine, on macOS, Windows, and Linux.

**Install:** [one command](#quick-install) · **Short link:** [`github.com/AntonKhakhalin/ocu`](https://github.com/AntonKhakhalin/ocu) · Fork of [opensymph/open-computer-use](https://github.com/opensymph/open-computer-use)

```bash
npm i -g https://github.com/AntonKhakhalin/open-computer-use/releases/download/v1.2.1-anton.2/antonkhakhalin-open-computer-use-1.2.1-anton.2.tgz
```

**What this fork adds on macOS** (everything else is upstream, unchanged):

- **Exact window targeting** — every window is a real CGWindowID; same-bounds windows resolve by identity, never by "first match".
- **Background window observation** — read a specific window's accessibility tree without activation or focus stealing.
- **Minimized-window observation** — minimized windows stay discoverable in `list_windows`, resolvable, and observable; value writes work while minimized.
- **Native `launch_app`** — background launch (no focus steal), instance reuse, returns `pid` + `windows[]`.
- **Window-specific screenshots** — `get_window_state` captures the targeted window itself, with `screenshotId`-gated coordinate actions.
- **Background-first AX interaction** — the accessibility API is preferred over synthetic input wherever a reliable operation exists.

> [!NOTE]
> **This repository is a fork of [opensymph/open-computer-use](https://github.com/opensymph/open-computer-use).**
> The original project, architecture, and core implementation belong to the upstream project.
> This fork adds the macOS window-management work currently proposed upstream
> ([PR #2 — native macOS `launch_app`](https://github.com/opensymph/open-computer-use/pull/2),
> [PR #3 — native macOS window management](https://github.com/opensymph/open-computer-use/pull/3))
> and a multi-agent distribution surface (fork npm package, fork GitHub Releases, fork skill URLs).
> It remains **MIT licensed**. If you only want the upstream stable release, use
> [opensymph/open-computer-use](https://github.com/opensymph/open-computer-use) — it is fully capable on its own,
> and nothing here implies endorsement by upstream maintainers.

## Why this fork

| Capability | Upstream stable (`v1.2.0`) | This fork |
| --- | --- | --- |
| Native macOS window management (`list_windows`, `get_window`, `get_window_state`, `activate_window`, window-targeted actions) | Windows only; macOS "in progress" | **Included and tested** (proposed upstream in [PR #3](https://github.com/opensymph/open-computer-use/pull/3)) |
| Native macOS `launch_app` (background launch, instance reuse, returns `pid` + `windows[]`) | Not available | **Included and tested** (proposed upstream in [PR #2](https://github.com/opensymph/open-computer-use/pull/2)) |
| Exact CGWindowID window identity; same-bounds disambiguation; closed/ghost-window rejection | — | Included (PR #3) |
| Window-targeted coordinate actions with `screenshotId` observation gating on macOS | — | Included (PR #3) |
| macOS input-delivery & background-operation best practices in the agent skill | — | Included |
| Install surface | npm `@opensymph/open-computer-use` | Fork npm package, fork GitHub Releases, fork skill URLs (below) |

Everything else — the nine core tools, the 14-tool MCP surface, the three-platform contract, the guardrails — is upstream's, unchanged.

## Supported agents

| Agent | How |
| --- | --- |
| Codex CLI & Codex App | `ocu install-codex-mcp` or `ocu install-codex-plugin` |
| Claude Code | `ocu install-claude-mcp` |
| OpenCode | `ocu install-opencode-mcp` |
| Gemini CLI | `ocu install-gemini-mcp` (`--scope user` for global) |
| Cursor | `ocu install-cursor-mcp` (writes `~/.cursor/mcp.json`; `--scope project` writes `./.cursor/mcp.json`) |
| ZCode | [Plugin install](#zcode) (skill + auto-connected MCP server) |
| Any other MCP client | [Generic MCP config](#generic-mcp-configuration) |
| Agent Skills–compatible agents | [Skill install](#skill-install) |

Installers are idempotent: they detect existing configuration, preserve unrelated MCP servers and settings, and report exactly what they wrote.

Prefer one command for everything? `ocu setup` detects which agents are present (Codex, Claude Code, OpenCode, Gemini, Cursor), configures only the ones it finds, and never overwrites existing entries:

```bash
ocu setup                # configure every detected agent
ocu setup --dry-run      # show what would change
ocu setup --agents codex,claude
```

## Quick install

Simplest working route — the fork's npm tarball from [GitHub Releases](https://github.com/AntonKhakhalin/open-computer-use/releases):

```bash
npm i -g https://github.com/AntonKhakhalin/open-computer-use/releases/download/v1.2.1-anton.2/antonkhakhalin-open-computer-use-1.2.1-anton.2.tgz
ocu doctor        # verify the install; macOS: prompts for Accessibility + Screen Recording
ocu call list_apps
```

The tarball bundles the native runtimes for all supported `os-arch` pairs (macOS, Windows, Linux); the launcher picks the right one. When the fork npm package is published, `npm i -g @antonkhakhalin/open-computer-use` will be equivalent.

No npm? Build from source and link the binary:

```bash
git clone https://github.com/AntonKhakhalin/open-computer-use.git
cd open-computer-use
./scripts/install-local-runtime.sh   # builds the current platform's runtime, links open-computer-use + ocu
```

macOS 14+ needs `Accessibility` and `Screen Recording` granted once. Windows and Linux work out of the box in a signed-in desktop session (Linux desktops need AT-SPI2, which GNOME and friends ship by default).

## Connect your agent

```bash
ocu setup                  # auto-detect all installed agents and configure them in one pass

# or configure one agent explicitly:
ocu install-codex-mcp      # Codex CLI & Codex App
ocu install-codex-plugin   # Codex App, plugin form
ocu install-claude-mcp     # Claude Code
ocu install-gemini-mcp     # Gemini CLI (--scope user for global)
ocu install-opencode-mcp   # opencode
ocu install-cursor-mcp     # Cursor (user scope; --scope project for ./.cursor/mcp.json)
```

### ZCode

This repo ships as a ZCode plugin — one install gives you the skill and an auto-connected MCP server:

1. Install the runtime once (the plugin falls back to it when no local build exists):

   ```bash
   npm i -g https://github.com/AntonKhakhalin/open-computer-use/releases/download/v1.2.1-anton.2/antonkhakhalin-open-computer-use-1.2.1-anton.2.tgz
   ```

2. In ZCode, open **Settings → Plugin Management → Discover** and click **+**.
3. Add this repository — the GitHub URL `AntonKhakhalin/open-computer-use`, or a local checkout directory.
4. Find **Open Computer Use** in the list and click **Get**.
5. Start a new session. Check **Settings → MCP** shows `open-computer-use` as connected, then just ask: *"list the windows on my screen"*.

To remove it later: Installed tab → Open Computer Use → uninstall.

## Skill install

The skill is installable guidance that teaches an agent to use these tools well. Installing the skill does **not** install the runtime binary — it only adds the instructions. Three distinct steps, in order:

1. **Runtime install** — get the `open-computer-use` / `ocu` binary on your PATH ([Quick install](#quick-install)).
2. **MCP connection** — point your agent at the runtime ([Connect your agent](#connect-your-agent)).
3. **Skill install** — optional, adds best-practices guidance:

```bash
npx skills add AntonKhakhalin/open-computer-use -g -a claude-code --skill open-computer-use -y
npx skills add AntonKhakhalin/open-computer-use -g -a codex --skill open-computer-use -y
```

Any agent the [`skills`](https://www.npmjs.com/package/skills) CLI supports works (`-a <agent>`; see `npx skills add -h` for the list). The skill also lives in this repo at [`skills/open-computer-use`](./skills/open-computer-use) for manual copying.

## Generic MCP configuration

Any host that can launch a local stdio MCP server can use this runtime.

JSON (Claude Code, Cursor, Gemini CLI, most clients):

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

TOML (Codex `~/.codex/config.toml`):

```toml
[mcp_servers."open-computer-use"]
command = "open-computer-use"
args = ["mcp"]
```

This is a **local stdio** server: it runs on your machine, no remote/network endpoint is involved.

## macOS advanced capabilities

**Verified:**

- List and identify individual windows — `list_windows` returns real windows with exact **CGWindowID**s.
- Target multiple windows belonging to one app — window ids, not app-level key-window guesses.
- Activate a specific window — `activate_window` raises one window and verifies the result.
- Observe and interact with background windows — accessibility-first paths work without activation or focus stealing.
- Window-specific screenshots — `get_window_state` captures the targeted window itself, with `screenshotId`-gated coordinate actions (stale ids rejected).
- Same-bounds window identity — windows with identical frames resolve by AX identity, never by "first match"; closed/ghost windows are rejected, not echoed as live.
- Native app launching — `launch_app` starts apps in the background (no focus steal), reuses running instances, and returns `pid` + `windows[]`.
- Minimized windows — discoverable in `list_windows`, resolvable and observable; `set_value` works on them.

**Known limitations:**

- Minimized windows: discovery depends on a private macOS window-identity capability — when it is unavailable, `list_windows` lists on-screen windows only (check the capability line in `ocu doctor`). Restore to visible before relying on key-event input (value writes still work while minimized).
- Plain unmodified `press_key` events are dropped while the user is actively typing (delivered when input is quiet); prefer `type_text` / AX paths — see [the skill reference](./skills/open-computer-use/references/macos-input.md).
- Window titles in `list_windows` require Screen Recording permission; ids still work without it.
- Linux window2 tools return an explicit "not supported yet" error.
- Fork release artifacts are **ad-hoc signed** (no Developer ID / notarization), so macOS permission grants are tied to the exact build — re-grant via `ocu doctor` if you replace the binary.

## Security / privacy

- **Local execution.** Desktop control never leaves your machine; there is no cloud dependency for any computer-use operation.
- **Accessibility-first.** The runtime prefers the accessibility API over synthetic input; your real pointer, focus, and foreground app stay put unless you explicitly opt into global input.
- **Password-manager deny list.** Password managers are never launched or automated, regardless of flags.
- **Gated power features.** App launching, focus-stealing activation, and global input injection each sit behind explicit environment-variable gates (default off).
- **macOS permissions.** `Accessibility` and `Screen Recording` are required, granted once via `ocu doctor` onboarding.
- **License.** [MIT](./LICENSE) — the upstream copyright notice is preserved.

## The tools

Nine core tools, identical across all three platforms:

| Tool | What it does |
| --- | --- |
| `list_apps` | List running and recently used applications. |
| `get_app_state` | Read an app's accessibility tree and screenshot. |
| `click` | Click by `element_index` or screenshot coordinates. |
| `perform_secondary_action` | Invoke an element's own secondary action. |
| `scroll` | Scroll an element by pages, or a window by pixel deltas. |
| `drag` | Drag between two coordinates. |
| `type_text` | Type text, Unicode-safe, background-first. |
| `press_key` | Press a key or chord (`ctrl+s`, `return`, `page_up`…). |
| `set_value` | Set the value of a settable control directly. |

Five additional window-level tools — `list_windows`, `get_window`, `get_window_state`, `launch_app`, `activate_window` — follow the newer window2 API and are available on macOS and Windows (Linux in progress). On macOS the window id is a CGWindowID, and the action tools accept the same optional `window` argument plus `screenshotId` for coordinate actions as on Windows.

## Platform status

| Platform | Runtime | Notes |
| --- | --- | --- |
| macOS | Swift | Visual cursor, permission onboarding, `sky_click` background clicks, full window2 API with exact CGWindowID identity; display-level desktop commands (see below). |
| Windows | Go, single exe | UI Automation + Win32, process-isolated operations, full window2 API; display-level desktop commands (see below). |
| Linux | Go, single binary | Native AT-SPI2 over D-Bus, zero runtime dependencies; display-level X11 commands (see below). |

### Display-level desktop commands (all platforms)

Every runtime ships the same whole-desktop CLI commands that mirror the classic `xdotool` / `ffmpeg` desktop stack — same command names, flags, and JSON output on macOS, Windows, and Linux — handy for headless VNC desktops or full-screen observation where you want to capture or drive the entire screen rather than a single app:

```bash
open-computer-use screenshot --output shot.png   # whole-desktop PNG (base64 to stdout without --output)
open-computer-use cursor-position                # pointer x/y + desktop size (JSON, identical shape)
open-computer-use record start --output rec.mp4 --fps 60 --quality demo --polish
open-computer-use record stop --save-as demo-take   # also writes demo-take.polished.mp4 when --polish
open-computer-use record polish --input demo-take.mp4  # compositor: zoom/lens/blur/cursor/keys (or --engine ffmpeg / --ripples)
open-computer-use record discard                 # stop + delete (Cursor RecordScreen DISCARD parity)
open-computer-use record status
```

`screenshot` and `cursor-position` are read-only. Per-platform notes:

| | Linux | Windows | macOS |
| --- | --- | --- | --- |
| screenshot | pure-Go X11 read, `--display :N` | GDI read of the whole virtual desktop | per-display capture composited over the desktop bounds (Screen Recording permission) |
| cursor-position | X11 `QueryPointer` | `GetCursorPos` + virtual screen | CGEvent pointer in top-left desktop coordinates |
| input backend | `xdotool` (needs PATH) | SendInput | CGEvent to the HID tap (Accessibility permission) |
| input gate | `OPEN_COMPUTER_USE_ALLOW_GLOBAL_POINTER_FALLBACKS=1` | `OPEN_COMPUTER_USE_WINDOWS_ALLOW_FOREGROUND_INPUT=1` | `OPEN_COMPUTER_USE_MACOS_ALLOW_FOREGROUND_INPUT=1` |
| record backend | `ffmpeg x11grab` (needs PATH) | `ffmpeg gdigrab` (needs PATH) | prefers `ffmpeg avfoundation` when on PATH; falls back to `/usr/sbin/screencapture -v` |
| record quality | `--quality demo` (default) / `draft` / `proxy`; `--fps`, `--draw-mouse`, `discard`, `stop --save-as` | same | same flags; ffmpeg path honors them, screencapture fallback ignores encode knobs |
| record polish | clean-room frame compositor aligned with polished-renderer (idle remap → zoom → lens warp → camera motion blur → cursor depress/motion-blur → keystroke chips). `--engine ffmpeg` legacy filter path; optional `--ripples`. Logs display `input` into `<stem>.events.json`. | same | macOS uses ffmpeg+ASS path; accepts `--engine` for CLI parity |

The Linux commands accept `--display` (defaults `$DISPLAY`, then `:0`; a VNC/AnyOS desktop is usually `:1`); Windows and macOS operate on the whole desktop and have no `--display`. Global synthetic input moves the real pointer/keyboard, so each platform gates it behind its own opt-in flag (default off):

```bash
OPEN_COMPUTER_USE_ALLOW_GLOBAL_POINTER_FALLBACKS=1 open-computer-use input click --x 960 --y 600   # Linux
OPEN_COMPUTER_USE_WINDOWS_ALLOW_FOREGROUND_INPUT=1 open-computer-use.exe input type "hello"       # Windows
OPEN_COMPUTER_USE_MACOS_ALLOW_FOREGROUND_INPUT=1 open-computer-use input key ctrl+s                # macOS
```

These commands are CLI-only and never touch the official 14-tool MCP surface.

## Upstream relationship

- **Short link:** [github.com/AntonKhakhalin/ocu](https://github.com/AntonKhakhalin/ocu) — alias repository for this project (README + install pointer only).
- **Upstream project:** [opensymph/open-computer-use](https://github.com/opensymph/open-computer-use) — original architecture and core implementation.
- **Forked work proposed upstream:** [PR #2 — native macOS `launch_app`](https://github.com/opensymph/open-computer-use/pull/2) (branch `feat/macos-launch-app`), [PR #3 — native macOS window management and window-targeted actions](https://github.com/opensymph/open-computer-use/pull/3) (branch `feat/macos-window-management`).
- **Fork-only:** this repository's `feat/public-distribution` branch (branding, fork packaging, installers, release artifacts).
- **License:** MIT, with the upstream copyright notice preserved in [LICENSE](./LICENSE).
- Upstream maintainers have not reviewed or endorsed this fork.

## Documentation

- [Architecture](./docs/ARCHITECTURE.md) — how the three runtimes work
- [Public launch copy](./docs/PUBLIC_LAUNCH.md) — reusable announcement, pitch, and feature bullets
- [Skill references](./skills/open-computer-use) — usage, installation, troubleshooting
- [Security policy](./SECURITY.md) and [third-party notices](./THIRD_PARTY_NOTICES.md)
- [Contributing](./CONTRIBUTING.md)

## License

[MIT](./LICENSE)
