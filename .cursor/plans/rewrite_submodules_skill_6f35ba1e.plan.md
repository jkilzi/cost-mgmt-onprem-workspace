---
name: Rewrite submodules skill
overview: "Replace the current git-submodules-status skill with a config-driven, three–use-case workflow: a slim UC1 table (Name / Branch / Status), UC2 rebase-based drift fix (print + optional apply), and UC3 agent-led setup writing `references/config.json`. Ignore all remotes except the configured upstream; remove fork/origin/extra-remote reporting from the default path."
todos:
  - id: add-config-artifacts
    content: Add references/config.json.example + document schema; decide gitignore for references/config.json
    status: completed
  - id: rewrite-script
    content: "Replace scripts/submodule-status.sh: config load, --show / --fix-print / --fix-apply, upstream-only drift (local default vs upstream tip), no extra-remote noise"
    status: completed
  - id: rewrite-skill-docs
    content: "Rewrite SKILL.md + reference.md: UC1–UC3 triggers, setup-only-first rule, emoji Status semantics"
    status: completed
  - id: verify-manual
    content: Run --show and --fix-print against workspace with populated config.json
    status: completed
isProject: false
---

# Rewrite `git-submodules-status` skill (UC1–UC3)

## Locked semantics (from you + follow-up)

- **Upstream identification**: Not inferred from `.gitmodules` URL or org heuristics. **Only** the remote name stored per submodule in [`references/config.json`](.cursor/skills/git-submodules-status/references/config.json) (new file).
- **Ignore other remotes**: Remove [`note_extra_remotes`](.cursor/skills/git-submodules-status/scripts/submodule-status.sh) and any stderr about “additional remotes.”
- **UC1 drift**: Resolve the **upstream** default branch name (`git remote show -n <upstream>`, ignore `(not queried)`, then `refs/remotes/<upstream>/HEAD`, then try `main` / `master` / `trunk` / `develop` if refs exist — same pattern as today but scoped to **configured upstream only**). Compare **`refs/heads/<default>`** to **`refs/remotes/<upstream>/<default>`** (local default branch vs its upstream remote-tracking tip). If local branch missing, Status should say so (not “drifted” vs “missing local default”).
- **UC2 reconcile**: For each submodule: `fetch <upstream>`, `checkout <default>`, `rebase <upstream>/<default>` (your choice: rebase). Guard: if working tree dirty, **do not** apply; print clear message. Default **print-only** commands in the script; add **`--apply`** (or `--yes`) to actually run commands for automation, documented as destructive to the checked-out branch’s history relative to upstream.

## Files to change / add

| Item | Action |
|------|--------|
| [`SKILL.md`](.cursor/skills/git-submodules-status/SKILL.md) | Rewrite: triggers (“show submodules”, “fix drift”, “setup submodules skill”), strict rule that **UC3 runs alone first** until `references/config.json` exists and validates, stdout/stderr contract, emoji convention for clean/dirty. |
| [`reference.md`](.cursor/skills/git-submodules-status/reference.md) | Replace with: `config.json` schema, column meanings, drift definition, UC2 command outline, flags (`--show`, `--fix-print`, `--fix-apply` or single entrypoint + flags — pick one and document). |
| [`references/config.json.example`](.cursor/skills/git-submodules-status/references/config.json.example) | Commit a template array (no real machine-specific data). |
| [`references/config.json`](.cursor/skills/git-submodules-status/references/config.json) | **Created by setup** (likely gitignored — recommend adding to workspace `.gitignore` or documenting “local only”; optional: you commit yours if you want it shared). |
| [`scripts/submodule-status.sh`](.cursor/skills/git-submodules-status/scripts/submodule-status.sh) | **Replace** current implementation: drop fork check, `.gitmodules` URL column, drift vs origin, reconcile-to-origin, `SUBMODULE_STATUS_GITHUB_USER`, and extra-remote notes. New behavior: parse `.gitmodules` for **submodule name** + path; load config JSON (`jq` if available, else minimal `python3 -c` or `grep`/`sed` fallback — prefer `jq` with clear error if missing). |

## Script behavior (concise)

- **No config / invalid config**: exit non-zero + stderr message: run “setup submodules skill” (agent fills `references/config.json`).
- **`--show` (default)**: Markdown table **Name | Branch | Status** only to stdout.
  - **Name**: `.gitmodules` submodule key (e.g. `koku-ui`).
  - **Branch**: `git -C <path> rev-parse --abbrev-ref HEAD` → if `HEAD`, show `detached (\`<short>\`)`; else `\`<branch>\` (\`<short>\`)`**.
  - **Status**: clean/dirty with emojis (e.g. clean + in-sync / clean + drifted / dirty + …); include short drift summary (match / N commits behind-ahead if cheap via `rev-list --left-right --count` between local default branch and `refs/remotes/<upstream>/<default>`).
- **`--fix-print`**: For each submodule, print a fenced bash block: `fetch`, `checkout <default>`, `rebase <upstream>/<default>`, using absolute paths; stderr only for skips (dirty, missing branch, missing upstream remote).
- **`--fix-apply`**: Same as print but run commands; stop on first failure; respect dirty guard.

## UC3 (“setup submodules skill”) — agent workflow (not bash interview)

Because the skill is invoked by an agent in chat, **setup** is best specified as:

1. User says **exactly** “setup submodules skill”.
2. Agent reads [`.gitmodules`](<WORKSPACE_ROOT>/.gitmodules) for submodule **names** (`cost-onprem-chart`, `koku`, `koku-ui`, `insights-rbac-ui`).
3. Agent asks once per submodule: “What’s the upstream remote name for `<name>`?”
4. Agent writes [`references/config.json`](.cursor/skills/git-submodules-status/references/config.json) in the array shape you specified.
5. Agent validates each `upstream_name` exists in that submodule (`git remote get-url <upstream_name>`).

No other submodule-skill actions in that turn (per your requirement).

The shell script **consumes** config only; it does not interactive-prompt (keeps CI/agent parity).

## Migration / cleanup

- Remove obsolete flags (`--default-branch-drift`, `--reconcile-print` tied to origin/upstream tips, fork env vars) from docs and script.
- Optionally keep `REPO_ROOT` as first positional arg for consistency with today.

## Verification

- Run script with example config matching your current remotes (`project-koku`, `insights-onprem`, `RedHatInsights`, etc.) and confirm UC1 table + drift strings.
- Dry-run `--fix-print` on a clean repo; confirm no mutation.
- `--fix-apply` on a throwaway branch (manual test) optional.
