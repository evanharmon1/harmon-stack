## Context

See proposal.md - Why. Two things already exist in this repo and shape the
approach:

- `devcontainer-build.yml` already has `build` (matrix image build),
  `devcontainer-verify` (today only rolls up `build`), and
  `devcontainer-assert-bot` (starts a real bot container, runs
  `bot-autonomy.sh verify` in it via `scripts/devcontainer-smoke.sh`, needs a
  registry login for its cache because `.devcontainer/devcontainer.json`'s
  `cacheFrom` is a static field). All three currently sit behind the
  workflow's `paths:` filter.
- `template/.github/workflows/[% if include_terraform %]terraform.yml[% endif %].jinja`
  already solves the identical problem for a different required check
  (`terraform-verify`): a `terraform-changes` detector job replaces a
  workflow-level `paths:` filter, `terraform-plan-apply` (the credentialed
  leg) explicitly excludes `merge_group` because "GitHub does not expose the
  queued PR's origin on that event", and `terraform-verify` centralizes every
  fork/skip/predicate check the leaf jobs used to do individually. This
  design is a direct port of that pattern onto devcontainer-build.yml.

## Goals / Non-Goals

**Goals:**
- Match the terraform.yml pattern's structure and idioms closely enough that
  a reviewer who knows one recognizes the other immediately.
- Keep `scripts/verify-ci-results.sh` unmodified — every aggregator check
  reduces to a `name=result` pair it already knows how to verify.
- Keep the diff to `build`/`devcontainer-assert-bot` minimal: only what's
  needed to add change-gating and the merge_group carve-out.

**Non-Goals:**
- Making `devcontainer-assert-bot` run credential-free on `merge_group`. Its
  cache source is `.devcontainer/devcontainer.json`'s static `cacheFrom`
  field (read by the `devcontainer` CLI, not the workflow), which cannot be
  conditioned per CI event. Standing the whole job down on `merge_group` is
  simpler and strictly safer than attempting a partial credential-free path
  whose registry-auth-failure behavior (soft-degrade vs. hard-fail on a
  private cache ref) is not something this design wants to depend on.
- Automating the fork-PR trusted rerun. See proposal.md - Non-goals.

## Decisions

**Reuse the existing `devcontainer-verify` job name for the required
context**, rather than introducing a new job/context name. It already exists
in the workflow (today only checking `build`), is not yet referenced by any
ruleset, and "verify" already means "roll up this workflow's leaf jobs" by
this repo's own convention (`build.yml`'s `verify`, `terraform.yml`'s
`terraform-verify`). Renaming would add churn with no migration benefit.

**Two-dot diff with the raw payload SHAs, not `origin/<branch>` +
three-dot.** `scripts/require-release-title.sh` uses `origin/<base-branch>` +
three-dot specifically to avoid a stale `pull_request.base.sha`.
`terraform-changed.sh` instead uses the raw `base.sha`/`head.sha` (or
`merge_group.base_sha`/`head_sha`) with a two-dot `git diff --no-renames`,
and treats `push`/`workflow_dispatch` (no natural range) as an unconditional
"changed" reconciliation. This design follows `terraform-changed.sh`,
because:
- The detector's failure mode is asymmetric by design (fail-safe to
  "changed"): a stale base can only make the two-dot diff show *more* files
  than a fresh merge-base would, never fewer, so staleness cannot produce a
  false "unchanged".
- Matching the newer, already-shipped precedent in this exact repository
  outweighs the marginal precision `origin/<branch>` would add, since the
  detector's job is only to skip an expensive build, not to gate a release
  decision the way `require-release-title.sh` does.

**`merge_group` gets its own `build-merge-group` job with a statically
narrower `permissions:` block, rather than a runtime skip inside `build`.**
An earlier version of this design kept one `build` job and had it skip
`docker/login-action` (and blank `cacheFrom`) when
`github.event_name == 'merge_group'`. That is not a real credential
boundary: `merge_group` runs the workflow definition from the **queued
candidate tree**, which includes the very changes being evaluated, so a PR
that also edits this file can simply delete that runtime guard (or add a
credential-reading step directly) and use the job's token — which still
carries `packages: write`, declared statically for the push case — without
ever calling the now-absent login step. `permissions:` is the one thing in
this file such an edit cannot silently repurpose: GitHub mints the job's
token from that block before any step, trusted or attacker-added, executes,
and a diff that widens it back to `packages: write` is exactly the
conspicuous, reviewable change `require_code_owner_review` exists to catch
(every file, workflows included, requires this repository's one CODEOWNERS
reviewer). `build-merge-group` therefore declares only
`permissions: {contents: read}` — no `packages` key at all, hence no scope
to authenticate with regardless of what its steps try — and carries no
`docker/login-action` step under any condition, not merely a skipped one.
`build` keeps `packages: write` for the push case it still needs, and now
excludes `merge_group` outright via its own `if:`, mirroring how
`devcontainer-assert-bot` already excludes it.

**`devcontainer-assert-bot` stands down entirely on `merge_group`, with no
low-privilege sibling of its own.** Unlike `build`, its registry use is not
a workflow-level input this design can move to a separate job's cache
config: it uses the `devcontainer` CLI (`scripts/devcontainer-smoke.sh`),
which reads its cache source from the static `cacheFrom` field in
`.devcontainer/devcontainer.json` — not a workflow expression, and shared
with every human and bot devcontainer session, so it cannot be templated
per CI event without diverging from what everyone else actually runs.
Standing the job down is the same trade-off `terraform-plan-apply` already
makes for the same reason.

**Centralize verification in the aggregator; delete the leaf jobs' own
self-checks.** Today's `devcontainer-assert-bot` has its own internal
"Verify deliberate skip at the untrusted-fork boundary" step. `terraform.yml`
has no equivalent in `terraform-plan-apply` — every skip/result check lives
solely in `terraform-verify`. Adopting that shape here removes duplicate
logic and gives the aggregator a single, complete picture of why each leaf
did or did not run.

**Alternatives considered:**
- *Keep the workflow-level `paths:` filter and add `merge_group` alongside
  it.* Rejected: a required check that never reports on an unrelated PR
  (because the whole workflow didn't run) blocks that PR's merge forever —
  the exact failure mode `terraform-verify`'s comment already names and this
  change exists to avoid for devcontainer-build.yml too.
- *A single `build` job that skips `docker/login-action` and blanks
  `cacheFrom` at runtime when `github.event_name == 'merge_group'`.* This
  was the change's first draft, confirmed wrong in challenge round 1
  (2026-09-05): the job still declared `packages: write` unconditionally, so
  the "credential-free" property depended entirely on a same-file runtime
  guard a queued, workflow-file-editing PR can simply not include in its own
  submitted copy. Superseded by the `build-merge-group` split above, which
  moves the boundary to a place a same-file edit cannot reach.
- *Make `devcontainer-assert-bot` credential-free on `merge_group` by
  passing an empty `cacheFrom` via an `--override-config` or a generated
  devcontainer.json variant.* Rejected as unnecessary complexity for a path
  that only needs to run once per pull request anyway (see the fork-PR
  runbook) — standing the job down for the one event where its provenance
  can't be verified is simpler and does not risk depending on
  registry-auth-failure behavior this design has not verified empirically.

## Risks / Trade-offs

- **A fork PR's devcontainer content never gets automated real validation
  before merge** → mitigated by the documented manual rerun runbook in
  `docs/architecture/branch-protection.md`, and bounded the same way this
  repository already bounds it for `verify`/`security`: required-reviewer +
  code-owner approval is the actual gate for fork content, not the
  automated check alone.
- **`build-merge-group` builds without any registry cache, so it is slower
  than a same-repo PR's `build`** → acceptable; `merge_group` runs are far
  less frequent than PR pushes, and correctness (a token with no `packages`
  scope at all, not merely an unused one) outweighs build speed here.
- **Duplicated job steps between `build` and `build-merge-group`** (matrix,
  checkout, buildx setup, the build step, cleanup) → accepted: GitHub
  Actions has no in-file mechanism to share a job body across two different
  static `permissions:` blocks, and a `workflow_call` split would be a much
  larger restructuring for a two-job duplication. A future change to the
  shared build steps must be applied to both jobs; `task audit:dogfood`'s
  root/template diff and code review are what catch that, the same way they
  already catch drift elsewhere in this file.
- **The push/workflow_dispatch "always changed" reconciliation means every
  merge to `main` rebuilds the devcontainer image cache, even for an
  unrelated change** → same trade-off `terraform.yml` already accepts for
  its own push path; the cost is one extra image build per merge, which also
  keeps the registry `-cache` ref warm for the next PR.

## Migration Plan

Land the workflow, script, ruleset-template, and doc changes together in one
PR (this change). No live-ruleset edit happens here — see proposal.md -
Non-goals; that is issue #1157's `[HUMAN]` acceptance criterion, applied by
the maintainer once this PR's workflow has run green on `main` at least
once, following `docs/architecture/branch-protection.md`'s existing
"merge the workflow first, then add the context" order. No rollback beyond a
normal revert PR is needed: nothing here is destructive or stateful.
