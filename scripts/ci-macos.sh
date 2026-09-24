#!/usr/bin/env bash

# macOS CI (see .github/workflows/ci-macos.yml).
#
# What runs here and why:
#   - swift build        compile the full Swift package (Kit + app + fixture)
#   - swift test         unit tests: every pure test runs; live/permission-
#                        dependent tests are gated behind OCU_RUN_LIVE_TESTS
#                        (default off) so CI never launches GUI apps and
#                        never risks a TCC prompt hang
#   - app bundle build   the release packaging script with ad-hoc signing
#                        (validates Info.plist, iconset, codesign path)
#   - releasetool        go vet + build (platform-independent release tooling)
#
# Tests that cannot run in CI (documented per task requirements):
#   - live fixture tests (WindowManagementTests "Live fixture tests" and
#     "Window identity" sections): need a GUI session plus, for most
#     assertions, Accessibility granted to the test process. CI runners do
#     not have TCC grants; prompting would hang the build. Run locally with
#     OCU_RUN_LIVE_TESTS=1 swift test.
#   - SkyClick live tests: additionally need the SkyLight SPI and a running
#     Chrome instance (OPEN_COMPUTER_USE_RUN_SKY_CLICK_LIVE_TEST=1).
#   - launch_app live test: launches Calculator (OCU_RUN_LIVE_TESTS=1).

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Script syntax hygiene (same checks as scripts/ci.sh).
while IFS= read -r file; do
  bash -n "$file"
done < <(find "${repo_root}/scripts" -type f -name '*.sh' | sort)

while IFS= read -r file; do
  node --check "$file"
done < <(find "${repo_root}/scripts" -type f -name '*.mjs' | sort)

# Swift package: build everything, then run the unit suite.
swift build
swift test

# macOS app bundle packaging check (debug build, ad-hoc signing).
"${repo_root}/scripts/build-open-computer-use-app.sh" debug

# Release tooling.
if command -v go >/dev/null 2>&1; then
  (
    cd "${repo_root}/scripts/releasetool"
    go vet ./...
    go build ./...
  )
fi

echo "macOS CI 检查通过"
