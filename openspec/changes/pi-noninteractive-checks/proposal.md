## Why

The `devcontainer/bot-autonomy` spec's manual-validation and default-answer
scenarios ask the maintainer to run a representative pi operation and observe
zero prompts, but do not constrain pi to a non-interactive mode. Only
`pi -p`, `--mode json`, and `--mode rpc` carry the no-prompt guarantee this
same spec documents elsewhere (pi's "no elevated trust" requirement): bare
interactive `pi` against a repository with untrusted `.pi/` resources can
still present pi's trust prompt. Read literally, the two scenarios could be
satisfied by an invocation the rest of the spec never guarantees is
prompt-free. The same ambiguity exists one level down, in the pin-PR
handoff checklist `scripts/sync-devcontainer-image.sh` generates for a
human to run by hand.

## What Changes

- Tighten the two manual-verification scenarios under `devcontainer/
  bot-autonomy`'s "End-to-end effective autonomy" requirement
  ("representative operations complete without a prompt when every
  Copier-gated harness is enabled" and "each Copier-gated harness stays
  prompt-enabled by design at its default answer") to name pi's
  non-interactive invocation (`pi -p`, `--mode json`, or `--mode rpc`)
  explicitly, instead of leaving pi's invocation unqualified.
- Update the pi item in the reviewer checklist `scripts/
  sync-devcontainer-image.sh`'s `write_body()` generates to name the same
  non-interactive form, and extend `scripts/
  test-devcontainer-image-automation.sh` to assert the new literal text.

## Non-goals

- Does not change pi's actual runtime behavior, trust posture, or the
  maintainer's "no elevated trust" decision — pi's non-interactive modes
  already never prompt for trust; this change only tightens the wording of
  the scenarios and checklist that verify it.
- Does not touch oh-my-pi's scenarios or checklist item. Oh-my-pi's
  no-prompt guarantee comes from its persisted `tools.approvalMode: yolo`
  config, not from an invocation flag, so it carries none of the
  bare-interactive ambiguity this change closes for pi.
- Does not change Copilot CLI's, Claude Code's, Codex's, Antigravity's, or
  OpenCode's scenario wording, or any other requirement in this spec.
- Does not modify `template/` — this is a root-only spec and script fix.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `devcontainer/bot-autonomy`: the "End-to-end effective autonomy"
  requirement's two manual-verification scenarios now name pi's
  non-interactive invocation instead of leaving it unqualified.

## Impact

- `openspec/specs/devcontainer/bot-autonomy/spec.md` (synced from this
  change's delta spec)
- `scripts/sync-devcontainer-image.sh` (`write_body()`'s reviewer checklist)
- `scripts/test-devcontainer-image-automation.sh` (the matching literal-text
  assertion)
- No behavior change: pi already satisfies the no-prompt guarantee in its
  non-interactive modes. This is a documentation/spec and checklist-wording
  fix only.
