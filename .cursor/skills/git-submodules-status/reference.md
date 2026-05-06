# Output shape and customization

The canonical script [scripts/submodule-status.sh](scripts/submodule-status.sh) defines the markdown table. Change the script if you add/remove columns or change formatting.

## Columns (current)

| Column | Meaning |
|--------|---------|
| Path | Submodule path from root `.gitmodules` (relative to repo root) |
| URL | Clone URL from `.gitmodules` |
| Commit | Short SHA at `HEAD` in the submodule checkout |
| Branch | Current branch, or `detached @ <short SHA>` when not on a branch |
| Working tree | `clean` / `dirty`, or `missing (not checked out)` / `not a git work tree` when uninitialized |

## Skeleton (filled by the script)

```markdown
| Path | URL | Commit | Branch | Working tree |
|------|-----|--------|--------|--------------|
| `<path>` | <url> | `<short>` | <branch or detached> | clean | dirty | … |
```
