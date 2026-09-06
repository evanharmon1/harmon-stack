## 1. Workflow trigger behavior (harmon-init)

- [ ] 1.1 Update the root release-content workflow job predicate so opened,
      synchronized, reopened, title-edited, and body-edited events run
      validation; marker comment updates are handled on the comment surface.
- [ ] 1.2 Apply the same trigger behavior to the template workflow twin.
- [ ] 1.3 Update the build workflow's `closing-keywords` and aggregate `verify`
      dependency behavior so every authoritative body edit produces the
      required successful result, while marker comment edits do not enqueue a
      new validation run.
- [ ] 1.4 Add root/template fixture coverage for title-only, body-only,
      combined, comment-only, opened, synchronized, and reopened events.

## 2. Authority and parity verification (harmon-init)

- [ ] 2.1 Add tests proving progress-only updates create no required guard
      check after clean code-head validation.
- [ ] 2.2 Add tests proving root/template behavior remains in parity, including
      malformed marker and concurrent-update fixtures at the workflow boundary.
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

## 4. Gates

- [ ] 4.1 Run `task spec:validate`.
- [ ] 4.2 Run `task check`, `task verify`, and `task security` in the
      foreground with bounded timeouts.
