# FLPATH-4164 — RBAC UI on-prem MFE (POC)

**Jira:** [FLPATH-4164](https://redhat.atlassian.net/browse/FLPATH-4164) (*POC: RBAC UI as on-prem MFE (koku-ui-onprem + chart RBAC API)*). **Parent:** [FLPATH-3424](https://redhat.atlassian.net/browse/FLPATH-3424).

**Pipeline SoT (git checkout):** [`pipelines/rpi/v1/stages/10-research/output/flpath-4164/RESEARCH.md`](../../pipelines/rpi/v1/stages/10-research/output/flpath-4164/RESEARCH.md) (includes **§ UX vision reference** — Stefan mock on Jira + session link). **20-plan:** [`pipelines/rpi/v1/stages/20-plan/output/flpath-4164/PLAN.md`](../../pipelines/rpi/v1/stages/20-plan/output/flpath-4164/PLAN.md).

**Prerequisite (closed):** [FLPATH-4180](https://redhat.atlassian.net/browse/FLPATH-4180) — see [`flpath-4180-fec-rbac-mfe.md`](flpath-4180-fec-rbac-mfe.md).

**UX vision (product):** On **FLPATH-4164**, Jira **comment +** `ux-vision-my-user-access-cost-onprem.png` (Identity and Access Management shell, **My User Access**); session context: [FLPATH-3424 focused comment](https://redhat.atlassian.net/browse/FLPATH-3424?focusedCommentId=16901888).

## Implementation status (2026-05-18)

| Layer | State |
|-------|--------|
| Remote | `apps/rbac-ui-onprem` — `insightsRbac`, `/rbac/`, `./Iam`; `npm run verify:onprem` ✅ |
| Host | static `/rbac/`, proxy `/api/rbac`, `/iam/*`, `FlagProvider`, chrome + notification shims |
| Image | `Containerfile` serves `./rbac` alongside other MFE remotes |
| Branch | `submodules/koku-ui` → `feat/flpath-4164` |
| Next | Phase 7: `start:onprem:dev` + cluster UI image verification |
