## 1. Workflow trigger behavior (harmon-init)

- [ ] 1.1 Add root/template regression assertions that release-content and
      closing-keyword validation remain authoritative for opened, synchronized,
      reopened, title-edited, body-edited, and combined edits.
- [ ] 1.2 Add root/template assertions that marker comment edits use the comment
      event surface and do not enqueue either guard or bypass the aggregate
      `verify` dependency.
- [ ] 1.3 Add root/template fixture coverage for title-only, body-only,
      combined, comment-only, opened, synchronized, and reopened events.

## 2. Authority and parity verification (harmon-init)

- [ ] 2.1 Add tests proving progress-only updates create no required guard
      check after clean code-head validation.
- [ ] 2.2 Add tests proving root/template event behavior remains in parity;
      assign malformed-marker and concurrent-update fixtures to the
      harmon-devkit updater tests, not this workflow boundary.
- [ ] 2.3 Run the maintainer replay of PR #1070 and record that the visible
      progress correction starts no guard or readiness wait.

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

- [ ] 3.4 Land and release the harmon-devkit updater/fingerprint projection,
      sync the released version, and record that prerequisite before accepting
      the harmon-init workflow change.

## 4. Gates

- [ ] 4.1 Run `task spec:validate`.
- [ ] 4.2 Run `task check`, `task verify`, and `task security` in the
      foreground with bounded timeouts.
