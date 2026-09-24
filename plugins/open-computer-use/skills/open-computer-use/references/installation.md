# Open Computer Use Installation

Read this reference when the user asks to install, verify, repair, or explain Open Computer Use setup.

This skill documents the `AntonKhakhalin/open-computer-use` fork (a fork of `opensymph/open-computer-use` with native macOS window management). Repository short link: <https://github.com/AntonKhakhalin/ocu>. The three install steps are independent — do not confuse them:

1. **Runtime install** — puts the `open-computer-use` / `ocu` binary on the PATH. Required for anything to work.
2. **MCP connection** — points the agent at the runtime (`open-computer-use mcp`). Required for the agent to call the tools.
3. **Skill install** — adds this guidance to the agent. Optional; it does **not** install the binary or connect MCP. If the agent can see these instructions but `open-computer-use` is not on the PATH, install the runtime first.

## Platform Requirements

The macOS runtime requires macOS 14.0 or later. Windows and Linux use their own platform runtimes and are not subject to this macOS minimum.

On macOS, verify the system version before attempting to run the CLI:

```sh
sw_vers -productVersion
```

On macOS versions earlier than 14.0, npm installation may succeed but the bundled binary cannot launch. `open-computer-use doctor` and changes to Accessibility or Screen Recording permissions cannot fix this binary incompatibility.

## Install The CLI

Use the fork npm package when it is published:

```sh
npm install -g @antonkhakhalin/open-computer-use
```

Until it is published, install the fork's npm tarball from GitHub Releases (bundled native runtimes for all supported platforms):

```sh
npm install -g https://github.com/AntonKhakhalin/open-computer-use/releases/download/v1.2.1-anton.1/antonkhakhalin-open-computer-use-1.2.1-anton.1.tgz
```

Or build from source and link the binary:

```sh
git clone https://github.com/AntonKhakhalin/open-computer-use.git && cd open-computer-use
./scripts/install-local-runtime.sh
```

Verify:

```sh
open-computer-use -h
ocu -h
open-computer-use call list_apps
```

Supported npm packages expose `ocu` as the short alias. If it is unavailable, use `open-computer-use`.

If the package is already installed and the user asks to update it:

```sh
npm update -g open-computer-use
```

## macOS Permissions

On supported macOS versions, Accessibility and Screen Recording permissions are required before real app state and actions can work.

Run:

```sh
open-computer-use doctor
```

If permissions are missing, the onboarding UI opens. Ask the user to grant the requested permissions in System Settings. Do not try to bypass TCC prompts or silently manipulate protected settings.

Windows and Linux do not use this macOS onboarding step, but they still need a logged-in desktop session.

## Install Into Agent MCP Configs

Or configure all detected agent MCP configs at once (non-interactive, idempotent, never overwrites existing entries):

```sh
ocu setup
ocu setup --dry-run
ocu setup --agents codex,claude
```

Use the built-in installers when the user needs a single specific agent:

```sh
open-computer-use install-codex-mcp
ocu install-codex-mcp
open-computer-use install-claude-mcp
open-computer-use install-gemini-mcp
open-computer-use install-gemini-mcp --scope user
open-computer-use install-opencode-mcp
```

Codex App can also use the plugin installer:

```sh
open-computer-use install-codex-plugin
```

For any other MCP client, add a stdio server manually:

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

## Install This Skill

Install the skill for Codex:

```sh
npx skills add AntonKhakhalin/open-computer-use -g -a codex --skill open-computer-use -y
npx skills ls -g -a codex | rg 'open-computer-use'
```

Install the skill for Claude Code:

```sh
npx skills add AntonKhakhalin/open-computer-use -g -a claude-code --skill open-computer-use -y
```

Update an existing global skill install:

```sh
npx skills update open-computer-use -g -y
npx skills upgrade open-computer-use -g -y
```

## Verification

After CLI and MCP setup:

```sh
open-computer-use call list_apps
ocu call list_apps
open-computer-use call get_app_state --args '{"app":"TextEdit"}'
```

If this fails, read [troubleshooting.md](troubleshooting.md).
