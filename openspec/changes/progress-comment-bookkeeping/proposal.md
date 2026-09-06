## Why

Progress bookkeeping currently lives in the pull-request body, while validation
workflows subscribe to every `pull_request.edited` event. A ledger correction can
therefore rerun release-content and closing-keyword validation on an unchanged
head, invalidating otherwise-current readiness evidence; PR #1070 demonstrated
the failure mode on 2026-08-26, with similar reruns observed in issues #1165, #1166,
the issues #1160 and #1172 on 2026-09-05. The repository needs a durable,
machine-owned
progress surface whose updates are distinguishable from authoritative PR edits.

## What Changes

- Define a marker-owned top-level progress comment with a stable ownership
  marker and canonical stage, round, current-result, and next-action sections.
- Specify that the progress updater is idempotent and compare-before-write,
  preserves human-authored content, rejects missing or duplicate markers, and
  handles concurrent updates safely.
- Narrow the release-content and closing-keyword workflow triggers to opened,
  synchronized, reopened, and title-edited pull requests; body-only edits do
  not start those guard jobs, while title-only edits still do.
- Add root/template workflow parity tests for title-only, body-only, combined,
  synchronized, malformed-marker, and concurrent-update fixtures.
- Define readiness fingerprinting so only schema-validated, non-authoritative
  progress fields in the owned marker are excluded; reviews, replies, deferred
  findings, and all other comments remain authoritative.
- Record the final human replay of PR #1070 as a release verification criterion.

The marker format, updater, and readiness-fingerprint implementation belong to
the vendored shared skills in harmon-devkit and are deliberately not edited in
this repository. This change specifies that follow-on explicitly so the two
repositories have a testable handoff.

## Non-goals

- Skipping validation after a title, head, base, or changed-file update.
- Excluding review findings, review replies, deferred findings, or any human
  or non-marker comment from readiness evidence.
- Moving deferred-finding ownership or migrating existing deferred ledgers.
- Editing the vendored `shepherd`, `gauntlet`, or `track-work` skills here.
- Implementing the harmon-devkit updater or fingerprinting mechanism in
  harmon-init.

## Capabilities

### New Capabilities

- `pull-request-progress-bookkeeping`: marker-owned progress metadata,
  non-retriggering guard events, and readiness-authority boundaries.

### Modified Capabilities

- None.

## Impact

This affects `.github/workflows/release-content-guard.yml`, the corresponding
Copier template workflow, `.github/workflows/build.yml`'s `closing-keywords`
job, and their workflow tests. It also establishes an interface consumed by
the harmon-devkit `shepherd`, `gauntlet`, and `track-work` skills. Related
upstream work is harmon-devkit issue #461 (latest-run-per-check, in progress)
and issue #490 (`gh run rerun` replays the stored payload); those constraints inform the
event and run-correlation design but are not implemented by this proposal.
