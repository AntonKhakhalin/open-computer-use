# CI/CD Notes

This template ships with a CI/CD skeleton that does not depend on a specific language stack.

## Current release entry points

- `scripts/release-package.sh`: builds the universal `Open Computer Use.app`, cross-compiles the Linux / Windows runtimes, and stages the three existing root/alias npm packages; each package embeds the macOS app, Linux binaries, and Windows exes, exposes npm bin entry points such as `open-computer-use` / `ocu`, and produces `dist/release/npm/*.tgz` and `dist/release/release-manifest.json`. CI currently continues to use ad-hoc signing explicitly, staying consistent with the earlier release chain; local debug/dev builds may use the development machine's own signing identity.
- `scripts/build-open-computer-use-linux.sh`: builds the experimental Linux `open-computer-use` binary locally, supporting `arm64` / `amd64`; the release package embeds these two artifacts into the existing npm package's `dist/linux/`.
- `scripts/build-open-computer-use-windows.sh`: builds the experimental Windows `open-computer-use.exe` locally, supporting `arm64` / `amd64`; the release package embeds these two artifacts into the existing npm package's `dist/windows/`.
- `.github/workflows/release.yml`: supports automatic release on pushing a semver tag, and manual triggering; on a tag push it runs the npm release packaging logic and publishes the npm package. `Open Computer Use` npm artifacts default to ad-hoc signing; if the `OPEN_COMPUTER_USE_CODESIGN_*` secrets are configured, the `Developer ID Application` certificate is imported first, then the release `.app` is signed uniformly with the same identity.

## macOS CI (`ci-macos.yml`)

- `.github/workflows/ci-macos.yml`: triggered on push to `main` and all PRs, running on **`macos-26`** (versioned GitHub-hosted macOS runner, the same label as `release.yml` — stable, with Xcode + Swift toolchain preinstalled). All actions are pinned to commit SHAs.
- `scripts/ci-macos.sh` runs in order:
  1. Script hygiene checks (every `scripts/*.sh` passes `bash -n`, every `scripts/*.mjs` passes `node --check`);
  2. `swift build` — compiles the full Swift package (Kit + app + fixture);
  3. `swift test` — unit tests: all **pure tests** run; **live tests** that depend on a real GUI / permissions are gated by `OCU_RUN_LIVE_TESTS` (default off) and skipped by default in CI, so CI never launches a GUI app or gets stuck on a TCC authorization prompt;
  4. `scripts/build-open-computer-use-app.sh debug` — validates the macOS app bundle packaging chain (Info.plist, iconset, ad-hoc codesign path);
  5. `go vet` + `go build` — release tooling (platform-agnostic).

**Tests that cannot run in CI (explicitly recorded as required by the task):**

- Live fixture tests (the "Live fixture tests" / "Window identity" sections of `WindowManagementTests`, plus the live tests for minimized-window listing): they need a real GUI session, and most assertions need the test process granted Accessibility; the CI runner has no TCC grant, and the prompt would hang the build. Run locally: `OCU_RUN_LIVE_TESTS=1 swift test`.
- SkyClick live tests: additionally depend on the SkyLight SPI and a running Chrome instance (`OPEN_COMPUTER_USE_RUN_SKY_CLICK_LIVE_TEST=1`).
- `launch_app` live tests: launch Calculator (`OCU_RUN_LIVE_TESTS=1`).

## Design principles

The goal of this default pipeline is to set up the delivery chain before the project truly takes shape, rather than pretending to already know how a future project will be built and deployed.

Once the new project's tech stack is settled, keep extending on this real build chain in `scripts/release-package.sh` rather than starting a parallel process.

All GitHub Actions are already pinned to commit SHAs. Keep this constraint when upgrading actions later.

## Recommended wiring order

1. Keep `ci.yml` as the repository's basic gate.
2. Keep stacking the project's own verification commands in `scripts/ci.sh`.
3. Continue extending release artifacts on the existing real build in `scripts/release-package.sh`.
4. Add specific deployment jobs only after the tech stack and environment stabilize.
5. Even if the delivery method changes, keep supply chain capabilities such as SBOM and provenance.

## Default release artifacts

The current release pipeline produces:

- `dist/release/release-manifest.json`
- `dist/release/npm/khakhalin-open-computer-use-<version>.tgz` (fork package name `@khakhalin/open-computer-use`)
- The npm release artifact uploaded in GitHub Actions

In other words, even though the project has not yet entered a more complex deployment stage, the repository now already has both a real, reusable npm artifact packaging chain and a git-tag-driven macOS app DMG delivery chain.
