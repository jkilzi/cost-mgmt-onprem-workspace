#!/usr/bin/env bash
#
# Workaround: Keycloak declarative user profile + Envoy JWT (org_id / account_number)
#
# RHBK / modern Keycloak realms created by deploy-rhbk.sh get Keycloak's default
# declarative user profile (username, email, firstName, lastName only). Custom
# attributes org_id and account_number are SILENTLY DROPPED on user create/update
# until unmanagedAttributePolicy is ENABLED (or those attributes are added to the
# profile). Tokens then lack org_id/account_number → Envoy 401 → UI bounce to login.
#
# Usage:
#   ./keycloak-fix-org-jwt-claims.sh fix          # apply (idempotent)
#   ./keycloak-fix-org-jwt-claims.sh verify     # exit 0 if OK, 1 if fix needed or error
#   ./keycloak-fix-org-jwt-claims.sh fix --dry-run
#
# Prerequisites: oc (logged in), curl, jq
#
# Environment (defaults match deploy-rhbk.sh / chart expectations):
#   RHBK_NAMESPACE=keycloak
#   REALM_NAME=kubernetes
#   KEYCLOAK_ROUTE_NAME=keycloak
#   KEYCLOAK_USERNAME=admin
#   ORG_ID=org1234567
#   ACCOUNT_NUMBER=7890123

set -euo pipefail

RHBK_NAMESPACE="${RHBK_NAMESPACE:-keycloak}"
REALM_NAME="${REALM_NAME:-kubernetes}"
KEYCLOAK_ROUTE_NAME="${KEYCLOAK_ROUTE_NAME:-keycloak}"
KEYCLOAK_USERNAME="${KEYCLOAK_USERNAME:-admin}"
ORG_ID="${ORG_ID:-org1234567}"
ACCOUNT_NUMBER="${ACCOUNT_NUMBER:-7890123}"

CMD="${1:-}"
DRY_RUN=0
if [[ "${2:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

usage() {
  sed -n '1,25p' "$0" | tail -n +2
  echo "Commands: fix | verify | help"
  exit "${1:-0}"
}

[[ "$CMD" == "help" || "$CMD" == "-h" || "$CMD" == "--help" ]] && usage 0
[[ -z "$CMD" ]] && usage 1

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}

need_cmd oc
need_cmd curl
need_cmd jq

if ! oc whoami >/dev/null 2>&1; then
  echo "ERROR: not logged in; run oc login" >&2
  exit 1
fi

kc_host="$(oc get route "$KEYCLOAK_ROUTE_NAME" -n "$RHBK_NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || true)"
if [[ -z "$kc_host" ]]; then
  echo "ERROR: no route '$KEYCLOAK_ROUTE_NAME' in namespace '$RHBK_NAMESPACE'" >&2
  exit 1
fi
KEYCLOAK_URL="https://${kc_host}"

ADMIN_USERNAME="$(oc get secret keycloak-initial-admin -n "$RHBK_NAMESPACE" -o jsonpath='{.data.username}' 2>/dev/null | base64 -d || true)"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="$(oc get secret keycloak-initial-admin -n "$RHBK_NAMESPACE" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)"
if [[ -z "$ADMIN_PASSWORD" ]]; then
  echo "ERROR: could not read keycloak-initial-admin password in $RHBK_NAMESPACE" >&2
  exit 1
fi

get_admin_token() {
  curl -sk -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${ADMIN_USERNAME}" \
    -d "password=${ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token // empty'
}

ACCESS_TOKEN="$(get_admin_token)"
if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "ERROR: failed to obtain Keycloak master admin token" >&2
  exit 1
fi

profile_get() {
  curl -sk "$KEYCLOAK_URL/admin/realms/${REALM_NAME}/users/profile" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}"
}

profile_put() {
  local body="$1"
  curl -sk -o /dev/null -w "%{http_code}" -X PUT "$KEYCLOAK_URL/admin/realms/${REALM_NAME}/users/profile" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$body"
}

user_id_for_username() {
  local u="$1"
  curl -sk "$KEYCLOAK_URL/admin/realms/${REALM_NAME}/users?username=${u}&exact=true" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq -r '.[0].id // empty'
}

user_get() {
  local id="$1"
  curl -sk "$KEYCLOAK_URL/admin/realms/${REALM_NAME}/users/${id}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}"
}

user_list_brief() {
  local u="$1"
  curl -sk "$KEYCLOAK_URL/admin/realms/${REALM_NAME}/users?username=${u}&exact=true&briefRepresentation=false" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}"
}

check_profile_enabled() {
  local pol
  pol="$(profile_get | jq -r '.unmanagedAttributePolicy // empty')"
  [[ "$pol" == "ENABLED" ]]
}

check_user_attrs() {
  local blob
  blob="$(user_list_brief "$KEYCLOAK_USERNAME")"
  echo "$blob" | jq -e --arg org "$ORG_ID" \
    '.[0].attributes.org_id // [] | index($org) != null' >/dev/null 2>&1 || return 1
  echo "$blob" | jq -e --arg acct "$ACCOUNT_NUMBER" \
    '.[0].attributes.account_number // [] | index($acct) != null' >/dev/null 2>&1 || return 1
}

case "$CMD" in
  verify)
    ok=1
    if check_profile_enabled; then
      echo "OK: realm user profile unmanagedAttributePolicy=ENABLED"
    else
      echo "NEEDS_FIX: unmanagedAttributePolicy is not ENABLED (declarative profile blocks custom user attributes)"
      ok=0
    fi
    if check_user_attrs; then
      echo "OK: user '${KEYCLOAK_USERNAME}' has org_id=${ORG_ID} and account_number=${ACCOUNT_NUMBER}"
    else
      echo "NEEDS_FIX: user '${KEYCLOAK_USERNAME}' missing org_id/account_number attributes (or wrong values)"
      ok=0
    fi
    [[ "$ok" -eq 1 ]] && exit 0
    exit 1
    ;;
  fix)
    PROFILE_JSON="$(profile_get)"
    if ! echo "$PROFILE_JSON" | jq -e . >/dev/null 2>&1; then
      echo "ERROR: invalid JSON from users/profile (wrong realm or Keycloak down?)" >&2
      exit 1
    fi
    PROFILE_NEW="$(echo "$PROFILE_JSON" | jq '. + {unmanagedAttributePolicy: "ENABLED"}')"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] Would PUT users/profile with unmanagedAttributePolicy=ENABLED"
      echo "[dry-run] Would merge user ${KEYCLOAK_USERNAME} attributes org_id/account_number"
      exit 0
    fi
    code="$(profile_put "$PROFILE_NEW")"
    if [[ "$code" != "200" && "$code" != "204" ]]; then
      echo "ERROR: PUT users/profile failed HTTP $code" >&2
      exit 1
    fi
    echo "Applied: realm user profile unmanagedAttributePolicy=ENABLED (HTTP $code)"

    USER_ID="$(user_id_for_username "$KEYCLOAK_USERNAME")"
    if [[ -z "$USER_ID" ]]; then
      echo "ERROR: no user named '$KEYCLOAK_USERNAME' in realm $REALM_NAME" >&2
      exit 1
    fi
    USER_JSON="$(user_get "$USER_ID")"
    USER_BODY="$(echo "$USER_JSON" | jq --arg org "$ORG_ID" --arg acct "$ACCOUNT_NUMBER" \
      'del(.access)
       | .attributes = ((.attributes // {}) + {org_id: [$org], account_number: [$acct]})')"
    code="$(curl -sk -o /dev/null -w "%{http_code}" -X PUT "$KEYCLOAK_URL/admin/realms/${REALM_NAME}/users/${USER_ID}" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$USER_BODY")"
    if [[ "$code" != "204" ]]; then
      echo "ERROR: PUT user failed HTTP $code" >&2
      exit 1
    fi
    echo "Applied: user '$KEYCLOAK_USERNAME' ($USER_ID) attributes org_id/account_number (HTTP $code)"

    SELF="${BASH_SOURCE[0]:-$0}"
    if ! bash "$SELF" verify >/dev/null 2>&1; then
      echo "WARNING: post-fix verify did not pass; re-run with: bash $SELF verify" >&2
      exit 1
    fi
    echo "Verify: OK (profile + user attributes)"
    ;;
  *)
    usage 1
    ;;
esac
