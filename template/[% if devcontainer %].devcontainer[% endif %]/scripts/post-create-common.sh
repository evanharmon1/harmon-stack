#!/usr/bin/env bash
set -euo pipefail

# Prevent VS Code's JS debug extension from breaking Node.js processes.
# The extension injects NODE_OPTIONS=--require .../bootloader.js, but the
# bootloader may not exist during lifecycle commands (extensions not installed
# yet or workspace storage path is stale). This is a non-interactive context,
# so the shell profile's `unset NODE_OPTIONS` doesn't apply.
unset NODE_OPTIONS
# Prevent a host-exported ANTHROPIC_API_KEY from silently winning over
# CLAUDE_CODE_OAUTH_TOKEN and billing the API account instead.
unset ANTHROPIC_API_KEY

if [ -z "${DEVCONTAINER_GIT_NAME:-}" ] || [ -z "${DEVCONTAINER_GIT_EMAIL:-}" ]; then
    echo "DEVCONTAINER_GIT_NAME and DEVCONTAINER_GIT_EMAIL must be set." >&2
    exit 1
fi

# Shell aliases/functions are version-controlled in .devcontainer/config/ and
# baked into the image at /usr/local/share/devcontainer-config/shell-aliases.sh
# by the Dockerfile. We only wire up the source line in the rc files below.
PROFILE_SOURCE_LINE='source /usr/local/share/devcontainer-config/shell-aliases.sh'

# All runtime git-config writes target the image's XDG environment config
# explicitly. `git config --global` picks its file at runtime — ~/.gitconfig
# when that file exists, the XDG file otherwise — and whether ~/.gitconfig
# exists here depends on whether VS Code's copyGitConfig has copied the host's
# in yet, so --global writes land in a different file per attach mode and per
# lifecycle ordering. Pinning the file makes the environment layer
# deterministic and keeps ~/.gitconfig personal-only (issue #542).
ENV_GITCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/git/config"
mkdir -p "$(dirname "$ENV_GITCONFIG")"

# --- Workspace ownership reconciliation ---
# Git 2.35+ refuses to inspect a bind-mounted repository when the host checkout
# owner differs from the in-container user. Resolve the mounted workspace from
# its .git marker without asking Git first, then add that exact canonical path
# to the environment config before any later command can inspect or write the
# repository. A wildcard safe.directory would hide the mismatch while
# allowing unrelated repositories to be trusted, so it is never used here.
resolve_workspace_root() {
    local candidate="$1"
    while [ "$candidate" != "/" ]; do
        if [ -e "$candidate/.git" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
        candidate="$(dirname "$candidate")"
    done
    return 1
}

workspace_venv_is_mount() {
    local workspace_root="$1"

    [ -d "$workspace_root/.venv" ] || return 1
    command -v mountpoint >/dev/null 2>&1 || return 1
    mountpoint -q "$workspace_root/.venv"
}

reject_unexpected_workspace_mounts() {
    local workspace_root="$1"
    local mountinfo="${2:-/proc/self/mountinfo}"
    local allow_venv_mount="${3:-0}"
    local mount_path mount_paths

    [ -r "$mountinfo" ] || {
        echo "ERROR: workspace mount metadata is unavailable: ${mountinfo}" >&2
        return 1
    }
    mount_paths="$(awk -v root="$workspace_root" '
        {
            mount_path = $5
            gsub(/\\040/, " ", mount_path)
            gsub(/\\011/, "\t", mount_path)
            gsub(/\\134/, "\\", mount_path)
            if (index(mount_path, root "/") == 1) {
                print mount_path
            }
        }
    ' "$mountinfo")" || return 1
    while IFS= read -r mount_path; do
        case "$mount_path" in
        "$workspace_root")
            ;;
        "$workspace_root/.venv" | "$workspace_root/.venv"/*)
            if [ "$allow_venv_mount" -ne 1 ]; then
                echo "ERROR: refusing to reconcile an unexpected nested mount inside the workspace: ${mount_path}" >&2
                return 1
            fi
            ;;
        "$workspace_root"/*)
            echo "ERROR: refusing to reconcile an unexpected nested mount inside the workspace: ${mount_path}" >&2
            return 1
            ;;
        esac
    done <<EOF
$mount_paths
EOF
}

reconcile_workspace_ownership() {
    local env_gitconfig="$1"
    local workspace_root canonical_workspace_root git_dir default_hooks_dir hooks_dir container_user venv_is_mount

    workspace_root="$(resolve_workspace_root "$(pwd -P)")" || {
        echo "ERROR: could not resolve the repository/workspace root from $(pwd -P)" >&2
        return 1
    }
    [ "$workspace_root" != "/" ] || {
        echo "ERROR: refusing to reconcile the filesystem root as a workspace" >&2
        return 1
    }

    # This read is deliberately an exact-line match. An existing wildcard (or
    # another repository path) does not satisfy the workspace's own entry.
    if ! git config --file "$env_gitconfig" --get-all safe.directory 2>/dev/null |
        grep -Fqx "$workspace_root"; then
        git config --file "$env_gitconfig" --add safe.directory "$workspace_root" || return 1
    fi

    container_user="$(id -un)" || return 1
    # Let root perform this read-only boundary check: a mismatched checkout can
    # have a private .git directory whose owner prevents the container user
    # from canonicalizing it. The exact -c entry keeps this probe scoped to the
    # discovered workspace. Generated Python projects mount .venv as a
    # container-private volume; prune that path only when it is actually
    # mounted, so an ordinary in-workspace .venv is reconciled.
    canonical_workspace_root="$(sudo git -C "$workspace_root" \
        -c "safe.directory=$workspace_root" \
        rev-parse --path-format=absolute --show-toplevel)" || {
        echo "ERROR: Git could not resolve the repository/workspace root at ${workspace_root}" >&2
        return 1
    }
    canonical_workspace_root="$(cd "$canonical_workspace_root" && pwd -P)" || {
        echo "ERROR: Git reported an unusable repository/workspace root: ${canonical_workspace_root}" >&2
        return 1
    }
    [ "$canonical_workspace_root" = "$workspace_root" ] || {
        echo "ERROR: Git resolved a repository/workspace root outside the discovered workspace: ${canonical_workspace_root}" >&2
        return 1
    }
    venv_is_mount=0
    if workspace_venv_is_mount "$workspace_root"; then
        venv_is_mount=1
    fi
    case "$(uname -s)" in
    Linux)
        reject_unexpected_workspace_mounts "$workspace_root" /proc/self/mountinfo "$venv_is_mount" || return 1
        ;;
    *)
        # The production container is Linux. Keep the helper runnable from
        # macOS bash 3.2 tests, where procfs is not present; if a non-Linux
        # environment does expose mountinfo, retain the same guard there.
        if [ -r /proc/self/mountinfo ]; then
            reject_unexpected_workspace_mounts "$workspace_root" /proc/self/mountinfo "$venv_is_mount" || return 1
        fi
        ;;
    esac

    # Repair ownership before the container user reads repository metadata.
    # -xdev handles mounts on a different device, while -user avoids issuing
    # needless chowns on already-reconciled entries. Changing only the owner
    # preserves host-provided shared groups, and -h ensures an in-workspace
    # symlink cannot redirect chown to an external target.
    if [ "$venv_is_mount" -eq 1 ]; then
        sudo find "$workspace_root" -xdev \
            -path "$workspace_root/.venv" -prune -o \
            ! -user "$container_user" -exec chown -h "$container_user" {} + || return 1
    else
        sudo find "$workspace_root" -xdev \
            ! -user "$container_user" -exec chown -h "$container_user" {} + || return 1
    fi

    git_dir="$(git -C "$workspace_root" rev-parse --path-format=absolute --absolute-git-dir)" || {
        echo "ERROR: Git could not resolve the Git directory for ${workspace_root}" >&2
        return 1
    }
    default_hooks_dir="${git_dir%/}/hooks"
    case "$default_hooks_dir" in
    "$workspace_root"/*) ;;
    *)
        echo "ERROR: refusing to reconcile a default hooks directory outside the workspace: ${default_hooks_dir}" >&2
        return 1
        ;;
    esac

    # post-create.sh copies the repository's managed hooks to .git/hooks even
    # when Git's effective core.hooksPath is a user-managed path elsewhere.
    # Create and repair that default directory without following symlinks.
    if [ ! -L "$default_hooks_dir" ]; then
        ensure_workspace_directory "$workspace_root" "$default_hooks_dir" "$container_user" || return 1
    fi

    hooks_dir="$(git -C "$workspace_root" rev-parse --path-format=absolute --git-path hooks)" || {
        echo "ERROR: Git could not resolve the effective hooks directory for ${workspace_root}" >&2
        return 1
    }
    case "$hooks_dir" in
    "$workspace_root"/*)
        if [ "$hooks_dir" != "$default_hooks_dir" ]; then
            ensure_workspace_directory "$workspace_root" "$hooks_dir" "$container_user" || return 1
        fi
        ;;
    *)
        # A user-level core.hooksPath is intentionally not ours to chown. The
        # managed hooks cannot be installed there without mutating an
        # unrelated path, so fail the lifecycle rather than claiming hooks are
        # ready when Git will resolve a different directory.
        echo "ERROR: refusing to continue with a Git hooks path outside the workspace: ${hooks_dir}" >&2
        return 1
        ;;
    esac

    RECONCILED_WORKSPACE_ROOT="$workspace_root"
}

ensure_workspace_directory() {
    local workspace_root="$1"
    local directory="$2"
    local container_user="$3"
    local current="$directory"

    case "$directory" in
    "$workspace_root"/*) ;;
    *)
        echo "ERROR: refusing to create a directory outside the workspace: ${directory}" >&2
        return 1
        ;;
    esac
    while [ "$current" != "$workspace_root" ]; do
        [ ! -L "$current" ] || {
            echo "ERROR: refusing to reconcile a symlinked workspace directory: ${current}" >&2
            return 1
        }
        if [ ! -d "$current" ]; then
            sudo mkdir -p "$current" || return 1
        fi
        sudo chown "$container_user" "$current" || return 1
        sudo chmod u+rwx "$current" || return 1
        current="$(dirname "$current")"
    done
}

install_lefthook_hooks() {
    local workspace_root="$1"
    local git_dir default_hooks_dir hooks_dir

    git_dir="$(git -C "$workspace_root" rev-parse --path-format=absolute --absolute-git-dir)" || {
        echo "ERROR: Git could not resolve the Git directory for Lefthook in ${workspace_root}" >&2
        return 1
    }
    default_hooks_dir="${git_dir%/}/hooks"
    hooks_dir="$(git -C "$workspace_root" rev-parse --path-format=absolute --git-path hooks)" || {
        echo "ERROR: Git could not resolve the effective hooks directory for Lefthook in ${workspace_root}" >&2
        return 1
    }

    case "$hooks_dir" in
    "$workspace_root"/*)
        if [ "$hooks_dir" = "$default_hooks_dir" ]; then
            lefthook install
        else
            # Lefthook rejects a custom core.hooksPath unless --force is used.
            # Force only an effective path inside the reconciled workspace; an
            # external path is user-managed and must not receive our writes.
            lefthook install --force
        fi
        ;;
    *)
        echo "ERROR: refusing to install Lefthook outside the workspace: ${hooks_dir}" >&2
        return 1
        ;;
    esac
}

# --- End workspace ownership reconciliation ---
RECONCILED_WORKSPACE_ROOT=""
reconcile_workspace_ownership "$ENV_GITCONFIG"
WORKSPACE_ROOT="$RECONCILED_WORKSPACE_ROOT"
cd "$WORKSPACE_ROOT"
echo "==> Workspace ownership reconciled for $(id -un):$(id -gn): ${WORKSPACE_ROOT}"

# Git identity for commits. Written to the environment layer, so in a bot or
# headless container DEVCONTAINER_GIT_* is the identity. When a human attaches
# via VS Code and copyGitConfig brings their personal ~/.gitconfig in, its
# user.* wins over this layer — that copy is personal-only config, and the
# attaching human's own identity taking precedence is the intended outcome.
git config --file "$ENV_GITCONFIG" user.name "${DEVCONTAINER_GIT_NAME}"
git config --file "$ENV_GITCONFIG" user.email "${DEVCONTAINER_GIT_EMAIL}"

# Loud, actionable guidance for an unauthenticated `gh`. The dev profile carries
# no GH_TOKEN and does not persist its login, so this is that profile's ordinary
# first-run state in EVERY attach mode — not just a bot misconfiguration on the
# headless path. Hence a shared helper: the VS Code branch below needs the same
# message and would otherwise say nothing at all.
#
# The REMEDY differs by profile, and printing the wrong one is a security bug
# rather than a typo: telling a bot container to `gh auth login` would put an
# operator credential — `workflow` scope and all — inside a bypassPermissions
# agent container, which is the exact escalation the bot PAT's denials exist to
# stop (docs/architecture/security.md). Each profile's own post-create.sh
# declares which remedy applies via DEVCONTAINER_GH_AUTH; anything else falls
# back to the token message, so the operator instructions can only ever appear
# where a wrapper explicitly asked for them.
#
# $1 is an extra command for the login path (the git bridge), omitted where
# VS Code already manages git's credential.
# The scope list the login line below asks for comes from scripts/gh-scopes.sh,
# the same file status.sh and setup-gh-scopes.sh read, so the banner cannot
# drift from what the session-start check demands (issue #827). Sourced
# defensively: this script also runs in trees where the workspace folder is not
# yet the repo root, and a missing helper must not fail the whole post-create.
GH_SCOPES_LIB="${GH_SCOPES_LIB:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/gh-scopes.sh}"
if [ -r "${GH_SCOPES_LIB}" ]; then
    # shellcheck source=scripts/gh-scopes.sh
    . "${GH_SCOPES_LIB}"
else
    gh_scopes_request_list() { printf '%s' "repo,workflow,project,read:project"; }
fi

gh_auth_help() {
    echo "=============================================================="
    echo "  GitHub CLI is NOT authenticated — gh pr / gh api and the"
    echo "  related-repo clones will fail until this is fixed."
    echo ""
    if [ "${DEVCONTAINER_GH_AUTH:-token}" = "login" ]; then
        echo "  This profile authenticates as you. Log in:"
        echo ""
        echo "    gh auth login --hostname github.com --git-protocol https \\"
        echo "      --web --scopes \"$(gh_scopes_request_list)\""
        echo ""
        echo "  Then, in the checkout, 'task setup:gh-scopes' verifies the"
        echo "  scopes landed and adds any this repo needs. (It refreshes an"
        echo "  EXISTING login — it cannot replace the command above.)"
        if [ -n "${1:-}" ]; then
            echo "    $1"
        fi
        echo ""
        echo "  Then re-run: bash .devcontainer/scripts/bootstrap-related-repos.sh"
        echo "  See docs/guides/devcontainers.md."
    else
        echo "  This profile authenticates from GH_TOKEN. Do NOT run"
        echo "  'gh auth login' here — that would put a human credential in an"
        echo "  agent container. Populate GH_TOKEN in the env-file this profile"
        echo "  loads (1Password Environment locally, workspace parameters on"
        echo "  Coder) and rebuild. See docs/guides/bot-account.md."
    fi
    echo "=============================================================="
}

# Let VS Code's devcontainer integration manage the in-container git credential
# helper. Installing gh's URL-specific helpers here can confuse the remote
# containers bootstrap when it replaces credential.helper on attach.
if [ -n "${REMOTE_CONTAINERS_IPC:-}" ] || [ "${REMOTE_CONTAINERS:-}" = "true" ]; then
    # Unset from both global-scope files: a prior `gh auth setup-git` may have
    # written the helpers to either one (gh uses --global, whose target file
    # varies — see ENV_GITCONFIG above).
    for cfg in "$ENV_GITCONFIG" "$HOME/.gitconfig"; do
        [ -f "$cfg" ] || continue
        git config --file "$cfg" --unset-all credential.https://github.com.helper || true
        git config --file "$cfg" --unset-all credential.https://gist.github.com.helper || true
    done
    echo "VS Code devcontainer detected; skipping gh auth setup-git."
    # VS Code's forwarded host credential covers *git* on this path, but not
    # `gh` — it reads its own config, and the dev profile supplies no GH_TOKEN.
    # Pass NO git bridge: unsetting those helpers two lines up is deliberate, so
    # telling the user to run `gh auth setup-git` would undo it.
    gh auth status >/dev/null 2>&1 || gh_auth_help
elif gh auth status >/dev/null 2>&1; then
    gh auth setup-git
else
    # Nothing manages git's credential here, so the bridge is part of the fix.
    gh_auth_help "gh auth setup-git"
fi

# The GitHub SSH→HTTPS insteadOf rewrites are baked into the image's
# environment gitconfig (.devcontainer/config/gitconfig) — static config
# belongs in the image layer, not in runtime writes.

# Effective read, not --global: the scoped read surface skips the XDG file
# once ~/.gitconfig exists, so it would print empty exactly when identity
# lives in the environment layer.
echo "Git user: $(git config user.name)"
echo "GitHub auth status:"
gh auth status || true

# push.autoSetupRemote is baked in the environment gitconfig alongside the
# other static settings.

echo "==> Fixing ownership of persistent volume dirs..."
for dir in /home/vscode/.codex /home/vscode/.claude /home/vscode/.gemini \
    /home/vscode/.copilot /home/vscode/.pi /home/vscode/.omp \
    /home/vscode/.agent-deck /home/vscode/.shell-history \
    /home/vscode/.config /home/vscode/.config/herdr /home/vscode/.config/opencode \
    /home/vscode/.local /home/vscode/.local/share /home/vscode/.local/share/opencode \
    /home/vscode/.local/share/zoxide; do
    sudo mkdir -p "$dir"
    sudo chown vscode:vscode "$dir"
    chmod 700 "$dir"
done

# --- Coder persistent volume symlinks ---
# Coder's envbuilder does not support devcontainer volume mounts, so on Coder
# the template provides a single persistent volume at ~/.persistent/ and we
# symlink the individual directories there.
#
# ORDERING IS LOAD-BEARING: this block must run BEFORE link-claude-json.sh and
# the onboarding seed below. Until these symlinks exist, ~/.claude on Coder is
# the container-local directory the ownership loop just created — the helper
# and the seed would populate THAT, and this block's migration `cp -a` would
# then copy the fresh stub over ~/.persistent/.claude/'s real account state:
# the exact clobber this change exists to prevent, surviving on the one
# platform whose persistence is wired by symlink instead of mount.
if [ "${CODER:-}" = "true" ] && [ -d "/home/vscode/.persistent" ]; then
    echo "==> Coder detected — setting up persistent volume symlinks..."
    for dir in .claude .codex .gemini .copilot .pi .omp .agent-deck .shell-history; do
        mkdir -p "/home/vscode/.persistent/$dir"
        if [ -d "$HOME/$dir" ] && [ ! -L "$HOME/$dir" ]; then
            if cp -a "$HOME/$dir/." "/home/vscode/.persistent/$dir/"; then
                rm -rf "${HOME:?}/$dir"
                ln -sfn "/home/vscode/.persistent/$dir" "$HOME/$dir"
            else
                echo "WARN: $dir migration to ~/.persistent failed;" \
                    "leaving $HOME/$dir on the container-local filesystem" >&2
            fi
        else
            ln -sfn "/home/vscode/.persistent/$dir" "$HOME/$dir"
        fi
    done
    mkdir -p "/home/vscode/.persistent/zoxide" "$HOME/.local/share"
    if [ -d "$HOME/.local/share/zoxide" ] && [ ! -L "$HOME/.local/share/zoxide" ]; then
        cp -a "$HOME/.local/share/zoxide/." "/home/vscode/.persistent/zoxide/" 2>/dev/null || true
        rm -rf "${HOME:?}/.local/share/zoxide"
    fi
    ln -sfn "/home/vscode/.persistent/zoxide" "$HOME/.local/share/zoxide"
    mkdir -p "/home/vscode/.persistent/herdr" "$HOME/.config"
    # Unlike the agent dirs above, ~/.config/herdr can hold the only copy of
    # session snapshots — never delete the source unless the copy succeeded,
    # and fail the lifecycle rather than continue unpersisted: a
    # warn-and-continue would let Herdr write snapshots the next rebuild
    # silently discards.
    if [ -d "$HOME/.config/herdr" ] && [ ! -L "$HOME/.config/herdr" ]; then
        if ! cp -a "$HOME/.config/herdr/." "/home/vscode/.persistent/herdr/"; then
            echo "ERROR: Herdr state migration to ~/.persistent failed;" \
                "fix the persistent volume and rebuild" >&2
            exit 1
        fi
        rm -rf "${HOME:?}/.config/herdr"
    fi
    ln -sfn "/home/vscode/.persistent/herdr" "$HOME/.config/herdr"
    bash .devcontainer/scripts/persist-opencode.sh /home/vscode/.persistent
fi

# --- Persist ~/.claude.json into the ~/.claude volume ---
# MUST run before anything below that can spawn `claude` (the onboarding seed,
# the herdr integration install, and the agent-deck conductor setup all can) —
# a `claude` launched with no symlink in place writes a fresh, near-empty REAL
# file at ~/.claude.json, which post-start would then have moved OVER the
# persisted 38 KB of account state. And it must run AFTER the Coder persistence
# block above, so that on Coder ~/.claude already points into ~/.persistent
# rather than at the container-local directory. See link-claude-json.sh.
bash .devcontainer/scripts/link-claude-json.sh

# --- Claude Code onboarding seed ---
# Pre-seed ~/.claude/.claude.json so fresh containers skip the onboarding
# wizard (upstream issue: https://github.com/anthropics/claude-code/issues/8938).
# post-start-common.sh creates ~/.claude.json → ~/.claude/.claude.json so
# Claude Code finds this file on first launch. Guard: only seed on an empty
# volume — existing session data (token, settings) must never be clobbered.
# Same ordering constraint as the helper: on Coder this must see the
# persistent ~/.claude, not the pre-symlink local one.
CLAUDE_SESSION_FILE="$HOME/.claude/.claude.json"
if [ -d "$HOME/.claude" ] && [ ! -f "$CLAUDE_SESSION_FILE" ]; then
    echo '{"hasCompletedOnboarding":true}' >"$CLAUDE_SESSION_FILE"
    chmod 0600 "$CLAUDE_SESSION_FILE"
    echo "==> Seeded ~/.claude/.claude.json with hasCompletedOnboarding=true"
fi

# --- Herdr agent integrations ---
# resume_agents_on_restore only resumes agents whose Herdr integration has
# recorded a native session reference, and the integration also reports
# authoritative working/blocked state to the sidebar instead of Herdr
# screen-scraping. The installer is version-aware and file-writing only (no
# running server needed), so re-running on every create is safe. Guarded:
# the pinned shared image may predate the herdr binary, and a failed install
# only degrades resume back to fresh shells — never block the container on it.
if command -v herdr >/dev/null 2>&1; then
    for agent in claude codex opencode pi omp copilot; do
        herdr integration install "$agent" ||
            echo "WARN: herdr integration install $agent failed (non-fatal)" >&2
    done
fi

# --- Agent-Deck config seeding ---
# When a fresh volume mount shadows ~/.agent-deck, seed it from the image-baked
# config. Source lives at /usr/local/share/ rather than /tmp/ because /tmp is a
# tmpfs at runtime on Coder hosts and would shadow build-time content.
if [ -d "$HOME/.agent-deck" ] && [ ! -f "$HOME/.agent-deck/config.toml" ]; then
    echo "==> Seeding agent-deck config into persistent volume..."
    cp /usr/local/share/devcontainer-config/agent-deck.toml "$HOME/.agent-deck/config.toml"
fi

# --- Claude Code settings ---
# Two layers, both owned by the dev container (never the volume):
#
#   1. /etc/claude-code/managed-settings.json — baked by the Dockerfile.
#      Highest precedence (policySettings); enforces skipDangerousModePermissionPrompt,
#      defaultMode, and the baseline Bash(...) allow list. Users CANNOT override
#      these. Source of truth: .devcontainer/config/claude-settings.json.
#
#   2. ~/.claude/settings.json (user level) — seed-merged below from
#      claude-user-defaults.json. Provides defaults the user CAN override
#      (currently: model, plus the statusLine renderer baked at
#      /etc/claude-code/statusline.sh). Existing values in ~/.claude/
#      settings.json always win on conflict, so /model and other in-app changes
#      stick across post-create runs. On a fresh volume the defaults are
#      populated; on a volume wipe + rebuild they come back automatically.
CLAUDE_DEFAULTS_SRC=/usr/local/share/devcontainer-config/claude-user-defaults.json
CLAUDE_USER_SETTINGS="$HOME/.claude/settings.json"
if [ -d "$HOME/.claude" ] && [ -f "$CLAUDE_DEFAULTS_SRC" ]; then
    if [ ! -f "$CLAUDE_USER_SETTINGS" ]; then
        echo "==> Seeding ~/.claude/settings.json from dev container defaults..."
        install -m 0600 "$CLAUDE_DEFAULTS_SRC" "$CLAUDE_USER_SETTINGS"
    elif command -v jq >/dev/null 2>&1; then
        # Deep-merge: defaults fill in missing fields, existing user values win.
        # `.[0] * .[1]` puts existing on the right so it overrides defaults.
        tmp=$(mktemp)
        if jq -s '.[0] * .[1]' "$CLAUDE_DEFAULTS_SRC" "$CLAUDE_USER_SETTINGS" >"$tmp"; then
            if ! cmp -s "$tmp" "$CLAUDE_USER_SETTINGS"; then
                echo "==> Merging dev container defaults into ~/.claude/settings.json..."
                install -m 0600 "$tmp" "$CLAUDE_USER_SETTINGS"
            fi
            rm -f "$tmp"
        else
            echo "WARNING: jq merge of Claude user defaults failed; leaving settings.json unchanged" >&2
            rm -f "$tmp"
        fi
    fi
fi

if [ -f pyproject.toml ]; then
    echo "==> Setting up Python virtualenv and dependencies..."
    # .venv is a named volume (see devcontainer.json mounts), which docker
    # creates root-owned on first use — hand it to the container user before
    # uv sync writes into it.
    if [ -d .venv ] && [ ! -w .venv ]; then
        sudo chown "$(id -un):$(id -gn)" .venv
    fi
    uv sync
else
    echo "==> No pyproject.toml found; skipping Python setup."
fi

if [ -f ansible/requirements.yml ]; then
    echo "==> Installing Ansible Galaxy collections..."
    uv run ansible-galaxy collection install -r ansible/requirements.yml
else
    echo "==> No ansible/requirements.yml found; skipping Ansible setup."
fi

if [ -d services/harmon-lab-proxy/homepage ]; then
    echo "==> Installing Node.js dependencies for homepage..."
    (cd services/harmon-lab-proxy/homepage && npm ci)
fi

if [ -f lefthook.yml ] && command -v lefthook &>/dev/null; then
    echo "==> Setting up git hooks via lefthook..."
    install_lefthook_hooks "$WORKSPACE_ROOT"
fi

echo "==> Wiring up shell aliases/functions source line..."
# Source the image-baked shell-aliases.sh from both .bashrc and .zshrc so it
# works regardless of which shell is active (scripts still use bash).
for rcfile in ~/.bashrc ~/.zshrc; do
    touch "$rcfile"
    if ! grep -Fqx "${PROFILE_SOURCE_LINE}" "$rcfile"; then
        {
            echo ""
            echo "# Added by devcontainer post-create"
            echo "${PROFILE_SOURCE_LINE}"
        } >>"$rcfile"
    fi
done

if [ -d terraform ]; then
    echo "==> Initializing Terraform providers..."
    (cd terraform && terraform init -backend=false) || true
fi

if command -v direnv &>/dev/null && [ -f .envrc ]; then
    echo "==> Allowing direnv .envrc..."
    direnv allow
fi

# Clone related repos into /workspaces/ (idempotent + non-destructive; reads
# .devcontainer/related-repos.txt). Runs on create so a rebuilt container
# re-populates siblings. No-op when the list is empty/absent.
bash .devcontainer/scripts/bootstrap-related-repos.sh

echo "==> Setup complete! Run 'task verify' to validate your environment."
