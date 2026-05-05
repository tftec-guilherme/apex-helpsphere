"""Tenants repository — lookup e validação dos 5 tenants Apex."""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    # Sessao 9.2 (Decisao #17 + TD-4 cleanup): _pool.py retorna
    # MITokenConnectionFactory (substituto de aioodbc.Pool com API drop-in
    # `acquire()`). Mantemos type hint como o factory real para o ty checker
    # validar corretamente. Em runtime, qualquer objeto com `.acquire()` async
    # context manager funciona (duck typing assegurado pelo MITokenConnectionFactory).
    from ._pool import MITokenConnectionFactory

logger = logging.getLogger(__name__)


class TenantsRepository:
    """Repository para tenants Apex (lookup leve, baixa cardinalidade)."""

    def __init__(self, pool: MITokenConnectionFactory):
        self.pool = pool

    async def get_by_id(self, tenant_id: str) -> dict[str, Any] | None:
        """Retorna tenant pelo GUID, ou None se não existir."""
        async with self.pool.acquire() as conn, conn.cursor() as cur:
            await cur.execute(
                "SELECT tenant_id, brand_name, created_at " "FROM dbo.tbl_tenants WHERE tenant_id = ?",
                [tenant_id],
            )
            row = await cur.fetchone()
            if row is None:
                return None
            return _row_to_tenant(row)

    async def list_all(self) -> list[dict[str, Any]]:
        """Lista todos os tenants (uso admin / debug — baixa cardinalidade, sem paginação)."""
        async with self.pool.acquire() as conn, conn.cursor() as cur:
            await cur.execute("SELECT tenant_id, brand_name, created_at " "FROM dbo.tbl_tenants ORDER BY brand_name")
            return [_row_to_tenant(r) for r in await cur.fetchall()]


def _row_to_tenant(row: Any) -> dict[str, Any]:
    return {
        "tenant_id": str(row[0]),
        "brand_name": row[1],
        "created_at": row[2].isoformat() if row[2] else None,
    }
