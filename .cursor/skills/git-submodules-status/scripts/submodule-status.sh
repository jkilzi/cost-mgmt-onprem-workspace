#!/usr/bin/env bash
# Submodule status / drift fix — config-driven (see ../references/config.json).
#
# Usage:
#   submodule-status.sh [REPO_ROOT] [--show | --fix-print | --fix-apply]
#
# Default mode is --show. REPO_ROOT defaults to current git superproject top-level.
# Config path: <this-script-dir>/../references/config.json

set -euo pipefail

err() { printf '%s\n' "$*" >&2; }
die() { err "$*"; exit 1; }

usage() {
  err "Usage: ${0##*/} [REPO_ROOT] [--show | --fix-print | --fix-apply]"
  err "  --show       Markdown table: Name | Branch | Status (default)."
  err "  --fix-print  Print bash snippets: fetch upstream, checkout <default>, rebase upstream/<default>."
  err "  --fix-apply  Run those commands per submodule (stops on first git failure)."
  err "Requires references/config.json next to this skill (see references/config.schema.json)."
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON="${SCRIPT_DIR}/../references/config.json"

MODE="show"
REPO_ARG=""
for arg in "$@"; do
  case "$arg" in
    --show) MODE="show" ;;
    --fix-print) MODE="fix_print" ;;
    --fix-apply) MODE="fix_apply" ;;
    -h | --help) usage; exit 0 ;;
    -*)
      die "unknown option: $arg (use --help)"
      ;;
    "")
      ;;
    *)
      if [[ -n "$REPO_ARG" ]]; then
        die "error: multiple REPO_ROOT paths: $REPO_ARG and $arg"
      fi
      REPO_ARG="$arg"
      ;;
  esac
done

ROOT="${REPO_ARG:-}"
if [[ -n "$ROOT" ]]; then
  ROOT=$(cd "$ROOT" && git rev-parse --show-toplevel)
else
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die "error: not inside a git repository (pass REPO_ROOT if needed)"
fi

[[ -f "$CONFIG_JSON" ]] || die "error: missing config: $CONFIG_JSON — run setup (see skill: setup submodules skill)."

GITMODULES="$ROOT/.gitmodules"
[[ -f "$GITMODULES" ]] || die "error: no .gitmodules at $ROOT"

# --- config ---

get_upstream_name() {
  local sm_name="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg n "$sm_name" '.[] | select(.submodule_name == $n) | .upstream_name // empty' "$CONFIG_JSON" | head -1
    return 0
  fi
  python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); n=sys.argv[2]; print(next((str(r.get("upstream_name","")) for r in data if r.get("submodule_name")==n), ""))' "$CONFIG_JSON" "$sm_name"
}

# Default branch for a remote inside repo at $1: remote show -n, symbolic-ref, then common names.
remote_default_branch() {
  local full="$1" remote="$2"
  local b sym
  b=$(git -C "$full" remote show -n "$remote" 2>/dev/null | sed -n 's/.*HEAD branch: //p' | head -1 | tr -d '\r')
  b="${b#"${b%%[![:space:]]*}"}"
  b="${b%"${b##*[![:space:]]}"}"
  if [[ -n "$b" && "$b" != "(not queried)" && "$b" != "(unknown)" ]]; then
    echo "$b"
    return
  fi
  sym=$(git -C "$full" symbolic-ref -q "refs/remotes/${remote}/HEAD" 2>/dev/null || true)
  if [[ -n "$sym" ]]; then
    echo "${sym#refs/remotes/${remote}/}"
    return
  fi
  local try
  for try in main master trunk develop; do
    if git -C "$full" rev-parse -q --verify "refs/remotes/${remote}/${try}" >/dev/null 2>&1; then
      echo "$try"
      return
    fi
  done
  echo ""
}

ref_exists() {
  local full="$1" ref="$2"
  git -C "$full" rev-parse -q --verify "${ref}^{commit}" >/dev/null 2>&1
}

working_tree_clean() {
  local full="$1"
  [[ -z "$(git -C "$full" status --porcelain 2>/dev/null)" ]]
}

# Prints: in_sync | drift:<ahead>|<behind> | no_local:<branch> | no_upstream_ref | unknown_default
# (internal drift: first = ahead count, second = behind count; Status line prints "behind · ahead".)
drift_state() {
  local full="$1" upstream="$2" def="$3"
  local local_ref="refs/heads/${def}"
  local up_ref="refs/remotes/${upstream}/${def}"

  if [[ -z "$def" ]]; then
    echo "unknown_default"
    return
  fi
  if ! ref_exists "$full" "$local_ref"; then
    echo "no_local:${def}"
    return
  fi
  if ! ref_exists "$full" "$up_ref"; then
    echo "no_upstream_ref"
    return
  fi
  local o u
  read -r o u <<<"$(git -C "$full" rev-list --left-right --count "${local_ref}...${up_ref}" 2>/dev/null || echo "0 0")"
  if [[ "${o:-0}" -eq 0 && "${u:-0}" -eq 0 ]]; then
    echo "in_sync"
    return
  fi
  echo "drift:${o:-0}:${u:-0}"
}

format_branch_cell() {
  local full="$1"
  local ref sha
  ref=$(git -C "$full" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
  sha=$(git -C "$full" rev-parse --short HEAD 2>/dev/null || echo "?")
  if [[ "$ref" == "HEAD" ]]; then
    printf 'detached (`%s`)' "$sha"
  else
    printf '`%s` (`%s`)' "$ref" "$sha"
  fi
}

# Status line with emojis: working tree + upstream default drift (local default vs upstream tip)
format_status_cell() {
  local full="$1" upstream="$2" def="$3"
  local wt ds
  if working_tree_clean "$full"; then
    wt="✅ clean"
  else
    wt="⚠️ not clean"
  fi

  ds=$(drift_state "$full" "$upstream" "$def")
  case "$ds" in
    in_sync)
      printf '%s · 🔗 in sync with upstream `%s/%s`' "$wt" "$upstream" "$def"
      ;;
    drift:*)
      local a b
      a="${ds#drift:}"
      b="${a#*:}"
      a="${a%%:*}"
      printf '%s · 📤 %s behind `%s/%s` · %s ahead' "$wt" "$b" "$upstream" "$def" "$a"
      ;;
    no_local:*)
      local br="${ds#no_local:}"
      printf '%s · ❔ no local branch `%s` (upstream default `%s`)' "$wt" "$br" "$def"
      ;;
    no_upstream_ref)
      printf '%s · ❔ missing `refs/remotes/%s/%s` (fetch `%s` in submodule)' "$wt" "$upstream" "$def" "$upstream"
      ;;
    unknown_default)
      printf '%s · ❔ could not resolve upstream default branch' "$wt"
      ;;
    *)
      printf '%s · %s' "$wt" "$ds"
      ;;
  esac
}

print_fix_block() {
  local full="$1" sm_name="$2" upstream="$3" def="$4"
  local qf qu qd
  qf=$(printf '%q' "$full")
  qu=$(printf '%q' "$upstream")
  qd=$(printf '%q' "$def")
  printf '%s\n' "### \`${sm_name}\`"
  printf '%s\n' ""
  printf '%s\n' "\`\`\`bash"
  printf 'git -C %s fetch %s\n' "$qf" "$qu"
  printf 'git -C %s checkout %s\n' "$qf" "$qd"
  printf 'git -C %s rebase %s/%s\n' "$qf" "$qu" "$qd"
  printf '%s\n' "\`\`\`"
  printf '%s\n' ""
}

run_fix_apply() {
  local full="$1" upstream="$2" def="$3"
  git -C "$full" fetch "$upstream"
  git -C "$full" checkout "$def"
  git -C "$full" rebase "${upstream}/${def}"
}

# --- collect submodule rows (name path upstream) ---

declare -a SM_NAMES=()
declare -a SM_PATHS=()
declare -a SM_UPSTREAMS=()

path_keys=$(git config -f "$GITMODULES" --name-only --get-regexp '\.path$' 2>/dev/null || true)
[[ -n "$path_keys" ]] || die "error: .gitmodules defines no submodule paths."

while IFS= read -r path_key; do
  [[ "$path_key" =~ ^submodule\.(.+)\.path$ ]] || continue
  sm_name="${BASH_REMATCH[1]}"
  path=$(git config -f "$GITMODULES" --get "$path_key")
  up=$(get_upstream_name "$sm_name")
  if [[ -z "$up" ]]; then
    die "error: no config entry for submodule \"${sm_name}\" in ${CONFIG_JSON}"
  fi
  SM_NAMES+=("$sm_name")
  SM_PATHS+=("$path")
  SM_UPSTREAMS+=("$up")
done <<<"$path_keys"

# Warn about config entries that do not match any submodule in .gitmodules
if command -v jq >/dev/null 2>&1; then
  while IFS= read -r cn; do
    [[ -z "$cn" ]] && continue
    found=0
    for n in "${SM_NAMES[@]}"; do
      if [[ "$n" == "$cn" ]]; then
        found=1
        break
      fi
    done
    if [[ "$found" -eq 0 ]]; then
      err "warning: config.json lists unknown submodule_name \"${cn}\" (ignored)."
    fi
  done < <(jq -r '.[].submodule_name' "$CONFIG_JSON")
fi

# --- execute mode ---

if [[ "$MODE" == "show" ]]; then
  printf '| Name | Branch | Status |\n'
  printf '|------|--------|--------|\n'
  for i in "${!SM_NAMES[@]}"; do
    sm_name="${SM_NAMES[i]}"
    path="${SM_PATHS[i]}"
    upstream="${SM_UPSTREAMS[i]}"
    full="$ROOT/$path"

    if [[ ! -e "$full" ]] || ! git -C "$full" rev-parse --is-inside-work-tree &>/dev/null; then
      printf '| `%s` | — | ⚠️ not checked out (run \`git submodule update --init \"%s\"\`) |\n' "$sm_name" "$path"
      continue
    fi

    if ! git -C "$full" remote get-url "$upstream" &>/dev/null; then
      printf '| `%s` | %s | ❔ no remote `%s` in checkout — fix config or `git remote add` |\n' \
        "$sm_name" "$(format_branch_cell "$full")" "$upstream"
      continue
    fi

    def=$(remote_default_branch "$full" "$upstream")
    br=$(format_branch_cell "$full")
    st=$(format_status_cell "$full" "$upstream" "$def")
    printf '| `%s` | %s | %s |\n' "$sm_name" "$br" "$st"
  done
  exit 0
fi

if [[ "$MODE" == "fix_print" ]]; then
  printf '%s\n\n' "## Rebase local default onto upstream (dry-run)"
  printf '%s\n\n' "> Review before running. Skips dirty checkouts. Uses \`git -C\` with absolute paths."
  for i in "${!SM_NAMES[@]}"; do
    sm_name="${SM_NAMES[i]}"
    path="${SM_PATHS[i]}"
    upstream="${SM_UPSTREAMS[i]}"
    full="$ROOT/$path"

    if [[ ! -e "$full" ]] || ! git -C "$full" rev-parse --is-inside-work-tree &>/dev/null; then
      err "skip: ${sm_name}: not checked out (${path})"
      continue
    fi
    if ! git -C "$full" remote get-url "$upstream" &>/dev/null; then
      err "skip: ${sm_name}: remote \"${upstream}\" not found"
      continue
    fi
    def=$(remote_default_branch "$full" "$upstream")
    if [[ -z "$def" ]]; then
      err "skip: ${sm_name}: unknown upstream default branch"
      continue
    fi
    if ! working_tree_clean "$full"; then
      err "skip: ${sm_name}: working tree not clean — commit or stash first"
      continue
    fi
    print_fix_block "$full" "$sm_name" "$upstream" "$def"
  done
  exit 0
fi

# fix_apply
for i in "${!SM_NAMES[@]}"; do
  sm_name="${SM_NAMES[i]}"
  path="${SM_PATHS[i]}"
  upstream="${SM_UPSTREAMS[i]}"
  full="$ROOT/$path"

  if [[ ! -e "$full" ]] || ! git -C "$full" rev-parse --is-inside-work-tree &>/dev/null; then
    err "skip: ${sm_name}: not checked out (${path})"
    continue
  fi
  if ! git -C "$full" remote get-url "$upstream" &>/dev/null; then
    err "skip: ${sm_name}: remote \"${upstream}\" not found"
    continue
  fi
  def=$(remote_default_branch "$full" "$upstream")
  if [[ -z "$def" ]]; then
    err "skip: ${sm_name}: unknown upstream default branch"
    continue
  fi
  if ! working_tree_clean "$full"; then
    err "skip: ${sm_name}: working tree not clean — commit or stash first"
    continue
  fi
  if ! run_fix_apply "$full" "$upstream" "$def"; then
    err "error: ${sm_name}: git command failed"
    exit 1
  fi
done
exit 0
