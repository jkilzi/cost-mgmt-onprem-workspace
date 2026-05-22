# FLPATH-4164 — Visual sign-off (rc18 POC)

**Date:** 2026-05-21  
**Image (POC shell):** `quay.io/<your-org>/koku-ui-onprem:flpath-4164-rc18`  
**Image (parity verify):** `quay.io/<your-org>/koku-ui-onprem:flpath-4164-rc19` — cluster screenshots refreshed 2026-05-21  
**Cluster:** `https://cost-onprem-ui-cost-onprem.apps.<leased-cluster>.<workshop-domain>/` (record actual host locally; not committed)

**Refresh `cluster/*.png`:** Manual browser capture on cluster (1440×900 viewport). Cluster parity Cypress and copy script removed 2026-05-22.

## Stakeholder sign-off (layout shell)

> Round 2 matches my screen; IAM nav + five routes acceptable for rc18 POC.

**Evidence:** `cluster/*.png` (2026-05-21). Host sidebar does **not** overlap IAM content at normal panel width.

---

## Storybook parity — product decisions

| Area | Decision | Notes |
|------|----------|--------|
| **MUA-02** — bundle cards vs dropdown | **Fixed rc19** | [`cluster/02-mua.png`](cluster/02-mua.png) |
| **USR-02–05**, **ROL-02–05**, **GRP-02–05** — table toolbars, Create actions, pagination | **Fixed rc19** | [`cluster/03–05`](cluster/) |
| **C-01**, **C-02** — breadcrumbs, document title | **Out of scope (POC)** | Chrome stub / host tab title. |
| **OV** — overview landing icon | **Fixed** (host static) | `koku-ui-onprem` copies `iam.svg` → `/apps/frontend-assets/technology-icons/`; verify on cluster after rc20+ |

**Storybook baselines** (pin `b4ca3746`): `storybook/sb-*.png` · `insights-rbac-ui@b4ca374603344a60ea3260433a4c913f1ff93ae3`.

---

## OV — overview icon (fixed on host)

**Symptom (was):** Broken image on User Access overview (`alt="RBAC landing page icon"`).

**Cause:** Shared `Overview` references `/apps/frontend-assets/technology-icons/iam.svg` — a Hybrid Cloud Console path the on-prem host did not serve.

**Fix (2026-05-22):** Vendored canonical `iam.svg` from `console.redhat.com` into `submodules/koku-ui/apps/koku-ui-onprem/src/assets/technology-icons/iam.svg`. `CopyWebpackPlugin` in host webpack emits `dist/apps/frontend-assets/technology-icons/iam.svg` (served at `/` via chart nginx `location /`). No `insights-rbac-ui` edit.

**Verify:** On cluster, confirm `img.rbac-overview-icon` loads on `/iam/user-access/overview`. Rebuild **rc20+** and refresh `cluster/01-overview.png` for visual evidence.

---

## Screenshot index

| Route | Cluster | Storybook |
|-------|---------|-----------|
| Overview | `cluster/01-overview.png` | `storybook/sb-01-overview.png` |
| My User Access | `cluster/02-mua.png` | `storybook/sb-02b-mua-org-admin.png` |
| Users | `cluster/03-users.png` | `storybook/sb-03-users.png` |
| Roles | `cluster/04-roles.png` | `storybook/sb-03-roles.png` |
| Groups | `cluster/05-groups.png` | `storybook/sb-04-groups.png` |

---

## Sign-off table

| Reviewer | Date | Outcome |
|----------|------|---------|
| Stakeholder | 2026-05-21 | **POC shell accepted** — IAM nav + five routes (rc18) |
| | | **Storybook table/bundle parity** — must fix (tracked above) |
| | | **C-01/C-02** — out of scope for POC |
