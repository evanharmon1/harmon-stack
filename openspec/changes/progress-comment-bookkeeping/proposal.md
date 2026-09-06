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
- Keep release-content and closing-keyword validation authoritative for opened,
  synchronized, reopened, title-edited, and body-edited pull requests; move
  marker bookkeeping to the comment event surface so progress-only edits do not
  enqueue those guard jobs.
- Add root/template workflow parity tests for title-only, body-only, combined,
  comment-only, base-only `pull_request.edited`, synchronized, and reopened
  fixtures. Root/template tests own workflow-event fixtures; harmon-devkit owns
  malformed-marker, lookalike, timestamp, generation, and concurrent-updater
  fixtures.
- Define readiness fingerprinting so only schema-validated, non-authoritative
  progress fields in the owned marker are excluded; reviews, replies, deferred
  findings, and all other comments remain authoritative.
- Require a maintainer replay on a live draft with a clean unchanged head,
  readiness fingerprints before and after the marker update, and no
  progress-only guard or readiness wait; PR #1070 remains historical evidence.
- Require the harmon-devkit release and vendored fingerprint projection before
  accepting the harmon-init workflow change; existing workflow behavior is a
  regression assertion, not a no-op rewrite prescription.
- Exclude Foreman-managed PRs from the v1 capability until a compatible pinned
  Foreman release provides its own marker/readiness tests; a harmon-devkit sync
  cannot update the pinned `ponderousdev/foreman` binary.

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
- Enabling the capability for Foreman-managed PRs before a compatible Foreman
  release and pin bump exist.

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
the harmon-devkit `shepherd`, `gauntlet`, `track-work`, and `standardize-repo`
skills. The standalone readiness-fingerprint fallback in
`.claude/skills/standardize-repo/SKILL.md` (used when `shepherd` is absent and
currently hashing every top-level comment body and `updated_at`) is included in
the harmon-devkit follow-on scope with tests. Related
upstream work is harmon-devkit issue #461 (latest-run-per-check, in progress)
and issue #490 (`gh run rerun` replays the stored payload); those constraints inform the
event and run-correlation design but are not implemented by this proposal.

Marker rendering must emit no activation substring at all: next-action values
are structural data rendered as neutral prose, with a deny-list covering
`@codex review`, `@claude`, and every `@`-mention. This is required because the
Codex trigger contract and `.github/workflows/claude-review.yml` respond to
activation phrases in created issue comments. The follow-on also requires
head-SHA conditional transitions, post-write stale re-evaluation, and fully
paginated marker discovery.

## Open design questions

These questions remain maintainer-owned design questions; they are not resolved
by this proposal and must be settled before implementation:

- **Q1. Untrusted lookalike markers.** Reconcile the fail-closed update rule in
  the specification (approximately lines 28–30) with the non-blocking discovery
  rule in the specification (approximately lines 14–16) and design. Decide
  which rule wins and what the updater does when an untrusted lookalike exists.
- **Q2. Atomic comment updates.** GitHub's issue-comment API has no ETag,
  `If-Match`, or lock primitive in the current contract. Decide the concurrency
  mechanism—such as single-writer by construction, generation with read-back
  verification, or a GitHub App check-run lock—before implementation.
- **Q3. Deferred-findings ticks.** Ticking a deferred finding edits the PR body
  and retriggers its guards. Decide whether dispositions move to an
  authoritative field in the owned comment or whether this capability and the
  PR #1070 replay criterion are narrowed before implementation.
- **Q4. First-marker bootstrap.** Creating the first marker changes the
  fingerprint. Decide whether bootstrap occurs before evidence capture, applies
  only to new PRs, or has explicit first-creation projection semantics.
- **Q5. Rollback state handoff.** Define the quiescence or checkpoint that
  prevents rollback from regressing the visible ledger to a stale body state.
