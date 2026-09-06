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
  title-only and body-only validation; isolate marker comment bookkeeping on
  the comment event surface.
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

Keep `pull_request.edited` in the workflow event types and let both title and
body edits run the body-consuming guards. This is required because release
content and closing-keyword checks consume authoritative PR-body content. A
marker update is a separate `issue_comment` event and must not enqueue those
jobs. The aggregate build `verify` job must retain its successful
`closing-keywords` dependency for all authoritative edit paths.

An alternative was to remove `edited` entirely, but that would miss title- and
body corrections. A body-content hash was rejected because the body remains
authoritative and comment bookkeeping is already distinguishable by event
surface.

### Keep the marker contract in harmon-devkit

The shared skills define the stable marker, canonical schema, trusted publisher
identity, authenticated first-marker bootstrap, compare-before-write protocol,
lookalike handling, monotonic generation and expected-state invariants, per-PR
serialization, atomic conditional writes, stale-write behavior, and the
projection used for readiness fingerprinting. The projection normalizes away
all timestamps for a validated trusted marker. harmon-init consumes that
contract and tests the workflow boundary; it does not edit managed skill copies.
A missing or duplicate trusted marker is an explicit failure, except for the
authenticated first-marker creation transition. Untrusted lookalikes remain
authoritative content but do not participate in target discovery.

### Exclude a narrow schema projection from readiness

The fingerprint projection removes only fields declared non-authoritative by the
marker schema and normalizes away all timestamps for a validated trusted marker.
It continues to hash the PR title/body as authoritative content,
all reviews and inline comments, all top-level comments other than the
schema-recognized progress fields, thread resolution, replies, and deferred
findings. This avoids the unsafe alternative of excluding an entire comment or
the entire PR body.

### Test both layers and event shapes

Fixtures model title-only, body-only, combined, comment-only,
opened/synchronized/reopened events at the harmon-init workflow boundary.
Harmon-devkit owns malformed-marker, lookalike, timestamp, generation, and
concurrent-update fixtures. Root/template parity tests compare the rendered
behavior rather than assuming filename equality for Jinja files.
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
- [Risk] Concurrent or forged comment updates lose progress or impersonate the
  publisher → [Mitigation] authenticate the publisher identity, serialize by
  pull request, and use an atomic conditional write with stale-read refusal,
  owned by harmon-devkit.

## Migration Plan

Land and release the harmon-devkit marker/updater and fingerprint projection,
sync that released version into the consuming skills, and only then accept the
harmon-init workflow/test changes. The release and vendored sync are rollout
prerequisites: until they are present, the existing whole-comment readiness
fingerprint would still invalidate progress updates, so the PR #1070 replay
cannot pass. During rollout, retain existing PR-body deferred-finding ownership;
do not migrate or delete existing ledgers as part of this change. Rollback is a
restore of the previous harmon-devkit skills pin followed by its normal sync,
then a revert of the workflow/test changes and disabling the marker publisher,
leaving the previous PR-body writer and validation authoritative.

## Harmon-devkit follow-on

File a separate harmon-devkit issue with this scope:

> Add a marker-owned pull-request progress comment and updater for multi-stage
> workflow bookkeeping. Define a stable ownership marker and schema with
> canonical stage, round, current-result, and next-action sections. Authenticate
> the trusted publisher identity, safely bootstrap exactly one first marker, and
> implement idempotent compare-before-write updates that preserve human-authored
> content. Ignore untrusted marker lookalikes for discovery while retaining them
> as authoritative content. Serialize updates per pull request, carry a
> monotonic generation and expected prior state, and use atomic conditional
> writes; reject duplicate trusted markers and refuse stale concurrent writes.
> Normalize away all timestamps for a validated trusted marker in the readiness
> projection. Export
> a readiness-fingerprint projection that excludes only schema-validated,
> non-authoritative progress fields in that owned comment; keep review findings,
> replies, deferred findings, and every non-marker comment authoritative. Add
> tests for malformed markers, concurrent updates, idempotence, and all
> authoritative-surface mutations. Do not move deferred-finding ownership.

## Open Questions

The two round-4 P1s are intentionally carried as maintainer-owned design
questions rather than resolved here:

- **Q1. Untrusted lookalike markers:** reconcile the fail-closed update rule with
  non-blocking discovery and decide how an updater behaves when a lookalike
  exists.
- **Q2. Atomic comment updates:** choose a concurrency mechanism that the
  GitHub issue-comment API can support before implementation; the current
  alternatives are single-writer by construction, generation with read-back
  verification, or a GitHub App check-run lock.

The remaining implementation choices belong inside the harmon-devkit follow-on
after Q1 and Q2 are settled.
