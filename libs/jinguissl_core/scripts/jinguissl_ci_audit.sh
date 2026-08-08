#!/usr/bin/env bash
set -euo pipefail

mode="${1:-public}"
root="${2:-.}"

case "${mode}" in
  public|hosted-graph|dependency-lock) ;;
  *)
    echo "usage: $0 [public|hosted-graph|dependency-lock] [repo-root]" >&2
    exit 2
    ;;
esac

cd "${root}"

failures=0
warnings=0

note() {
  printf '%s\n' "$*"
}

warn() {
  warnings=$((warnings + 1))
  printf '::warning::%s\n' "$*"
}

fail() {
  failures=$((failures + 1))
  printf '::error::%s\n' "$*"
}

scan_text() {
  local pattern="$1"
  grep --binary-files=without-match -RInE "${pattern}" . \
    --exclude-dir=.git \
    --exclude-dir=target \
    --exclude-dir=.cjpm \
    --exclude=.git \
    --exclude='jinguissl_ci_audit.sh'
}

check_conflict_markers() {
  if scan_text '^(<<<<<<<|=======|>>>>>>>)'; then
    fail "conflict markers found"
  fi
}

check_credentials() {
  local pattern='(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|GITCODE_TOKEN[[:space:]]*=|GITHUB_TOKEN[[:space:]]*=)'
  if scan_text "${pattern}"; then
    fail "credential-like material found"
  fi

  local found_key=0
  while IFS= read -r file; do
    case "${file}" in
      ./testdata/*|*/testdata/*|./scripts/jinguissl_ci_audit.sh)
        continue
        ;;
    esac
    if ! grep -Iq . "${file}"; then
      continue
    fi
    if grep -qE '^-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----$' "${file}" &&
       grep -qE '^-----END (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----$' "${file}"; then
      printf '%s\n' "${file}"
      found_key=1
    fi
  done < <(find . \( -path './.git' -o -name target -o -path './.cjpm' \) -prune -o -type f -print)

  if [ "${found_key}" -ne 0 ]; then
    fail "non-test private key block found"
  fi
}

check_local_paths() {
  local pattern='(/Users/|/private/tmp/|/var/folders/|/Library/Frameworks/Cangjie)'
  if scan_text "${pattern}"; then
    fail "local host path leaked into public surface"
  fi
}

check_governance_residue() {
  local found=0
  for path in ./AGENTS.md ./AGTNS.md ./_helper; do
    if [ -e "${path}" ]; then
      printf '%s\n' "${path}"
      found=1
    fi
  done
  if find . \( -path './.git' -o -path './target' \) -prune -o -name AGTNS.md -print | grep -q .; then
    find . \( -path './.git' -o -path './target' \) -prune -o -name AGTNS.md -print
    found=1
  fi
  if [ "${found}" -ne 0 ]; then
    fail "member-local governance residue found"
  fi
}

check_target_artifacts() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git ls-files 'target/**' | grep -q .; then
      git ls-files 'target/**'
      fail "tracked target artifact found"
    fi
  elif find . -path './target/*' -type f | grep -q .; then
    find . -path './target/*' -type f
    warn "target artifacts found in non-git file truth; exclude them from hosted publish copies"
  fi
}

check_old_import_roots() {
  local pattern='(JinguiSSL\.jinguissl|jinguissl_core\.jinguissl|jinguissl_contract\.jinguissl|src/jinguissl_contract)'
  if scan_text "${pattern}"; then
    fail "stale JinguiSSL import/root residue found"
  fi
}

check_dependency_graph() {
  if [ ! -f cjpm.toml ]; then
    return
  fi
  if grep -nE '\{[[:space:]]*path[[:space:]]*=' cjpm.toml; then
    if [ "${mode}" = "hosted-graph" ]; then
      fail "local path dependency is forbidden in hosted-graph mode"
    else
      warn "local path dependency observed; hosted graph must use hosted dependencies before release claims"
    fi
  fi
}

check_dependency_lock() {
  if [ "${mode}" != "dependency-lock" ] || [ ! -f cjpm.toml ]; then
    return
  fi

  local dependency_url
  local lock_line
  local found=0
  while IFS= read -r dependency_url; do
    [ -n "${dependency_url}" ] || continue
    found=1
    if [ ! -f cjpm.lock ]; then
      fail "git dependency ${dependency_url} has no cjpm.lock"
      continue
    fi
    lock_line="$(grep -F "git = \"${dependency_url}\"" cjpm.lock | head -n 1 || true)"
    if [ -z "${lock_line}" ]; then
      fail "cjpm.lock does not match git dependency ${dependency_url}"
      continue
    fi
    if ! printf '%s\n' "${lock_line}" | grep -Eq ', commitId = "[0-9a-fA-F]{40}"'; then
      fail "cjpm.lock has no full commitId for git dependency ${dependency_url}"
    fi
  done < <(sed -nE 's/.*git[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' cjpm.toml)

  if [ "${found}" -eq 0 ]; then
    note "no hosted git dependency requires a lock check"
  fi
}

check_toolchain_surface() {
  if [ "${mode}" = "hosted-graph" ]; then
    note "toolchain availability is verified after workflow SDK install"
  fi
}

note "JinguiSSL CI audit mode: ${mode}"
check_conflict_markers
check_credentials
check_local_paths
check_governance_residue
check_target_artifacts
check_old_import_roots
check_dependency_graph
check_dependency_lock
check_toolchain_surface

if [ "${failures}" -ne 0 ]; then
  note "JinguiSSL CI audit failed: ${failures} error(s), ${warnings} warning(s)"
  exit 1
fi

note "JinguiSSL CI audit passed: ${warnings} warning(s)"
