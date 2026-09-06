## Purpose

Provides a stable, machine-owned surface for multi-stage pull-request progress
so bookkeeping changes do not retrigger validation or weaken readiness evidence.

## ADDED Requirements

### Requirement: Canonical marker-owned progress comment

The progress record MUST be one top-level comment containing a stable ownership
marker and canonical sections for stage, round, current result, and next action.
The marker MUST be unique to the pull request, and the comment's immutable
GitHub author/App identity MUST match the configured trusted publisher. Marker
text and schema validation alone MUST NOT establish ownership. Lookalike marker
text from other authors MUST remain ordinary authoritative comment content and
MUST NOT block discovery of the trusted comment.

#### Scenario: `test_progress_comment_has_canonical_sections`
- **Given** a pull request passes through two or more workflow stages
- **When** progress is published
- **Then** exactly one marker-owned top-level comment contains the stable marker and all four canonical sections

### Requirement: Safe idempotent progress updates

For initialization, the authenticated trusted publisher MUST use a distinct
create operation when the pull request has zero markers: it may create exactly
one marker after rechecking for a competing marker, and a concurrent marker
causes the operation to fail closed. If a marker exists but is untrusted, or if
more than one marker exists, every update operation MUST fail closed; it MUST
not treat an untrusted marker as an initialization target.

The updater MUST compare the canonical rendered content before writing, MUST
leave unchanged content untouched, MUST preserve content outside the owned
sections, and MUST refuse to proceed when the ownership marker is missing or
duplicated. An authenticated publisher MUST be able to create the first marker
when none exists, using an atomic create-or-recheck operation that refuses if a
competing marker appears. Concurrent updates MUST not silently overwrite a
newer valid progress record: the updater MUST serialize updates per pull
request and use an atomic conditional write (for example, an ETag/If-Match
precondition), retrying only after a fresh read and refusing on a stale
precondition.

#### Scenario: `test_progress_update_is_compare_before_write_and_preserves_humans`
- **Given** an owned comment contains human-authored content and the requested canonical progress is unchanged
- **When** the updater runs
- **Then** it performs no write and leaves the human-authored content intact

#### Scenario: `test_progress_update_bootstraps_one_authenticated_marker`
- **Given** an authenticated trusted publisher invokes the distinct
  initialization operation and finds zero markers
- **When** it rechecks and no competing marker appears
- **Then** it creates exactly one marker-owned comment and subsequent updates target it

#### Scenario: `test_progress_update_rejects_untrusted_or_duplicate_markers`
- **Given** a pull request has a marker authored by an untrusted identity, or
  has more than one trusted ownership marker
- **When** the updater searches for its target comment
- **Then** it fails closed without modifying any existing comment or creating a
  second marker

#### Scenario: `test_progress_update_refuses_concurrent_stale_write`
- **Given** two updates read the same prior comment and one update commits first
- **When** the second update attempts its conditional compare-and-write
- **Then** serialization or the atomic precondition detects the changed source
  and the second update refuses to overwrite it

### Requirement: Guard workflows run only for authoritative pull-request edits

Release-content and closing-keyword validation MUST run for opened,
synchronized, reopened, title-edited, and body-edited pull requests. A
body-only edit remains authoritative because both guards consume PR-body
content; it MUST not be treated as marker bookkeeping. Marker comment updates
use the comment event surface and MUST not start either guard job. The event
filter MUST distinguish title edits from comment updates, because
`pull_request.edited` has no event-level title filter.

#### Scenario: `test_body_only_edit_runs_authoritative_guards`
- **Given** a pull request head and title are unchanged and only the body changes
- **When** the edited event is evaluated
- **Then** both body-consuming guard jobs start and the aggregate verify job
  receives their successful results

#### Scenario: `test_title_only_edit_reruns_release_content_guard`
- **Given** a pull request head and changed files are unchanged
- **When** the title changes and the event includes `changes.title`
- **Then** release-content validation runs exactly once and can replace the prior status with the expected title result

#### Scenario: `test_combined_edit_runs_guards`
- **Given** a pull request title and body change in one edited event
- **When** the event is evaluated
- **Then** every applicable guard runs exactly once

#### Scenario: `test_progress_comment_edit_runs_no_body_guard`
- **Given** a pull request body and head are unchanged and only the trusted
  marker comment changes
- **When** the comment event is evaluated
- **Then** neither body guard nor the aggregate verify job starts a new run

#### Scenario: `test_open_sync_reopen_trigger_guards`
- **Given** a pull request event is opened, synchronized, or reopened
- **When** the workflow receives the event
- **Then** the applicable guard jobs run regardless of whether the body also contains progress metadata

### Requirement: Readiness authority excludes only validated progress fields

Readiness fingerprinting MUST exclude only the schema-validated,
non-authoritative progress fields inside the marker-owned comment. Its
projection MUST include no comment timestamps, including `updated_at`, for a
validated trusted marker. Review findings, review replies, deferred findings,
every non-marker comment (including marker lookalikes), and all other
pull-request content MUST remain authoritative fingerprint inputs.

#### Scenario: `test_fingerprint_ignores_only_validated_progress_fields`
- **Given** an owned marker comment changes only schema-valid progress fields or
  its GitHub-maintained timestamps
- **When** readiness content is fingerprinted
- **Then** the fingerprint remains unchanged

#### Scenario: `test_fingerprint_changes_for_authoritative_surfaces`
- **Given** the same pull request and head
- **When** a review finding, reply, deferred finding, non-marker comment, or non-progress marker field changes
- **Then** the readiness fingerprint changes

#### Scenario: `test_untrusted_marker_lookalike_remains_authoritative`
- **Given** an untrusted commenter copies the marker into a separate comment
- **When** the updater discovers the trusted target and readiness content is
  fingerprinted
- **Then** the lookalike does not block publishing, and its full content remains
  an authoritative fingerprint input

### Requirement: Progress changes do not invalidate current validation

Updating marker-owned progress after a clean code-head validation MUST create no
new required guard check and MUST NOT invalidate otherwise-current readiness
evidence. The aggregate verify job MUST continue to require successful
closing-keyword validation for every authoritative pull-request edit, including
body-only edits.

Every progress write MUST carry a monotonic generation and the expected prior
canonical state. A generation or prior-state mismatch MUST refuse the write,
even when the physical comment revision is otherwise fresh, so delayed intent
cannot regress stage or round state.

#### Scenario: `test_progress_update_rejects_stale_semantic_transition`
- **Given** two serialized updates have the same expected prior state and one
  commits a newer generation first
- **When** the delayed update attempts its conditional write
- **Then** the delayed update refuses and cannot regress the visible stage or round

Rollback MUST restore the previous harmon-devkit skills pin and run its normal
sync before disabling the marker publisher. The previous PR-body progress writer
and readiness behavior MUST work unchanged after rollback.

#### Scenario: `test_rollback_restores_previous_progress_writer`
- **Given** marker-aware skills were rolled out
- **When** rollback pins and syncs the previous released skills version
- **Then** the PR-body ledger writer works unchanged and marker publishing is no
  longer required

#### Scenario: `test_post_validation_progress_update_preserves_readiness`
- **Given** all required code-head validation is clean and readiness evidence is current
- **When** only the owned progress fields are updated
- **Then** no guard job starts and the existing readiness evidence remains current

### Requirement: Root and template behavior stay equivalent

The root workflows and their Copier-rendered template twins MUST implement the
same trigger behavior. Root/template tests MUST cover title-only edits,
body-only edits, combined edits, comment events, and synchronized heads. The
harmon-devkit updater tests MUST cover malformed markers and concurrent comment
updates.

#### Scenario: `test_root_template_progress_workflow_parity`
- **Given** the root workflow and its rendered template twin
- **When** the parity suite evaluates all progress-edit fixtures
- **Then** both layers produce the same expected trigger and authority results

### Requirement: Human replay verifies the historical failure mode

Before this capability is accepted, a maintainer MUST replay the final progress
correction from PR #1070 and confirm that the visible ledger updates without
starting another release-content guard or readiness wait.

#### Scenario: `test_maintainer_replays_pr_1070_progress_correction`
- **Given** the final PR #1070 progress correction is reproduced on an unchanged code head
- **When** the marker-owned ledger is updated
- **Then** the ledger is visible and no release guard or readiness wait is started
