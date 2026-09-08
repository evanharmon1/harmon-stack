#!/usr/bin/env bash
# Hermetic regression coverage for the composite action's pinned lint tools.
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
root_action="${repo}/.github/actions/setup/action.yml"
template_action="${repo}/template/.github/actions/setup/action.yml.jinja"

fail() {
    echo "TEST FAIL: $*" >&2
    exit 1
}

test_tmp="$(mktemp -d -t harmon-init-setup-versions-XXXXXX)"
trap 'rm -rf "$test_tmp"' EXIT
fake_bin="${test_tmp}/bin"
downloads="${test_tmp}/downloads"
install_log="${test_tmp}/installs"
mkdir -p "$fake_bin" "$downloads"
: >"$install_log"

# Bind the test to the real action body, and prove the three root/template
# blocks stay identical. The template has surrounding Jinja, but these tool
# installers are unconditional twins.
python3 - "$root_action" "$template_action" "${test_tmp}/install-lint-tools.sh" "$downloads" <<'PY'
import pathlib
import sys

root_path, template_path, output_path, downloads = sys.argv[1:]
root = pathlib.Path(root_path).read_text()
template = pathlib.Path(template_path).read_text()

for dependency in ("koalaman/shellcheck", "mvdan/sh", "rhysd/actionlint"):
    marker = f"depName={dependency} "

    def block(text: str) -> str:
        start = text.index(marker)
        start = text.rfind("\n", 0, start) + 1
        end = text.index("\n        fi\n", start) + len("\n        fi\n")
        return text[start:end]

    root_block = block(root)
    if root_block != block(template):
        raise SystemExit(f"{dependency}: root/template installer blocks differ")
    if "| grep -q" in root_block:
        raise SystemExit(
            f"{dependency}: version guard reintroduced the producer | grep -q pipefail hazard"
        )

lines = root.splitlines()
step = lines.index(
    "    - name: Install lint tools (file, shellcheck, shfmt, actionlint, yamllint, yq)"
)
run = next(i for i in range(step + 1, len(lines)) if lines[i] == "      run: |")
body = []
for line in lines[run + 1 :]:
    if line.startswith("    - "):
        break
    if not line.startswith("        ") and line:
        raise SystemExit(f"unexpected indentation in lint-tools action body: {line!r}")
    body.append(line[8:] if line else "")

if not body:
    raise SystemExit("lint-tools action body extraction was empty")
script = "#!/usr/bin/env bash\nset -euo pipefail\n" + "\n".join(body) + "\n"
script = script.replace("/tmp/", downloads.rstrip("/") + "/")
pathlib.Path(output_path).write_text(script)
PY
chmod +x "${test_tmp}/install-lint-tools.sh"

cat >"${fake_bin}/shellcheck" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'ShellCheck - shell script analysis tool' 'version: 0.9.0'
EOF
cat >"${fake_bin}/shfmt" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'v3.12.0'
EOF
cat >"${fake_bin}/actionlint" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '1.7.11' 'installed by building from source' 'built with go1.24.0 compiler for linux/amd64'
EOF
cat >"${fake_bin}/yq" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'yq (https://github.com/mikefarah/yq/) version v4.44.3'
EOF
cat >"${fake_bin}/yamllint" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"${fake_bin}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=
while [ "$#" -gt 0 ]; do
    if [ "$1" = -o ]; then
        output="$2"
        shift 2
    else
        shift
    fi
done
if [ -n "$output" ]; then
    if [ "${output##*/}" = shfmt ]; then
        cat >"$output" <<'SHFMT'
#!/usr/bin/env bash
printf '%s\n' 'v3.13.1'
SHFMT
        chmod +x "$output"
    else
        printf '%s\n' archive >"$output"
    fi
else
    printf '%s\n' archive
fi
EOF
cat >"${fake_bin}/tar" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case " $* " in
*" -xJf "*)
    mkdir -p "${TEST_DOWNLOADS}/shellcheck-v0.10.0"
    cat >"${TEST_DOWNLOADS}/shellcheck-v0.10.0/shellcheck" <<'SHELLCHECK'
#!/usr/bin/env bash
printf '%s\n' 'ShellCheck - shell script analysis tool' 'version: 0.10.0'
SHELLCHECK
    chmod +x "${TEST_DOWNLOADS}/shellcheck-v0.10.0/shellcheck"
    ;;
*)
    # Consume the complete curl stream so this fixture also exercises the
    # action under pipefail without manufacturing an early-reader SIGPIPE.
    cat >/dev/null
    cat >"${TEST_DOWNLOADS}/actionlint" <<'ACTIONLINT'
#!/usr/bin/env bash
printf '%s\n' '1.7.12' 'installed by building from source' 'built with go1.24.0 compiler for linux/amd64'
ACTIONLINT
    chmod +x "${TEST_DOWNLOADS}/actionlint"
    ;;
esac
EOF
cat >"${fake_bin}/sha256sum" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
EOF
cat >"${fake_bin}/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
install)
    source_path="$4"
    destination="$5"
    ;;
mv)
    source_path="$2"
    destination="$3"
    ;;
*) exit 1 ;;
esac
if [ "${destination%/}" = /usr/local/bin ]; then
    destination="${TEST_FAKE_BIN}/${source_path##*/}"
else
    destination="${TEST_FAKE_BIN}/${destination##*/}"
fi
cp "$source_path" "$destination"
chmod +x "$destination"
printf '%s\n' "${destination##*/}" >>"${TEST_INSTALL_LOG}"
EOF
chmod +x "${fake_bin}"/*

run_action() {
    PATH="${fake_bin}:${PATH}" \
        TEST_DOWNLOADS="$downloads" \
        TEST_FAKE_BIN="$fake_bin" \
        TEST_INSTALL_LOG="$install_log" \
        "${test_tmp}/install-lint-tools.sh"
}

run_action

shellcheck_output="$(PATH="${fake_bin}:${PATH}" shellcheck --version)"
case "$shellcheck_output" in
*"version: 0.10.0"*) : ;;
*) fail "wrong-version shellcheck was not replaced: ${shellcheck_output}" ;;
esac
[ "$(PATH="${fake_bin}:${PATH}" shfmt --version)" = v3.13.1 ] ||
    fail "wrong-version shfmt was not replaced"
actionlint_output="$(PATH="${fake_bin}:${PATH}" actionlint --version)"
case "$actionlint_output" in
1.7.12$'\n'*) : ;;
*) fail "wrong-version actionlint was not replaced: ${actionlint_output}" ;;
esac

for tool in shellcheck shfmt actionlint; do
    [ "$(grep -c "^${tool}$" "$install_log")" -eq 1 ] ||
        fail "${tool} was not installed exactly once"
done

# Once PATH holds the pins, a second action run must keep them and skip all
# three installers.
run_action
[ "$(wc -l <"$install_log" | tr -d ' ')" -eq 3 ] ||
    fail "matching pinned tools were reinstalled"

echo "setup action tool-version checks: PASS"
