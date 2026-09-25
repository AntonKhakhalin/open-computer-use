# Repository Collaboration Conventions

This document defines the default collaboration style for an agent-first repository. Constraints that are strongly tied to a specific tech stack should be split into dedicated neighboring docs — do not turn this file into a grab bag.

## Development principles

- Prefer simple, clear, observable solutions; do not pile up hard-to-maintain complexity.
- Organize the repository so it is readable and executable by agents; important information that exists only in chat logs and people's heads is the same as not existing.
- Keep code, docs, tests, configuration, and release records updated from the same source.
- If an agent keeps failing on the same kind of problem, fix the environment, the scaffolding, and the conventions first — do not treat "try the prompt a few more times" as the main solution.
- Every time you fix a bug, also check whether the tests and docs should be strengthened, so the same kind of problem gets fixed only once.

## Documentation discipline

- `AGENTS.md` is routing only; do not pile a big blob of rules into it.
- `docs/` is the authoritative source of repository-level knowledge.
- Once behavior changes, the corresponding docs must be updated in the same change.
- Files, directories, script entry points, and doc links inside the repository always use relative paths; never write machine-specific absolute paths.
- Rather than keep piling content into a big doc, prefer adding a small doc with clear boundaries.

## Git and review

- Keep commits scoped and accurately described.
- Sync the latest remote code before `git push`, so you do not push a stale branch state.
- Before committing or opening a PR, confirm docs, examples, and scripts already reflect the final state.
- For complex or high-risk changes, write the plan and key decisions into docs first, then start.
- In reviews, reference files in the repository; do not rely on context that only a few people know.

## Testing and verification

- Every substantive code change should leave the verification capability slightly stronger than before.
- Prefer crystallizing it into commands and scripts that can run directly in the repository.
- If the project includes a UI, it must be able to start and be verified independently locally.
- If the project depends on logs, metrics, or traces, provide local or CI-accessible paths to them where possible.
- Even if the project has not yet wired in a real build pipeline, repository-level CI should already be running.

## CI/CD and delivery

- CI should at least guard repository readability and basic security; do not wait until the project grows to add it.
- The CD skeleton should first produce explicit artifacts and provenance, rather than assuming deployment targets too early.
- When a real tech stack is wired in later, extend the existing pipelines first; do not set up a separate ad-hoc script that bypasses them.

## Configuration hygiene

- Keep example configuration as consistent as possible with the actual defaults.
- Document every environment variable and external dependency needed to start.
- Do not let critical initialization steps live only in a corner of the README; script them wherever possible.
