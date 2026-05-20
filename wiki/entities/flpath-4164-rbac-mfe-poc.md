# FLPATH-4164 — RBAC UI on-prem MFE (POC)

**Jira:** [FLPATH-4164](https://redhat.atlassian.net/browse/FLPATH-4164) (*POC: RBAC UI as on-prem MFE (koku-ui-onprem + chart RBAC API)*). **Parent:** [FLPATH-3424](https://redhat.atlassian.net/browse/FLPATH-3424).

**Pipeline SoT:** [`pipelines/rpi/v1/stages/20-plan/output/flpath-4164/PLAN.md`](../../pipelines/rpi/v1/stages/20-plan/output/flpath-4164/PLAN.md) — consolidated scope, research digest, phases 0–8 (nav fix). Facts-only research: [`RESEARCH.md`](../../pipelines/rpi/v1/stages/10-research/output/flpath-4164/RESEARCH.md).

**Prerequisite (closed):** [FLPATH-4180](https://redhat.atlassian.net/browse/FLPATH-4180) — see [`flpath-4180-fec-rbac-mfe.md`](flpath-4180-fec-rbac-mfe.md).

**UX vision (product):** On **FLPATH-4164**, Jira **comment +** `ux-vision-my-user-access-cost-onprem.png` (Identity and Access Management shell, **My User Access**); session context: [FLPATH-3424 focused comment](https://redhat.atlassian.net/browse/FLPATH-3424?focusedCommentId=16901888).

## Implementation status (2026-05-19)

| Layer | State |
|-------|--------|
| Remote | `apps/rbac-ui-onprem` — `insightsRbac`, `/rbac/`, `./Iam` (lazy entry); `RBACHook` shim; `npm run verify:onprem` ✅ |
| Host | static `/rbac/`, proxy `/api/rbac`, `/iam/*`, `FlagProvider` under `ScalprumProvider`, chrome stub |
| Chart | nginx `location /rbac/` — branch `feat/flpath-4164-ui-rbac-nginx` in `cost-onprem-chart` |
| Cluster image | `quay.io/<your-org>/koku-ui-onprem:flpath-4164-rc15` — hybrid pack (digest in [`VERIFICATION.md`](../../pipelines/rpi/v1/stages/40-verify/output/flpath-4164/VERIFICATION.md)) |
| Branch | `submodules/koku-ui` → `feat/flpath-4164` |
| Verified | Overview + **My User Access** on `<leased-cluster>`; local nav **5/5** (`verify:onprem-nav`) |
| Host nav | `basename=/iam`, `useAppLink` shim, **stable** `useChrome` singleton, PF shims, `assign`/`href`; see **PLAN.md** Phase 8 |
| Next | Manual cluster nav spot-check on **rc15** (SSO); PRs (koku-ui + chart) |
