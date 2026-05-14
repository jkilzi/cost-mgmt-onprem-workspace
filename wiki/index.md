# Wiki index

Catalog of pages in this workspace wiki. **Agents:** keep this list accurate when you add, rename, or materially change a page (one line per page, link + summary).

## Workspace

| Page | Summary |
|------|---------|
| [workspace/overview.md](workspace/overview.md) | Cost Management workspace: purpose, boundaries, relation to pipelines/submodules; links to `AGENTS.md`, `.cursor/rules/rpi-pipeline.mdc`, and `.cursor/rules/llm-wiki.mdc`. |

## Concepts

*(Add concept pages here as they are created.)*

## Entities

| Page | Summary |
|------|---------|
| [entities/demo-catalog-cost-onprem-install.md](entities/demo-catalog-cost-onprem-install.md) | Demo Catalog SNO install order; RHBK; **UI login bounce** (Envoy JWT + Keycloak declarative profile); debug commands; ingress tag expiry note. |
| [entities/known-issue-keycloak-declarative-profile-jwt.md](entities/known-issue-keycloak-declarative-profile-jwt.md) | **Known issue:** Keycloak default user profile drops `org_id`/`account_number` → Envoy 401 → UI re-login; skill script workaround + scenarios. |
| [entities/flpath-4180-fec-rbac-mfe.md](entities/flpath-4180-fec-rbac-mfe.md) | **FLPATH-4180:** FEC `ExtensionsPlugin` / fed docs vs `koku-ui-onprem` Scalprum + `DynamicRemotePlugin`; pointer to RPI `flpath-4180` research (unblocks **FLPATH-4164**). |

## Sources ingested

*(Link summary pages for material under `wiki/raw/` after ingest.)*
