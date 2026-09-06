## Context

The repository already stores an importable ruleset JSON and has root/template task and documentation twins. GitHub's ruleset API returns server-owned identifiers and timestamps that cannot be compared meaningfully with the file. See proposal.md and the delta spec for the user-visible contract.

## Goals / Non-Goals

**Goals:**

- Keep the audit portable across the root repository and generated repositories.
- Make comparison deterministic and readable in both success and drift cases.
- Keep network interaction isolated so fixture tests remain hermetic.

**Non-Goals:**

- Automating ruleset application; the maintainer continues to apply changes in GitHub Settings because the REST update/create path is not a safe idempotent replacement for the UI and has known rule compatibility issues.

## Decisions

- **Use a shell entry point with injectable JSON fixtures.** The task calls one `scripts/*.sh` file, while an environment-controlled fixture mode lets unit tests exercise the same normalization and exit behavior without network. This follows the repository's shell portability and trivial Taskfile command conventions. A language-specific test harness was rejected because it would duplicate the comparison logic.
- **Normalize with `jq`.** Remove server metadata (`id`, `integration_id`, timestamps, `_links`) and sort rules and required-check contexts by stable keys before comparing. Textual JSON formatting is not significant. Hand-written normalization was rejected as more error-prone and less readable.
- **Resolve repository identity from the Git remote.** The script derives `{owner}/{repo}` from the named GitHub remote and uses the read-only `gh api` calls for list then detail. A direct API URL or write-capable helper was rejected because it would bypass repository identity and violate the read-only contract.
- **Keep root/template twins synchronized.** The root script and task are concrete dogfood copies; the template script and task are their generated equivalents. The rendered ruleset remains profile-aware through its existing conditionals, and template tests assert the conditional contexts.

## Risks / Trade-offs

- [GitHub API response shape changes] → Normalize only documented comparison metadata, fail as unavailable on malformed responses, and keep fixture coverage for the expected shape.
- [CLI permission or repository discovery failure] → Use exit status 2 and an explicit diagnostic rather than classifying an unknown remote state as clean.
- [Valid server-owned fields differ] → Exclude only fields that GitHub owns and cannot be represented by the import file; policy fields remain compared.

## Migration Plan

Add the task to the root and generated Taskfiles. Consumers can run it after configuring `gh` read access. If drift is reported, a maintainer reviews the diff and updates the live ruleset manually in GitHub Settings or intentionally updates the checked-in import file; no rollback action is performed by the command.
