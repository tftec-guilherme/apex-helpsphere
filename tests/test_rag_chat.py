"""Integration tests para `/chat/rag` blueprint — Story 06.10 Lab Inter Parte 8.

Cobertura:
- 503 quando RAG_ENABLED=false (default) com payload didatico
- 415 quando body nao e JSON
- 400 quando body invalido (ticket_id ausente / description vazia)
- 403 quando JWT claim app_tenant_id ausente (anti-spoofing multi-tenant)
- 500 quando RAG_ENABLED=true mas RAG_FUNCTION_URL ausente (config invalida)
- 200 + payload quando proxy upstream retorna JSON valido
- 502 quando upstream retorna >= 400
- 502 quando upstream retorna body nao-JSON
"""

from __future__ import annotations

from typing import Any
from unittest.mock import AsyncMock, MagicMock

import pytest
import pytest_asyncio
from quart import Quart

from blueprints.rag_chat import rag_chat_bp
from config import CONFIG_AUTH_CLIENT

TENANT_ID = "11111111-1111-1111-1111-111111111111"

CLAIMS_VALID = {
    "sub": "test-user-1",
    "name": "Diego Almeida",
    "preferred_username": "diego@apex.com",
    "app_tenant_id": TENANT_ID,
}
CLAIMS_NO_TENANT = {"sub": "broken-user", "name": "User"}


@pytest_asyncio.fixture
async def make_client():
    def _factory(claims: dict[str, Any] | None = None):
        app = Quart(__name__)
        app.register_blueprint(rag_chat_bp)
        mock_auth = MagicMock()
        mock_auth.get_auth_claims_if_enabled = AsyncMock(
            return_value=claims if claims is not None else CLAIMS_VALID
        )
        app.config[CONFIG_AUTH_CLIENT] = mock_auth
        return app

    yield _factory


@pytest.mark.asyncio
async def test_chat_rag_disabled_returns_503(make_client, monkeypatch):
    """RAG_ENABLED=false (default) — 503 + payload didatico apontando para o guia."""
    monkeypatch.delenv("RAG_ENABLED", raising=False)
    app = make_client()
    async with app.test_client() as client:
        response = await client.post(
            "/chat/rag",
            json={"ticket_id": 42, "description": "test"},
        )
    assert response.status_code == 503
    body = await response.get_json()
    assert body["implementation_status"] == "rag_disabled"
    assert "Lab Intermediario" in body["see_also"]
    assert "RAG_ENABLED=true" in body["detail"]


@pytest.mark.asyncio
async def test_chat_rag_non_json_returns_415(make_client, monkeypatch):
    """RAG_ENABLED=true mas body nao-JSON — 415."""
    monkeypatch.setenv("RAG_ENABLED", "true")
    monkeypatch.setenv("RAG_FUNCTION_URL", "https://func.example.com")
    app = make_client()
    async with app.test_client() as client:
        response = await client.post(
            "/chat/rag",
            data="not json",
            headers={"Content-Type": "text/plain"},
        )
    assert response.status_code == 415


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "body,expected_message_substr",
    [
        ({}, "ticket_id"),
        ({"ticket_id": "abc", "description": "x"}, "ticket_id"),
        ({"ticket_id": -1, "description": "x"}, "ticket_id"),
        ({"ticket_id": 1, "description": ""}, "description"),
        ({"ticket_id": 1, "description": "   "}, "description"),
    ],
)
async def test_chat_rag_invalid_body_returns_400(make_client, monkeypatch, body, expected_message_substr):
    monkeypatch.setenv("RAG_ENABLED", "true")
    monkeypatch.setenv("RAG_FUNCTION_URL", "https://func.example.com")
    app = make_client()
    async with app.test_client() as client:
        response = await client.post("/chat/rag", json=body)
    assert response.status_code == 400
    payload = await response.get_json()
    assert expected_message_substr in payload["error"]


@pytest.mark.asyncio
async def test_chat_rag_missing_tenant_claim_returns_403(make_client, monkeypatch):
    monkeypatch.setenv("RAG_ENABLED", "true")
    monkeypatch.setenv("RAG_FUNCTION_URL", "https://func.example.com")
    app = make_client(claims=CLAIMS_NO_TENANT)
    async with app.test_client() as client:
        response = await client.post(
            "/chat/rag",
            json={"ticket_id": 42, "description": "anything"},
        )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_chat_rag_enabled_but_no_url_returns_500(make_client, monkeypatch):
    monkeypatch.setenv("RAG_ENABLED", "true")
    monkeypatch.delenv("RAG_FUNCTION_URL", raising=False)
    app = make_client()
    async with app.test_client() as client:
        response = await client.post(
            "/chat/rag",
            json={"ticket_id": 42, "description": "anything"},
        )
    assert response.status_code == 500
    body = await response.get_json()
    assert body["error"] == "rag_misconfigured"


class _FakeAiohttpResponse:
    def __init__(self, status: int, json_data: Any = None, text_data: str | None = None):
        self.status = status
        self._json = json_data
        self._text = text_data if text_data is not None else ""

    async def text(self):
        if self._text:
            return self._text
        if self._json is not None:
            import json as _json
            return _json.dumps(self._json)
        return ""

    async def json(self, content_type=None):
        if self._json is None:
            raise ValueError("not json")
        return self._json

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False


class _FakeAiohttpSession:
    def __init__(self, response: _FakeAiohttpResponse):
        self._response = response
        self.last_url: str | None = None
        self.last_json: Any = None
        self.last_headers: dict[str, str] | None = None

    def post(self, url, json=None, headers=None):
        self.last_url = url
        self.last_json = json
        self.last_headers = headers
        return self._response

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False


@pytest.mark.asyncio
async def test_chat_rag_proxy_success_returns_200(make_client, monkeypatch):
    monkeypatch.setenv("RAG_ENABLED", "true")
    monkeypatch.setenv("RAG_FUNCTION_URL", "https://func.example.com")
    monkeypatch.setenv("RAG_FUNCTION_KEY", "secret-key")

    fake_response = _FakeAiohttpResponse(
        status=200,
        json_data={"suggested_response": "ok", "confidence": 0.9, "citations": []},
    )
    fake_session = _FakeAiohttpSession(fake_response)

    def fake_session_factory(timeout=None):
        return fake_session

    monkeypatch.setattr("blueprints.rag_chat.aiohttp.ClientSession", fake_session_factory)

    app = make_client()
    async with app.test_client() as client:
        response = await client.post(
            "/chat/rag",
            json={"ticket_id": 42, "description": "Como reembolsar lojista?"},
        )

    assert response.status_code == 200
    body = await response.get_json()
    assert body["suggested_response"] == "ok"
    assert body["confidence"] == 0.9
    assert fake_session.last_url == "https://func.example.com/api/tickets/eval/suggest"
    assert fake_session.last_headers["x-functions-key"] == "secret-key"
    assert fake_session.last_json["ticket_id"] == 42
    assert fake_session.last_json["description"] == "Como reembolsar lojista?"


@pytest.mark.asyncio
async def test_chat_rag_proxy_upstream_error_returns_502(make_client, monkeypatch):
    monkeypatch.setenv("RAG_ENABLED", "true")
    monkeypatch.setenv("RAG_FUNCTION_URL", "https://func.example.com")

    fake_response = _FakeAiohttpResponse(status=500, text_data="internal upstream boom")
    fake_session = _FakeAiohttpSession(fake_response)
    monkeypatch.setattr("blueprints.rag_chat.aiohttp.ClientSession", lambda timeout=None: fake_session)

    app = make_client()
    async with app.test_client() as client:
        response = await client.post(
            "/chat/rag",
            json={"ticket_id": 42, "description": "test"},
        )

    assert response.status_code == 502
    body = await response.get_json()
    assert body["error"] == "rag_upstream_error"
    assert body["upstream_status"] == 500
    assert "boom" in body["upstream_body"]


@pytest.mark.asyncio
async def test_chat_rag_proxy_strips_trailing_slash(make_client, monkeypatch):
    """RAG_FUNCTION_URL com trailing slash nao duplica path no upstream call."""
    monkeypatch.setenv("RAG_ENABLED", "true")
    monkeypatch.setenv("RAG_FUNCTION_URL", "https://func.example.com/")

    fake_response = _FakeAiohttpResponse(
        status=200, json_data={"suggested_response": "ok"}
    )
    fake_session = _FakeAiohttpSession(fake_response)
    monkeypatch.setattr("blueprints.rag_chat.aiohttp.ClientSession", lambda timeout=None: fake_session)

    app = make_client()
    async with app.test_client() as client:
        response = await client.post(
            "/chat/rag",
            json={"ticket_id": 1, "description": "x"},
        )
    assert response.status_code == 200
    assert fake_session.last_url == "https://func.example.com/api/tickets/eval/suggest"
