# Release Guide

This document governs the future patch / minor release process in this repository, with the goal of avoiding version-source inconsistencies such as "the git tag has already been published, but the npm staging artifact version is still the old value".

## When it is required reading

- Read this document first if the task contains any of the following actions:
  - bumping the version
  - cutting a release tag
  - pushing a release tag
  - investigating why a GitHub Actions release failed
  - re-publishing a failed version

## When to publish a public release

- For day-to-day fixes, alignment verification against the official `computer-use`, and local regressions, the default is to only build the local app / binary and point the MCP client at the local build artifacts.
- Do not use a patch release as a routine verification means; only enter the release checklist below when the user explicitly asks for a public release, or when a fix has reached a stable state that needs to be delivered to external users.
- If the only goal is to let Codex use the latest local implementation, prefer updating the `open-computer-use` MCP server command in the local `~/.codex/config.toml` to point at the repository's local build artifacts, instead of bumping the version, cutting a tag, and pushing a release.

## Current release entry points

- Local staging / building the tgz: `./scripts/release-package.sh`
- Local staging npm package directory: `node ./scripts/npm/build-packages.mjs`
- Local publish: `node ./scripts/npm/publish-packages.mjs`
- CI workflow: `.github/workflows/release.yml`
- User-visible release notes: `docs/releases/feature-release-notes.md`
- GitHub Release body: `docs/releases/github/vX.Y.Z.md`
- GitHub Release page: the workflow creates or updates it using the reviewed English notes file; it does not auto-generate the body directly from PR titles.

## Current version sources

This repository currently has two kinds of release version sources:

- npm staging package version: the `version` in `plugins/open-computer-use/.codex-plugin/plugin.json` is authoritative.
- GitHub Release body: `docs/releases/github/<tag>.md` is authoritative; the file name must exactly match the actual tag.

In other words:

- Changing only the git tag without changing this manifest will not produce a new npm version.
- `scripts/npm/build-packages.mjs` reads the version from this manifest and then generates the three root/alias staging packages; each package embeds macOS, Linux, and Windows runtime artifacts.
- So before a release, this manifest must first be bumped to the target version.
- If the English notes for the target tag are missing, or the notes are inconsistent with the manifest/tag, the `release-metadata` job will fail before the npm job starts.

## Release Checklist

### 1. Unify the version numbers first

Check and sync at least these locations:

- `plugins/open-computer-use/.codex-plugin/plugin.json`
- `packages/OpenComputerUseKit/Sources/OpenComputerUseKit/OpenComputerUseVersion.swift`
- `apps/OpenComputerUseSmokeSuite/Sources/OpenComputerUseSmokeSuite/main.swift`
- `packages/OpenComputerUseKit/Tests/OpenComputerUseKitTests/OpenComputerUseKitTests.swift`
- `apps/OpenComputerUseLinux/main.go`
- `apps/OpenComputerUseWindows/main.go`
- `docs/releases/feature-release-notes.md`
- `docs/releases/github/vX.Y.Z.md`

If this release round also changed other externally exposed version strings, align those as well; do not only change half of them.

### 2. Prepare and verify the GitHub Release notes

Create the file for the target tag from `docs/releases/github/TEMPLATE.md`, and run:

```bash
node ./scripts/validate-github-release-notes.mjs --tag v0.1.14
```

Validation requirements:

- The tag must be `vX.Y.Z` or `X.Y.Z` and match the plugin manifest version.
- The body must start with `## What's Changed` and contain 1-3 user-visible English changes.
- The body must not contain CJK characters.
- The body must contain exactly one `Full Changelog` link pointing to the current tag.

If any requirement is not met, do not cut the tag. After the tag push, the `release-metadata` job runs the same validation again and blocks the npm job from starting on failure.

### 3. Verify locally that the version sources took effect

Run at least these three steps:

```bash
node ./scripts/validate-github-release-notes.mjs --tag v0.1.14
swift test
node ./scripts/npm/build-packages.mjs --out-dir dist/release/npm-staging-check
```

Then check the staging package versions directly:

```bash
node -p "require('./dist/release/npm-staging-check/open-computer-use/package.json').version"
test -x "dist/release/npm-staging-check/open-computer-use/dist/linux/arm64/open-computer-use"
test -f "dist/release/npm-staging-check/open-computer-use/dist/windows/arm64/open-computer-use.exe"
test -x "dist/release/npm-staging-check/open-computer-use/bin/ocu"
node -e "const bin=require('./dist/release/npm-staging-check/open-computer-use/package.json').bin; if (bin.ocu !== 'bin/ocu') process.exit(1)"
node -e "if (require('./dist/release/npm-staging-check/open-computer-use/package.json').optionalDependencies) process.exit(1)"
```

If what is printed here is not the target version, do not cut the tag.

If the current checkout already has a `dist/Open Computer Use.app` matching the target version, you can temporarily add `--skip-build` to skip the redundant build; but do not add this flag by default in a clean checkout, otherwise the staging script will fail because `dist/Open Computer Use.app` is missing.

### 4. Commit the version bump

- Commit the release version bump as a separate commit.
- The commit message must make it obvious that this is release wrap-up, not an ordinary feature commit.

### 5. Cut the tag and push

The current convention uses `vX.Y.Z`:

```bash
git tag -a v0.1.14 -m "v0.1.14"
git push origin main
git push origin v0.1.14
```

After the tag push, `.github/workflows/release.yml` packages the npm artifacts and attaches them to an auto-created GitHub Release; npm publishing only runs automatically on tag push when the `NPM_TOKEN` secret is configured, and can also be triggered manually via workflow_dispatch (check publish_to_npm; OIDC trusted publishing is supported).

### 6. Check the GitHub Release notes

After every tag push, check the GitHub Release page; do not just confirm the workflow is green:

```bash
gh release view v0.1.14 --json body,url
```

The workflow uses `docs/releases/github/<tag>.md` to create a new Release; if the Release already exists, it updates the body with the same file. GitHub's auto-generated notes are no longer the body source, so using Chinese in PR titles will not change the language of the public Release.

Minimum requirements:

- The release body must match the target notes file in the repository.
- `What's Changed` must list the 1-3 user-visible English changes for this release.
- Keep the `Full Changelog` link.

## How to investigate a failed release

### 1. Look at the latest run first

```bash
gh run list -R AntonKhakhalin/open-computer-use --limit 10
gh run view -R AntonKhakhalin/open-computer-use <run-id> --log-failed
```

### 2. Which kind of error to focus on

- `release-metadata` failure
  - First run `node ./scripts/validate-github-release-notes.mjs --tag <tag>` locally.
  - Check that `docs/releases/github/<tag>.md` exists, that the manifest version matches, that the body does not contain CJK, and that Full Changelog points to the current tag.
- `npm error 403 ... You cannot publish over the previously published versions`
  - This is usually not a token permission problem, but rather the staging package version still being the old version.
  - First re-check the `version` in `plugin.json`, then the `package.json` actually produced by the staging package.
- `npm error 404 Not Found - PUT https://registry.npmjs.org/<package>`
  - First confirm whether the old versions of the target package are still visible on the registry: `npm view <package> versions --json`.
  - The current publish script skips a package of the same version that already exists before publishing, and briefly retries on publish failure; if GitHub Actions OIDC is available, it prefers trusted publishing with `--provenance` and falls back to `NODE_AUTH_TOKEN`. If some package was already partially published successfully before re-releasing the tag, re-running the same release will not be interrupted by that package already existing.
- `npm error need auth ... You need to authorize this machine using npm adduser`
  - If the log shows that `GitHub Actions OIDC trusted publishing` was selected, first check the npm CLI version in CI; trusted publishing requires npm `11.5.1+`, and the npm package job in the current release workflow uses Node `24` and explicitly checks the npm version.
  - If the npm CLI version meets the requirement and this error still occurs, it means the npmjs.com package side has not yet configured the current GitHub repo / workflow file as a trusted publisher.
- Build-stage failure
  - First look at `Build npm release artifacts` or Swift compilation errors.
- publish authentication failure
  - Then look at `.github/workflows/release.yml`, `scripts/npm/publish-packages.mjs`, and the npm trusted publishing / token fallback configuration.

## Currently known limitations

- The npm release artifacts for `Open Computer Use` still fall back to ad-hoc signing when the org-level `APPLE_CERTIFICATE` / `APPLE_CERTIFICATE_PASSWORD` secrets are not configured; once configured, the `Developer ID Application` certificate is imported first and everything is signed uniformly under that identity; missing secrets do not block the entire release.
- The `open-computer-use` npm root package embeds six `os-arch` native artifacts, so the package size is larger than a macOS-only version; before release, confirm the staging package contains `dist/Open Computer Use.app`, `dist/linux/`, and `dist/windows/`, and confirm the launcher does not declare `optionalDependencies`.

## If a tag was cut incorrectly

If the remote tag already points to the wrong commit, delete the tag first, then fix the version source, then re-cut it.

Delete the local tag:

```bash
git tag -d v0.1.14
```

Delete the remote tag:

```bash
git push origin :refs/tags/v0.1.14
```

After fixing, re-create and push the tag with the same name.

## Documentation sync requirements

For every release, sync at least these categories of documentation:

- `docs/releases/feature-release-notes.md`
- `docs/releases/github/vX.Y.Z.md`
- If the release process itself changed, this `docs/releases/RELEASE_GUIDE.md`

If a release exposes a new process pitfall, do not just remember it in chat; add it directly to this document.
