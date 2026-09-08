#!/usr/bin/env bash
# test-devcontainer-git-ownership.sh — regression coverage for bind-mounted
# workspace ownership and Git's exact safe.directory fallback.
#
# The fixture cannot change a host checkout's owner without relying on sudo, so
# it records the privileged reconciliation commands instead. The command log
# proves the real post-create function targets only the resolved workspace and
# its hooks directory; the Linux bot devcontainer smoke test remains the
# decisive check of a real UID-mismatched bind mount.
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
    echo "TEST FAIL: $*" >&2
    exit 1
}

post_create=".devcontainer/scripts/post-create-common.sh"
[ -r "$post_create" ] || fail "$post_create not found"

tmp_root="$(mktemp -d -t harmon-git-ownership-XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

# Extract the production functions verbatim. This keeps the fixture attached
# to the implementation instead of growing a second, drifting copy of the
# ownership algorithm.
helpers="${tmp_root}/workspace-helpers.sh"
sed -n '/^resolve_workspace_root()/,/^# --- End workspace ownership reconciliation ---$/p' \
    "$post_create" | sed '$d' >"$helpers"
[ -s "$helpers" ] || fail "could not extract workspace ownership helpers"
grep -q '^reconcile_workspace_ownership()' "$helpers" ||
    fail "the extracted helpers do not include reconcile_workspace_ownership"

# The reconciliation must happen before the first explicit repository write.
reconcile_line="$(grep -n '^WORKSPACE_ROOT="' "$post_create" | head -1 | cut -d: -f1)"
lefthook_line="$(grep -n '^    lefthook install$' "$post_create" | head -1 | cut -d: -f1)"
[ -n "$reconcile_line" ] && [ -n "$lefthook_line" ] ||
    fail "could not locate reconciliation or lefthook install in $post_create"
[ "$reconcile_line" -lt "$lefthook_line" ] ||
    fail "workspace reconciliation occurs after lefthook install"

fixture="${tmp_root}/fixture"
repo="${fixture}/workspaces/example"
unrelated="${fixture}/unrelated"
home="${fixture}/home"
xdg="${fixture}/xdg"
fake_bin="${fixture}/bin"
log="${fixture}/sudo.log"
mkdir -p "$repo" "$unrelated" "$home" "$xdg/git" "$fake_bin"
repo="$(cd "$repo" && pwd -P)"
unrelated="$(cd "$unrelated" && pwd -P)"

git -C "$repo" init -q
mkdir -p "$repo/.git/hooks" "$repo/subdirectory"
git -C "$repo" config --file "$xdg/git/config" --add safe.directory '*'
chmod 0500 "$repo/.git/hooks"

# The real post-create script invokes sudo; this fixture records the exact
# target while allowing chmod to operate on the fixture's own hook directory.
cat >"$fake_bin/sudo" <<'SUDO'
#!/bin/sh
set -eu
printf '%s\n' "$*" >>"${SUDO_LOG:?SUDO_LOG is required}"
case "${1:-}" in
chown)
    exit 0
    ;;
chmod|mkdir)
    "$@"
    ;;
*)
    "$@"
    ;;
esac
SUDO
chmod 0755 "$fake_bin/sudo"

run_reconcile() {
    (
        cd "$repo"
        HOME="$home" XDG_CONFIG_HOME="$xdg" SUDO_LOG="$log" \
            PATH="$fake_bin:$PATH" bash -c \
            '. "$1"; reconcile_workspace_ownership "$2"' _ "$helpers" "$xdg/git/config"
    )
}

echo "==> a mismatched workspace requests reconciliation at the exact root"
resolved="$(run_reconcile)"
[ "$resolved" = "$repo" ] ||
    fail "resolved workspace root was '$resolved', expected '$repo'"
owner="$(id -un):$(id -gn)"
grep -Fqx "chown -R ${owner} ${repo}" "$log" ||
    fail "workspace ownership was not reconciled at the resolved root"
grep -Fqx "chown -R ${owner} ${repo}/.git/hooks" "$log" ||
    fail "Git hooks ownership was not reconciled at the exact hooks path"
grep -Fqx "chmod u+rwx ${repo}/.git/hooks" "$log" ||
    fail "Git hooks were not made writable"
! grep -Fq "$unrelated" "$log" ||
    fail "ownership reconciliation touched an unrelated path"
[ -w "$repo/.git/hooks" ] || fail "the hook fixture is not writable after reconciliation"

echo "==> the exact safe.directory entry is added beside, not replaced by, a wildcard"
safe_entries="$(HOME="$home" XDG_CONFIG_HOME="$xdg" \
    git config --file "$xdg/git/config" --get-all safe.directory)"
[ "$(printf '%s\n' "$safe_entries" | grep -Fxc "$repo")" -eq 1 ] ||
    fail "the exact workspace safe.directory entry is missing or duplicated: ${safe_entries}"
[ "$(printf '%s\n' "$safe_entries" | grep -Fxc '*')" -eq 1 ] ||
    fail "the pre-existing wildcard safe.directory entry was unexpectedly rewritten"
actual_root="$(HOME="$home" XDG_CONFIG_HOME="$xdg" \
    git -C "$repo" rev-parse --path-format=absolute --show-toplevel)"
[ "$actual_root" = "$repo" ] ||
    fail "Git did not inspect the exact safe workspace: ${actual_root}"

echo "==> repeated post-create ownership reconciliation is idempotent"
run_reconcile >/dev/null
safe_entries="$(HOME="$home" XDG_CONFIG_HOME="$xdg" \
    git config --file "$xdg/git/config" --get-all safe.directory)"
[ "$(printf '%s\n' "$safe_entries" | grep -Fxc "$repo")" -eq 1 ] ||
    fail "repeated reconciliation duplicated safe.directory: ${safe_entries}"

echo "==> hooks paths outside the workspace are rejected before mutation"
git -C "$repo" config core.hooksPath "$unrelated/hooks"
before_lines="$(wc -l <"$log" | tr -d ' ')"
set +e
run_reconcile >/dev/null 2>"${tmp_root}/outside.err"
outside_rc=$?
set -e
[ "$outside_rc" -ne 0 ] ||
    fail "an out-of-workspace hooks path was accepted"
[ "$(wc -l <"$log" | tr -d ' ')" = "$before_lines" ] ||
    fail "an out-of-workspace hooks path triggered ownership mutation"

echo "devcontainer git ownership: all cases passed"
