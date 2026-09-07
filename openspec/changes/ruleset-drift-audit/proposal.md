## Why

The checked-in branch-protection ruleset is an import template while the live GitHub ruleset is maintained manually, so required checks and safety flags can silently diverge. A read-only audit makes that drift visible in this repository and in every generated repository.

## What Changes

- Add `task audit:ruleset`, backed by a portable shell script, that fetches and normalizes the named live ruleset and reports a readable diff with distinct drift and unavailable/absent outcomes.
- Ship the task and script in both root and template layers, with rendered profile-specific required-check contexts covered by tests.
- Add hermetic fixture-based tests for matching rulesets, missing/extra values, absent rulesets, and permission failures.
- Document the audit beside the required-check update procedure and explain why applying changes remains a manual GitHub UI operation.

## Capabilities

### New Capabilities

- `ci/ruleset-drift-audit`: read-only comparison of checked-in and live GitHub branch rulesets.

### Modified Capabilities

- _(none)_

## Non-goals

- Applying, creating, or updating a GitHub ruleset.
- Replacing the existing ruleset import JSON or changing branch-protection policy.
- Requiring network access for the unit tests.

## Impact

The root and template Taskfiles, audit scripts, fixture tests, branch-protection documentation, and ruleset JSON are affected. Runtime use requires the GitHub CLI with read access to repository rulesets; the audit performs no writes.
