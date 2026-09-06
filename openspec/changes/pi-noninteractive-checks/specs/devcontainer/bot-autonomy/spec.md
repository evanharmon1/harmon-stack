## MODIFIED Requirements

### Requirement: End-to-end effective autonomy
A freshly rebuilt, generated bot devcontainer SHALL run a representative
filesystem operation and a representative GitHub operation through each
authenticated, in-scope, and (for a Copier-gated harness) enabled harness
with zero approval prompts. For a Copier-gated harness whose option is at
its default (disabled), the *absence* of a prompt-free run is the
correct, by-design outcome — not a gap this requirement expects closed.

#### Scenario: representative operations complete without a prompt when every Copier-gated harness is enabled (manual verification)
- **WHEN** an operator rebuilds a freshly generated bot devcontainer with
  `use_antigravity_cli: true` and `use_copilot_cli: true` and, for each of
  Claude Code, Codex, Antigravity, OpenCode, Copilot CLI, pi — invoked
  non-interactively as `pi -p "<prompt>"`, `--mode json`, or `--mode rpc`,
  never bare interactive `pi`, the only invocations the no-prompt
  guarantee below covers — and oh-my-pi, authenticates the harness and
  runs one representative filesystem write and one representative GitHub
  API read/write
- **THEN** every operation completes without an approval prompt from any
  of the seven harnesses

#### Scenario: each Copier-gated harness stays prompt-enabled by design at its default answer (manual verification)
- **WHEN** an operator rebuilds a freshly generated bot devcontainer with
  `use_antigravity_cli` and `use_copilot_cli` left at their defaults
  (disabled) and, for each of Claude Code, Codex, Antigravity, OpenCode,
  Copilot CLI, pi — invoked non-interactively as above — and oh-my-pi,
  authenticates the harness and runs the same representative operations
- **THEN** Claude Code, Codex, OpenCode, pi, and oh-my-pi complete without
  an approval prompt, and Antigravity and Copilot CLI each prompt as they
  would out of the box — a prompt-enabled Antigravity CLI and Copilot CLI
  at their default answers is the verified-correct outcome (per the
  disabled-by-option requirements above), not a failure of this
  requirement
