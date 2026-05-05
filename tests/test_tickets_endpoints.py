"""Integration tests para endpoints HelpSphere — Story 06.5c.7 (deprecation 410).

Origem em Story 06.5a Sessão 2.3 (testes dos 6 endpoints CRUD + suggest + tenants).
Refactor em Story 06.5c.7: 4 endpoints CRUD viraram 410 Gone (Decisão #16 hybrid).
2 endpoints PRESERVADOS (`/suggest` e `/tenants/me`) continuam testados como antes.

Tests auto-suficientes: criam Quart app mínima com APENAS o tickets_bp registrado,
sem invocar create_app() do template upstream.

Mock strategy:
- AuthenticationHelper mockado para retornar auth_claims controlados (apenas
  endpoints PRESERVADOS — endpoints 410 NÃO usam @authenticated, pular mock)
- TenantsRepository mockado via AsyncMock para `/tenants/me`
- TICKETS_BACKEND_URI mockado via monkeypatch.setenv

Cobertura:
- 410 Gone + Link header em GET /api/tickets, GET /api/tickets/{id},
  POST /api/tickets/{id}/comments, PATCH /api/tickets/{id}
- Body JSON estruturado (error, message, successor_uri, since, epic) em todos 410
- Edge case: TICKETS_BACKEND_URI ausente → Link header omitido + successor_uri null
- 501 explicit no /suggest (stub Lab Inter — preservado)
- 200 + payload em /tenants/me (preservado)
- 403 em /tenants/me sem JWT claim app_tenant_id (anti-spoofing — preservado)
"""

from __future__ import annotations

from typing import Any
from unittest.mock import AsyncMock, MagicMock

import pytest
import pytest_asyncio
from quart import Quart

from blueprints.tickets import tickets_bp
from config import CONFIG_AUTH_CLIENT, CONFIG_TENANTS_REPO

TENANT_ID = "11111111-1111-1111-1111-111111111111"
TICKETS_BASE_URI = "https://capps-tickets-test.azurecontainerapps.io"

CLAIMS_VALID = {
    "sub": "test-user-1",
    "name": "Diego Almeida",
    "preferred_username": "diego@apex.com",
    "app_tenant_id": TENANT_ID,
}
CLAIMS_NO_TENANT = {
    "sub": "test-user-broken",
    "name": "User Without Claim",
}


# ---------------------------------------------------------------------------
# Fixture: cria Quart app com tickets_bp + mocks
# ---------------------------------------------------------------------------


@pytest_asyncio.fixture
async def make_client():
    """Factory que cria client Quart com claims customizáveis por teste."""

    def _factory(claims: dict[str, Any] | None = None):
        app = Quart(__name__)
        app.register_blueprint(tickets_bp)

        mock_auth = MagicMock()
        mock_auth.get_auth_claims_if_enabled = AsyncMock(return_value=claims if claims is not None else CLAIMS_VALID)
        app.config[CONFIG_AUTH_CLIENT] = mock_auth
        app.config[CONFIG_TENANTS_REPO] = AsyncMock()
        return app

    yield _factory


# ===========================================================================
# Story 06.5c.7 — Tests dos 4 endpoints DEPRECATED (410 Gone)
# ===========================================================================


@pytest.mark.parametrize(
    "method,path,expected_link_path",
    [
        ("GET", "/api/tickets", "/api/tickets"),
        ("GET", "/api/tickets/42", "/api/tickets/42"),
        ("POST", "/api/tickets/42/comments", "/api/tickets/42/comments"),
        ("PATCH", "/api/tickets/42", "/api/tickets/42"),
    ],
)
@pytest.mark.asyncio
async def test_deprecated_endpoint_returns_410_with_link_header(
    make_client, monkeypatch, method, path, expected_link_path
):
    """Cada endpoint deprecated retorna 410 + Link header com successor URI exato."""
    monkeypatch.setenv("TICKETS_BACKEND_URI", TICKETS_BASE_URI)

    app = make_client()
    async with app.test_client() as client:
        response = await client.open(method=method, path=path)

    assert response.status_code == 410, f"{method} {path} esperado 410, got {response.status_code}"

    expected_link = f'<{TICKETS_BASE_URI}{expected_link_path}>; rel="successor-version"'
    assert (
        response.headers.get("Link") == expected_link
    ), f"{method} {path} Link header errado: {response.headers.get('Link')}"

    body = await response.get_json()
    assert body["error"] == "endpoint_deprecated"
    assert body["successor_uri"] == f"{TICKETS_BASE_URI}{expected_link_path}"
    assert body["epic"] == "06.5c"
    assert body["since"] == "2026-05-04"
    assert "tickets-service .NET" in body["message"]


@pytest.mark.asyncio
async def test_deprecated_endpoint_without_tickets_backend_uri_omits_link(make_client, monkeypatch):
    """Edge case: env var TICKETS_BACKEND_URI ausente → Link omitido + successor_uri null."""
    monkeypatch.delenv("TICKETS_BACKEND_URI", raising=False)

    app = make_client()
    async with app.test_client() as client:
        response = await client.get("/api/tickets")

    assert response.status_code == 410
    assert "Link" not in response.headers, "Link header NÃO deveria existir sem TICKETS_BACKEND_URI"

    body = await response.get_json()
    assert body["error"] == "endpoint_deprecated"
    assert body["successor_uri"] is None
    assert body["epic"] == "06.5c"


@pytest.mark.asyncio
async def test_deprecated_endpoint_strips_trailing_slash_from_uri(make_client, monkeypatch):
    """TICKETS_BACKEND_URI com trailing slash não duplica path no Link header."""
    monkeypatch.setenv("TICKETS_BACKEND_URI", f"{TICKETS_BASE_URI}/")

    app = make_client()
    async with app.test_client() as client:
        response = await client.get("/api/tickets/99")

    assert response.status_code == 410
    expected_link = f'<{TICKETS_BASE_URI}/api/tickets/99>; rel="successor-version"'
    assert response.headers.get("Link") == expected_link


@pytest.mark.asyncio
async def test_deprecated_endpoints_skip_authentication(make_client, monkeypatch):
    """Endpoints 410 NÃO requerem token. Request sem JWT ainda recebe 410 (não 401)."""
    monkeypatch.setenv("TICKETS_BACKEND_URI", TICKETS_BASE_URI)

    # Pass empty claims simulating no auth — 410 deve retornar mesmo assim
    app = make_client(claims={})
    async with app.test_client() as client:
        response = await client.get("/api/tickets")

    # Esperado 410 (não 401/403) — deprecated não exige auth
    assert response.status_code == 410


# ===========================================================================
# Story 06.5c.7 D3 — Tests dos 2 endpoints PRESERVADOS (sem mudança)
# ===========================================================================


@pytest.mark.asyncio
async def test_suggest_returns_501_with_didactic_payload(make_client):
    """`/suggest` continua retornando 501 + payload didático (Lab Intermediário)."""
    app = make_client()
    async with app.test_client() as client:
        response = await client.post("/api/tickets/42/suggest")

    assert response.status_code == 501
    body = await response.get_json()
    assert body["implementation_status"] == "not_implemented_yet"
    assert body["ticket_id"] == 42
    assert "Lab Intermediário" in body["see_also"]


@pytest.mark.asyncio
async def test_suggest_requires_auth_tenant_claim(make_client):
    """`/suggest` valida JWT claim app_tenant_id mesmo sendo stub."""
    app = make_client(claims=CLAIMS_NO_TENANT)
    async with app.test_client() as client:
        response = await client.post("/api/tickets/42/suggest")

    assert response.status_code == 403


@pytest.mark.asyncio
async def test_tenants_me_returns_tenant_payload(make_client):
    """`/api/tenants/me` retorna payload do TenantsRepository.get_by_id."""
    app = make_client()
    fake_tenant = {
        "tenant_id": TENANT_ID,
        "name": "Apex Default",
        "code": "apex-default",
    }
    app.config[CONFIG_TENANTS_REPO].get_by_id = AsyncMock(return_value=fake_tenant)

    async with app.test_client() as client:
        response = await client.get("/api/tenants/me")

    assert response.status_code == 200
    body = await response.get_json()
    assert body == fake_tenant
    app.config[CONFIG_TENANTS_REPO].get_by_id.assert_awaited_once_with(TENANT_ID)


@pytest.mark.asyncio
async def test_tenants_me_404_when_claim_resolves_to_unknown_tenant(make_client):
    """`/api/tenants/me` retorna 404 se tenant_id da JWT claim não existe no schema."""
    app = make_client()
    app.config[CONFIG_TENANTS_REPO].get_by_id = AsyncMock(return_value=None)

    async with app.test_client() as client:
        response = await client.get("/api/tenants/me")

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_tenants_me_403_without_app_tenant_id_claim(make_client):
    """`/api/tenants/me` retorna 403 se JWT não tem claim app_tenant_id."""
    app = make_client(claims=CLAIMS_NO_TENANT)
    async with app.test_client() as client:
        response = await client.get("/api/tenants/me")

    assert response.status_code == 403
