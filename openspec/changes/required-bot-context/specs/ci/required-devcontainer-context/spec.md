## Purpose

Defines the always-on required-status-check contract for the bot devcontainer
container assertion: the aggregator that branch protection requires must be
emitted on every pull request and merge-group run, pass a docs-only change
without building, and never hand registry credentials to fork-controlled or
merge-queued content.

## ADDED Requirements

### Requirement: Always-on required aggregator
`devcontainer-build.yml`'s `devcontainer-verify` job SHALL run on every
`pull_request` and `merge_group` event against the repository, with no
workflow-level `paths:` filter gating whether the workflow runs at all.
Whether the expensive build/assertion jobs it rolls up actually execute is
decided by job-level change detection, never by suppressing the aggregator
itself.

#### Scenario: aggregator reports on a pull request
- **WHEN** a pull request is opened, synchronized, or reopened against the
  repository
- **THEN** the `devcontainer-verify` status check is reported on that pull
  request's head commit, with a final state of `success` or `failure` (never
  left unreported)

#### Scenario: aggregator reports on a merge-group run
- **WHEN** a `merge_group` event runs for a queued pull request
- **THEN** the `devcontainer-verify` status check is reported for that
  merge-group run

### Requirement: Docs-only pull requests pass without building
A pull request that changes no path relevant to the devcontainer (not
`.devcontainer/**`, not the `devcontainer-build.yml` workflow file, and not
the scripts that build or assert it) SHALL receive a passing
`devcontainer-verify` result without the container image being built or the
bot-autonomy container assertion running.

#### Scenario: a documentation-only change passes without a build
- **WHEN** a pull request changes only files outside `.devcontainer/**`,
  `.github/workflows/devcontainer-build.yml`, and the devcontainer
  build/assert/detect scripts
- **THEN** `devcontainer-verify` succeeds, and the jobs that build the
  devcontainer image and run the bot-autonomy container assertion do not
  execute

#### Scenario: a relevant change still triggers the real build
- **WHEN** a pull request changes a path matched by the devcontainer change
  detector
- **THEN** the devcontainer image build and the bot-autonomy container
  assertion both run, and `devcontainer-verify` requires both to succeed

### Requirement: Both ruleset layers name the required context
The checked-in importable branch protection ruleset, at both the root layer
(`.github/Branch Protection Ruleset - Protect Main.json`) and the template
layer (its `template/` twin), SHALL list `devcontainer-verify` in
`required_status_checks`. `docs/architecture/branch-protection.md` and its
template twin SHALL document the check in the required-checks table.

#### Scenario: root ruleset names the context
- **WHEN** `.github/Branch Protection Ruleset - Protect Main.json` is read
- **THEN** its `required_status_checks` array includes an entry whose
  `context` is `devcontainer-verify`

#### Scenario: template ruleset names the context
- **WHEN** the template's `Branch Protection Ruleset - Protect Main.json.jinja`
  is rendered for a devcontainer-enabled profile
- **THEN** the rendered `required_status_checks` array includes an entry
  whose `context` is `devcontainer-verify`

### Requirement: Fork pull requests reach a trusted validation path
A pull request from a fork that changes `.devcontainer/**` SHALL NOT be
permanently unmergeable: `devcontainer-verify` reports a deliberate,
passing result (the same repository-controlled-job-skip pattern this
repository already applies to `verify`/`security` for forks) rather than
hanging unreported, and `docs/architecture/branch-protection.md` SHALL
document a maintainer-triggered, `pull_request_target`-free procedure for
obtaining a real, credentialed validation of such a pull request's
devcontainer content on a same-repository branch before it is approved or
merged.

#### Scenario: a fork pull request touching the devcontainer is not blocked
- **WHEN** a pull request from a fork changes a path matched by the
  devcontainer change detector
- **THEN** the devcontainer build and bot-autonomy assertion jobs are
  skipped rather than run with credentials, and `devcontainer-verify` still
  reports a passing result for that pull request

#### Scenario: a documented trusted rerun path exists
- **WHEN** a maintainer needs a real, credentialed CI signal for a fork
  pull request's devcontainer change before approving it
- **THEN** `docs/architecture/branch-protection.md` documents how to obtain
  one by re-running the workflow against a same-repository branch, without
  using `pull_request_target`

### Requirement: Merge-group runs a credential-free container validation
A `merge_group` event SHALL run a devcontainer container validation that
never authenticates to the container registry, because GitHub does not
expose whether the queued pull request originated from a fork on that
event. The bot-autonomy container assertion, which cannot be made
credential-free without disabling its registry cache, SHALL NOT run on
`merge_group`.

#### Scenario: a merge-group build never authenticates to the registry
- **WHEN** a `merge_group` event triggers `devcontainer-build.yml` for a
  change matched by the devcontainer change detector
- **THEN** the devcontainer image build runs to completion without any step
  logging in to the container registry, and `devcontainer-verify` requires
  that build to succeed

#### Scenario: the bot-autonomy assertion stands down on merge-group
- **WHEN** a `merge_group` event triggers `devcontainer-build.yml`
- **THEN** the bot-autonomy container assertion job does not run, and
  `devcontainer-verify` treats its skip as the expected, passing outcome for
  that event
