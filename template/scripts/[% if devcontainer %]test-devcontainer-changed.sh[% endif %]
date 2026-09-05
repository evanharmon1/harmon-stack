#!/usr/bin/env bash
# test-devcontainer-changed.sh — regression for the devcontainer change
# detector.
#
# Every case here is a way the required `devcontainer-verify` check could go
# wrong: a false `false` skips validation on a real devcontainer change, and
# a detector that errors out wedges the check entirely.
set -euo pipefail

fail() {
    echo "TEST FAIL: $*" >&2
    exit 1
}

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
helper="$repo_root/scripts/devcontainer-changed.sh"

tmp="$(mktemp -d -t test-devcontainer-changed-XXXXXX)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

repo="$tmp/repo"
mkdir -p "$repo/.devcontainer" "$repo/src" "$repo/.github/workflows" "$repo/scripts"
cd "$repo"
git init -q .
git config user.email test@example.com
git config user.name Test

printf '%s\n' 'FROM scratch' >.devcontainer/Dockerfile
printf '%s\n' 'x' >src/app.js
printf '%s\n' 'name: Devcontainer Build' >.github/workflows/devcontainer-build.yml
printf '%s\n' '#!/usr/bin/env bash' >scripts/verify-ci-results.sh
printf '%s\n' '#!/usr/bin/env bash' >scripts/devcontainer-assert.sh
printf '%s\n' '#!/usr/bin/env bash' >scripts/devcontainer-smoke.sh
git add -A
git commit -qm base
base="$(git rev-parse HEAD)"

# ── an unrelated change is a no-op ──────────────────────────────────
printf '%s\n' 'y' >src/app.js
git commit -qam "unrelated"
[ "$("$helper" "$base" HEAD)" = false ] ||
    fail "a change touching only src/ was reported as a devcontainer change"

# ── a .devcontainer/ change counts ──────────────────────────────────
prev="$(git rev-parse HEAD)"
printf '%s\n' 'FROM ghcr.io/evanharmon1/harmon-devcontainer:pinned' >.devcontainer/Dockerfile
git commit -qam "devcontainer"
[ "$("$helper" "$prev" HEAD)" = true ] ||
    fail "a change under .devcontainer/ was not detected"

# ── a nested .devcontainer/ change counts ───────────────────────────
prev="$(git rev-parse HEAD)"
mkdir -p .devcontainer/dev
printf '%s\n' '{}' >.devcontainer/dev/devcontainer.json
git add -A
git commit -qm "nested"
[ "$("$helper" "$prev" HEAD)" = true ] ||
    fail "a change under .devcontainer/dev/ was not detected"

# ── editing the workflow counts: it decides how the container is built ──
prev="$(git rev-parse HEAD)"
printf '%s\n' '# edited' >>.github/workflows/devcontainer-build.yml
git commit -qam "workflow"
[ "$("$helper" "$prev" HEAD)" = true ] ||
    fail "a change to the devcontainer-build.yml workflow itself was not detected"

# ── each watched script counts ──────────────────────────────────────
for script in verify-ci-results devcontainer-assert devcontainer-smoke; do
    prev="$(git rev-parse HEAD)"
    printf '%s\n' '# edited' >>"scripts/${script}.sh"
    git commit -qam "edit ${script}"
    [ "$("$helper" "$prev" HEAD)" = true ] ||
        fail "a change to scripts/${script}.sh was not detected"
done

# ── the detector script itself counts (it decides its own coverage) ─────
prev="$(git rev-parse HEAD)"
printf '%s\n' '#!/usr/bin/env bash' >scripts/devcontainer-changed.sh
git add -A
git commit -qm "add detector"
[ "$("$helper" "$prev" HEAD)" = true ] ||
    fail "a change to scripts/devcontainer-changed.sh itself was not detected"

# ── a path that merely starts with the same letters does NOT ────────
# `.devcontainer-notes.md` must not match the `.devcontainer/` prefix.
prev="$(git rev-parse HEAD)"
printf '%s\n' 'notes' >.devcontainer-notes.md
git add -A
git commit -qm "lookalike"
[ "$("$helper" "$prev" HEAD)" = false ] ||
    fail "a path merely prefixed '.devcontainer' was treated as a devcontainer change"

# ── moving a file OUT of .devcontainer/ counts ──────────────────────
# Rename detection reports only the DESTINATION path, so moving a file out of
# .devcontainer/ can hide the fact that .devcontainer/ lost it. Only
# `--no-renames` makes the source side visible. The moved file is
# deliberately NOT matched by any other rule at its destination, so this
# case would pass with --no-renames reverted and prove nothing.
prev="$(git rev-parse HEAD)"
mkdir -p .devcontainer/config docs
printf '%s\n' 'asset content' >.devcontainer/config/asset.txt
git add -A
git commit -qm "add config asset"
prev="$(git rev-parse HEAD)"
git mv .devcontainer/config/asset.txt docs/asset.txt
git commit -qm "move out"
[ "$("$helper" "$prev" HEAD)" = true ] ||
    fail "moving a file OUT of .devcontainer/ was not detected (rename hid the source path)"
git mv docs/asset.txt .devcontainer/config/asset.txt
git commit -qm "move back"

# ── deletions count as changes ───────────────────────────────────────
prev="$(git rev-parse HEAD)"
git rm -q .devcontainer/dev/devcontainer.json
git commit -qm "delete"
[ "$("$helper" "$prev" HEAD)" = true ] ||
    fail "deleting a devcontainer file was not detected"

# ── fail-safe: unusable input must answer true, never false ─────────
[ "$("$helper" "" HEAD 2>/dev/null)" = true ] ||
    fail "an empty base must fail safe to changed=true"
[ "$("$helper" 0000000000000000000000000000000000000000 HEAD 2>/dev/null)" = true ] ||
    fail "an all-zero base (branch creation) must fail safe to changed=true"
[ "$("$helper" deadbeefdeadbeefdeadbeefdeadbeefdeadbeef HEAD 2>/dev/null)" = true ] ||
    fail "a base missing from the clone must fail safe to changed=true"
[ "$("$helper" "$base" deadbeefdeadbeefdeadbeefdeadbeefdeadbeef 2>/dev/null)" = true ] ||
    fail "a head missing from the clone must fail safe to changed=true"

# ── the workflow reads this from $GITHUB_OUTPUT, not stdout ─────────
out="$tmp/gh-output"
: >"$out"
GITHUB_OUTPUT="$out" "$helper" "$base" HEAD >/dev/null
grep -q '^changed=true$' "$out" ||
    fail "changed= was not written to \$GITHUB_OUTPUT"

echo "Devcontainer change-detection regression: PASS"
