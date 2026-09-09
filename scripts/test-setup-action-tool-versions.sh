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
stale_bin="${test_tmp}/stale-bin"
helper_bin="${test_tmp}/helpers"
curl_log="${test_tmp}/curl.log"
install_log="${test_tmp}/install.log"
mkdir -p "$stale_bin" "$helper_bin"
: >"$curl_log"
: >"$install_log"

# Bind the test to the real action body and prove the complete shared installer
# segment stays identical between the root action and its template twin.
python3 - "$root_action" "$template_action" "${test_tmp}/install-lint-tools.sh" <<'PY'
import pathlib
import sys

root_path, template_path, output_path = sys.argv[1:]
root = pathlib.Path(root_path).read_text()
template = pathlib.Path(template_path).read_text()


def installer_segment(text: str) -> str:
    start = text.index(
        "        # renovate: datasource=github-releases depName=koalaman/shellcheck "
    )
    yq_install = text.index(
        '          install -m 0755 "${lint_tools_tmp}/yq"', start
    )
    end = text.index("\n        fi\n", yq_install) + len("\n        fi\n")
    return text[start:end]


root_segment = installer_segment(root)
template_segment = "\n".join(
    line
    for line in installer_segment(template).splitlines()
    if line not in ("[% if use_skills_sync %]", "[% endif %]")
) + "\n"
if root_segment != template_segment:
    raise SystemExit("root/template pinned lint-tool installer segments differ")
if "| grep -q" in root_segment:
    raise SystemExit("version guard reintroduced the producer | grep -q hazard")
for expected in (
    "X64|x86_64)",
    "ARM64|arm64|aarch64)",
    "Unsupported runner architecture",
    "harmon-init-lint-tools-download.XXXXXX",
    '>> "$GITHUB_PATH"',
    "fb096c5d1ac6beabbdbaa2874d025badb03ee07929f0c9ff67563ce8c75398b1",
    "32d92acaa5cd8abb29fc49dac123dc412442d5713967819d8af2c29f1b3857c7",
    "a2c097180dd884a8d50c956ee16a9cec070f30a7947cf4ebf87d5f36213e9ed7",
    "0e7e1524f68d91b3ff9b089872d185940ab0fa020a5a9052046ef10547023156",
):
    if expected not in root_segment:
        raise SystemExit(f"installer segment is missing {expected!r}")

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
pathlib.Path(output_path).write_text(
    "#!/usr/bin/env bash\nset -euo pipefail\n" + "\n".join(body) + "\n"
)
PY
chmod +x "${test_tmp}/install-lint-tools.sh"

cat >"${stale_bin}/shellcheck" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'ShellCheck - shell script analysis tool' 'version: 0.9.0'
EOF
cat >"${stale_bin}/shfmt" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'v3.12.0'
EOF
cat >"${stale_bin}/actionlint" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '1.7.11' 'installed by building from source' 'built with go1.24.0 compiler for linux/amd64'
EOF
cat >"${stale_bin}/yq" <<'EOF'
#!/usr/bin/env bash
exit 127
EOF
cat >"${helper_bin}/yamllint" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"${helper_bin}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=
url=
while [ "$#" -gt 0 ]; do
    case "$1" in
    -o)
        output="$2"
        shift 2
        ;;
    http*)
        url="$1"
        shift
        ;;
    *) shift ;;
    esac
done
[ -n "$output" ] && [ -n "$url" ]
mkdir -p "$(dirname "$output")"
printf '%s|%s\n' "$output" "$url" >>"$TEST_CURL_LOG"
case "${output##*/}" in
shfmt)
    cat >"$output" <<'SHFMT'
#!/usr/bin/env bash
printf '%s\n' 'v3.13.1'
SHFMT
    chmod +x "$output"
    ;;
yq)
    cat >"$output" <<'YQ'
#!/usr/bin/env bash
printf '%s\n' 'yq (https://github.com/mikefarah/yq/) version v4.44.3'
YQ
    chmod +x "$output"
    ;;
*) printf '%s\n' archive >"$output" ;;
esac
EOF
cat >"${helper_bin}/tar" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
archive=
destination=
while [ "$#" -gt 0 ]; do
    case "$1" in
    -xJf|-xzf)
        archive="$2"
        shift 2
        ;;
    -C)
        destination="$2"
        shift 2
        ;;
    *) shift ;;
    esac
done
[ -n "$archive" ] && [ -n "$destination" ]
case "${archive##*/}" in
shellcheck.tar.xz)
    mkdir -p "${destination}/shellcheck-v0.10.0"
    cat >"${destination}/shellcheck-v0.10.0/shellcheck" <<'SHELLCHECK'
#!/usr/bin/env bash
printf '%s\n' 'ShellCheck - shell script analysis tool' 'version: 0.10.0'
SHELLCHECK
    chmod +x "${destination}/shellcheck-v0.10.0/shellcheck"
    ;;
actionlint.tar.gz)
    cat >"${destination}/actionlint" <<'ACTIONLINT'
#!/usr/bin/env bash
printf '%s\n' '1.7.12' 'installed by building from source' 'built with go1.24.0 compiler for linux/amd64'
ACTIONLINT
    chmod +x "${destination}/actionlint"
    ;;
*) exit 1 ;;
esac
EOF
cat >"${helper_bin}/sha256sum" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
EOF
cat >"${helper_bin}/install" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "$1" = -m ] && [ "$2" = 0755 ] && [ "$#" -eq 4 ]
source_path="$3"
destination="$4"
mkdir -p "$(dirname "$destination")"
cp "$source_path" "$destination"
chmod +x "$destination"
printf '%s|%s\n' "${destination##*/}" "$destination" >>"$TEST_INSTALL_LOG"
EOF
chmod +x "${stale_bin}"/* "${helper_bin}"/*

run_action() {
    arch="$1"
    runner_temp="$2"
    github_path="$3"
    effective_path="${stale_bin}:${helper_bin}:${PATH}"
    if [ -s "$github_path" ]; then
        published_bin="$(tail -n 1 "$github_path")"
        effective_path="${published_bin}:${effective_path}"
    fi
    PATH="$effective_path" \
        RUNNER_ARCH="$arch" \
        RUNNER_TEMP="$runner_temp" \
        GITHUB_PATH="$github_path" \
        TEST_CURL_LOG="$curl_log" \
        TEST_INSTALL_LOG="$install_log" \
        "${test_tmp}/install-lint-tools.sh"
}

assert_pins() {
    published_bin="$1"
    tool_path="${published_bin}:${stale_bin}:${helper_bin}:${PATH}"
    shellcheck_output="$(PATH="$tool_path" shellcheck --version)"
    case "$shellcheck_output" in
    *"version: 0.10.0"*) : ;;
    *) fail "wrong-version shellcheck remained authoritative: ${shellcheck_output}" ;;
    esac
    [ "$(PATH="$tool_path" shfmt --version)" = v3.13.1 ] ||
        fail "wrong-version shfmt remained authoritative"
    actionlint_output="$(PATH="$tool_path" actionlint --version)"
    case "$actionlint_output" in
    1.7.12$'\n'*) : ;;
    *) fail "wrong-version actionlint remained authoritative: ${actionlint_output}" ;;
    esac
    [ "$(PATH="$tool_path" yq --version)" = 'yq (https://github.com/mikefarah/yq/) version v4.44.3' ] ||
        fail "missing yq was not replaced with the architecture-correct pin"
}

run_arch_case() {
    arch="$1"
    shellcheck_asset="$2"
    shfmt_asset="$3"
    actionlint_asset="$4"
    yq_asset="$5"
    runner_temp="${test_tmp}/runner-${arch}"
    github_path="${test_tmp}/github-path-${arch}"
    mkdir -p "$runner_temp"
    : >"$github_path"

    installs_before="$(wc -l <"$install_log" | tr -d ' ')"
    run_action "$arch" "$runner_temp" "$github_path"
    published_bin="$(tail -n 1 "$github_path")"
    case "$published_bin" in
    "${runner_temp}/harmon-init-lint-tools/0.10.0-3.13.1-1.7.12/${arch}") : ;;
    *) fail "${arch}: GITHUB_PATH did not receive the job-private versioned bin first" ;;
    esac
    assert_pins "$published_bin"

    grep -Fq "/${shellcheck_asset}" "$curl_log" || fail "${arch}: wrong shellcheck asset"
    grep -Fq "/${shfmt_asset}" "$curl_log" || fail "${arch}: wrong shfmt asset"
    grep -Fq "/${actionlint_asset}" "$curl_log" || fail "${arch}: wrong actionlint asset"
    grep -Fq "/${yq_asset}" "$curl_log" || fail "${arch}: wrong yq asset"
    if grep -Fq '/usr/local/bin' "$install_log"; then
        fail "${arch}: installer still wrote to the host-global bin directory"
    fi

    installs_after="$(wc -l <"$install_log" | tr -d ' ')"
    [ "$((installs_after - installs_before))" -eq 4 ] ||
        fail "${arch}: mismatched or missing tools were not each installed exactly once"

    # A second invocation in the same job sees the published versioned bin at
    # the front of PATH and must not install again.
    run_action "$arch" "$runner_temp" "$github_path"
    [ "$(wc -l <"$install_log" | tr -d ' ')" -eq "$installs_after" ] ||
        fail "${arch}: matching pinned tools were reinstalled"
}

run_arch_case X64 \
    shellcheck-v0.10.0.linux.x86_64.tar.xz \
    shfmt_v3.13.1_linux_amd64 \
    actionlint_1.7.12_linux_amd64.tar.gz \
    yq_linux_amd64
run_arch_case ARM64 \
    shellcheck-v0.10.0.linux.aarch64.tar.xz \
    shfmt_v3.13.1_linux_arm64 \
    actionlint_1.7.12_linux_arm64.tar.gz \
    yq_linux_arm64

# The stale PATH entries remain untouched; precedence comes only from the
# job-private directory published by the action.
[ "$(PATH="${stale_bin}:${PATH}" shfmt --version)" = v3.12.0 ] ||
    fail "fixture did not keep the stale PATH tool ahead of /usr/local/bin"

x64_download="$(sed -n '1p' "$curl_log")"
arm64_download="$(sed -n '5p' "$curl_log")"
x64_download_dir="$(dirname "${x64_download%%|*}")"
arm64_download_dir="$(dirname "${arm64_download%%|*}")"
[ "$x64_download_dir" != "$arm64_download_dir" ] ||
    fail "architecture runs reused one download directory"
case "$x64_download_dir" in
"${test_tmp}/runner-X64"/harmon-init-lint-tools-download.*) : ;;
*) fail "X64 downloads escaped RUNNER_TEMP" ;;
esac
case "$arm64_download_dir" in
"${test_tmp}/runner-ARM64"/harmon-init-lint-tools-download.*) : ;;
*) fail "ARM64 downloads escaped RUNNER_TEMP" ;;
esac

unsupported_temp="${test_tmp}/runner-unsupported"
unsupported_path="${test_tmp}/github-path-unsupported"
mkdir -p "$unsupported_temp"
: >"$unsupported_path"
curl_count="$(wc -l <"$curl_log" | tr -d ' ')"
if unsupported_output="$(run_action RISCV64 "$unsupported_temp" "$unsupported_path" 2>&1)"; then
    fail "unsupported architecture was accepted"
fi
case "$unsupported_output" in
*"Unsupported runner architecture"*) : ;;
*) fail "unsupported architecture failure did not explain the refusal" ;;
esac
[ "$(wc -l <"$curl_log" | tr -d ' ')" -eq "$curl_count" ] ||
    fail "unsupported architecture downloaded an asset before failing"

echo "setup action tool-version checks: PASS"
