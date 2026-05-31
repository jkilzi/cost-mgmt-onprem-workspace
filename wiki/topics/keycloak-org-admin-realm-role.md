# Keycloak `org-admin` realm role (on-prem)

**Scope:** Cost Management on-prem · **Realm:** default `kubernetes` (from [`deploy-rhbk.sh`](../../submodules/cost-onprem-chart/scripts/deploy-rhbk.sh))

## What it does

The Envoy gateway reads the JWT `realm_access.roles` claim. If it contains **`org-admin`**, the gateway sets **`is_org_admin: true`** in the `X-Rh-Identity` header sent to Koku and insights-rbac.

That flag drives:

- **insights-rbac** `admin_default` groups (e.g. Cost Administrator, Sources administrator) for `scope=principal` role lists — including **IAM → My User Access** bundle tables
- Org-admin behavior in Cost Management APIs (see chart [rbac-setup.md](../../submodules/cost-onprem-chart/docs/operations/rbac-setup.md))

Without `org-admin`, a user with no explicit RBAC group membership gets **`meta.count: 0`** on `/api/rbac/v1/roles/?scope=principal&…` even when the RBAC API is healthy.

## Option 1 — Keycloak Admin Console (day-2, single user)

Use when a user already exists and you only need to grant or revoke org admin.

**Prerequisites:** Keycloak admin credentials (namespace `keycloak`, secret `keycloak-initial-admin` unless you changed it).

1. Open the Keycloak admin console (cluster route under `keycloak`, or port-forward to the Keycloak service).
2. Select realm **`kubernetes`** (not `master`).
3. **Realm roles** → confirm role **`org-admin`** exists (created by [`deploy-rhbk.sh`](../../submodules/cost-onprem-chart/scripts/deploy-rhbk.sh) realm import).
4. **Users** → find the user (e.g. `admin`) → open the user.
5. **Role mapping** tab → **Assign role** → filter **Realm roles** → select **`org-admin`** → **Assign**.
6. User must **log out and log in again** so the access token includes the new role.

**Revoke:** same path → **Unassign** `org-admin` from the user.

## Option 2 — Declarative via Helm values + `deploy-rhbk.sh` (install / re-sync)

Use when provisioning or re-applying users from chart values.

In your Helm values overlay:

```yaml
jwtAuth:
  realmUsers:
    - username: admin
      password: <change-me>
      email: admin@example.com
      firstName: Admin
      lastName: User
      orgId: "org1234567"
      accountNumber: "7890123"
      orgAdmin: true   # script assigns Keycloak realm role "org-admin"
    - username: viewer
      password: <change-me>
      orgAdmin: false  # no org-admin role
```

From `submodules/cost-onprem-chart`:

```bash
./scripts/deploy-rhbk.sh -f /path/to/your-values.yaml
```

The script creates/updates users from `jwtAuth.realmUsers` and **assigns or removes** the `org-admin` realm role to match each entry’s `orgAdmin` flag (idempotent on re-run).

Defaults live in chart [`values.yaml`](../../submodules/cost-onprem-chart/cost-onprem/values.yaml) under `jwtAuth.realmUsers`.

## Option 3 — RBAC bootstrap job (explicit group, not a substitute for JWT)

`rbac.bootstrapAdmin.enabled: true` runs a post-install Helm job that adds the bootstrap user to RBAC groups/policies. That can restore Cost API access but **does not** set `is_org_admin` in JWT. For IAM **My User Access** and other `admin_default`-based flows, you still want **`org-admin`** on the Keycloak user (Option 1 or 2).

See [installation.md — RBAC](../../submodules/cost-onprem-chart/docs/operations/installation.md) and `rbac.bootstrapAdmin` in chart values.

## Verify

1. **JWT:** After login, decode the **access token** (lab only). Confirm `realm_access.roles` includes **`org-admin`**. Also confirm root-level **`org_id`** and **`account_number`** if API calls fail with 401 — see [known-issue-keycloak-declarative-profile-jwt.md](../entities/known-issue-keycloak-declarative-profile-jwt.md).
2. **RBAC API logs:** `oc logs deployment/cost-onprem-rbac-api -n cost-onprem --tail=20` — structured lines should show `is_admin: True` for that user’s requests (field name in logs; maps from `is_org_admin`).
3. **Roles endpoint:** With a valid session, DevTools → Network → `/api/rbac/v1/roles/?scope=principal&application=cost-management,subscriptions,ocp-advisor,ocm` → **`meta.count` ≥ 1** for an org admin (typically **Cost Administrator** on the OpenShift bundle).

## Related

- [demo-catalog-cost-onprem-install.md](../entities/demo-catalog-cost-onprem-install.md) — RHBK install order, JWT troubleshooting
- [rbac-setup.md — Identity header](../../submodules/cost-onprem-chart/docs/operations/rbac-setup.md) — upstream operator guide (identity header, `realmUsers`, FedRAMP notes)
