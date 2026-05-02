"""Tickets repository — async SQL access para tbl_tickets.

Multi-tenancy: TODOS os métodos exigem `tenant_id` (extraído da JWT claim
`app_tenant_id` pelo blueprint). WHERE tenant_id = ? é compulsório em queries
de leitura, escrita e contagem.

Padrão production-grade:
- Bind params (?) em TODAS as queries — nunca f-string com input do usuário.
- LEFT JOIN para evitar N+1 em get_with_comments.
- Limites de paginação (limit 1-100) validados no repository.
- COUNT(*) separado para paginação correta no client.
"""
from __future__ import annotations

import logging
from typing import Any

import aioodbc

logger = logging.getLogger(__name__)


class TicketsRepository:
    """Repository para CRUD de tickets respeitando isolation por tenant."""

    def __init__(self, pool: aioodbc.Pool):
        self.pool = pool

    async def list(
        self,
        *,
        tenant_id: str,
        status: str | None = None,
        category: str | None = None,
        limit: int = 20,
        offset: int = 0,
    ) -> list[dict[str, Any]]:
        """Lista tickets do tenant com filtros opcionais e paginação."""
        if not 1 <= limit <= 100:
            raise ValueError("limit deve estar entre 1 e 100")
        if offset < 0:
            raise ValueError("offset não pode ser negativo")

        where = ["tenant_id = ?"]
        params: list[Any] = [tenant_id]
        if status:
            where.append("status = ?")
            params.append(status)
        if category:
            where.append("category = ?")
            params.append(category)

        sql = f"""
            SELECT
                ticket_id, tenant_id, subject, description, category,
                language, status, priority, confidence_score,
                attachment_blob_paths, created_at, updated_at
            FROM dbo.tbl_tickets
            WHERE {' AND '.join(where)}
            ORDER BY created_at DESC
            OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
        """
        params.extend([offset, limit])

        async with self.pool.acquire() as conn, conn.cursor() as cur:
            await cur.execute(sql, params)
            cols = [c[0] for c in cur.description]
            rows = await cur.fetchall()
            return [_row_to_ticket(dict(zip(cols, r))) for r in rows]

    async def count(
        self,
        *,
        tenant_id: str,
        status: str | None = None,
        category: str | None = None,
    ) -> int:
        """Total de tickets do tenant (para paginação correta no client)."""
        where = ["tenant_id = ?"]
        params: list[Any] = [tenant_id]
        if status:
            where.append("status = ?")
            params.append(status)
        if category:
            where.append("category = ?")
            params.append(category)

        sql = f"SELECT COUNT(*) FROM dbo.tbl_tickets WHERE {' AND '.join(where)}"

        async with self.pool.acquire() as conn, conn.cursor() as cur:
            await cur.execute(sql, params)
            row = await cur.fetchone()
            return int(row[0])

    async def get_with_comments(
        self,
        *,
        ticket_id: int,
        tenant_id: str,
    ) -> dict[str, Any] | None:
        """Retorna ticket + comments thread em UMA query (LEFT JOIN, evita N+1).

        Returns None se ticket não existir ou não pertencer ao tenant.
        """
        sql = """
            SELECT
                t.ticket_id, t.tenant_id, t.subject, t.description, t.category,
                t.language, t.status, t.priority, t.confidence_score,
                t.attachment_blob_paths, t.created_at, t.updated_at,
                c.comment_id, c.author, c.content, c.created_at AS comment_created_at
            FROM dbo.tbl_tickets t
            LEFT JOIN dbo.tbl_comments c ON c.ticket_id = t.ticket_id
            WHERE t.ticket_id = ? AND t.tenant_id = ?
            ORDER BY c.created_at ASC
        """
        async with self.pool.acquire() as conn, conn.cursor() as cur:
            await cur.execute(sql, [ticket_id, tenant_id])
            rows = await cur.fetchall()
            if not rows:
                return None

            first = rows[0]
            ticket = _row_to_ticket(
                {
                    "ticket_id": first[0],
                    "tenant_id": first[1],
                    "subject": first[2],
                    "description": first[3],
                    "category": first[4],
                    "language": first[5],
                    "status": first[6],
                    "priority": first[7],
                    "confidence_score": first[8],
                    "attachment_blob_paths": first[9],
                    "created_at": first[10],
                    "updated_at": first[11],
                }
            )
            ticket["comments"] = [
                {
                    "comment_id": int(r[12]),
                    "author": r[13],
                    "content": r[14],
                    "created_at": r[15].isoformat() if r[15] else None,
                }
                for r in rows
                if r[12] is not None
            ]
            return ticket

    async def patch(
        self,
        *,
        ticket_id: int,
        tenant_id: str,
        status: str | None = None,
        priority: str | None = None,
    ) -> dict[str, Any] | None:
        """Atualiza status e/ou priority parcialmente.

        Returns dict do ticket atualizado, ou None se não encontrado/sem permissão.
        Validação dos valores está nos CHECK constraints do schema (raise driver
        error se inválido).
        """
        if status is None and priority is None:
            raise ValueError("Pelo menos um de status/priority deve ser informado")

        updates: list[str] = []
        params: list[Any] = []
        if status is not None:
            updates.append("status = ?")
            params.append(status)
        if priority is not None:
            updates.append("priority = ?")
            params.append(priority)

        params.extend([ticket_id, tenant_id])
        sql = (
            f"UPDATE dbo.tbl_tickets SET {', '.join(updates)} "
            "WHERE ticket_id = ? AND tenant_id = ?"
        )

        async with self.pool.acquire() as conn, conn.cursor() as cur:
            await cur.execute(sql, params)
            if cur.rowcount == 0:
                return None

            await cur.execute(
                "SELECT ticket_id, tenant_id, subject, description, category, "
                "language, status, priority, confidence_score, "
                "attachment_blob_paths, created_at, updated_at "
                "FROM dbo.tbl_tickets WHERE ticket_id = ? AND tenant_id = ?",
                [ticket_id, tenant_id],
            )
            cols = [c[0] for c in cur.description]
            row = await cur.fetchone()
            return _row_to_ticket(dict(zip(cols, row))) if row else None


def _row_to_ticket(raw: dict[str, Any]) -> dict[str, Any]:
    """Normaliza tipos SQL → JSON-serializable (datetime → ISO 8601, GUID → str)."""
    return {
        **raw,
        "tenant_id": str(raw["tenant_id"]) if raw.get("tenant_id") is not None else None,
        "confidence_score": float(raw["confidence_score"])
        if raw.get("confidence_score") is not None
        else None,
        "created_at": raw["created_at"].isoformat() if raw.get("created_at") else None,
        "updated_at": raw["updated_at"].isoformat() if raw.get("updated_at") else None,
    }
