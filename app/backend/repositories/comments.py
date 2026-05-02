"""Comments repository — async SQL access para tbl_comments.

Comments pertencem a tickets via FK ON DELETE CASCADE. Validação de tenant
acontece via JOIN explícito antes de inserir (impede comment cross-tenant).
"""
from __future__ import annotations

import logging
from typing import Any

import aioodbc

logger = logging.getLogger(__name__)


class CommentsRepository:
    """Repository para comments de tickets (multi-tenant safe via JOIN check)."""

    def __init__(self, pool: aioodbc.Pool):
        self.pool = pool

    async def add(
        self,
        *,
        ticket_id: int,
        tenant_id: str,
        author: str,
        content: str,
    ) -> dict[str, Any]:
        """Insere comment garantindo que ticket pertence ao tenant.

        Raises:
            ValueError: se ticket não existir ou não pertencer ao tenant,
                        ou se author/content forem vazios.
        """
        if not author or not author.strip():
            raise ValueError("author não pode ser vazio")
        if not content or not content.strip():
            raise ValueError("content não pode ser vazio")

        author = author.strip()
        content = content.strip()

        async with self.pool.acquire() as conn, conn.cursor() as cur:
            await cur.execute(
                "SELECT 1 FROM dbo.tbl_tickets WHERE ticket_id = ? AND tenant_id = ?",
                [ticket_id, tenant_id],
            )
            if await cur.fetchone() is None:
                raise ValueError(
                    f"Ticket {ticket_id} não existe ou não pertence ao tenant"
                )

            await cur.execute(
                "INSERT INTO dbo.tbl_comments (ticket_id, author, content) "
                "OUTPUT INSERTED.comment_id, INSERTED.created_at "
                "VALUES (?, ?, ?)",
                [ticket_id, author, content],
            )
            row = await cur.fetchone()
            return {
                "comment_id": int(row[0]),
                "ticket_id": ticket_id,
                "author": author,
                "content": content,
                "created_at": row[1].isoformat() if row[1] else None,
            }
