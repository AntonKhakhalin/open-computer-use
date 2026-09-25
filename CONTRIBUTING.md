# Contributing

This repository is set up for agent-first development, but these rules apply equally to humans and agents.

## Basic collaboration

- Start from `AGENTS.md`, then read the docs relevant to the type of task.
- Repository-level knowledge must live in versioned files — not only in chat logs, verbal syncs, or ticket comments.
- If behavior changes, update the code, docs, tests, and release notes together.
- For large, high-risk, or multi-round tasks, write the plan and key decisions down before starting.

## Before opening a pull request

- Run `make check-docs`.
- If the change is user-visible, add a release note.
- Make sure examples, scripts, and documentation match the current implementation.

## Review defaults

- Prefer small PRs with a clear scope.
- State risks, migration impact, and follow-up work explicitly.
- If the context is complex, link the relevant docs directly instead of relying on reviewers to guess.
