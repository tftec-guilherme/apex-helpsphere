"""HelpSphere RAG chat proxy blueprint - Lab Intermediario (Story 06.10 Parte 8).

Endpoint: POST /chat/rag

Comportamento gated pela env var RAG_ENABLED:

- RAG_ENABLED=false (default): retorna HTTP 503 com payload didatico apontando
  o aluno para a Parte 8 do Lab Intermediario do guia D06.
- RAG_ENABLED=true:
    1. Valida claim JWT app_tenant_id (multi-tenant safe by default - mesmo
       contrato do /api/tickets/{id}/suggest).
    2. Faz POST para ${RAG_FUNCTION_URL}/api/tickets/eval/suggest com header
       x-functions-key: ${RAG_FUNCTION_KEY} e body {description, attachment_urls}.
    3. Retorna a resposta da Function App como JSON (shape esperado:
       {suggested_response, confidence, citations}).

Body esperado (request):
    {"ticket_id": int, "description": str}

Body retornado (sucesso, 200):
    {"suggested_response": str, "confidence": float,
     "citations": [{"source": str, "page": int}]}

Decisao arquitetural - caminho da rota (Story 06.10 Parte 8):
    O guia do Lab Intermediario (linha 1796) usa literalmente
    curl POST $BACKEND_URI/chat, mas /chat ja e o endpoint do upstream
    azure-search-openai-demo (ChatReadRetrieveReadApproach com schema
    {messages: [...]}). Para evitar conflito de schema e preservar o /chat
    upstream funcional para outros usos, o proxy RAG vive em /chat/rag.
    A Parte 8 do guia deve ser atualizada para refletir esse caminho.

Comparacao com /api/tickets/{id}/suggest:
    - /api/tickets/{id}/suggest opera no contexto de UM ticket existente.
      Continua como stub 501 ate aluna implementar pipeline RAG completo.
    - /chat/rag (este modulo) e um proxy fino para a Function App externa
      de RAG. Aceita ticket_id + description direto do body, util para o
      ChatPanel flutuante.

Story: 06.10 (Disciplina 06 - IA e Automacao no Azure / Lab Intermediario).
"""

from __future__ import annotations

import logging
import os
from typing import Any

import aiohttp
from quart import Blueprint, abort, jsonify, request

from decorators import authenticated
from error import error_response

logger = logging.getLogger(__name__)

rag_chat_bp = Blueprint("helpsphere_rag_chat", __name__)


def _resolve_tenant_id(auth_claims: dict[str, Any]) -> str:
    """Extrai app_tenant_id do JWT claim. HTTP 403 se ausente.

    Mesma logica de blueprints/tickets.py::_resolve_tenant_id. Duplicada aqui
    para manter o blueprint independente.
    """
    tenant_id = auth_claims.get("app_tenant_id") or auth_claims.get("extn.app_tenant_id")
    if not tenant_id:
        for key, value in auth_claims.items():
            if key.endswith("app_tenant_id") and value:
                tenant_id = value
                break
    if not tenant_id:
        logger.warning(
            "JWT sem claim app_tenant_id (nem forma extension_*) | sub=%s | name=%s",
            auth_claims.get("sub"),
            auth_claims.get("name"),
        )
        abort(
            403,
            description="JWT claim app_tenant_id ausente - configurar Directory Extension + Optional Claim no Entra App Registration",
        )
    return str(tenant_id)


def _rag_enabled() -> bool:
    """Le RAG_ENABLED do env. Lookup por request - permite toggle sem restart."""
    return os.environ.get("RAG_ENABLED", "false").lower() == "true"


@rag_chat_bp.post("/chat/rag")
@authenticated
async def chat_rag(auth_claims: dict[str, Any]):
    """Proxy autenticado para a Function App externa de RAG do Lab Intermediario.

    Quando RAG_ENABLED=false retorna 503 + payload didatico. Quando true, valida
    o body, valida o tenant claim, e faz POST para a Function App. Erros HTTP da
    Function App sao propagados como 502 (bad gateway upstream) com payload
    descritivo. Timeout de 30s no upstream call.
    """
    if not _rag_enabled():
        return (
            jsonify(
                {
                    "detail": (
                        "Endpoint /chat/rag desabilitado - defina RAG_ENABLED=true no "
                        "Container App backend e configure RAG_FUNCTION_URL + "
                        "RAG_FUNCTION_KEY apontando para sua Function App de RAG "
                        "(criada na Parte 7 do Lab Intermediario)."
                    ),
                    "implementation_status": "rag_disabled",
                    "see_also": "Lab Intermediario (D06) - Parte 8: Plug no stack apex-helpsphere real",
                }
            ),
            503,
        )

    if not request.is_json:
        return jsonify({"error": "request must be json"}), 415

    body = await request.get_json()
    if not isinstance(body, dict):
        return jsonify({"error": "request body must be a JSON object"}), 400

    ticket_id = body.get("ticket_id")
    description = body.get("description")
    if not isinstance(ticket_id, int) or ticket_id <= 0:
        return jsonify({"error": "ticket_id must be a positive integer"}), 400
    if not isinstance(description, str) or not description.strip():
        return jsonify({"error": "description must be a non-empty string"}), 400

    # Multi-tenant safety - mesmo padrao de /api/tickets/{id}/suggest.
    _ = _resolve_tenant_id(auth_claims)

    rag_url = os.environ.get("RAG_FUNCTION_URL", "").strip().rstrip("/")
    rag_key = os.environ.get("RAG_FUNCTION_KEY", "").strip()
    if not rag_url:
        logger.error("RAG_ENABLED=true mas RAG_FUNCTION_URL ausente - config inconsistente")
        return (
            jsonify(
                {
                    "error": "rag_misconfigured",
                    "detail": "RAG_ENABLED=true exige RAG_FUNCTION_URL definido no Container App backend.",
                }
            ),
            500,
        )

    upstream_endpoint = f"{rag_url}/api/tickets/eval/suggest"
    headers = {"Content-Type": "application/json"}
    if rag_key:
        headers["x-functions-key"] = rag_key

    payload = {
        "ticket_id": ticket_id,
        "description": description,
        "attachment_urls": body.get("attachment_urls", []),
    }

    timeout = aiohttp.ClientTimeout(total=30)
    try:
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.post(upstream_endpoint, json=payload, headers=headers) as response:
                response_text = await response.text()
                if response.status >= 400:
                    logger.warning(
                        "RAG Function App upstream retornou %s para ticket_id=%s: %s",
                        response.status,
                        ticket_id,
                        response_text[:200],
                    )
                    return (
                        jsonify(
                            {
                                "error": "rag_upstream_error",
                                "upstream_status": response.status,
                                "upstream_body": response_text[:1000],
                            }
                        ),
                        502,
                    )
                try:
                    data = await response.json(content_type=None)
                except Exception as parse_err:
                    logger.exception("RAG upstream retornou body nao-JSON: %s", parse_err)
                    return (
                        jsonify(
                            {
                                "error": "rag_upstream_invalid_json",
                                "upstream_body": response_text[:1000],
                            }
                        ),
                        502,
                    )
                return jsonify(data)
    except aiohttp.ClientError as net_err:
        logger.exception("Erro de rede chamando RAG Function App: %s", net_err)
        return error_response(net_err, "/chat/rag")
    except Exception as error:
        return error_response(error, "/chat/rag")
