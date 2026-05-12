---
name: git-submodules-status
description: >-
  Use when the user says "show submodules", "fix drift", or exactly "setup submodules skill".
  UC1: markdown table (Name, Branch, Status) from root .gitmodules + references/config.json.
  UC2: print or run rebase of local default branch onto configured upstream default.
  UC3: interview once to build config.json; do not mix with other submodule actions in that turn.
  Runs scripts/submodule-status.sh. Ignores all git remotes except the configured upstream per submodule.
disable-model-invocation: true
---

# Git submodules status (workspace root)

## Prerequisites

- [`references/config.json`](references/config.json) must exist and conform to [`references/config.schema.json`](references/config.schema.json). It is **gitignored**; the schema is committed. After UC3, create `config.json` (see [reference.md](reference.md) for a minimal instance).
- Without valid config, the script exits non-zero — run **UC3** first.

## UC3 — "setup submodules skill" (run alone first)

**Trigger:** user says exactly **`setup submodules skill`**.

**In that turn, do only this** (no `--show`, no `--fix-print`, no other submodule tooling):

1. Read the repository root [`.gitmodules`](../../../.gitmodules) and list each **`submodule "<name>"`** key (e.g. `koku-ui`).
2. For each name, ask: **What’s the upstream remote name for `<name>`?** (the remote pointing at the parent repo they forked from; often the GitHub org name).
3. Write [`references/config.json`](references/config.json) as a JSON array:

   ```json
   [
     { "submodule_name": "koku-ui", "upstream_name": "project-koku" }
   ]
   ```

4. Validate: in each submodule checkout, `git remote get-url <upstream_name>` succeeds (if the submodule is not initialized yet, note that validation can happen after `git submodule update --init`).

## UC1 — "show submodules"

**Trigger:** phrases like **show submodules**, **submodule status**.

1. Run:

   ```bash
   ./.cursor/skills/git-submodules-status/scripts/submodule-status.sh [REPO_ROOT] --show
   ```

   Default mode is `--show` if no mode flag is passed.

2. Present **stdout** (markdown table) as the main answer.

3. Present **stderr** only if the script printed warnings/errors (e.g. missing config, skip messages).

**Table columns**

| Column | Meaning |
|--------|---------|
| **Name** | Submodule key from `.gitmodules` (not the path). |
| **Branch** | Current checkout: `` `branch` (`shortsha`) `` or `detached (`shortsha`)`. |
| **Status** | **✅ clean** or **⚠️ not clean** (working tree), then alignment of **local** `refs/heads/<default>` vs **`refs/remotes/<upstream>/<default>`** (see [reference.md](reference.md) glossary). **🔗 in sync** when tips match; **📤** *N* **behind** … **·** *M* **ahead** when they differ; or **❔** if data is missing. |

Other remotes (`origin`, extra forks, etc.) are **not** listed by this skill.

## UC2 — "fix drift"

**Trigger:** **fix drift**, reconcile drift to upstream.

1. Default: print commands only:

   ```bash
   ./.cursor/skills/git-submodules-status/scripts/submodule-status.sh [REPO_ROOT] --fix-print
   ```

2. Only if the user explicitly asks to **run** the fix: `--fix-apply` (runs `fetch <upstream>`, `checkout <default>`, `rebase <upstream>/<default>` per submodule; skips dirty trees; exits on first git failure).

3. Do **not** run `--fix-apply` without clear user consent (history rewrite risk on that branch).

## Workflow rules

- **Source of truth:** root `.gitmodules` for submodule **names** and paths; `references/config.json` for **upstream remote name** per submodule only.
- **Do not** infer upstream from `.gitmodules` `url` or from extra remotes.
- After changing a submodule’s committed revision, remind the user to **commit the superproject** gitlink if they intend to record it.

## Reference

Column details, JSON schema, and flags: [reference.md](reference.md).
