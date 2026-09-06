- [ ] 0.1 Settle proposal open design question Q1 in `proposal.md`,
      `design.md`, and affected `spec.md` requirements/scenarios/follow-on
      scope: choose the authoritative behavior when an untrusted marker
      lookalike exists, reconciling fail-closed updates with non-blocking
      discovery.
- [ ] 0.2 Settle proposal open design question Q2 in `proposal.md`,
      `design.md`, and affected `spec.md` requirements/scenarios/follow-on
      scope: choose an implementable concurrency mechanism for issue comments
      before writing the updater.
- [ ] 0.3 Settle Q3 in `proposal.md`, `design.md`, and affected `spec.md`
      requirements/scenarios/follow-on scope: decide how deferred-finding body
      ticks interact with authoritative readiness evidence.
- [ ] 0.4 Settle Q4 in `proposal.md`, `design.md`, and affected `spec.md`
      requirements/scenarios/follow-on scope: define first-marker bootstrap
      ordering and its readiness projection semantics.
- [ ] 0.5 Settle Q5 in `proposal.md`, `design.md`, and affected `spec.md`
      requirements/scenarios/follow-on scope: define rollback quiescence or a
      checkpoint that prevents stale visible-ledger regression.

## 1. Workflow trigger behavior (harmon-init)

- [ ] 1.1 Add root/template regression assertions that release-content and
      closing-keyword validation remain authoritative for opened, synchronized,
      reopened, title-edited, body-edited, and combined edits.
- [ ] 1.2 Add root/template assertions that marker comment edits use the comment
      event surface and do not enqueue either guard or bypass the aggregate
      `verify` dependency.
- [ ] 1.3 Add root/template fixture coverage for title-only, body-only,
      combined, comment-only, base-only `pull_request.edited`, opened,
      synchronized, and reopened events. Keep marker/updater fixtures in
      harmon-devkit; root/template tests cover workflow event fixtures.

## 2. Authority and parity verification (harmon-init)

- [ ] 2.1 Add tests proving progress-only updates create no required guard
      check after clean code-head validation.
- [ ] 2.2 Add tests proving root/template event behavior remains in parity and
      covers the base-only edited payload; assign malformed-marker, lookalike,
      timestamp, generation, and concurrent-update fixtures to the harmon-devkit
      updater tests, not this workflow boundary.
- [ ] 2.3 Run the maintainer replay of PR #1070 and record that the visible
      progress correction starts no guard or readiness wait.

- [ ] 2.4 In the harmon-devkit follow-on, test that validated marker timestamp
      changes do not change readiness fingerprints, while other comment
      timestamps remain authoritative.
- [ ] 2.5 In the harmon-devkit follow-on, test that an untrusted marker lookalike
      cannot block trusted publishing but remains in readiness input.
- [ ] 2.6 In the harmon-devkit follow-on, test monotonic generation and expected
      prior-state rejection for delayed concurrent updates.
- [ ] 2.7 Test rollback by restoring the previous skills pin and sync, then
      verifying the prior PR-body ledger writer works unchanged.

## 3. Harmon-devkit follow-on (separate issue; not implemented here)

- [ ] 3.1 File the follow-on issue using the exact scope in design.md:
      marker schema, canonical sections, authenticated publisher ownership,
      safe first-marker bootstrap, idempotent compare-before-write updater,
      preservation of human content, rejection of untrusted/missing/duplicate
      markers, atomic serialized concurrent-write refusal, and tests.
- [ ] 3.2 Implement the readiness projection in harmon-devkit so only
      schema-validated non-authoritative progress fields are excluded; retain
      reviews, replies, deferred findings, and all non-marker comments.
- [ ] 3.3 Keep the vendored copies in harmon-init managed by the normal
      harmon-devkit sync; do not hand-edit them in this change.

- [ ] 3.4 [HUMAN] Maintainer-owned: wait for harmon-devkit to land and publish
      the updater/fingerprint projection release, sync the released version,
      and record that prerequisite before accepting the harmon-init workflow
      change.

## 4. Gates

- [ ] 4.1 Run `task spec:validate`.
- [ ] 4.2 Run `task check`, `task verify`, and `task security` in the
      foreground with bounded timeouts.
