## 1. Change detector script

- [x] 1.1 Add `scripts/devcontainer-changed.sh <base_sha> <head_sha>`,
      mirroring `scripts/terraform-changed.sh`'s shape: an `emit()` helper
      that prints the answer and writes `changed=` to `$GITHUB_OUTPUT` when
      set, a path matcher covering `.devcontainer/**`,
      `.github/workflows/devcontainer-build.yml`,
      `scripts/verify-ci-results.sh`, `scripts/devcontainer-assert.sh`,
      `scripts/devcontainer-smoke.sh`, and itself, and fail-safe-to-`true`
      handling for an empty/all-zero/unresolvable base or head and any two-dot
      `git diff --no-renames` failure. Verify with `shellcheck --severity=error`
      and `shfmt -d` on the file.
- [x] 1.2 Add `scripts/test-devcontainer-changed.sh`, mirroring
      `scripts/test-terraform-changed.sh`'s hermetic temp-git-repo structure:
      an unrelated change is a no-op, a `.devcontainer/**` change counts, the
      workflow file itself counts, each of the other three watched scripts
      counts, a lookalike path prefix (e.g. `.devcontainer-notes.md`) does
      NOT count, a deletion counts, and the fail-safe cases (empty base,
      all-zero base, unresolvable base, unresolvable head) all answer `true`.
      Verify by running the script directly and confirming it exits 0 with a
      final "PASS" line.
- [x] 1.3 Add a `test:devcontainer-changed` task to `Taskfile.yml` that runs
      `scripts/test-devcontainer-changed.sh`; add it to the `verify` task's
      command list. Verify with `task test:devcontainer-changed` passing
      standalone.
- [x] 1.4 Add `- run: task test:devcontainer-changed` to
      `.github/workflows/build.yml`'s `lint` job step list (that job
      enumerates `task test:*` by hand rather than calling `task verify` —
      confirm whether `test:ci-results`, the closest unconditional analog,
      is listed there and follow the same placement). Verify by grepping
      `build.yml` for the new step.
- [x] 1.5 Add root/template twins under `template/scripts/`
      (`devcontainer-changed.sh` and `test-devcontainer-changed.sh`,
      verbatim — no jinja substitution needed, matching
      `template/scripts/[% if include_terraform %]terraform-changed.sh[% endif %]`'s
      pattern of a plain, unconditional filename since `devcontainer` is
      already the template's own conditional flag on the workflow/dir, not
      on individual scripts). Verify with `task test:dogfood-parity`.

## 2. Workflow triggers and the `devcontainer-changes` job

- [x] 2.1 In `.github/workflows/devcontainer-build.yml`, remove the
      workflow-level `paths:` filters from both `push` and `pull_request`,
      add `branches: [main]` under `pull_request`, add a bare `merge_group:`
      trigger, and add a header comment explaining the deliberate absence of
      `paths:` (mirroring `terraform.yml`'s comment). Verify with
      `actionlint` (part of `task check`).
- [x] 2.2 Add the `devcontainer-changes` job: same fork-boundary `if:` as
      today's `build` job, `fetch-depth: 0` checkout, an env block deriving
      `BASE_SHA`/`HEAD_SHA` from `pull_request`/`merge_group` payload fields
      (empty for `push`/`workflow_dispatch`, mirroring `terraform-changes`),
      and a step calling
      `./scripts/devcontainer-changed.sh "$BASE_SHA" "$HEAD_SHA"` with a
      `changed` job output. Verify by rendering the workflow through
      `actionlint` and by tracing the `if:`/output wiring by hand against
      `terraform-changes`.
- [x] 2.3 Apply the identical changes to the template twin
      `template/.github/workflows/[% if devcontainer %]devcontainer-build.yml[% endif %].jinja`
      (same triggers, same new job, `[[ ci_runs_on_default ]]` in place of
      the literal runner fallback). Verify with `task test:dogfood-structure`.

## 3. `build` job: gate on change detection, go credential-free on merge_group

- [x] 3.1 Add `needs: [devcontainer-changes]` to `build` and extend its `if:`
      with `needs.devcontainer-changes.outputs.changed == 'true' &&` ahead of
      the existing fork check. Verify the job is skipped when the detector
      reports `false` (traced by hand; exercised end-to-end once the PR is
      open).
- [x] 3.2 Guard the `docker/login-action` step with
      `if: github.event_name != 'merge_group'`, and make the
      `devcontainers/ci` step's `cacheFrom` input empty when
      `github.event_name == 'merge_group'` (leave `cacheTo`/`push` as they
      are — already conditioned on `push`). Add a code comment stating why:
      GitHub does not expose the queued PR's fork-vs-same-repo origin on
      `merge_group`. Verify by grepping the job for exactly one
      `docker/login-action` step guarded by that `if:`, and confirm no other
      step in this job references `secrets.GITHUB_TOKEN` unconditionally.
- [x] 3.3 Apply the identical changes to the template twin. Verify with
      `task test:dogfood-parity` (verbatim job body once flag literals are
      accounted for) or `test:dogfood-structure` as appropriate.

## 4. `devcontainer-assert-bot` job: gate on change detection, stand down on merge_group

- [x] 4.1 Add `needs: [devcontainer-changes, build]`; replace the job's
      current `if: always()` plus its internal "Verify deliberate skip at
      the untrusted-fork boundary" step with a single job-level `if:`
      mirroring `terraform-plan-apply`:
      `needs.devcontainer-changes.outputs.changed == 'true' && github.event_name != 'merge_group' && (github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository)`.
      Delete the now-redundant internal fork-skip step and its `IS_FORK` env
      var — that verification moves to `devcontainer-verify` (task 5).
      Verify by confirming the job body no longer references `IS_FORK` and
      that every remaining step runs unconditionally (the job-level `if:`
      is now the only gate).
- [x] 4.2 Add a code comment on the job explaining why `merge_group` is
      excluded outright rather than made credential-free (its cache source
      is `.devcontainer/devcontainer.json`'s static `cacheFrom` field, which
      cannot be conditioned per CI event — see design.md - Decisions).
      Verify by reading the comment against design.md for consistency.
- [x] 4.3 Apply the identical changes to the template twin. Verify with
      `task test:dogfood-structure`.

## 5. `devcontainer-verify` aggregator: the required context

- [x] 5.1 Extend `devcontainer-verify`'s `needs:` to
      `[devcontainer-changes, build, devcontainer-assert-bot]` and rewrite
      its steps to mirror `terraform-verify` exactly, adapted: a
      fork-boundary step (inline `check_skipped`, no checkout, expects all
      three deps `skipped`), a non-fork checkout, "Verify the change
      detector ran" (`devcontainer-changes` must be `success`), "Verify
      deliberate no-op" (when `changed == 'false'`, `build` and
      `devcontainer-assert-bot` must both be `skipped`), "Verify the build
      succeeded" (when `changed != 'false'`, `build` must be `success`), and
      "Verify the container assertion matched its predicate" (when
      `changed != 'false'`, `devcontainer-assert-bot` expected result is
      `success` unless `github.event_name == 'merge_group'`, else
      `skipped`). Reuse `scripts/verify-ci-results.sh` unmodified for every
      script-based check. Verify with `actionlint` and by hand-tracing every
      `(fork, merge_group, changed)` combination against the table in
      design.md.
- [x] 5.2 Apply the identical changes to the template twin. Verify with
      `task test:dogfood-structure`.

## 6. Branch protection ruleset (checked-in import template)

- [x] 6.1 Add `{"context": "devcontainer-verify", "integration_id": 15368}`
      to `required_status_checks` in
      `.github/Branch Protection Ruleset - Protect Main.json`, after
      `closing-keywords`. Verify with
      `jq '.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context'`
      listing `devcontainer-verify`.
- [x] 6.2 Add the same entry, in the equivalent position (ahead of the
      `[% if use_codeql %]`/`[% if include_terraform %]` conditional
      entries), to the template twin
      `template/.github/Branch Protection Ruleset - Protect Main.json.jinja`.
      Verify by rendering a `devcontainer`-enabled profile and re-running
      the `jq` query above against the rendered file.

## 7. Documentation

- [x] 7.1 Update `docs/architecture/branch-protection.md`'s required-checks
      table to add `devcontainer-verify`; add a new subsection documenting
      the merge_group credential-free carve-out (mirroring the
      `terraform-plan-apply`/merge_group paragraph already in the template's
      `branch-protection.md.jinja`) and the fork-PR trusted-rerun runbook
      (`gh pr checkout`, push to a same-repository branch, open a throwaway
      PR against `main` to get a credentialed run, never merge it; review
      the diff for `.github/workflows/**`/`scripts/devcontainer-*` tampering
      first; never use `pull_request_target`). Verify with `markdownlint-cli2`
      (part of `task check`) and a manual read-through against the spec
      delta's fork-PR requirement.
- [x] 7.2 Apply the equivalent updates to
      `template/docs/architecture/branch-protection.md.jinja`. Verify with
      `task test:dogfood-structure`.
- [x] 7.3 Update `docs/architecture/ci-cd.md`'s `devcontainer-build.yml`
      bullet to describe the required `devcontainer-verify` aggregate,
      job-level change detection via `devcontainer-changes`, the
      merge_group credential-free path, and a pointer to the branch
      protection doc's fork-PR runbook. Verify with `markdownlint-cli2`.
- [x] 7.4 Apply the equivalent update to
      `template/docs/architecture/ci-cd.md.jinja`. Verify with
      `task test:dogfood-structure`.

## 8. Full verification sweep

- [ ] 8.1 Run `task spec:validate`, `task check`, `task verify`, and
      `task security`; all green.
- [ ] 8.2 Run `actionlint` directly against both the root and rendered
      template workflow to confirm no expression/shell errors (already
      covered by `task check` and `task test:template`, run standalone if
      either flags something to isolate it faster).
- [ ] 8.3 Confirm `task test:dogfood-parity` and `task test:dogfood-structure`
      are green after every file above is edited.
- [ ] 8.4 Re-run the issue's own verify commands
      (`grep -n 'if: always()\|merge_group\|paths:' .github/workflows/devcontainer-build.yml`
      and the `jq` ruleset query) and confirm they show the always-on
      aggregator and merge_group trigger, and that both ruleset layers list
      `devcontainer-verify`.
