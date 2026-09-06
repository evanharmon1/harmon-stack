## Context

See proposal.md - Why. Today both workflows subscribe to `opened`, `edited`,
`synchronize`, and `reopened`; GitHub supplies title-change details only inside
the edited payload. The readiness gate currently fingerprints the PR title/body,
reviews, top-level comments, inline comments, and review-thread resolution, so
the new authority boundary must be narrow. The vendored `shepherd`, `gauntlet`,
and `track-work` copies are managed by harmon-devkit and are not editable here.

## Goals / Non-Goals

**Goals:**

- Make workflow dispatch depend on authoritative PR changes while retaining
  title-only validation.
- Keep root and template workflows structurally equivalent and testable.
- Define a precise handoff contract for the shared marker and fingerprint.
- Preserve every review, reply, deferred-finding, and non-marker authority.

**Non-Goals:**

- Implementing or vendoring the shared updater in harmon-init.
- Moving deferred-finding ownership or changing readiness policy beyond the
  progress-field exclusion.
- Suppressing validation for head, base, title, changed-file, or other content
  changes.

## Decisions

### Separate event subscription from job eligibility

Keep `pull_request.edited` in the workflow event types, then guard each job with
an expression that accepts non-edited events or an edited event whose
`github.event.changes.title` is present. This is required because GitHub does
not offer a title-only event filter. A title edit therefore reruns validation;
a body-only edit reaches the workflow but starts no guard job. The build
`closing-keywords` job and release-content workflow receive equivalent logic.

An alternative was to remove `edited` entirely, but that would miss title-only
corrections. A body-content hash was rejected because it cannot reliably
distinguish authoritative body edits from machine bookkeeping and would still
couple validation to the body surface.

### Keep the marker contract in harmon-devkit

The shared skills define the stable marker, canonical schema, compare-before-write
protocol, stale-write/concurrency behavior, and the projection used for
readiness fingerprinting. harmon-init consumes that contract and tests the
workflow boundary; it does not edit managed skill copies. A missing or duplicate
marker is an explicit failure, not an invitation to guess ownership.

### Exclude a narrow schema projection from readiness

The fingerprint projection removes only fields declared non-authoritative by the
marker schema. It continues to hash the PR title/body as authoritative content,
all reviews and inline comments, all top-level comments other than the
schema-recognized progress fields, thread resolution, replies, and deferred
findings. This avoids the unsafe alternative of excluding an entire comment or
the entire PR body.

### Test both layers and event shapes

Fixtures model title-only, body-only, combined, opened/synchronized/reopened,
malformed-marker, and concurrent-update cases. Root/template parity tests compare
the rendered behavior rather than assuming filename equality for Jinja files.
The historical PR #1070 replay remains a maintainer verification item, not an
automated claim of live GitHub state.

### Account for upstream run semantics

harmon-devkit #461 is the related latest-run-per-check work in progress, and
harmon-devkit #490 documents that `gh run rerun` replays the stored payload. The
workflow design must therefore make the original event authoritative and avoid
assuming a rerun can reinterpret a body-only event as a title edit.

## Risks / Trade-offs

- [Risk] GitHub payload shape changes or omits `changes.title` unexpectedly →
  [Mitigation] fixture-test the exact event expressions and fail closed in the
  workflow tests; retain the explicit title-edit scenario.
- [Risk] A broad marker exclusion hides a human finding → [Mitigation] require
  schema validation and test mutations to every excluded/non-excluded surface.
- [Risk] Root/template drift reintroduces inconsistent gates → [Mitigation]
  maintain both twins and make parity a definition-of-done test.
- [Risk] Concurrent comment updates lose progress → [Mitigation] updater-side
  compare-and-write with stale-read refusal, owned by harmon-devkit.

## Migration Plan

Implement the workflow trigger and test changes in harmon-init, then land the
harmon-devkit follow-on that provides the marker/updater and fingerprint
projection. During rollout, retain existing PR-body deferred-finding ownership;
do not migrate or delete existing ledgers as part of this change. Rollback is a
revert of the workflow trigger predicates, leaving the shared marker inert.

## Harmon-devkit follow-on

File a separate harmon-devkit issue with this scope:

> Add a marker-owned pull-request progress comment and updater for multi-stage
> workflow bookkeeping. Define a stable ownership marker and schema with
> canonical stage, round, current-result, and next-action sections. Implement
> idempotent compare-before-write updates that preserve human-authored content,
> reject missing or duplicate markers, and refuse stale concurrent writes. Export
> a readiness-fingerprint projection that excludes only schema-validated,
> non-authoritative progress fields in that owned comment; keep review findings,
> replies, deferred findings, and every non-marker comment authoritative. Add
> tests for malformed markers, concurrent updates, idempotence, and all
> authoritative-surface mutations. Do not move deferred-finding ownership.

## Open Questions

None. The remaining implementation choices belong inside the already-bounded
harmon-devkit follow-on and do not change this contract.
