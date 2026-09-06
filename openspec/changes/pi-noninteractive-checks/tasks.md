## 1. Spec wording

- [x] 1.1 Sync this change's delta spec into
      `openspec/specs/devcontainer/bot-autonomy/spec.md` so the two
      manual-verification scenarios under "End-to-end effective autonomy"
      name pi's non-interactive invocation (`pi -p`, `--mode json`, or
      `--mode rpc`); verify by re-reading the synced scenario text and
      running `openspec validate --specs`.

## 2. Pin-PR handoff checklist

- [x] 2.1 Update `scripts/sync-devcontainer-image.sh`'s `write_body()` pi
      checklist item to name the same non-interactive form; verify by
      rendering the function's output and reading it back.
- [x] 2.2 Update the matching literal-text assertion in
      `scripts/test-devcontainer-image-automation.sh`; verify with
      `task test:devcontainer:image:automation`.

## 3. Verification

- [x] 3.1 Run `task spec:validate` and `task verify`; both green.
