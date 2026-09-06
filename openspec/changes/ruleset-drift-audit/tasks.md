## 1. Audit implementation

- [x] 1.1 Add the root `scripts/audit-ruleset.sh` comparison command and verify shellcheck/shfmt pass plus fixture-mode exit behavior.
- [x] 1.2 Add the root `audit:ruleset` Taskfile target and verify it invokes the script with a trivial command definition.
- [x] 1.3 Add fixture-driven `scripts/test-audit-ruleset.sh` coverage for identical, missing context, extra live flag, absent ruleset, and permission-denied cases; verify the test passes without network.

## 2. Template parity and profile coverage

- [x] 2.1 Add the script and task to the template twin in lockstep and verify dogfood parity/structure checks pass.
- [x] 2.2 Verify rendered ruleset profiles retain the correct conditional `codeql-verify`, `terraform-verify`, and `devcontainer-verify` contexts.

## 3. Documentation

- [x] 3.1 Document `task audit:ruleset` beside the required-check update procedure in root and template branch-protection architecture docs, including the manual UI apply rationale; verify markdown lint.

## 4. Integrated verification

- [x] 4.1 Wire the unit test into the repository test tier and verify the standalone and task-based test targets pass.
- [ ] 4.2 Run `openspec validate --all`, `task spec:validate`, `task check`, `task verify`, and `task security`; verify all required gates are green.
- [ ] 4.3 Run `task audit:ruleset` once against the live repository and record its readable result for the draft PR report.
