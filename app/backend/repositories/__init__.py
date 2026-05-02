"""HelpSphere repositories — async SQL access layer.

Pattern: classes injetadas via current_app.config (espelha BlobManager,
SearchClient etc do template MS). Multi-tenancy enforced em todas as queries
via tenant_id (extraído da JWT claim app_tenant_id pelo blueprint).

Story 06.5a — Sessão 2.3.
"""
from ._pool import create_sql_pool
from .comments import CommentsRepository
from .tenants import TenantsRepository
from .tickets import TicketsRepository

__all__ = [
    "CommentsRepository",
    "TenantsRepository",
    "TicketsRepository",
    "create_sql_pool",
]
