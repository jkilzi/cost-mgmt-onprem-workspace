---
name: git-submodules-status
description: >-
  Use when the user says "show submodules status" or asks to display git submodule
  state from this workspace root. Shows submodule path, URL, short commit,
  checked-out branch (or detached state), and clean/dirty status using only the
  repository root `.gitmodules`. Runs the canonical script `scripts/submodule-status.sh`.
disable-model-invocation: true
---

# Git submodules status (workspace root)

## Quick start

1. From anywhere inside this repository, run:

   ```bash
   ./.cursor/skills/git-submodules-status/scripts/submodule-status.sh
   ```

   Or pass the superproject root: `.../submodule-status.sh /path/to/cost-management-workspace`

2. Show the script **stdout** (markdown table) as the main answer.

3. If there is **stderr** (missing checkout, etc.), summarize it after the table with the suggested next command.

**Output shape** is defined by the script. To change columns or format, edit `scripts/submodule-status.sh` (see [reference.md](reference.md) for a column reference).

## Workflow and constraints

- **Source of truth**: only submodules listed in the **repository root** `.gitmodules`, via the script—do not infer from directories. Ignore nested `.gitmodules` inside checked-out submodules unless the user asks.
- **Display-only**: do not run `git submodule update`, fetch, or checkout unless the user requests it. Do not suggest `git submodule update --remote` unless they ask for that workflow.
- **Presentation**: table first, then stderr notes; missing paths usually mean `git submodule update --init [--recursive]`. If the script exits non-zero, quote the error and suggest running from inside the repo or passing `REPO_ROOT`.
- **After a submodule commit changes** (checkout, pull, bump): remind the user to **commit the superproject** so the new gitlink is recorded (e.g. `git add <path> && git commit` at the workspace root).
- **Honest failures**: do not hide non-zero exits. Do not recurse into a submodule’s own submodules unless the user asks.
