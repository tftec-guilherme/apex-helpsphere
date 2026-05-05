"""HelpSphere v2.1.0 — auth_init.py (TWO-APP PATTERN, Decisão #19).

Replaces the upstream single-app pattern with the production-grade two-app pattern
required by Microsoft Entra ID:

  - Server App `helpsphere`     — exposes `access_as_user` scope, Directory
                                  Extension `app_tenant_id`, Optional Claim,
                                  `requestedAccessTokenVersion=2` (CRITICAL).
  - Client App `helpsphere-client` — SPA + Web platforms, Graph perms (User.Read +
                                     openid + profile + email + offline_access),
                                     consumes Server's `access_as_user` scope.

Microsoft BLOCKS single-app self-token consumption with `AADSTS90009` (application
requesting token for itself), so SPA + API on the same App Reg is unsupported.

All operations are idempotent: re-running this script never breaks existing apps,
secrets, extensions, grants — it only fills in what's missing.

Outputs persisted to azd env (consumed by Bicep `main.parameters.json`):
  AZURE_SERVER_APP_ID, AZURE_SERVER_APP_SECRET,
  AZURE_CLIENT_APP_ID, AZURE_CLIENT_APP_SECRET,
  AZURE_USE_AUTHENTICATION=true.

References:
  - Decisão #19 (DECISION-LOG.md): two-app pattern obrigatorio
  - Decisão #20 (DECISION-LOG.md): Directory Extension app_tenant_id +
    requestedAccessTokenVersion=2 + Optional Claim
  - feedback_two_app_pattern_required.md (project memory)
  - feedback_bicep_audience_must_use_serverappid.md (project memory)
"""

import asyncio
import json
import os
import subprocess
import uuid
from typing import Any, Optional

import aiohttp
from azure.identity.aio import AzureDeveloperCliCredential
from kiota_abstractions.api_error import APIError
from kiota_abstractions.base_request_configuration import RequestConfiguration
from msgraph import GraphServiceClient
from msgraph.generated.applications.applications_request_builder import (
    ApplicationsRequestBuilder,
)
from msgraph.generated.applications.item.add_password.add_password_post_request_body import (
    AddPasswordPostRequestBody,
)
from msgraph.generated.models.api_application import ApiApplication
from msgraph.generated.models.application import Application
from msgraph.generated.models.implicit_grant_settings import ImplicitGrantSettings
from msgraph.generated.models.o_auth2_permission_grant import OAuth2PermissionGrant
from msgraph.generated.models.password_credential import PasswordCredential
from msgraph.generated.models.permission_scope import PermissionScope
from msgraph.generated.models.required_resource_access import RequiredResourceAccess
from msgraph.generated.models.resource_access import ResourceAccess
from msgraph.generated.models.service_principal import ServicePrincipal
from msgraph.generated.models.spa_application import SpaApplication
from msgraph.generated.models.web_application import WebApplication
from msgraph.generated.oauth2_permission_grants.oauth2_permission_grants_request_builder import (
    Oauth2PermissionGrantsRequestBuilder,
)

from auth_common import test_authentication_enabled
from load_azd_env import load_azd_env

# ---------------------------------------------------------------------------
# Constants — display names + Microsoft Graph well-known IDs
# ---------------------------------------------------------------------------

SERVER_APP_DISPLAY_NAME = "helpsphere"
CLIENT_APP_DISPLAY_NAME = "helpsphere-client"

GRAPH_APP_ID = "00000003-0000-0000-c000-000000000000"
GRAPH_SCOPES = {
    # name                              # scope id (Microsoft Graph delegated)
    "User.Read": "e1fe6dd8-ba31-4d61-89e7-88639da4683d",
    "openid": "37f7f235-527c-4136-accd-4a02d197296e",
    "profile": "14dad69e-099b-42c9-810b-d002981feec1",
    "email": "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0",
    "offline_access": "7427e0e9-2fba-42fe-b0c0-848c9e6a8182",
}
GRAPH_BASE = "https://graph.microsoft.com/v1.0"

# Deterministic UUID for the `access_as_user` scope on the Server App.
# Idempotency: same UUID across re-runs so PATCH never duplicates the scope.
ACCESS_AS_USER_SCOPE_ID = uuid.UUID("7b207263-0c4a-4127-a6fe-38ea8c8cd1a7")
SCOPE_NAME = "access_as_user"


# ---------------------------------------------------------------------------
# azd env helpers
# ---------------------------------------------------------------------------


def update_azd_env(name: str, val: str) -> None:
    """Set a variable in the active azd env file."""
    subprocess.run(f'azd env set {name} "{val}"', shell=True, check=False)


# ---------------------------------------------------------------------------
# Application lookup helpers
# ---------------------------------------------------------------------------


async def find_app_by_app_id(graph_client: GraphServiceClient, app_id: str) -> Optional[Application]:
    """Fetch an application by its appId (clientId), returns None if not found."""
    try:
        return await graph_client.applications_with_app_id(app_id).get()
    except APIError:
        return None


async def find_app_by_display_name(graph_client: GraphServiceClient, display_name: str) -> Optional[Application]:
    """Fetch the FIRST application matching the display name (idempotency lookup)."""
    query_params = ApplicationsRequestBuilder.ApplicationsRequestBuilderGetQueryParameters(
        filter=f"displayName eq '{display_name}'"
    )
    request_config = RequestConfiguration[ApplicationsRequestBuilder.ApplicationsRequestBuilderGetQueryParameters](
        query_parameters=query_params
    )
    try:
        result = await graph_client.applications.get(request_configuration=request_config)
        if result and result.value:
            return result.value[0]
    except APIError:
        pass
    return None


async def ensure_application(
    graph_client: GraphServiceClient,
    display_name: str,
    app_id_env_var: str,
) -> tuple[str, str]:
    """Create or look up an application. Returns (object_id, app_id). Idempotent.

    Lookup order:
      1) `app_id_env_var` already present in azd env → re-use that App Reg
      2) Search by display name (handles re-runs after env was wiped)
      3) Create new
    """
    # 1) env-based lookup
    cached_app_id = os.getenv(app_id_env_var, "no-id")
    if cached_app_id and cached_app_id != "no-id":
        existing = await find_app_by_app_id(graph_client, cached_app_id)
        if existing and existing.id and existing.app_id:
            print(f"[ensure_application] Reusing {display_name} from azd env: {existing.app_id}")
            return existing.id, existing.app_id

    # 2) display-name lookup (env wipe / cross-machine re-run)
    by_name = await find_app_by_display_name(graph_client, display_name)
    if by_name and by_name.id and by_name.app_id:
        print(f"[ensure_application] Found existing {display_name} by name: {by_name.app_id}")
        update_azd_env(app_id_env_var, by_name.app_id)
        return by_name.id, by_name.app_id

    # 3) create
    print(f"[ensure_application] Creating {display_name}...")
    created = await graph_client.applications.post(
        Application(display_name=display_name, sign_in_audience="AzureADMyOrg")
    )
    if not created or not created.id or not created.app_id:
        raise RuntimeError(f"Failed to create application {display_name}")
    update_azd_env(app_id_env_var, created.app_id)
    print(f"[ensure_application] Created {display_name}: {created.app_id}")
    return created.id, created.app_id


async def ensure_service_principal(graph_client: GraphServiceClient, app_id: str) -> str:
    """Ensure a Service Principal exists for `app_id`. Returns SP object id."""
    try:
        sp = await graph_client.service_principals_with_app_id(app_id).get()
        if sp and sp.id:
            return sp.id
    except APIError:
        pass

    # 404 → create it
    print(f"[ensure_service_principal] Creating SP for {app_id}")
    created = await graph_client.service_principals.post(ServicePrincipal(app_id=app_id))
    if not created or not created.id:
        raise RuntimeError(f"Failed to create service principal for {app_id}")
    return created.id


async def ensure_secret(
    graph_client: GraphServiceClient,
    object_id: str,
    secret_env_var: str,
    display: str = "AppSecret",
) -> None:
    """Create a client secret only if azd env doesn't have one yet.

    NOTE: secrets cannot be re-fetched from Graph — we MUST trust the env var
    presence to decide. If user lost the secret, set `secret_env_var=` in azd env
    to empty string and re-run.
    """
    if os.getenv(secret_env_var, "no-secret") not in ("no-secret", ""):
        print(f"[ensure_secret] {secret_env_var} already in azd env — skip secret creation")
        return

    print(f"[ensure_secret] Creating secret for {object_id} → {secret_env_var}")
    body = AddPasswordPostRequestBody(password_credential=PasswordCredential(display_name=display))
    response = await graph_client.applications.by_application_id(object_id).add_password.post(body)
    if not response or not response.secret_text:
        raise RuntimeError(f"Failed to create secret for {object_id}")
    update_azd_env(secret_env_var, response.secret_text)


# ---------------------------------------------------------------------------
# Server App — features (scope, version 2 token, identifierUris, Optional Claim)
# ---------------------------------------------------------------------------


def _server_app_features_payload(server_app_id: str) -> Application:
    """Build the Application patch body for Server App features.

    Sets:
      - identifierUris = [api://<server_app_id>]
      - api.requestedAccessTokenVersion = 2 (CRITICAL — without this, Directory
        Extension claims do NOT flow into the access token)
      - api.oauth2PermissionScopes = [access_as_user]
      - web.implicitGrantSettings.enableIdTokenIssuance = true
    """
    return Application(
        identifier_uris=[f"api://{server_app_id}"],
        api=ApiApplication(
            requested_access_token_version=2,
            oauth2_permission_scopes=[
                PermissionScope(
                    id=ACCESS_AS_USER_SCOPE_ID,
                    admin_consent_display_name="Access HelpSphere API",
                    admin_consent_description="Allows the app to access HelpSphere API as the signed-in user.",
                    user_consent_display_name="Access HelpSphere API",
                    user_consent_description="Allow the app to access HelpSphere API on your behalf",
                    is_enabled=True,
                    value=SCOPE_NAME,
                    type="User",
                )
            ],
        ),
        web=WebApplication(
            implicit_grant_settings=ImplicitGrantSettings(enable_id_token_issuance=True),
        ),
    )


async def patch_server_app_features(
    graph_client: GraphServiceClient, server_object_id: str, server_app_id: str
) -> None:
    """Apply identifierUris + scope + accessTokenV2 + idTokenIssuance — idempotent.

    Microsoft Graph rejeita PATCH em oauth2PermissionScopes quando o scope já
    existe e está `isEnabled=true` (CannotDeleteOrUpdateEnabledEntitlement).
    Solução: GET primeiro, e se o scope `access_as_user` JÁ existe com o ID
    determinístico esperado, EXCLUI `oauth2_permission_scopes` do payload e
    PATCH-a apenas os outros campos (identifierUris + requestedAccessTokenVersion
    + web.implicitGrantSettings).
    """
    print(f"[patch_server_app_features] Applying server app features → {server_app_id}")

    # GET current state to decide if we need to include scopes in the patch.
    # Match por VALUE (não ID) — sessões anteriores podem ter criado o scope
    # com UUIDs diferentes do determinístico ACCESS_AS_USER_SCOPE_ID. O que
    # importa para idempotência é existir um scope com value="access_as_user"
    # enabled — qualquer UUID válido serve, e re-PATCH com UUID diferente é
    # rejeitado por Microsoft Graph (CannotDeleteOrUpdateEnabledEntitlement).
    existing = await graph_client.applications.by_application_id(server_object_id).get()
    scope_already_correct = False
    if existing and existing.api and existing.api.oauth2_permission_scopes:
        for scope in existing.api.oauth2_permission_scopes:
            if scope.value == SCOPE_NAME and scope.is_enabled is True:
                scope_already_correct = True
                print(
                    f"[patch_server_app_features] Scope access_as_user already exists enabled "
                    f"(id={scope.id}) → skipping scope patch"
                )
                break

    if scope_already_correct:
        # PATCH WITHOUT oauth2_permission_scopes (avoids enabled-scope mutation error)
        payload = Application(
            identifier_uris=[f"api://{server_app_id}"],
            api=ApiApplication(requested_access_token_version=2),
            web=WebApplication(
                implicit_grant_settings=ImplicitGrantSettings(enable_id_token_issuance=True),
            ),
        )
    else:
        payload = _server_app_features_payload(server_app_id)
    await graph_client.applications.by_application_id(server_object_id).patch(payload)


# ---------------------------------------------------------------------------
# Directory Extension `app_tenant_id` + Optional Claim
# These features need raw Graph REST (msgraph SDK doesn't expose them cleanly).
# ---------------------------------------------------------------------------


async def _get_graph_token(credential: AzureDeveloperCliCredential) -> str:
    token = await credential.get_token("https://graph.microsoft.com/.default")
    return token.token


async def ensure_directory_extension(
    session: aiohttp.ClientSession,
    token: str,
    server_object_id: str,
    server_app_id: str,
) -> str:
    """Ensure Directory Extension `app_tenant_id` exists on Server App.

    Returns the FULL extension name (`extension_<appIdNoHyphens>_app_tenant_id`),
    which is what the Optional Claim entry must reference.
    """
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    list_url = f"{GRAPH_BASE}/applications/{server_object_id}/extensionProperties"
    async with session.get(list_url, headers=headers) as resp:
        resp.raise_for_status()
        body = await resp.json()
        for ext in body.get("value", []):
            if ext.get("name", "").endswith("_app_tenant_id"):
                print(f"[ensure_directory_extension] Reusing existing extension: {ext['name']}")
                return ext["name"]

    # POST create
    print("[ensure_directory_extension] Creating Directory Extension app_tenant_id ...")
    payload = {
        "name": "app_tenant_id",
        "dataType": "String",
        "targetObjects": ["User"],
    }
    async with session.post(list_url, headers=headers, json=payload) as resp:
        resp.raise_for_status()
        body = await resp.json()
        full_name: str = body["name"]
        print(f"[ensure_directory_extension] Created extension: {full_name}")
        return full_name


async def ensure_optional_claim(
    session: aiohttp.ClientSession,
    token: str,
    server_object_id: str,
    extension_full_name: str,
) -> None:
    """Ensure Optional Claim points at extension on accessToken + idToken.

    saml2Token left empty (no SAML in this stack).
    Idempotent: PATCH with full state — if already present, no-op.
    """
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    url = f"{GRAPH_BASE}/applications/{server_object_id}"

    # First read current optionalClaims to merge non-conflicting entries.
    async with session.get(f"{url}?$select=optionalClaims", headers=headers) as resp:
        resp.raise_for_status()
        existing = (await resp.json()).get("optionalClaims") or {}

    def merge(claims: list[dict[str, Any]] | None) -> list[dict[str, Any]]:
        out = [c for c in (claims or []) if c.get("name") != extension_full_name]
        out.append(
            {
                "name": extension_full_name,
                "source": "user",
                "essential": False,
                "additionalProperties": [],
            }
        )
        return out

    payload = {
        "optionalClaims": {
            "accessToken": merge(existing.get("accessToken")),
            "idToken": merge(existing.get("idToken")),
            "saml2Token": existing.get("saml2Token") or [],
        }
    }
    print(f"[ensure_optional_claim] PATCH optionalClaims → {extension_full_name}")
    async with session.patch(url, headers=headers, json=payload) as resp:
        if resp.status >= 400:
            text = await resp.text()
            raise RuntimeError(f"Optional Claim PATCH failed ({resp.status}): {text}")


# ---------------------------------------------------------------------------
# Client App — features (SPA + Web platforms, idTokenIssuance, perms)
# ---------------------------------------------------------------------------


def _client_app_features_payload(server_app_id: str, backend_uri: str) -> Application:
    """Build the Application patch body for Client App features.

    `backend_uri`: redirect URIs root. If empty, only localhost dev URIs are set
    (auth_update.py overrides at postprovision once Container App FQDN is known).
    """
    spa_uris: list[str] = ["http://localhost:50505/redirect", "http://localhost:5173/redirect"]
    web_uris: list[str] = ["http://localhost:50505/.auth/login/aad/callback"]
    if backend_uri:
        spa_uris.append(f"{backend_uri}/redirect")
        web_uris.append(f"{backend_uri}/.auth/login/aad/callback")

    return Application(
        sign_in_audience="AzureADMyOrg",
        spa=SpaApplication(redirect_uris=spa_uris),
        web=WebApplication(
            redirect_uris=web_uris,
            implicit_grant_settings=ImplicitGrantSettings(enable_id_token_issuance=True),
        ),
        required_resource_access=[
            # Microsoft Graph delegated permissions
            RequiredResourceAccess(
                resource_app_id=GRAPH_APP_ID,
                resource_access=[
                    ResourceAccess(id=uuid.UUID(GRAPH_SCOPES["User.Read"]), type="Scope"),
                    ResourceAccess(id=uuid.UUID(GRAPH_SCOPES["openid"]), type="Scope"),
                    ResourceAccess(id=uuid.UUID(GRAPH_SCOPES["profile"]), type="Scope"),
                    ResourceAccess(id=uuid.UUID(GRAPH_SCOPES["email"]), type="Scope"),
                    ResourceAccess(id=uuid.UUID(GRAPH_SCOPES["offline_access"]), type="Scope"),
                ],
            ),
            # Server App `access_as_user` scope
            RequiredResourceAccess(
                resource_app_id=server_app_id,
                resource_access=[ResourceAccess(id=ACCESS_AS_USER_SCOPE_ID, type="Scope")],
            ),
        ],
    )


async def patch_client_app_features(
    graph_client: GraphServiceClient,
    client_object_id: str,
    server_app_id: str,
    backend_uri: str,
) -> None:
    """Apply SPA + Web platforms + idTokenIssuance + perms — idempotent."""
    print(f"[patch_client_app_features] Applying client app features → {client_object_id}")
    payload = _client_app_features_payload(server_app_id, backend_uri)
    await graph_client.applications.by_application_id(client_object_id).patch(payload)


# ---------------------------------------------------------------------------
# Admin consent — oauth2PermissionGrants
# ---------------------------------------------------------------------------


async def ensure_oauth2_grant(
    graph_client: GraphServiceClient,
    client_principal_id: str,
    resource_principal_id: str,
    scope: str,
    label: str,
) -> None:
    """Idempotent admin-consent grant. Skips if grant for this (clientId,resourceId) exists."""
    filter_query = f"clientId eq '{client_principal_id}' and resourceId eq '{resource_principal_id}'"
    query_params = Oauth2PermissionGrantsRequestBuilder.Oauth2PermissionGrantsRequestBuilderGetQueryParameters(
        filter=filter_query
    )
    request_config = RequestConfiguration[
        Oauth2PermissionGrantsRequestBuilder.Oauth2PermissionGrantsRequestBuilderGetQueryParameters
    ](query_parameters=query_params)

    try:
        existing = await graph_client.oauth2_permission_grants.get(request_configuration=request_config)
    except APIError as err:
        print(f"[ensure_oauth2_grant] LIST failed for {label}: {err}")
        return

    if existing and existing.value:
        current_scopes = set((existing.value[0].scope or "").split())
        wanted_scopes = set(scope.split())
        if wanted_scopes.issubset(current_scopes):
            print(f"[ensure_oauth2_grant] Already granted {label}: {scope}")
            return
        # extend existing grant with missing scopes
        merged = " ".join(sorted(current_scopes | wanted_scopes))
        grant_id = existing.value[0].id
        if grant_id:
            try:
                await graph_client.oauth2_permission_grants.by_o_auth2_permission_grant_id(grant_id).patch(
                    OAuth2PermissionGrant(scope=merged)
                )
                print(f"[ensure_oauth2_grant] Extended {label}: {merged}")
                return
            except APIError as err:
                print(f"[ensure_oauth2_grant] PATCH failed for {label}: {err}")
                return

    try:
        await graph_client.oauth2_permission_grants.post(
            OAuth2PermissionGrant(
                client_id=client_principal_id,
                consent_type="AllPrincipals",
                resource_id=resource_principal_id,
                scope=scope,
            )
        )
        print(f"[ensure_oauth2_grant] Granted {label}: {scope}")
    except APIError as err:
        status = getattr(err, "response_status_code", None)
        if status in {401, 403}:
            print(
                f"[ensure_oauth2_grant] No admin perms to grant {label}. "
                "Have a Global Admin run admin-consent in the portal."
            )
        else:
            raise


# ---------------------------------------------------------------------------
# Set Directory Extension value on the current user (auth_init only writes the
# schema; auth_update sets the value at postprovision once SQL is seeded).
# Kept here as a no-op stub for symmetry — actual write lives in auth_update.py.
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


async def main() -> None:  # pragma: no cover
    load_azd_env()

    if not test_authentication_enabled():
        print("AZURE_USE_AUTHENTICATION is not true — skipping auth_init.")
        return

    auth_tenant = (os.getenv("AZURE_AUTH_TENANT_ID") or os.getenv("AZURE_TENANT_ID") or "").strip()
    if not auth_tenant:
        raise SystemExit("Error: No tenant ID set. Set AZURE_AUTH_TENANT_ID or AZURE_TENANT_ID in your azd env.")

    print(f"[auth_init] Setting up authentication for tenant {auth_tenant}")
    credential = AzureDeveloperCliCredential(tenant_id=auth_tenant)
    graph_client = GraphServiceClient(credentials=credential, scopes=["https://graph.microsoft.com/.default"])

    backend_uri = (os.getenv("BACKEND_URI") or "").strip()

    # ------------------------------------------------------------------
    # 1. Server App — `helpsphere`
    # ------------------------------------------------------------------
    server_object_id, server_app_id = await ensure_application(
        graph_client, SERVER_APP_DISPLAY_NAME, "AZURE_SERVER_APP_ID"
    )
    await ensure_secret(graph_client, server_object_id, "AZURE_SERVER_APP_SECRET", "ServerAppSecret")
    await patch_server_app_features(graph_client, server_object_id, server_app_id)

    # Service Principal for server (required by oauth2PermissionGrants + access_as_user surface)
    server_sp_id = await ensure_service_principal(graph_client, server_app_id)

    # Directory Extension + Optional Claim (REST-level operations)
    token = await _get_graph_token(credential)
    async with aiohttp.ClientSession() as session:
        extension_full_name = await ensure_directory_extension(session, token, server_object_id, server_app_id)
        await ensure_optional_claim(session, token, server_object_id, extension_full_name)

    update_azd_env("AZURE_APP_TENANT_ID_EXTENSION", extension_full_name)

    # ------------------------------------------------------------------
    # 2. Client App — `helpsphere-client`
    # ------------------------------------------------------------------
    client_object_id, client_app_id = await ensure_application(
        graph_client, CLIENT_APP_DISPLAY_NAME, "AZURE_CLIENT_APP_ID"
    )
    await ensure_secret(graph_client, client_object_id, "AZURE_CLIENT_APP_SECRET", "ClientAppSecret")
    await patch_client_app_features(graph_client, client_object_id, server_app_id, backend_uri)
    client_sp_id = await ensure_service_principal(graph_client, client_app_id)

    # ------------------------------------------------------------------
    # 3. Admin consent — Microsoft Graph + Server App scope
    # ------------------------------------------------------------------
    graph_sp_id = await ensure_service_principal(graph_client, GRAPH_APP_ID)

    print("[auth_init] Granting admin consent for Microsoft Graph delegated perms...")
    await ensure_oauth2_grant(
        graph_client,
        client_principal_id=client_sp_id,
        resource_principal_id=graph_sp_id,
        scope="User.Read openid profile email offline_access",
        label="client→Graph",
    )

    print("[auth_init] Granting admin consent for Server App access_as_user...")
    await ensure_oauth2_grant(
        graph_client,
        client_principal_id=client_sp_id,
        resource_principal_id=server_sp_id,
        scope=SCOPE_NAME,
        label="client→Server",
    )

    # ------------------------------------------------------------------
    # 4. Final state to azd env
    # ------------------------------------------------------------------
    update_azd_env("AZURE_USE_AUTHENTICATION", "true")
    print(
        json.dumps(
            {
                "server_app_id": server_app_id,
                "client_app_id": client_app_id,
                "extension": extension_full_name,
                "server_sp_id": server_sp_id,
                "client_sp_id": client_sp_id,
            },
            indent=2,
        )
    )
    print("[auth_init] DONE — two-app pattern (Decisão #19) provisioned.")


if __name__ == "__main__":
    asyncio.run(main())
