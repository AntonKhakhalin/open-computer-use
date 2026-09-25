# Release Notes Guide

`feature-release-notes.md` records user-visible new features, experience improvements, and important fixes.

`github/vX.Y.Z.md` is the reviewed English body for GitHub Releases. For every public release, create the target tag's file from `github/TEMPLATE.md`, and run the release notes validation before cutting the tag.

If the task is "prepare a release / bump a version / cut a tag / investigate a failed release", read `RELEASE_GUIDE.md` first.

## Rules

- Group by month, using the format `## YYYY-MM`
- Within the same month, insert the newest content at the top
- Write user value first, then the change summary
- Do not dump pure internal refactors and implementation noise in here
- GitHub Release bodies default to reviewed English; do not auto-generate them from PR titles

## Suggested columns

- Date
- Feature area
- User value
- Change summary
