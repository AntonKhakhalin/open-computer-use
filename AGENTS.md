# open-computer-use

This repository is a `Computer Use` project built for agent-collaborative development.

`AGENTS.md` is intentionally short: it only navigates, it does not carry all the rules. The repository's `docs/` is the authoritative source of local knowledge.

If a code or process change makes a doc stale, fix it in the same round of work.

## Read first at the start of each round

- `docs/REPO_COLLAB_GUIDE.md`: repository-level collaboration, commits, doc sync, and testing conventions.
- `docs/ARCHITECTURE.md`: overall repository structure and expected boundaries.
- `docs/design-docs/core-beliefs.md`: agent-first working principles and the design intent of this template.

## Read before finishing code changes

- `docs/QUALITY_SCORE.md`: current quality tiers and main weaknesses.

## Read as needed per task

- `docs/PRODUCT_SENSE.md`: product value, trade-off approach, and prioritization.
- `docs/RELIABILITY.md`: runtime stability, observability, and pre-release requirements.
- `docs/SECURITY.md`: security defaults for auth, data handling, external integrations, and so on.
- `docs/SUPPLY_CHAIN_SECURITY.md`: dependencies, SBOM, artifact provenance, and repository-level supply-chain security defaults.
- `docs/CICD.md`: the repository's CI/CD skeleton and how to wire in a real project later.
- `docs/FRONTEND.md`: if the repository contains a frontend, this records the corresponding conventions.
- `CONTRIBUTING.md`: default checklist before and after PRs, and collaboration requirements.
- `docs/releases/README.md`: how to maintain user-facing release records.
- `docs/releases/RELEASE_GUIDE.md`: if a task involves bumping a version, cutting a tag, or pushing a release, read this release guide first.
- `docs/references/README.md`: external references collected in the repository.

## Working rules

- Prefer small, clear abstractions that are friendly to both the repository and agents.
- By default, reply in the language the user asked the question in; if the user switches language, switch the reply language accordingly.
- If the user's current input is in English, reply directly in English.
- Before pushing, sync the latest remote code, then run `git push`.
- Keep prompts, rules, and architecture constraints versioned in the repository wherever possible.
- For complex multi-round tasks, write a clear plan before starting, and record key decisions in docs.
