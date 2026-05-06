#!/usr/bin/env bash
# Prints submodule status from the repository root .gitmodules (source of truth).
# Usage: submodule-status.sh [REPO_ROOT]
# REPO_ROOT defaults to the git top-level of the current working directory.

set -euo pipefail

err() {
  printf '%s\n' "$*" >&2
}

die() {
  err "$@"
  exit 1
}

ROOT="${1:-}"
if [[ -n "$ROOT" ]]; then
  ROOT=$(cd "$ROOT" && git rev-parse --show-toplevel)
else
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die "error: not inside a git repository (pass REPO_ROOT if needed)"
fi

GITMODULES="$ROOT/.gitmodules"
[[ -f "$GITMODULES" ]] || die "error: no .gitmodules at repository root: $ROOT"

printf '| Path | URL | Commit | Branch | Working tree |\n'
printf '|------|-----|--------|--------|--------------|\n'

path_keys=$(git config -f "$GITMODULES" --name-only --get-regexp '\.path$' 2>/dev/null || true)
if [[ -z "$path_keys" ]]; then
  err "note: .gitmodules defines no submodule paths."
  exit 0
fi

while IFS= read -r path_key; do
  [[ "$path_key" =~ ^submodule\.(.+)\.path$ ]] || continue
  name="${BASH_REMATCH[1]}"
  path=$(git config -f "$GITMODULES" --get "$path_key")
  url=$(git config -f "$GITMODULES" --get "submodule.${name}.url" 2>/dev/null || echo "")

  full="$ROOT/$path"
  short_sha="—"
  branch_cell="—"
  wt="—"

  if [[ ! -e "$full" ]]; then
    wt="missing (not checked out)"
    printf '| `%s` | %s | %s | %s | %s |\n' "$path" "$url" "$short_sha" "$branch_cell" "$wt"
    err "note: ${path}: path missing — run: git submodule update --init --recursive"
    continue
  fi

  if ! git -C "$full" rev-parse --is-inside-work-tree &>/dev/null; then
    wt="not a git work tree"
    printf '| `%s` | %s | %s | %s | %s |\n' "$path" "$url" "$short_sha" "$branch_cell" "$wt"
    err "note: ${path}: not a valid submodule checkout — try: git submodule update --init \"${path}\""
    continue
  fi

  short_sha=$(git -C "$full" rev-parse --short HEAD 2>/dev/null || echo "?")
  ref=$(git -C "$full" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
  if [[ "$ref" == "HEAD" ]]; then
    branch_cell="detached @ ${short_sha}"
  else
    branch_cell="$ref"
  fi

  if [[ -n "$(git -C "$full" status --porcelain 2>/dev/null)" ]]; then
    wt="dirty"
  else
    wt="clean"
  fi

  printf '| `%s` | %s | `%s` | %s | %s |\n' "$path" "$url" "$short_sha" "$branch_cell" "$wt"
done <<< "$path_keys"
