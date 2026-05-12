# git-submodules-status — reference

Canonical script: [`scripts/submodule-status.sh`](scripts/submodule-status.sh).

## `references/config.json`

- **Path:** `.cursor/skills/git-submodules-status/references/config.json` (sibling of `scripts/`). The workspace [`.gitignore`](../../../.gitignore) ignores this file so local upstream names are not forced into git.
- **JSON Schema:** [`references/config.schema.json`](references/config.schema.json) (draft-07) — committed; use with editors or `ajv`/`check-jsonschema` to validate `config.json`.

**Instance shape:** a JSON array of objects with `submodule_name` and `upstream_name` only (`additionalProperties: false` in the schema).

| Field | Type | Meaning |
|-------|------|---------|
| `submodule_name` | string | Must match the `[submodule "…"]` name in root `.gitmodules`. |
| `upstream_name` | string | Remote name inside that submodule’s repo (e.g. `project-koku`). |

Every submodule listed in `.gitmodules` **must** have exactly one matching `submodule_name` entry, or the script exits with an error.

Extra entries in `config.json` whose `submodule_name` is not in `.gitmodules` produce a **stderr warning** and are ignored.

**Minimal valid instance** (illustrative — names must match your `.gitmodules` and remotes):

```json
[
  { "submodule_name": "koku-ui", "upstream_name": "project-koku" }
]
```

## Script flags

| Flag | Behavior |
|------|----------|
| `--show` | *(default)* Print markdown table: **Name \| Branch \| Status**. |
| `--fix-print` | Print markdown + fenced bash per submodule: `fetch`, `checkout <default>`, `rebase upstream/default`. Skips dirty / missing / invalid checkouts (stderr). |
| `--fix-apply` | Run the same git sequence; skips dirty; **exits 1** on first failing `git` command. |
| `-h`, `--help` | Usage on stderr. |

Positional **`REPO_ROOT`** (optional): git top-level of the superproject; defaults to current repo.

**Dependencies:** `jq` **or** `python3` to parse JSON.

## Drift semantics (UC1 Status)

1. Resolve **upstream default branch name** inside the submodule: `git remote show -n <upstream>`, ignoring `HEAD branch: (not queried)`; else `refs/remotes/<upstream>/HEAD`; else first existing remote-tracking ref among `main`, `master`, `trunk`, `develop`.
2. Compare **`refs/heads/<default>`** (local branch named like upstream default) to **`refs/remotes/<upstream>/<default>`**.
3. **Independent of current `HEAD`:** drift describes whether **that local default branch** matches the upstream tip, not whether you are checked out on it.
4. Counts use `git rev-list --left-right --count refs/heads/<default>...refs/remotes/<upstream>/<default>`: the script reports them as **behind** then **ahead** (see [Glossary](#glossary-status-drift-counts)).

## Glossary (Status drift counts)

In the **Status** column, when the local default branch tip and `refs/remotes/<upstream>/<default>` differ, the script prints **`📤` *N* behind `upstream/default` · *M* ahead**:

| Term | Meaning |
|------|--------|
| **Behind (N)** | Commits reachable from the upstream remote-tracking tip that are **not** reachable from your local `refs/heads/<default>`. Plainly: your local branch with that name is **missing N commits** that already exist on upstream’s default. |
| **Ahead (M)** | Commits reachable from your local `refs/heads/<default>` that are **not** reachable from the upstream tip. Plainly: you have **M commits** on that local branch that upstream’s default does not contain. |

These are the two numbers from `git rev-list --left-right --count` (merge-base relative), ordered as **behind · ahead** in the table for readability.

## Status emojis (working tree)

| Emoji | Meaning |
|-------|---------|
| ✅ clean | `git status --porcelain` empty in submodule. |
| ⚠️ not clean | Uncommitted changes in submodule. |

Drift suffix uses **🔗** (in sync), **📤** *N* **behind** … **·** *M* **ahead** (out of sync), or **❔** (missing data).

## UC2 command sequence (per submodule)

```text
git -C <absolute-submodule-path> fetch <upstream_name>
git -C <absolute-submodule-path> checkout <default_branch>
git -C <absolute-submodule-path> rebase <upstream_name>/<default_branch>
```

`--fix-print` never runs these; `--fix-apply` runs them when the tree is clean and remotes exist.
