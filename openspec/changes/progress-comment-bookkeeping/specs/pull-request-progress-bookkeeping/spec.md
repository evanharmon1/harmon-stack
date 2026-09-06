## Purpose

Provides a stable, machine-owned surface for multi-stage pull-request progress
so bookkeeping changes do not retrigger validation or weaken readiness evidence.

## ADDED Requirements

### Requirement: Canonical marker-owned progress comment

The progress record MUST be one top-level comment containing a stable ownership
marker and canonical sections for stage, round, current result, and next action.
The marker MUST be unique to the pull request and distinguish machine-owned
progress from human-authored content.

#### Scenario: `test_progress_comment_has_canonical_sections`
- **Given** a pull request passes through two or more workflow stages
- **When** progress is published
- **Then** exactly one marker-owned top-level comment contains the stable marker and all four canonical sections

### Requirement: Safe idempotent progress updates

The updater MUST compare the canonical rendered content before writing, MUST
leave unchanged content untouched, MUST preserve content outside the owned
sections, and MUST refuse to proceed when the ownership marker is missing or
duplicated. Concurrent updates MUST not silently overwrite a newer valid
progress record.

#### Scenario: `test_progress_update_is_compare_before_write_and_preserves_humans`
- **Given** an owned comment contains human-authored content and the requested canonical progress is unchanged
- **When** the updater runs
- **Then** it performs no write and leaves the human-authored content intact

#### Scenario: `test_progress_update_rejects_missing_or_duplicate_markers`
- **Given** a pull request has zero or more than one ownership marker
- **When** the updater searches for its target comment
- **Then** it fails closed without creating or modifying a comment

#### Scenario: `test_progress_update_refuses_concurrent_stale_write`
- **Given** two updates read the same prior comment and one update commits first
- **When** the second update attempts its compare-and-write
- **Then** the second update detects the changed source and refuses to overwrite it

### Requirement: Guard workflows run only for authoritative pull-request edits

Release-content and closing-keyword validation MUST run for opened,
synchronized, reopened, and title-edited pull requests. A body-only edit MUST
not start either guard job. The event filter MUST distinguish title edits from
body edits using the presence of the pull-request title change payload, because
`pull_request.edited` has no event-level title filter.

#### Scenario: `test_body_only_edit_starts_no_guard_job`
- **Given** a pull request head and title are unchanged and only the body changes
- **When** the edited event is evaluated
- **Then** neither guard job starts

#### Scenario: `test_title_only_edit_reruns_release_content_guard`
- **Given** a pull request head and changed files are unchanged
- **When** the title changes and the event includes `changes.title`
- **Then** release-content validation runs exactly once and can replace the prior status with the expected title result

#### Scenario: `test_combined_edit_runs_guards`
- **Given** a pull request title and body change in one edited event
- **When** the event is evaluated
- **Then** every applicable guard runs exactly once

#### Scenario: `test_open_sync_reopen_trigger_guards`
- **Given** a pull request event is opened, synchronized, or reopened
- **When** the workflow receives the event
- **Then** the applicable guard jobs run regardless of whether the body also contains progress metadata

### Requirement: Readiness authority excludes only validated progress fields

Readiness fingerprinting MUST exclude only the schema-validated,
non-authoritative progress fields inside the marker-owned comment. Review
findings, review replies, deferred findings, every non-marker comment, and all
other pull-request content MUST remain authoritative fingerprint inputs.

#### Scenario: `test_fingerprint_ignores_only_validated_progress_fields`
- **Given** an owned marker comment changes only schema-valid progress fields
- **When** readiness content is fingerprinted
- **Then** the fingerprint remains unchanged

#### Scenario: `test_fingerprint_changes_for_authoritative_surfaces`
- **Given** the same pull request and head
- **When** a review finding, reply, deferred finding, non-marker comment, or non-progress marker field changes
- **Then** the readiness fingerprint changes

### Requirement: Progress changes do not invalidate current validation

Updating marker-owned progress after a clean code-head validation MUST create no
new required guard check and MUST NOT invalidate otherwise-current readiness
evidence.

#### Scenario: `test_post_validation_progress_update_preserves_readiness`
- **Given** all required code-head validation is clean and readiness evidence is current
- **When** only the owned progress fields are updated
- **Then** no guard job starts and the existing readiness evidence remains current

### Requirement: Root and template behavior stay equivalent

The root workflows and their Copier-rendered template twins MUST implement the
same trigger behavior. Tests MUST cover title-only edits, body-only edits,
combined edits, synchronized heads, malformed markers, and concurrent comment
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
