## Why

`devcontainer-assert-bot` (added by the archived `bot-autonomy-bootstrap`
change, #1150) proves in CI that a fresh bot container applies and verifies
every harness policy — but it runs behind `devcontainer-build.yml`'s
workflow-level `paths:` filter and is not a required branch-protection
context, so a PR that breaks the bot policy can still merge if a reviewer
does not look. That change's design.md deliberately deferred promoting it,
because promotion needs four things at once: a context emitted on every pull
request (including docs-only ones), both checked-in ruleset layers naming
it, a trusted validation path for fork PRs (which never get registry
credentials), and a credential-free container validation for `merge_group`
runs (which can carry fork-authored content GitHub does not label as such).
This change builds all four, so the invariant holds: **once required, the
context is emitted for every pull request and merge-group run, never blocks
a docs-only change, and never runs fork-controlled content with registry
credentials.**

## What Changes

- Add a `devcontainer-changes` job to `devcontainer-build.yml` (and its
  template twin) that replaces the workflow-level `paths:` filter with
  job-level detection, mirroring this repo's existing
  `terraform-changes`/`terraform-changed.sh` pattern. New script
  `scripts/devcontainer-changed.sh <base_sha> <head_sha>` (+
  `scripts/test-devcontainer-changed.sh`), fail-safe to "changed" on any
  unresolvable input.
- Remove `devcontainer-build.yml`'s workflow-level `paths:` filters from
  `push` and `pull_request`; add a `merge_group:` trigger; add
  `pull_request: branches: [main]`.
- Gate the existing `build` job on `devcontainer-changes`' output. Add a
  merge_group credential-free path: skip `docker/login-action` and blank
  `cacheFrom` for `github.event_name == 'merge_group'`, so a queued build
  never authenticates to the registry.
- Gate the existing `devcontainer-assert-bot` job on `devcontainer-changes`'
  output and stand it down entirely for `merge_group` (its cache needs a
  registry login it must never receive on queued content, and its cache
  source is a static devcontainer.json field that cannot be conditioned per
  event). Remove its now-redundant internal fork-skip verification step —
  that check moves to the aggregator.
- Extend the existing `devcontainer-verify` job into the full required
  aggregator (`if: always()`, rolls up `devcontainer-changes`, `build`, and
  `devcontainer-assert-bot`), mirroring `terraform-verify`'s step structure:
  a fork-boundary check, a change-detector success check, a deliberate-no-op
  check for unrelated PRs, and per-job expected-result checks that account
  for the merge_group carve-out.
- Add `devcontainer-verify` to both checked-in ruleset layers'
  `required_status_checks` (`.github/Branch Protection Ruleset - Protect
  Main.json` and its template twin) — the importable template only; the
  maintainer applies the equivalent live-ruleset edit afterward (tracked by
  #1157's separate `[HUMAN]` acceptance criterion, out of scope here).
- Document, in `docs/architecture/branch-protection.md` (+ twin): the new
  required check, the merge_group credential-free carve-out, and a runbook
  for a maintainer to get a real credentialed CI signal on a fork PR that
  touches `.devcontainer/**` before approving it. Update
  `docs/architecture/ci-cd.md` (+ twin)'s `devcontainer-build.yml` bullet to
  match the new behavior.

## Capabilities

### New Capabilities

- `ci/required-devcontainer-context`: the always-on required aggregator
  behavior for `devcontainer-build.yml` — emission on every PR/merge-group
  run, docs-only pass-without-build, both ruleset layers naming the context,
  the fork trusted-validation runbook, and the merge_group credential-free
  path.

### Modified Capabilities

_(none — `devcontainer/bot-autonomy` and `devcontainer/harness-image` own
what the container assertion checks; this change only promotes the
existing, unmodified assertion to a required context.)_

## Non-goals

- Changing what `bot-autonomy.sh verify` (or the container assertion)
  checks — owned by the `devcontainer/bot-autonomy` and
  `devcontainer/harness-image` specs.
- Adding the devcontainer build/smoke test to `task ci` — it stays the
  documented CI-only exception (needs Docker + the devcontainer CLI, no
  graceful skip).
- Applying the new required context to the **live** GitHub repository
  ruleset — that is issue #1157's separate `[HUMAN]` acceptance criterion,
  done by the maintainer after this change's workflow lands green on `main`
  (`docs/architecture/branch-protection.md`'s documented order: merge the
  workflow first, then add the context in Settings).
- Redesigning `terraform.yml` / `terraform-changed.sh` — this change only
  reads them as a pattern to mirror for the devcontainer workflow.
- Building an automated bot or workflow for the fork-PR trusted rerun — it
  is a documented manual runbook (a maintainer-triggered,
  `pull_request_target`-free rerun on a same-repository branch), matching
  the issue's own example wording.

## Impact

- `.github/workflows/devcontainer-build.yml` and its template twin
  (triggers, jobs).
- New `scripts/devcontainer-changed.sh`, `scripts/test-devcontainer-changed.sh`
  and their `template/scripts/` twins.
- `Taskfile.yml` (new `test:devcontainer-changed` task, wired into `verify`)
  and `.github/workflows/build.yml`'s `lint` job step list.
- `.github/Branch Protection Ruleset - Protect Main.json` and its template
  twin.
- `docs/architecture/branch-protection.md` and `docs/architecture/ci-cd.md`,
  both root and template twins.
- No change to `.devcontainer/**` content, `scripts/devcontainer-assert.sh`,
  or `scripts/devcontainer-smoke.sh`.
