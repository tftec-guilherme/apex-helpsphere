"""Connection factory para Azure SQL com Managed Identity AAD.

WORKAROUND CRÍTICO (Story 06.5c.10 — Decisão #18):
ODBC Driver 18 + `Authentication=ActiveDirectoryMsi` + User-Assigned MI em
Linux Container Apps falha intermitentemente com `HYT00 Login timeout
expired`. O driver não obtém token corretamente do IMDS quando há User-
Assigned MI atribuída ao container.

Solução MS-recomendada: obter token AAD via `azure.identity` e injetar via
`SQL_COPT_SS_ACCESS_TOKEN` em `attrs_before`. Token cacheado por ~50min
(refresh antes do TTL de 60min do AAD).

Conexão fresh a cada acquire — workload leve do HelpSphere (lookup esporádico
em tbl_tenants para chat session validation) não justifica pool warmup.

Em dev local: `DefaultAzureCredential` (azd auth login / az login / VS Code).
Em produção: `ManagedIdentityCredential(client_id=AZURE_CLIENT_ID)`.
"""

from __future__ import annotations

import asyncio
import logging
import struct
import threading
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from typing import Any

import aioodbc

logger = logging.getLogger(__name__)

# ODBC Driver 18 magic constant para injetar token AAD pré-obtido.
# Ref: https://learn.microsoft.com/sql/connect/odbc/using-azure-active-directory#authenticating-with-an-access-token
SQL_COPT_SS_ACCESS_TOKEN = 1256
DB_TOKEN_SCOPE = "https://database.windows.net/.default"
TOKEN_CACHE_TTL_MIN = 50  # Refresh 10min antes do TTL real de 60min


class MITokenConnectionFactory:
    """Connection factory compatível com API aioodbc.Pool.

    Substitui `aioodbc.Pool` para casos onde precisamos injetar token AAD
    explícito (workaround User-Assigned MI no Linux). Expõe `acquire()` async
    context manager idêntico ao Pool, então repositories que usam
    `async with pool.acquire() as conn` continuam funcionando sem mudanças.
    """

    def __init__(self, *, dsn: str, credential: Any, scope: str = DB_TOKEN_SCOPE):
        self._dsn = dsn
        self._credential = credential
        self._scope = scope
        self._token_lock = threading.Lock()
        self._cached_struct_token: bytes | None = None
        self._cached_until: datetime | None = None

    def _get_token_struct(self) -> bytes:
        """Returns struct-packed token, refreshing if cache expired (sync).

        Run via `asyncio.to_thread` para não bloquear event loop.
        """
        with self._token_lock:
            now = datetime.now(timezone.utc)
            if self._cached_struct_token and self._cached_until and now < self._cached_until:
                return self._cached_struct_token

            token = self._credential.get_token(self._scope)
            token_bytes = token.token.encode("utf-16-le")
            self._cached_struct_token = struct.pack(f"=i{len(token_bytes)}s", len(token_bytes), token_bytes)
            self._cached_until = now + timedelta(minutes=TOKEN_CACHE_TTL_MIN)
            logger.info(
                "AAD token refreshed | scope=%s | cached_until=%s",
                self._scope,
                self._cached_until.isoformat(),
            )
            return self._cached_struct_token

    @asynccontextmanager
    async def acquire(self):
        """Abre conexão fresh com token AAD injetado via attrs_before.

        Conexão é fechada automaticamente no exit do context.
        """
        struct_token = await asyncio.to_thread(self._get_token_struct)
        attrs_before = {SQL_COPT_SS_ACCESS_TOKEN: struct_token}
        conn = await aioodbc.connect(
            dsn=self._dsn,
            autocommit=True,
            attrs_before=attrs_before,
        )
        try:
            yield conn
        finally:
            await conn.close()

    def close(self) -> None:
        """No-op — conexões são fechadas no acquire context exit."""
        pass

    async def wait_closed(self) -> None:
        """No-op — conexões são fechadas no acquire context exit."""
        pass


async def create_sql_pool(
    *,
    server: str,
    database: str,
    use_managed_identity: bool = False,
    azure_client_id: str | None = None,
    minsize: int = 2,  # noqa: ARG001 — mantido por compat de assinatura
    maxsize: int = 10,  # noqa: ARG001 — mantido por compat de assinatura
    pool_recycle: int = 3000,  # noqa: ARG001 — mantido por compat de assinatura
) -> MITokenConnectionFactory:
    """Cria connection factory com AAD authentication via token explícito.

    Args:
        server: FQDN do Azure SQL Server (ex: 'sql-x.database.windows.net')
        database: nome do database (ex: 'helpsphere')
        use_managed_identity: True para Container Apps (ManagedIdentityCredential),
                              False para dev local (DefaultAzureCredential)
        azure_client_id: User-Assigned MI client ID quando use_managed_identity=True
        minsize/maxsize/pool_recycle: aceitos por compat — não usados no factory

    Returns:
        MITokenConnectionFactory com API `async with factory.acquire() as conn`.
        Drop-in compatível com aioodbc.Pool nos métodos usados pelo HelpSphere.

    Notes:
        Driver MS ODBC 18 obrigatório no host (Dockerfile instala via apt:
        msodbcsql18 + unixodbc-dev). Token AAD obtido via azure.identity em vez
        de `Authentication=ActiveDirectoryMsi` no DSN — workaround para bug do
        driver com User-Assigned MI em Linux.
    """
    from azure.identity import DefaultAzureCredential, ManagedIdentityCredential

    if use_managed_identity:
        if azure_client_id:
            credential = ManagedIdentityCredential(client_id=azure_client_id)
            auth_mode = f"ManagedIdentityCredential(client_id={azure_client_id})"
        else:
            credential = ManagedIdentityCredential()
            auth_mode = "ManagedIdentityCredential(system-assigned)"
    else:
        credential = DefaultAzureCredential()
        auth_mode = "DefaultAzureCredential(dev)"

    # Connection Timeout=60: cobre cold-start de Azure SQL Serverless (resume
    # típico ~30-60s) caso autoPauseDelay tenha sido reativado em runtime.
    dsn = (
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server=tcp:{server},1433;"
        f"Database={database};"
        "Encrypt=yes;TrustServerCertificate=no;Connection Timeout=60;"
    )

    factory = MITokenConnectionFactory(dsn=dsn, credential=credential)

    # Eager token fetch: fail-fast se MI/credential não funciona.
    # Não força conexão SQL — apenas valida que conseguimos obter token AAD.
    await asyncio.to_thread(factory._get_token_struct)

    logger.info(
        "SQL connection factory criada | server=%s | db=%s | auth=%s",
        server,
        database,
        auth_mode,
    )
    return factory
