"""HelpSphere v2.1.0 — auth_update.py.

Postprovision hook (runs after Bicep deploys Container Apps). Two responsibilities:

1. Update Client App redirect URIs with the actual `BACKEND_URI` provisioned by
   the latest `azd up` (the FQDN is only known after Container Apps deploy).

2. Set the Directory Extension `app_tenant_id` value on the CURRENT signed-in
   user. The extension itself is created in `auth_init.py`; here we PATCH the
   user with an actual tenant GUID so the AAD claim is non-empty after first
   login.

   Tenant strategy:
     - Default tenant GUID = `11111111-1111-1111-1111-111111111111`
       (Apex Mercado, the first tenant seeded by `data/seed/tenants.sql`).
     - To assign yourself to a different tenant, run a one-shot Graph PATCH
       manually, e.g.:
           PATCH https://graph.microsoft.com/v1.0/me
           {"<extension_full_name>": "<tenant-guid>"}

Both operations are idempotent and only run when AZURE_USE_AUTHENTICATION=true.
"""

import asyncio
import os

import aiohttp
from azure.identity.aio import AzureDeveloperCliCredential
from msgraph import GraphServiceClient
from msgraph.generated.models.application import Application
from msgraph.generated.models.public_client_application import PublicClientApplication
from msgraph.generated.models.spa_application import SpaApplication
from msgraph.generated.models.web_application import WebApplication

from auth_common import get_application, test_authentication_enabled
from load_azd_env import load_azd_env

GRAPH_BASE = "https://graph.microsoft.com/v1.0"

# Tenant Apex Mercado (primeiro tenant em data/seed/tenants.sql).
# Aluno pode mudar manualmente via PATCH /me — ver docstring deste módulo.
DEFAULT_TENANT_GUID = "11111111-1111-1111-1111-111111111111"


def _build_redirect_uris(backend_uri: str) -> tuple[list[str], list[str]]:
    spa = ["http://localhost:50505/redirect", "http://localhost:5173/redirect"]
    web = ["http://localhost:50505/.auth/login/aad/callback"]
    if backend_uri:
        spa.append(f"{backend_uri}/redirect")
        web.append(f"{backend_uri}/.auth/login/aad/callback")
    # de-dup preservando ordem
    spa = list(dict.fromkeys(spa))
    web = list(dict.fromkeys(web))
    return spa, web


async def update_client_redirect_uris(graph_client: GraphServiceClient, client_app_id: str, backend_uri: str) -> None:
    client_object_id = await get_application(graph_client, client_app_id)
    if not client_object_id:
        print(f"[auth_update] Client app {client_app_id} not found — skip redirect URI update.")
        return

    spa_uris, web_uris = _build_redirect_uris(backend_uri)
    print(f"[auth_update] Updating redirect URIs for client app {client_app_id} → {backend_uri}")
    payload = Application(
        public_client=PublicClientApplication(redirect_uris=[]),
        spa=SpaApplication(redirect_uris=spa_uris),
        web=WebApplication(redirect_uris=web_uris),
    )
    await graph_client.applications.by_application_id(client_object_id).patch(payload)
    print(f"[auth_update] Redirect URIs updated for client app id {client_app_id}.")


async def set_extension_value_on_current_user(
    credential: AzureDeveloperCliCredential, extension_full_name: str, tenant_guid: str
) -> None:
    """PATCH the signed-in user with `<extension>=tenant_guid`. Idempotent."""
    if not extension_full_name:
        print("[auth_update] AZURE_APP_TENANT_ID_EXTENSION not set — skip user assignment.")
        return

    token_obj = await credential.get_token("https://graph.microsoft.com/.default")
    headers = {"Authorization": f"Bearer {token_obj.token}", "Content-Type": "application/json"}

    async with aiohttp.ClientSession() as session:
        # Read current value first to decide if PATCH is needed.
        async with session.get(
            f"{GRAPH_BASE}/me?$select=id,userPrincipalName,{extension_full_name}", headers=headers
        ) as resp:
            if resp.status == 403:
                print(
                    "[auth_update] /me returned 403. The federated SP cannot read /me — "
                    "the value must be set manually (or run auth_update.py interactively)."
                )
                return
            resp.raise_for_status()
            me = await resp.json()
            current = me.get(extension_full_name)
            if current == tenant_guid:
                print(f"[auth_update] {me.get('userPrincipalName')} already has {extension_full_name}={tenant_guid}")
                return

        print(
            f"[auth_update] Setting {extension_full_name}={tenant_guid} on "
            f"{me.get('userPrincipalName', me.get('id'))}"
        )
        async with session.patch(
            f"{GRAPH_BASE}/me", headers=headers, json={extension_full_name: tenant_guid}
        ) as patch_resp:
            if patch_resp.status >= 400:
                text = await patch_resp.text()
                raise RuntimeError(
                    f"PATCH /me failed ({patch_resp.status}): {text}\n"
                    "If running in CI, this is expected — set the value via portal."
                )
            print("[auth_update] User extension value set.")


async def main() -> None:  # pragma: no cover
    load_azd_env()
    if not test_authentication_enabled():
        print("AZURE_USE_AUTHENTICATION is not true — skip auth_update.")
        return

    auth_tenant = (os.getenv("AZURE_AUTH_TENANT_ID") or os.getenv("AZURE_TENANT_ID") or "").strip()
    if not auth_tenant:
        raise SystemExit("Error: No tenant ID set. Set AZURE_AUTH_TENANT_ID or AZURE_TENANT_ID in your azd env.")

    credential = AzureDeveloperCliCredential(tenant_id=auth_tenant)
    graph_client = GraphServiceClient(credentials=credential, scopes=["https://graph.microsoft.com/.default"])

    # 1) redirect URIs
    backend_uri = (os.getenv("BACKEND_URI") or "").strip()
    client_app_id = os.getenv("AZURE_CLIENT_APP_ID")
    if client_app_id and backend_uri:
        await update_client_redirect_uris(graph_client, client_app_id, backend_uri)
    elif not client_app_id:
        print("[auth_update] AZURE_CLIENT_APP_ID empty — auth_init not yet run? Skip URI update.")
    else:
        print("[auth_update] BACKEND_URI empty — Container App not provisioned. Skip URI update.")

    # 2) Directory Extension value on current user
    extension_full_name = os.getenv("AZURE_APP_TENANT_ID_EXTENSION", "").strip()
    tenant_guid = os.getenv("HELPSPHERE_DEFAULT_TENANT_GUID", DEFAULT_TENANT_GUID).strip()
    try:
        await set_extension_value_on_current_user(credential, extension_full_name, tenant_guid)
    except Exception as err:  # noqa: BLE001 — diagnostic-only; do not abort postprovision
        print(f"[auth_update] WARN — extension assignment failed: {err}")
        print("[auth_update] Continuing — set the extension value manually if needed.")


if __name__ == "__main__":
    asyncio.run(main())
