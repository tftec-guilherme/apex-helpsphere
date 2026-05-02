"""Connection pool aioodbc para Azure SQL com Managed Identity AAD.

Em produção (Container Apps): `Authentication=ActiveDirectoryMsi` — o driver
MSODBC obtém token AAD via IMDS automaticamente em cada conexão. Sem necessidade
de gerenciar refresh de token manualmente.

Em desenvolvimento (local): `Authentication=ActiveDirectoryDefault` — fallback
para `azd auth login` / `az login` / VS Code Azure extension.

Pool com `pool_recycle=3000s` (50min) recicla conexões antes de o token AAD
expirar (~60min). Combinado com ActiveDirectoryMsi, cada nova conexão obtém
token fresh do IMDS — refresh automático sem código nosso.
"""
from __future__ import annotations

import logging

import aioodbc

logger = logging.getLogger(__name__)


async def create_sql_pool(
    *,
    server: str,
    database: str,
    use_managed_identity: bool = False,
    azure_client_id: str | None = None,
    minsize: int = 2,
    maxsize: int = 10,
    pool_recycle: int = 3000,
) -> aioodbc.Pool:
    """Cria pool aioodbc com AAD authentication.

    Args:
        server: FQDN do Azure SQL Server (ex: 'helpsphere-prod.database.windows.net')
        database: nome do database (ex: 'helpsphere')
        use_managed_identity: True para Container Apps (ActiveDirectoryMsi),
                              False para dev local (ActiveDirectoryDefault)
        azure_client_id: opcional, User-Assigned MI client ID quando
                         use_managed_identity=True
        minsize: conexões mínimas no pool
        maxsize: conexões máximas no pool
        pool_recycle: segundos para reciclar conexão (50min < 60min do token AAD)

    Returns:
        Pool pronto para uso via `async with pool.acquire() as conn`

    Notes:
        Driver MS ODBC 18 obrigatório no host (Dockerfile instala via apt:
        msodbcsql18 + unixodbc-dev).
    """
    if use_managed_identity:
        auth_clause = "Authentication=ActiveDirectoryMsi;"
        if azure_client_id:
            auth_clause += f"User Id={azure_client_id};"
    else:
        auth_clause = "Authentication=ActiveDirectoryDefault;"

    dsn = (
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server=tcp:{server},1433;"
        f"Database={database};"
        f"{auth_clause}"
        "Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
    )

    pool = await aioodbc.create_pool(
        dsn=dsn,
        autocommit=True,
        minsize=minsize,
        maxsize=maxsize,
        pool_recycle=pool_recycle,
    )

    logger.info(
        "SQL pool criado | server=%s | db=%s | mi=%s | pool=[%d..%d] | recycle=%ds",
        server,
        database,
        use_managed_identity,
        minsize,
        maxsize,
        pool_recycle,
    )
    return pool
