#!/usr/bin/env bash
# devcontainer-changed.sh — decide whether a range of commits touches the
# devcontainer.
#
# devcontainer-build.yml deliberately carries NO top-level `paths:` filter,
# because `devcontainer-verify` is a required status check: a filtered
# workflow never reports on unrelated PRs, and a required check that never
# reports blocks the merge forever. So the workflow always runs and decides
# internally, and this is that decision.
#
# usage: devcontainer-changed.sh <base_sha> <head_sha>
#   prints `true` or `false` (also written to $GITHUB_OUTPUT as changed=...)
#
# Fails SAFE: anything it cannot determine — a missing/unknown sha, a shallow
# clone, the very first push — answers `true`. A wrong `true` costs one CI
# run; a wrong `false` waves an unvalidated devcontainer change straight
# through the required check.
set -euo pipefail

base="${1:-}"
head="${2:-HEAD}"

# Paths whose change means the devcontainer must be rebuilt and re-asserted:
#
#   .devcontainer/**                    the container definition itself
#   the workflow itself                 it decides how the container is
#                                        built, cached, and asserted
#   scripts/verify-ci-results.sh        the aggregator's own result-checking
#                                        helper
#   scripts/devcontainer-assert.sh      the fail-closed policy assertions run
#                                        inside the built container
#   scripts/devcontainer-smoke.sh       starts the container and drives the
#                                        assertion above
#   scripts/devcontainer-changed.sh     this file: it decides whether any of
#                                        the above need to run at all
matches_devcontainer() {
    grep -qE '(^\.devcontainer/|^\.github/workflows/devcontainer-build\.yml$|^scripts/(verify-ci-results|devcontainer-assert|devcontainer-smoke|devcontainer-changed)\.sh$)'
}

emit() {
    echo "$1"
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "changed=$1" >>"$GITHUB_OUTPUT"
    fi
    exit 0
}

# No base to compare against. Three ways to get here, all answering `true`:
# branch creation (all-zero sha), an event with no range (workflow_dispatch),
# and an event that reconciles BY DESIGN — a push to main, where an
# incremental before..after range can be stepped over by concurrency
# replacement (see the terraform-changes precedent this mirrors, in
# .github/workflows/terraform.yml.jinja).
case "$base" in
"" | 0000000000000000000000000000000000000000)
    echo "devcontainer-changed: no comparison range (base='${base}') — reconciling" >&2
    emit true
    ;;
esac

if ! git cat-file -e "${base}^{commit}" 2>/dev/null; then
    echo "devcontainer-changed: base $base is not in this clone — assuming changed" >&2
    emit true
fi
if ! git cat-file -e "${head}^{commit}" 2>/dev/null; then
    echo "devcontainer-changed: head $head is not in this clone — assuming changed" >&2
    emit true
fi

# `git diff` (two dots) rather than a merge-base range: the question is which
# files differ between what is deployed and what is proposed, not which
# commits are unique to the branch.
#
# --no-renames is load-bearing. With rename detection on (the default),
# moving .devcontainer/Dockerfile to docs/Dockerfile reports ONLY the
# destination path, so deleting the devcontainer definition by moving it out
# would look like "no devcontainer change" and skip validation. --no-renames
# reports both sides.
if ! changed_files="$(git diff --name-only --no-renames "$base" "$head" 2>/dev/null)"; then
    echo "devcontainer-changed: could not diff $base..$head — assuming changed" >&2
    emit true
fi

if printf '%s\n' "$changed_files" | matches_devcontainer; then
    emit true
fi

emit false
