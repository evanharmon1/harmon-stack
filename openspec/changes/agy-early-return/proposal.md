## Why

`ensure-antigravity-cli.sh`'s system-binary-sufficient early return exits
without inspecting a pre-existing `~/.local/bin/agy`, so a stale symlink (for
example one left behind after an older image's `agy-real` was removed) can
survive indefinitely — contradicting the bot-autonomy spec's launcher
invariant ("never a dangling symlink"). A first attempt to fix this, on the
branch for issue `#1168`, removed whatever it found unconditionally and was
reverted after challenge round 4 found a P1: it could delete a still-valid
wrapper before its replacement was guaranteed, if the settings-apply step that
runs first in `bot-autonomy/antigravity.sh`'s `cmd_apply` failed. The
reconciliation spec now documents the unresolved gap as launcher state
**(d) unreconciled** (`openspec/specs/devcontainer/bot-autonomy/spec.md`).
Issue `#1171` tracks a narrower, ordered fix; this change proposes and
implements it.

## What Changes

- `ensure-antigravity-cli.sh` (+ its verbatim `template/` twin): on the
  system-binary-sufficient early return, remove `~/.local/bin/agy` only when
  it is a dangling symlink or a symlink to an existing directory. A dangling
  symlink is already a broken launcher on its own; a symlink to an existing
  directory would make `bot-autonomy/antigravity.sh`'s `install_wrapper` —
  its unguarded `mv -f` — land inside that directory instead of replacing
  the link (a later `ln -sfn` replaces a symlink-to-directory cleanly and is
  not the concern). Every other pre-existing value — a regular file, a
  valid wrapper, or a
  symlink to an existing file — is left exactly as found. Nothing is ever
  deleted before a replacement exists on any other path; this branch
  continues to install nothing itself.
- `scripts/test-bot-autonomy.sh` (+ its verbatim `template/` twin): add
  fixtures covering the dangling-symlink and symlink-to-directory removal
  cases, the valid-wrapper and arbitrary-regular-file preservation cases, a
  symlink-to-an-existing-file preservation case (the negative case that
  proves the guard removes only the two breaking shapes, not every symlink),
  and a regression fixture confirming that a settings-apply failure inside
  `antigravity.sh`'s `cmd_apply` still aborts before `install_wrapper` runs,
  so a previously-installed valid wrapper survives untouched.
- `openspec/specs/devcontainer/bot-autonomy/spec.md`: with the early return
  now reconciling both breaking shapes, launcher state (d) never occurs after
  `ensure-antigravity-cli.sh` runs, in either profile. Collapse the "exactly
  one of four states" requirement (and its scenarios) back to three states,
  drop the state-(d)/#1171 exception from every scenario that carries it, and
  make the "`install_wrapper` always replaces cleanly" claim unconditional —
  a later `ln -sfn` already replaces a symlink-to-directory cleanly on its
  own and needed no such claim.
- `docs/guides/devcontainers.md` (+ its jinja `template/` twin): drop the
  state-(d)/#1171 caveat in the Antigravity section now that the early return
  self-heals a leftover that would otherwise block reconciliation.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `devcontainer/bot-autonomy`: the Antigravity launcher invariant
  (`~/.local/bin/agy` is exactly one of three states, never a dangling
  symlink or an unreplaceable symlink-to-directory) now holds unconditionally
  after `ensure-antigravity-cli.sh` runs, in both the bot and dev profiles —
  closing the state-(d) exception #1171 tracks.

## Impact

- Code: `.devcontainer/config/ensure-antigravity-cli.sh` and its `template/`
  twin (verbatim); `scripts/test-bot-autonomy.sh` and its `template/` twin
  (verbatim).
- Spec: `openspec/specs/devcontainer/bot-autonomy/spec.md` (the "Antigravity's
  launcher is exactly one of four states" requirement, renamed to three, and
  the "Human dev profile is unaffected by construction" requirement's
  scenario that carries the state-(d) exception).
- Docs: `docs/guides/devcontainers.md` and its `template/` jinja twin.
- No new Copier answer, environment variable, or external dependency. No
  change to `bot-autonomy/antigravity.sh`'s existing settings-apply-then-
  install_wrapper ordering — that ordering is already correct; this change
  only adds regression coverage confirming it.
