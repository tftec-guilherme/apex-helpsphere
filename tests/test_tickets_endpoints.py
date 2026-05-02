"""Integration tests para endpoints HelpSphere — Story 06.5a Sessão 2.3.

Tests auto-suficientes: criam Quart app mínima com APENAS o tickets_bp
registrado, sem invocar create_app() do template upstream (evita carregar
todo o stack AI Search/OpenAI/Cosmos do MS demo).

Mock strategy:
- AuthenticationHelper mockado para retornar auth_claims controlados
- Repositories mockados via AsyncMock — controlamos os retornos por teste

Cobertura:
- 200 com paginação correta em GET /api/tickets
- 403 quando JWT NAO tem claim `app_tenant_id` (segurança production-grade)
- 404 quando ticket nao existe ou nao pertence ao tenant
- 400 quando body PATCH/POST e invalido (Pydantic validation)
- 501 explicito no /suggest (stub Lab Inter)
- Author do comment vem do JWT (anti-spoofing)
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from unittest.mock import AsyncMock, MagicMock

import pytest
import pytest_asyncio
from quart import Quart

from blueprints.tickets import tickets_bp
from config import (
    CONFIG_AUTH_CLIENT,
    CONFIG_COMMENTS_REPO,
    CONFIG_TENANTS_REPO,
    CONFIG_TICKETS_REPO,
)

TENANT_ID = "11111111-1111-1111-1111-111111111111"
NOW_ISO = datetime(2026, 5, 1, 12, 0, 0, tzinfo=timezone.utc).isoformat()

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
        mock_auth.get_auth_claims_if_enabled = AsyncMock(
            return_value=claims if claims is not None else CLAIMS_VALID
        )
        app.config[CONFIG_AUTH_CLIENT] = mock_auth
        app.config[CONFIG_TICKETS_REPO] = AsyncMock()
        app.config[CONFIG_COMMENTS_REPO] = AsyncMock()
        app.config[CONFIG_TENANTS_REPO] = AsyncMock()
        return app

    yield _factory


def _fake_ticket(ticket_id: int = 1, **overrides: Any) -> dict[str, Any]:
    base = {
        "ticket_id": ticket_id,
        "tenant_id": TENANT_ID,
        "subject": "Pedido 84512 não entregue",
        "description": "Lojista solicita reembolso",
        "category": "Comercial",
        "language": "pt-BR",
        "status": "Open",
        "priority": "High",
        "confidence_score": None,
        "attachment_blob_paths": None,
        "created_at": NOW_ISO,
        "updated_at": NOW_ISO,
    }
    base.update(overrides)
    return base


# ===========================================================================
# GET /api/tickets
# ===========================================================================


@pytest.mark.asyncio
async def test_list_tickets_returns_paginated(make_client) -> None:
    app = make_client()
    app.config[CONFIG_TICKETS_REPO].list.return_value = [_fake_ticket(1), _fake_ticket(2)]
    app.config[CONFIG_TICKETS_REPO].count.return_value = 50

    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.get("/api/tickets?status=Open&limit=20&offset=0")

    assert response.status_code == 200
    data = await response.get_json()
    assert "items" in data
    assert "pagination" in data
    assert data["pagination"]["total"] == 50
    assert data["pagination"]["limit"] == 20
    assert data["pagination"]["offset"] == 0
    # Verificar que list foi chamado com tenant_id da claim
    app.config[CONFIG_TICKETS_REPO].list.assert_awaited_once()
    call_kwargs = app.config[CONFIG_TICKETS_REPO].list.call_args.kwargs
    assert call_kwargs["tenant_id"] == TENANT_ID
    assert call_kwargs["status"] == "Open"


@pytest.mark.asyncio
async def test_list_returns_403_when_no_app_tenant_claim(make_client) -> None:
    """Production-grade: JWT sem app_tenant_id NUNCA pode receber dados."""
    app = make_client(claims=CLAIMS_NO_TENANT)
    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.get("/api/tickets")

    assert response.status_code == 403
    # Repo NAO deve ter sido chamado
    app.config[CONFIG_TICKETS_REPO].list.assert_not_called()


@pytest.mark.asyncio
async def test_list_400_for_invalid_status_filter(make_client) -> None:
    app = make_client()
    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.get("/api/tickets?status=BogusStatus")

    assert response.status_code == 400


@pytest.mark.asyncio
async def test_list_400_for_invalid_limit(make_client) -> None:
    app = make_client()
    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.get("/api/tickets?limit=0")

    assert response.status_code == 400


# ===========================================================================
# GET /api/tickets/{id}
# ===========================================================================


@pytest.mark.asyncio
async def test_get_ticket_returns_detail_with_comments(make_client) -> None:
    app = make_client()
    ticket_with_comments = {
        **_fake_ticket(7),
        "comments": [
            {"comment_id": 100, "author": "Diego", "content": "Aberto", "created_at": NOW_ISO},
        ],
    }
    app.config[CONFIG_TICKETS_REPO].get_with_comments.return_value = ticket_with_comments

    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.get("/api/tickets/7")

    assert response.status_code == 200
    data = await response.get_json()
    assert data["ticket_id"] == 7
    assert len(data["comments"]) == 1


@pytest.mark.asyncio
async def test_get_ticket_returns_404_when_not_found(make_client) -> None:
    app = make_client()
    app.config[CONFIG_TICKETS_REPO].get_with_comments.return_value = None

    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.get("/api/tickets/9999")

    assert response.status_code == 404


# ===========================================================================
# POST /api/tickets/{id}/comments
# ===========================================================================


@pytest.mark.asyncio
async def test_add_comment_uses_jwt_name_as_author(make_client) -> None:
    """Anti-spoofing: author NAO vem do body, vem do JWT."""
    app = make_client()
    app.config[CONFIG_COMMENTS_REPO].add.return_value = {
        "comment_id": 200,
        "ticket_id": 7,
        "author": "Diego Almeida",
        "content": "Resolvido",
        "created_at": NOW_ISO,
    }

    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.post(
            "/api/tickets/7/comments",
            json={"content": "Resolvido conforme politica"},
        )

    assert response.status_code == 201
    call_kwargs = app.config[CONFIG_COMMENTS_REPO].add.call_args.kwargs
    assert call_kwargs["author"] == "Diego Almeida"  # do JWT name, NAO do body
    assert call_kwargs["tenant_id"] == TENANT_ID


@pytest.mark.asyncio
async def test_add_comment_400_when_content_empty(make_client) -> None:
    app = make_client()
    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.post("/api/tickets/7/comments", json={"content": ""})

    assert response.status_code == 400


@pytest.mark.asyncio
async def test_add_comment_404_when_ticket_not_in_tenant(make_client) -> None:
    app = make_client()
    app.config[CONFIG_COMMENTS_REPO].add.side_effect = ValueError(
        "Ticket 99 não existe ou não pertence ao tenant"
    )

    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.post("/api/tickets/99/comments", json={"content": "x"})

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_add_comment_415_when_not_json(make_client) -> None:
    app = make_client()
    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.post(
            "/api/tickets/7/comments", data="raw text", headers={"Content-Type": "text/plain"}
        )

    assert response.status_code == 415


# ===========================================================================
# PATCH /api/tickets/{id}
# ===========================================================================


@pytest.mark.asyncio
async def test_patch_ticket_status(make_client) -> None:
    app = make_client()
    app.config[CONFIG_TICKETS_REPO].patch.return_value = _fake_ticket(7, status="Resolved")

    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.patch("/api/tickets/7", json={"status": "Resolved"})

    assert response.status_code == 200
    data = await response.get_json()
    assert data["status"] == "Resolved"


@pytest.mark.asyncio
async def test_patch_400_when_invalid_status(make_client) -> None:
    app = make_client()
    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.patch("/api/tickets/7", json={"status": "BogusValue"})

    assert response.status_code == 400


@pytest.mark.asyncio
async def test_patch_400_when_no_field_informed(make_client) -> None:
    app = make_client()
    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.patch("/api/tickets/7", json={})

    assert response.status_code == 400


@pytest.mark.asyncio
async def test_patch_404_when_not_found(make_client) -> None:
    app = make_client()
    app.config[CONFIG_TICKETS_REPO].patch.return_value = None

    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.patch("/api/tickets/999", json={"status": "Resolved"})

    assert response.status_code == 404


# ===========================================================================
# POST /api/tickets/{id}/suggest (stub Lab Inter)
# ===========================================================================


@pytest.mark.asyncio
async def test_suggest_endpoint_returns_501_with_didactic_payload(make_client) -> None:
    app = make_client()
    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.post("/api/tickets/7/suggest")

    assert response.status_code == 501
    data = await response.get_json()
    assert data["implementation_status"] == "not_implemented_yet"
    assert "Lab Intermediário" in data["detail"]


@pytest.mark.asyncio
async def test_suggest_403_when_no_tenant_claim(make_client) -> None:
    """Production-grade: ate o stub valida tenant (multi-tenant safe by default)."""
    app = make_client(claims=CLAIMS_NO_TENANT)
    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.post("/api/tickets/7/suggest")

    assert response.status_code == 403


# ===========================================================================
# GET /api/tenants/me
# ===========================================================================


@pytest.mark.asyncio
async def test_get_my_tenant_returns_tenant_info(make_client) -> None:
    app = make_client()
    app.config[CONFIG_TENANTS_REPO].get_by_id.return_value = {
        "tenant_id": TENANT_ID,
        "brand_name": "Apex Mercado",
        "created_at": NOW_ISO,
    }

    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.get("/api/tenants/me")

    assert response.status_code == 200
    data = await response.get_json()
    assert data["brand_name"] == "Apex Mercado"
    app.config[CONFIG_TENANTS_REPO].get_by_id.assert_awaited_once_with(TENANT_ID)


@pytest.mark.asyncio
async def test_get_my_tenant_404_when_claim_orphaned(make_client) -> None:
    """Caso edge: token valido com claim de tenant que nao existe no banco."""
    app = make_client()
    app.config[CONFIG_TENANTS_REPO].get_by_id.return_value = None

    async with app.test_app() as test_app:
        client = test_app.test_client()
        response = await client.get("/api/tenants/me")

    assert response.status_code == 404
