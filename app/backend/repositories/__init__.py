"""HelpSphere repositories — async SQL access layer.

Pattern: classes injetadas via current_app.config (espelha BlobManager,
SearchClient etc do template MS). Multi-tenancy enforced em todas as queries
via tenant_id (extraído da JWT claim app_tenant_id pelo blueprint).

Story 06.5a — Sessão 2.3 (origem) · Story 06.5c.7 (Sessão 8) · TD-4 cleanup
(Sessão 9.2 cont): TicketsRepository e CommentsRepository removidos —
endpoints /api/tickets/* CRUD migraram para tickets-service .NET (Decisão
#16 hybrid microservices) e retornam 410 Gone no Python.
TenantsRepository PRESERVADO (D4 da 06.5c.7): backend continua precisando de
SELECT em tbl_tenants para chat session validation.
"""

from ._pool import create_sql_pool
from .tenants import TenantsRepository

__all__ = [
    "TenantsRepository",
    "create_sql_pool",
]
