"""HelpSphere tickets REST API — 5 endpoints @authenticated.

Story 06.5a — Sessão 2.3 (production-grade, sem atalhos).

Multi-tenancy:
    Todos os endpoints exigem JWT claim `app_tenant_id` (extraída pelo
    `_resolve_tenant_id`). Se ausente → HTTP 403. Sem fallback silencioso.

    Ratio: a Apex Group tem 5 brand tenants no schema SQL, todos no MESMO
    Entra tenant. A claim `app_tenant_id` é configurada via App Roles ou
    custom extension attribute no Entra App Registration. Backend valida
    JWT (assinatura, audience, exp) via `@authenticated` decorator e usa
    a claim para isolation real (WHERE tenant_id = ?).

Author de comments:
    Sempre extraído de auth_claims (`name` ou `preferred_username`). Body
    do POST /comments contém apenas `content` — author não é controlável
    pelo cliente (audit-friendly, anti-spoofing).

Stub `/suggest`:
    HTTP 501 explícito. Lab Intermediário implementa o RAG com Document
    Intelligence + AI Search + OpenAI.
"""
from __future__ import annotations

import logging
from typing import Any

from pydantic import BaseModel, Field, ValidationError, field_validator, model_validator
from quart import Blueprint, abort, current_app, jsonify, request

from config import (
    CONFIG_COMMENTS_REPO,
    CONFIG_TENANTS_REPO,
    CONFIG_TICKETS_REPO,
)
from decorators import authenticated
from error import error_response
from repositories import CommentsRepository, TenantsRepository, TicketsRepository

logger = logging.getLogger(__name__)

tickets_bp = Blueprint("helpsphere_tickets", __name__)

# Listas espelham CHECK constraints do schema (data/migrations/001_initial_schema.sql)
VALID_STATUS = ("Open", "InProgress", "Resolved", "Escalated")
VALID_PRIORITY = ("Low", "Medium", "High", "Critical")
VALID_CATEGORY = ("Comercial", "TI", "Operacional", "RH", "Financeiro")


# ---------------------------------------------------------------------------
# Pydantic models — body validation
# ---------------------------------------------------------------------------


class TicketPatchBody(BaseModel):
    """PATCH /api/tickets/{id} — pelo menos um de status/priority."""

    status: str | None = None
    priority: str | None = None

    @field_validator("status")
    @classmethod
    def _status_valid(cls, v: str | None) -> str | None:
        if v is not None and v not in VALID_STATUS:
            raise ValueError(f"status deve ser um de {list(VALID_STATUS)}")
        return v

    @field_validator("priority")
    @classmethod
    def _priority_valid(cls, v: str | None) -> str | None:
        if v is not None and v not in VALID_PRIORITY:
            raise ValueError(f"priority deve ser um de {list(VALID_PRIORITY)}")
        return v

    @model_validator(mode="after")
    def _at_least_one(self) -> "TicketPatchBody":
        if self.status is None and self.priority is None:
            raise ValueError("informe status, priority, ou ambos")
        return self


class CommentCreateBody(BaseModel):
    """POST /api/tickets/{id}/comments — author vem do JWT, não do body."""

    content: str = Field(min_length=1, max_length=10000)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _resolve_tenant_id(auth_claims: dict[str, Any]) -> str:
    """Extrai `app_tenant_id` do JWT claim. HTTP 403 se ausente.

    NUNCA fallback silencioso — token sem a claim é configuração quebrada
    do Entra App Registration e deve falhar audível.
    """
    tenant_id = auth_claims.get("app_tenant_id")
    if not tenant_id:
        logger.warning(
            "JWT sem claim app_tenant_id | sub=%s | name=%s",
            auth_claims.get("sub"),
            auth_claims.get("name"),
        )
        abort(403, description="JWT claim 'app_tenant_id' ausente — configurar no Entra App Registration")
    return str(tenant_id)


def _resolve_author(auth_claims: dict[str, Any]) -> str:
    """Identidade do usuário logado para audit trail em comments."""
    return (
        auth_claims.get("name")
        or auth_claims.get("preferred_username")
        or auth_claims.get("email")
        or "unknown-user"
    )


def _parse_int_query(name: str, default: int, *, minimum: int, maximum: int) -> int:
    raw = request.args.get(name, str(default))
    try:
        value = int(raw)
    except ValueError:
        abort(400, description=f"query param '{name}' deve ser inteiro")
    if not minimum <= value <= maximum:
        abort(400, description=f"query param '{name}' deve estar entre {minimum} e {maximum}")
    return value


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@tickets_bp.get("/api/tickets")
@authenticated
async def list_tickets(auth_claims: dict[str, Any]):
    """Lista tickets do tenant logado, com filtros e paginação offset-based."""
    tenant_id = _resolve_tenant_id(auth_claims)

    status = request.args.get("status")
    if status and status not in VALID_STATUS:
        abort(400, description=f"status deve ser um de {list(VALID_STATUS)}")
    category = request.args.get("category")
    if category and category not in VALID_CATEGORY:
        abort(400, description=f"category deve ser um de {list(VALID_CATEGORY)}")

    limit = _parse_int_query("limit", default=20, minimum=1, maximum=100)
    offset = _parse_int_query("offset", default=0, minimum=0, maximum=10_000)

    repo: TicketsRepository = current_app.config[CONFIG_TICKETS_REPO]
    try:
        items = await repo.list(
            tenant_id=tenant_id,
            status=status,
            category=category,
            limit=limit,
            offset=offset,
        )
        total = await repo.count(tenant_id=tenant_id, status=status, category=category)
    except Exception as error:
        return error_response(error, "/api/tickets")

    return jsonify(
        {
            "items": items,
            "pagination": {"limit": limit, "offset": offset, "total": total},
        }
    )


@tickets_bp.get("/api/tickets/<int:ticket_id>")
@authenticated
async def get_ticket(ticket_id: int, auth_claims: dict[str, Any]):
    """Detalhe do ticket + thread completa de comments (1 query LEFT JOIN)."""
    tenant_id = _resolve_tenant_id(auth_claims)

    repo: TicketsRepository = current_app.config[CONFIG_TICKETS_REPO]
    try:
        ticket = await repo.get_with_comments(ticket_id=ticket_id, tenant_id=tenant_id)
    except Exception as error:
        return error_response(error, f"/api/tickets/{ticket_id}")

    if ticket is None:
        return jsonify({"error": "ticket não encontrado ou sem permissão"}), 404
    return jsonify(ticket)


@tickets_bp.post("/api/tickets/<int:ticket_id>/comments")
@authenticated
async def add_comment(ticket_id: int, auth_claims: dict[str, Any]):
    """Adiciona comment ao ticket. Author = identidade do usuário logado."""
    tenant_id = _resolve_tenant_id(auth_claims)
    author = _resolve_author(auth_claims)

    if not request.is_json:
        return jsonify({"error": "request must be json"}), 415

    raw_body = await request.get_json()
    try:
        payload = CommentCreateBody.model_validate(raw_body or {})
    except ValidationError as e:
        return jsonify({"error": "validation_failed", "details": e.errors()}), 400

    comments_repo: CommentsRepository = current_app.config[CONFIG_COMMENTS_REPO]
    try:
        result = await comments_repo.add(
            ticket_id=ticket_id,
            tenant_id=tenant_id,
            author=author,
            content=payload.content,
        )
    except ValueError as e:
        msg = str(e)
        status_code = 404 if "não existe" in msg or "não pertence" in msg else 400
        return jsonify({"error": msg}), status_code
    except Exception as error:
        return error_response(error, f"/api/tickets/{ticket_id}/comments")

    return jsonify(result), 201


@tickets_bp.patch("/api/tickets/<int:ticket_id>")
@authenticated
async def patch_ticket(ticket_id: int, auth_claims: dict[str, Any]):
    """Atualiza status e/ou priority do ticket."""
    tenant_id = _resolve_tenant_id(auth_claims)

    if not request.is_json:
        return jsonify({"error": "request must be json"}), 415

    raw_body = await request.get_json()
    try:
        payload = TicketPatchBody.model_validate(raw_body or {})
    except ValidationError as e:
        return jsonify({"error": "validation_failed", "details": e.errors()}), 400

    repo: TicketsRepository = current_app.config[CONFIG_TICKETS_REPO]
    try:
        result = await repo.patch(
            ticket_id=ticket_id,
            tenant_id=tenant_id,
            status=payload.status,
            priority=payload.priority,
        )
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as error:
        return error_response(error, f"/api/tickets/{ticket_id}")

    if result is None:
        return jsonify({"error": "ticket não encontrado ou sem permissão"}), 404
    return jsonify(result)


@tickets_bp.post("/api/tickets/<int:ticket_id>/suggest")
@authenticated
async def suggest_response(ticket_id: int, auth_claims: dict[str, Any]):
    """Stub explícito — Lab Intermediário implementa o pipeline RAG completo.

    Retorna 501 Not Implemented + payload didático identificando o ponto
    de extensão. Mantém o contrato do endpoint estável para que o frontend
    da Sessão 3 já possa chamar.
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
