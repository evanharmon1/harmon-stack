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
ownership_find_line="$(grep -n '^        sudo find' "$post_create" | head -1 | cut -d: -f1)"
canonical_line="$(grep -n '^    canonical_workspace_root=.*sudo git' "$post_create" | head -1 | cut -d: -f1)"
[ -n "$reconcile_line" ] && [ -n "$lefthook_line" ] ||
    fail "could not locate reconciliation or lefthook install in $post_create"
[ "$reconcile_line" -lt "$lefthook_line" ] ||
    fail "workspace reconciliation occurs after lefthook install"
[ -n "$ownership_find_line" ] && [ -n "$canonical_line" ] ||
    fail "could not locate ownership repair or Git canonicalization in $post_create"
[ "$canonical_line" -lt "$ownership_find_line" ] ||
    fail "Git boundary validation occurs after ownership repair"

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
mkdir -p "$repo/.git/hooks" "$repo/.venv" "$repo/subdirectory"
git -C "$repo" config --file "$xdg/git/config" --add safe.directory '*'
chmod 0500 "$repo/.git/hooks"
chmod 0700 "$repo/.git"

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
find)
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

cat >"$fake_bin/mountpoint" <<'MOUNTPOINT'
#!/bin/sh
set -eu
[ "${1:-}" = "-q" ]
[ "${MOUNTPOINT_MODE:-mounted}" = "mounted" ]
MOUNTPOINT
chmod 0755 "$fake_bin/mountpoint"

run_reconcile_at() {
    target_repo="$1"
    target_config="$2"
    target_log="$3"
    (
        cd "$target_repo"
        HOME="$home" XDG_CONFIG_HOME="$xdg" SUDO_LOG="$target_log" \
            MOUNTPOINT_MODE="${MOUNTPOINT_MODE:-mounted}" \
            PATH="$fake_bin:$PATH" bash -c \
            '. "$1"; reconcile_workspace_ownership "$2"' _ "$helpers" "$target_config"
    )
}
run_reconcile() {
    run_reconcile_at "$repo" "$xdg/git/config" "$log"
}

echo "==> a mismatched workspace requests reconciliation at the exact root"
resolved="$(run_reconcile)"
[ "$resolved" = "$repo" ] ||
    fail "resolved workspace root was '$resolved', expected '$repo'"
container_user="$(id -un)"
grep -Fqx "find ${repo} -xdev -path ${repo}/.venv -prune -o ! -user ${container_user} -exec chown -h ${container_user} {} +" "$log" ||
    fail "workspace ownership was not reconciled at the resolved root"
grep -Fqx "chown ${container_user} ${repo}/.git/hooks" "$log" ||
    fail "Git hooks ownership was not reconciled at the exact hooks path"
! grep -Fq "chown ${container_user}:" "$log" ||
    fail "Git hooks ownership repair reset a shared group"
grep -Fqx "chmod u+rwx ${repo}/.git/hooks" "$log" ||
    fail "Git hooks were not made writable"
! grep -Fq "$unrelated" "$log" ||
    fail "ownership reconciliation touched an unrelated path"
[ -w "$repo/.git/hooks" ] || fail "the hook fixture is not writable after reconciliation"

echo "==> unexpected nested mounts are rejected before ownership mutation"
mountinfo="${fixture}/mountinfo"
printf '42 35 0:42 / %s rw,relatime - bind /source rw,relatime\n' \
    "$repo/.venv" >"$mountinfo"
if ! bash -c '. "$1"; reject_unexpected_workspace_mounts "$2" "$3"' \
    _ "$helpers" "$repo" "$mountinfo"; then
    fail "the configured .venv mount was unexpectedly rejected"
fi
printf '43 35 0:43 / %s rw,relatime - bind /source rw,relatime\n' \
    "$repo/foreign-mount" >>"$mountinfo"
if bash -c '. "$1"; reject_unexpected_workspace_mounts "$2" "$3"' \
    _ "$helpers" "$repo" "$mountinfo" 2>"${tmp_root}/mount.err"; then
    fail "an unexpected nested mount was accepted"
fi
grep -Fq "unexpected nested mount" "${tmp_root}/mount.err" ||
    fail "nested mount rejection did not explain the workspace boundary"

echo "==> an ordinary in-workspace .venv is included instead of pruned"
: >"$log"
MOUNTPOINT_MODE=unmounted run_reconcile >/dev/null
grep -Fqx "find ${repo} -xdev ! -user ${container_user} -exec chown -h ${container_user} {} +" "$log" ||
    fail "an ordinary in-workspace .venv was not included in ownership repair"
! grep -Fq "${repo}/.venv -prune" "$log" ||
    fail "an ordinary in-workspace .venv was unexpectedly pruned"

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

echo "==> a nested checkout cannot expand ownership reconciliation into its parent"
escape_parent="${fixture}/workspaces/parent"
escape_repo="${escape_parent}/nested"
escape_xdg="${fixture}/escape-xdg"
escape_log="${fixture}/escape-sudo.log"
mkdir -p "$escape_repo" "$escape_xdg/git"
git -C "$escape_parent" init -q
git -C "$escape_repo" init -q
git -C "$escape_repo" config core.worktree ../..
if run_reconcile_at "$escape_repo" "$escape_xdg/git/config" "$escape_log" >/dev/null 2>"${tmp_root}/escape.err"; then
    fail "a nested checkout with an expanding core.worktree was accepted"
fi
grep -Fq "outside the discovered workspace" "${tmp_root}/escape.err" ||
    fail "the nested checkout rejection did not explain the workspace boundary"
! grep -Eq '^(find|chown|chmod|mkdir) ' "$escape_log" ||
    fail "the rejected nested checkout triggered privileged ownership changes"

echo "==> missing in-workspace hooks ancestors become writable"
git -C "$repo" config core.hooksPath .config/git/hooks
run_reconcile >/dev/null
for directory in "$repo/.config" "$repo/.config/git" "$repo/.config/git/hooks"; do
    [ -d "$directory" ] || fail "hooks ancestor was not created: ${directory}"
    [ -w "$directory" ] || fail "hooks ancestor is not writable: ${directory}"
done

echo "==> hooks paths outside the workspace are left unchanged"
git -C "$repo" config core.hooksPath "$unrelated/hooks"
outside_resolved="$(run_reconcile 2>"${tmp_root}/outside.err")"
[ "$outside_resolved" = "$repo" ] ||
    fail "an out-of-workspace hooks path changed the resolved workspace: ${outside_resolved}"
! grep -Fq "$unrelated" "$log" ||
    fail "an out-of-workspace hooks path triggered ownership mutation"

echo "devcontainer git ownership: all cases passed"
