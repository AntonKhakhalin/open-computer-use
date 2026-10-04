# macOS single-process default (app-agent proxy → opt-in)

## Context

Before 2026-10-03, every macOS automation command (`mcp`, `doctor`, `call`, `snapshot`, `list-apps`, display-level commands) was forwarded by the CLI/MCP shim to a hidden background app-agent (`__open-computer-use-app-agent`) launched via LaunchServices, over a unix socket in the user temp directory. The stated purpose: make Accessibility / Screen Recording TCC grants land on the `Open Computer Use.app` bundle identity instead of the terminal / Node launcher.

This two-process design produced a recurring failure class observed in production use:

- The background agent is long-lived and process-lifetime-decoupled from the MCP host; stale agents from previous sessions (observed: 9 days old) keep holding the socket, and when a fresh shim's handshake against them fails the shim exits with `Open Computer Use.app agent closed the connection` and the whole MCP server dies with it.
- Agent/bundle copy skew (dev vs dist vs plugin-cached copies), socket-file staleness, and dual permission-state reconciliation all add failure surface.
- Windows and Linux runtimes already run every tool in a single binary with no helper process, with no comparable failure mode.

## Decision

Automation runs **in-process by default** on macOS. The legacy app-agent proxy is retained only behind the explicit `OPEN_COMPUTER_USE_AGENT_PROXY=1` opt-in for one release, then removed.

Key facts that make this safe:

1. TCC attributes Accessibility / Screen Recording to the *calling process's code identity*. Running `Open Computer Use.app/Contents/MacOS/OpenComputerUse` directly means the calling process is the bundle executable itself — the grant resolves to the same `Open Computer Use.app` bundle identity as before. This was verified live on the dev machine: the in-bundle binary reported `accessibility=granted, screenRecording=granted` from its own process and served a real Finder AX snapshot with zero agent processes running.
2. Every shipped launcher (npm launcher, `plugins/open-computer-use/scripts/launch-open-computer-use.sh`, terminal PATH installs) already execs the in-bundle binary, so the identity guarantee carries over to production configurations with no launcher changes.
3. The `.app` **bundle** is still required (stable bundle id + signature for TCC, and the LSUIElement onboarding UI); what is removed is the second *process*.

## Compatibility surface

- `OPEN_COMPUTER_USE_AGENT_PROXY=1` re-enables the full legacy proxy path (agent launch, socket transport, env forwarding) for one release.
- The deprecated `OPEN_COMPUTER_USE_DISABLE_APP_AGENT_PROXY=1` keeps working as a force-off guard (wins over the opt-in), so existing setups need no change.
- The pure decision function `shouldUseMacOSAppAgentProxy` flipped from `proxyDisabled` to `proxyEnabled`; unit tests pin "in-process unless explicitly opted in" for automation and display commands.
- In-process `mcp` prints one startup warning to **stderr** (stdout stays pure JSON-RPC; no TCC prompt is ever triggered from the MCP server) when Accessibility / Screen Recording are missing, pointing at `open-computer-use doctor`.

## Removal plan

After one release with the opt-in in place: delete the proxy branch, the socket transport, the agent entry point, and the env-forwarding layer from `apps/OpenComputerUse/Sources/OpenComputerUse/MacOSAppAgentProxy.swift`, and simplify `PermissionDiagnostics`' dual CLI/agent merge.

## Verification

- Unit: proxy-decision tests in `OpenComputerUseKitTests.swift` and `DesktopCommandTests.swift` (default-off + opt-in matrix).
- Runtime (macOS dev machine, fresh Dev bundle): `initialize` over stdio answered in-process, `doctor` correct in-process, live Finder `snapshot` with zero agent processes, no socket created.
- E2E: `./scripts/run-permission-onboarding-e2e.sh` now pins the in-process path by default (`OPEN_COMPUTER_USE_E2E_DISABLE_APP_AGENT_PROXY=0` exercises the legacy proxy opt-in).
