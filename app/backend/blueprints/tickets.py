"""HelpSphere tickets blueprint — endpoints CRUD DEPRECATED + auxiliary preserved.

Story 06.5a — Sessão 2.3 (origem — 5 endpoints CRUD + 1 RAG stub + 1 auxiliary).
Story 06.5c.7 — Sessão 8+ (Decisão #16 hybrid microservices — 4 CRUD viram 410 Gone).

Estado atual após 06.5c.7:
- 4 endpoints CRUD (`GET /api/tickets`, `GET /api/tickets/{id}`,
  `POST /api/tickets/{id}/comments`, `PATCH /api/tickets/{id}`) retornam
  HTTP 410 Gone (RFC 9110 §15.5.11) com header `Link: <successor-uri>;
  rel="successor-version"` (RFC 5988/8288). Migrados para tickets-service .NET.
- `POST /api/tickets/{id}/suggest` PRESERVADO (501 stub — Lab Intermediário
  implementa o RAG via Document Intelligence + AI Search + OpenAI).
- `GET /api/tenants/me` PRESERVADO (auxiliary — backend continua precisando
  para chat session validation via `_resolve_tenant_id`).

Successor URI:
    Lido de `os.environ["TICKETS_BACKEND_URI"]` (Bicep output do tickets-service .NET).
    Fallback graceful: se env var ausente, Link header omitido + `successor_uri: null`
    no body JSON. Backend log warning, não crash.

Multi-tenancy preservada nos endpoints PRESERVADOS:
    `_resolve_tenant_id` valida JWT claim `app_tenant_id` (HTTP 403 se ausente).
"""

from __future__ import annotations

import logging
import os
from typing import Any

from quart import Blueprint, abort, current_app, jsonify

from config import CONFIG_TENANTS_REPO
from decorators import authenticated
from error import error_response
from repositories import TenantsRepository

logger = logging.getLogger(__name__)

tickets_bp = Blueprint("helpsphere_tickets", __name__)


# ---------------------------------------------------------------------------
# Helpers — preservados (usados em /suggest e /tenants/me)
# ---------------------------------------------------------------------------


def _resolve_tenant_id(auth_claims: dict[str, Any]) -> str:
    """Extrai `app_tenant_id` do JWT claim. HTTP 403 se ausente.

    Decisão Q1B + free-tier AAD fallback:
    - Forma curta "app_tenant_id" requer Claims Mapping Policy (AAD P1+).
    - Forma longa "extension_<serverAppIdNoHyphens>_app_tenant_id" é emitida
      via Directory Extension + Optional Claim (free tier). Aceitar ambas
      mantém template usável sem licença premium.

    NUNCA fallback silencioso — token sem nenhuma das formas é configuração
    quebrada do Entra App Registration e deve falhar audível.
    """
    tenant_id = auth_claims.get("app_tenant_id") or auth_claims.get("extn.app_tenant_id")
    if not tenant_id:
        # Directory Extension fallback — em access tokens v2, AAD emite como
        # "extn.app_tenant_id" (curto); em id tokens, como "extension_<appId>_app_tenant_id" (longo).
        for k, v in auth_claims.items():
            if k.endswith("app_tenant_id") and v:
                tenant_id = v
                break
    if not tenant_id:
        logger.warning(
            "JWT sem claim app_tenant_id (nem forma extension_*) | sub=%s | name=%s",
            auth_claims.get("sub"),
            auth_claims.get("name"),
        )
        abort(
            403,
            description="JWT claim 'app_tenant_id' ausente — configurar Directory Extension + Optional Claim no Entra App Registration",
        )
    return str(tenant_id)


# ---------------------------------------------------------------------------
# Helper de deprecation 410 — Story 06.5c.7
# ---------------------------------------------------------------------------


def _deprecated_410(path_suffix: str = ""):
    """Story 06.5c.7: endpoint migrado para tickets-service .NET (Decisão #16).

    Retorna tuple (response, status_code, headers) seguindo Quart convention.

    Args:
        path_suffix: path component para construir successor URI completo.
            Ex: "/api/tickets/42/comments" → Link aponta para
            tickets-service equivalente.

    Returns:
        (jsonify(body), 410, headers).
        Link header omitido se TICKETS_BACKEND_URI não estiver setado
        (graceful fallback — backend log warning mas não crash).
    """
    successor_base = os.environ.get("TICKETS_BACKEND_URI", "").rstrip("/")
    full_uri = f"{successor_base}{path_suffix}" if successor_base else None

    body = {
        "error": "endpoint_deprecated",
        "message": (
            "Este endpoint migrou para o tickets-service .NET " "(Story 06.5c — Decisão #16 hybrid microservices)"
        ),
        "successor_uri": full_uri,
        "since": "2026-05-04",
        "epic": "06.5c",
    }

    headers: dict[str, str] = {}
    if full_uri:
        headers["Link"] = f'<{full_uri}>; rel="successor-version"'
    else:
        logger.warning("TICKETS_BACKEND_URI não setado — Link header omitido em 410 response")

    return jsonify(body), 410, headers


# ---------------------------------------------------------------------------
# 4 Endpoints DEPRECATED (Story 06.5c.7) — retornam 410 Gone
# ---------------------------------------------------------------------------
# NOTA D1 da story: @authenticated REMOVIDO destes endpoints. Deprecation
# response não exige token — request rejeitada antes de validation. Cliente
# usando Link header já sabe para onde migrar (tickets-service .NET).


@tickets_bp.get("/api/tickets")
async def list_tickets():
    """410 Gone — migrou para tickets-service .NET. Story 06.5c.7."""
    return _deprecated_410("/api/tickets")


@tickets_bp.get("/api/tickets/<int:ticket_id>")
async def get_ticket(ticket_id: int):
    """410 Gone — migrou para tickets-service .NET. Story 06.5c.7."""
    return _deprecated_410(f"/api/tickets/{ticket_id}")


@tickets_bp.post("/api/tickets/<int:ticket_id>/comments")
async def add_comment(ticket_id: int):
    """410 Gone — migrou para tickets-service .NET. Story 06.5c.7."""
    return _deprecated_410(f"/api/tickets/{ticket_id}/comments")


@tickets_bp.patch("/api/tickets/<int:ticket_id>")
async def patch_ticket(ticket_id: int):
    """410 Gone — migrou para tickets-service .NET. Story 06.5c.7."""
    return _deprecated_410(f"/api/tickets/{ticket_id}")


# ---------------------------------------------------------------------------
# 2 Endpoints PRESERVADOS (Story 06.5c.7 D3) — funcionam normalmente
# ---------------------------------------------------------------------------


@tickets_bp.post("/api/tickets/<int:ticket_id>/suggest")
@authenticated
async def suggest_response(auth_claims: dict[str, Any], ticket_id: int):
    """Stub explícito — Lab Intermediário implementa o pipeline RAG completo.

    Retorna 501 Not Implemented + payload didático identificando o ponto
    de extensão. Mantém o contrato do endpoint estável para que o frontend
    da Sessão 3 já possa chamar.

    PRESERVADO em 06.5c.7 (D3): RAG é Python territory, NÃO migra para .NET.

    Sessao 9.2 cont (TD-7 fix): auth_claims DEVE vir antes de ticket_id na
    assinatura. Decorator @authenticated faz `route_fn(auth_claims, *args,
    **kwargs)` — auth_claims sempre 1o positional. Quart passa ticket_id via
    `**view_args` (kwargs). Inverter ordem causa "TypeError: got multiple
    values for argument 'ticket_id'" → HTTP 500 em vez do 501 esperado.
    """
    _ = _resolve_tenant_id(auth_claims)  # valida tenant mesmo no stub (multi-tenant safe by default)
    return (
        jsonify(
            {
                "detail": (
                    "Endpoint stub — Lab Intermediário (D06) implementa o RAG via "
                    "Document Intelligence + Azure AI Search + Azure OpenAI sobre os "
                    "62 PDFs da base de conhecimento corporativa."
                ),
                "ticket_id": ticket_id,
                "implementation_status": "not_implemented_yet",
                "see_also": "Lab Intermediário — Sessão pedagógica do Bloco 3",
            }
        ),
        501,
    )


# Tenants endpoint auxiliar — útil para frontend popular dropdowns / debug
# PRESERVADO em 06.5c.7 (D3): tenants é compartilhado entre backend Python
# (chat session validation) e tickets-service .NET (tenant lookup).
@tickets_bp.get("/api/tenants/me")
@authenticated
async def get_my_tenant(auth_claims: dict[str, Any]):
    """Retorna info do tenant do usuário logado (resolved via JWT claim)."""
    tenant_id = _resolve_tenant_id(auth_claims)
    repo: TenantsRepository = current_app.config[CONFIG_TENANTS_REPO]
    try:
        tenant = await repo.get_by_id(tenant_id)
    except Exception as error:
        return error_response(error, "/api/tenants/me")

    if tenant is None:
        return jsonify({"error": "tenant_id da JWT claim não existe no schema"}), 404
    return jsonify(tenant)
