"""Unit tests para repositories HelpSphere — Story 06.5a Sessão 2.3.

Testes auto-suficientes (sem dependência do conftest.py do template upstream),
usando MockPool/MockConnection/MockCursor para simular aioodbc sem precisar
banco real.

Foco:
- Tenant filter compulsório em todos os métodos
- Bind params (?) presentes em SQL
- Paginação (limit/offset) validados nos extremos
- LEFT JOIN evita N+1 em get_with_comments
- Validação de cross-tenant em comments.add (SELECT 1 antes de INSERT)
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

import pytest

from repositories.comments import CommentsRepository
from repositories.tenants import TenantsRepository
from repositories.tickets import TicketsRepository

TENANT_ID_APEX = "11111111-1111-1111-1111-111111111111"
NOW = datetime(2026, 5, 1, 12, 0, 0, tzinfo=timezone.utc)


# ---------------------------------------------------------------------------
# Mock pool/connection/cursor — simula aioodbc sem banco real
# ---------------------------------------------------------------------------


class MockCursor:
    """Mock de aioodbc.Cursor com setup controlável via attrs."""

    def __init__(self) -> None:
        self.execute_calls: list[tuple[str, list[Any] | None]] = []
        # Próximo retorno (configurável por teste)
        self.next_fetchall: list[Any] = []
        self.next_fetchone: Any | None = None
        self.next_description: list[tuple[str, ...]] = []
        self.next_rowcount: int = 1
        # Sequência de retornos quando execute é chamado múltiplas vezes
        self._fetchall_queue: list[list[Any]] = []
        self._fetchone_queue: list[Any] = []
        self._description_queue: list[list[tuple[str, ...]]] = []

    def queue_fetchall(self, rows: list[Any], description: list[tuple[str, ...]]) -> None:
        self._fetchall_queue.append(rows)
        self._description_queue.append(description)

    def queue_fetchone(self, row: Any) -> None:
        self._fetchone_queue.append(row)

    async def execute(self, sql: str, params: list[Any] | None = None) -> None:
        self.execute_calls.append((sql.strip(), params))

    async def fetchall(self) -> list[Any]:
        if self._fetchall_queue:
            return self._fetchall_queue.pop(0)
        return self.next_fetchall

    async def fetchone(self) -> Any | None:
        if self._fetchone_queue:
            return self._fetchone_queue.pop(0)
        return self.next_fetchone

    @property
    def description(self) -> list[tuple[str, ...]]:
        if self._description_queue:
            return self._description_queue[0]
        return self.next_description

    @property
    def rowcount(self) -> int:
        return self.next_rowcount

    async def __aenter__(self) -> MockCursor:
        # Avança o description quando entra em novo contexto de cursor
        if self._description_queue and len(self._description_queue) > 1:
            self._description_queue.pop(0)
        return self

    async def __aexit__(self, *args: Any) -> None:
        return None


class MockConnection:
    def __init__(self, cursor: MockCursor):
        self._cursor = cursor

    def cursor(self) -> MockCursor:
        return self._cursor

    async def __aenter__(self) -> MockConnection:
        return self

    async def __aexit__(self, *args: Any) -> None:
        return None


class MockPool:
    def __init__(self, cursor: MockCursor | None = None):
        self.cursor = cursor or MockCursor()
        self._conn = MockConnection(self.cursor)

    def acquire(self) -> MockConnection:
        return self._conn

    def close(self) -> None:
        return None

    async def wait_closed(self) -> None:
        return None


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


TICKETS_DESCRIPTION = [
    ("ticket_id",),
    ("tenant_id",),
    ("subject",),
    ("description",),
    ("category",),
    ("language",),
    ("status",),
    ("priority",),
    ("confidence_score",),
    ("attachment_blob_paths",),
    ("created_at",),
    ("updated_at",),
]


def fake_ticket_row(
    *,
    ticket_id: int = 1,
    tenant_id: str = TENANT_ID_APEX,
    subject: str = "Test ticket",
    status: str = "Open",
    priority: str = "Medium",
    category: str = "Comercial",
) -> tuple[Any, ...]:
    return (
        ticket_id,
        tenant_id,
        subject,
        f"Description {ticket_id}",
        category,
        "pt-BR",
        status,
        priority,
        None,  # confidence_score
        None,  # attachment_blob_paths
        NOW,
        NOW,
    )


# ===========================================================================
# TicketsRepository
# ===========================================================================


@pytest.mark.asyncio
async def test_list_passes_tenant_id_as_bind_param() -> None:
    cursor = MockCursor()
    cursor.next_fetchall = [fake_ticket_row()]
    cursor.next_description = TICKETS_DESCRIPTION
    repo = TicketsRepository(MockPool(cursor))

    items = await repo.list(tenant_id=TENANT_ID_APEX)

    assert len(items) == 1
    sql, params = cursor.execute_calls[0]
    assert "WHERE tenant_id = ?" in sql
    assert params is not None and params[0] == TENANT_ID_APEX


@pytest.mark.asyncio
async def test_list_applies_status_and_category_filters() -> None:
    cursor = MockCursor()
    cursor.next_fetchall = []
    cursor.next_description = TICKETS_DESCRIPTION
    repo = TicketsRepository(MockPool(cursor))

    await repo.list(tenant_id=TENANT_ID_APEX, status="Open", category="TI", limit=5, offset=10)

    sql, params = cursor.execute_calls[0]
    assert "status = ?" in sql
    assert "category = ?" in sql
    assert "OFFSET ? ROWS FETCH NEXT ? ROWS ONLY" in sql
    assert params == [TENANT_ID_APEX, "Open", "TI", 10, 5]


@pytest.mark.asyncio
async def test_list_rejects_invalid_limit() -> None:
    repo = TicketsRepository(MockPool())
    with pytest.raises(ValueError, match="limit"):
        await repo.list(tenant_id=TENANT_ID_APEX, limit=0)
    with pytest.raises(ValueError, match="limit"):
        await repo.list(tenant_id=TENANT_ID_APEX, limit=101)


@pytest.mark.asyncio
async def test_list_rejects_negative_offset() -> None:
    repo = TicketsRepository(MockPool())
    with pytest.raises(ValueError, match="offset"):
        await repo.list(tenant_id=TENANT_ID_APEX, offset=-1)


@pytest.mark.asyncio
async def test_list_normalizes_datetime_to_iso() -> None:
    cursor = MockCursor()
    cursor.next_fetchall = [fake_ticket_row()]
    cursor.next_description = TICKETS_DESCRIPTION
    repo = TicketsRepository(MockPool(cursor))

    items = await repo.list(tenant_id=TENANT_ID_APEX)

    assert items[0]["created_at"] == NOW.isoformat()
    assert items[0]["tenant_id"] == TENANT_ID_APEX


@pytest.mark.asyncio
async def test_count_uses_same_filters_as_list() -> None:
    cursor = MockCursor()
    cursor.next_fetchone = (42,)
    repo = TicketsRepository(MockPool(cursor))

    total = await repo.count(tenant_id=TENANT_ID_APEX, status="Open")

    assert total == 42
    sql, params = cursor.execute_calls[0]
    assert "SELECT COUNT(*)" in sql
    assert params == [TENANT_ID_APEX, "Open"]


@pytest.mark.asyncio
async def test_get_with_comments_uses_left_join_single_query() -> None:
    """Critical: 1 query (LEFT JOIN), nao 2 (anti N+1)."""
    cursor = MockCursor()
    # Linha do ticket + 2 comments (mesmo ticket_id)
    rows = [
        (*fake_ticket_row(ticket_id=7), 100, "Diego", "Comment 1", NOW),
        (*fake_ticket_row(ticket_id=7), 101, "Marina", "Comment 2", NOW),
    ]
    cursor.next_fetchall = rows
    cursor.next_description = TICKETS_DESCRIPTION + [
        ("comment_id",),
        ("author",),
        ("content",),
        ("comment_created_at",),
    ]

    repo = TicketsRepository(MockPool(cursor))
    ticket = await repo.get_with_comments(ticket_id=7, tenant_id=TENANT_ID_APEX)

    assert ticket is not None
    assert ticket["ticket_id"] == 7
    assert len(ticket["comments"]) == 2
    assert ticket["comments"][0]["author"] == "Diego"

    # APENAS 1 execute call — confirmação de single-query LEFT JOIN
    assert len(cursor.execute_calls) == 1
    sql, _ = cursor.execute_calls[0]
    assert "LEFT JOIN" in sql


@pytest.mark.asyncio
async def test_get_with_comments_returns_none_when_not_found() -> None:
    cursor = MockCursor()
    cursor.next_fetchall = []
    cursor.next_description = []
    repo = TicketsRepository(MockPool(cursor))

    ticket = await repo.get_with_comments(ticket_id=999, tenant_id=TENANT_ID_APEX)

    assert ticket is None


@pytest.mark.asyncio
async def test_patch_requires_at_least_one_field() -> None:
    repo = TicketsRepository(MockPool())
    with pytest.raises(ValueError, match="status/priority"):
        await repo.patch(ticket_id=1, tenant_id=TENANT_ID_APEX)


@pytest.mark.asyncio
async def test_patch_returns_none_when_rowcount_zero() -> None:
    cursor = MockCursor()
    cursor.next_rowcount = 0
    repo = TicketsRepository(MockPool(cursor))

    result = await repo.patch(ticket_id=999, tenant_id=TENANT_ID_APEX, status="Resolved")

    assert result is None


# ===========================================================================
# CommentsRepository
# ===========================================================================


@pytest.mark.asyncio
async def test_comments_add_validates_cross_tenant_before_insert() -> None:
    """Critical: SELECT 1 antes do INSERT impede comment cross-tenant."""
    cursor = MockCursor()
    # 1ª query (SELECT 1): retorna (1,) -> ticket pertence ao tenant
    cursor.queue_fetchone((1,))
    # 2ª query (INSERT OUTPUT): retorna (comment_id, created_at)
    cursor.queue_fetchone((42, NOW))

    repo = CommentsRepository(MockPool(cursor))
    result = await repo.add(
        ticket_id=1,
        tenant_id=TENANT_ID_APEX,
        author="Diego",
        content="Resolvido conforme política",
    )

    assert result["comment_id"] == 42
    assert len(cursor.execute_calls) == 2
    select_sql, select_params = cursor.execute_calls[0]
    assert "SELECT 1" in select_sql
    assert select_params == [1, TENANT_ID_APEX]
    insert_sql, _ = cursor.execute_calls[1]
    assert "INSERT" in insert_sql
    assert "OUTPUT INSERTED" in insert_sql


@pytest.mark.asyncio
async def test_comments_add_raises_when_ticket_not_in_tenant() -> None:
    cursor = MockCursor()
    cursor.queue_fetchone(None)  # ticket NAO pertence ao tenant
    repo = CommentsRepository(MockPool(cursor))

    with pytest.raises(ValueError, match="não existe ou não pertence"):
        await repo.add(ticket_id=1, tenant_id=TENANT_ID_APEX, author="x", content="y")

    # Apenas 1 execute (SELECT) — INSERT NAO foi chamado
    assert len(cursor.execute_calls) == 1


@pytest.mark.asyncio
async def test_comments_add_rejects_empty_author_or_content() -> None:
    repo = CommentsRepository(MockPool())
    with pytest.raises(ValueError, match="author"):
        await repo.add(ticket_id=1, tenant_id=TENANT_ID_APEX, author="  ", content="ok")
    with pytest.raises(ValueError, match="content"):
        await repo.add(ticket_id=1, tenant_id=TENANT_ID_APEX, author="ok", content="")


# ===========================================================================
# TenantsRepository
# ===========================================================================


@pytest.mark.asyncio
async def test_tenant_get_by_id_returns_dict_or_none() -> None:
    cursor = MockCursor()
    cursor.queue_fetchone((TENANT_ID_APEX, "Apex Mercado", NOW))
    repo = TenantsRepository(MockPool(cursor))

    tenant = await repo.get_by_id(TENANT_ID_APEX)

    assert tenant == {
        "tenant_id": TENANT_ID_APEX,
        "brand_name": "Apex Mercado",
        "created_at": NOW.isoformat(),
    }


@pytest.mark.asyncio
async def test_tenant_list_all_returns_ordered_brands() -> None:
    cursor = MockCursor()
    cursor.next_fetchall = [
        ("aaa-...", "Apex Casa", NOW),
        ("bbb-...", "Apex Mercado", NOW),
    ]
    repo = TenantsRepository(MockPool(cursor))

    tenants = await repo.list_all()

    assert len(tenants) == 2
    sql, _ = cursor.execute_calls[0]
    assert "ORDER BY brand_name" in sql
