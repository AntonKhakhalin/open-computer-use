# Supply Chain Security

This document defines the supply chain security practices the template adopts by default.

## Default controls

- Review dependency changes in pull requests.
- Scan dependency declarations and lockfiles in the repository for vulnerabilities with OSV.
- Generate an SBOM for release artifacts.
- Generate build provenance attestation for release artifacts.
- Use OpenSSF Scorecard for repository-level security posture analysis.
- Pin all GitHub Actions to immutable commit SHAs, not drifting version tags.

## Current mapping

- `actions/dependency-review-action`: blocks PRs from introducing high-risk dependency changes.
- `google/osv-scanner-action`: scans known vulnerabilities based on the repository's dependency files.
- `anchore/sbom-action`: generates an SPDX-format SBOM.
- `actions/attest-build-provenance`: generates signed provenance for release artifacts.
- `ossf/scorecard-action`: analyzes repository-level security signals such as workflow permissions and branch protection.
- `scripts/check-action-pinning.sh`: fails CI directly if a workflow uses a floating tag instead of a SHA.

## Limitations and preconditions

- Dependency Review is directly usable on public repos; private repos usually need GitHub Advanced Security or the corresponding code security capability.
- OSV and SBOM effectiveness depend on identifiable dependency manifests or lockfiles existing in the repository.
- Provenance is only truly meaningful when `scripts/release-package.sh` actually represents the project's build output.
- Scorecard results also depend on the repository's real configuration, such as whether branch protection and workflow permission narrowing are actually enabled.

## Suggested follow-ups after the project lands

- Lock and commit the real dependency lockfile of the project.
- Make the build process as reproducible and verifiable as possible.
- Where conditions allow, add provenance verification to the deployment pipeline.
- Keep pushing attestation verification down into the deployment platform or admission layer.
