"""sql_init.py — postprovision hook para HelpSphere SQL.

Story 06.5a — Sessão 2.3 (origem).
Story 06.5c.4 — Sessão 7+ (tickets MI scoped grants — Decisão #16 hybrid).

Executa após `azd provision` (Bicep) ter criado:
- Azure SQL Server + Database `helpsphere`
- Backend Managed Identity (User-Assigned para Container Apps)
- Tickets Managed Identity (User-Assigned dedicada para tickets-service .NET)
- Entra Group como AAD admin do SQL Server

Operações (em ordem, idempotentes):

1. Conecta no Azure SQL como AAD admin (azd CLI user — pertencente ao grupo
   `sqlAadAdminGroupName` configurado no Bicep).
2. Cria USER no banco `helpsphere` para a backend MI (`CREATE USER FROM EXTERNAL PROVIDER`)
   + GRANT roles `db_datareader` + `db_datawriter` (legacy path — Decisão D1 da 06.5c.4:
   backend MI mantém broad grants até 06.5c.7 deprecar /api/tickets/* Python).
3. Cria USER no banco para a tickets MI + scoped object-level GRANTs:
   - SELECT/INSERT/UPDATE/DELETE em dbo.tbl_tickets + dbo.tbl_comments
   - SELECT em dbo.tbl_tenants
   Verificação automática via sys.database_permissions (fail-fast se mismatch).
4. Executa `data/migrations/001_initial_schema.sql` (3 tabelas + 2 índices + 1 trigger).
5. Se `AZURE_LOAD_SEED_DATA=true` (default), executa seeds em ordem:
   tenants.sql → tickets.sql → comments.sql.

Pré-requisitos no host (autossuficiente via venv `./.venv/`):
- Python 3.10+ com `pyodbc`, `azure-identity` (em requirements-dev ou requirements)
- MS ODBC Driver 18 for SQL Server
- `azd` CLI logado (azd auth login + az login)

Production-grade rationale (Decisão #5 + Decisão #16):
- AAD-only auth: nenhuma password gerenciada no banco.
- USER FROM EXTERNAL PROVIDER: cada serviço autentica via sua Managed Identity dedicada.
- Idempotência via `IF NOT EXISTS` e MERGE nos seeds — pode rodar N vezes sem erro.
- Least privilege scoped (tickets MI): object-level GRANTs por tabela, NÃO db_datareader/datawriter.
"""
from __future__ import annotations

import os
import re
import struct
import sys
from pathlib import Path

import pyodbc
from azure.identity import AzureDeveloperCliCredential

# Story 06.5c.4 T6: regex whitelist para validar MI display names antes de uso em f-strings T-SQL.
# UMI names são DNS-like (Microsoft Docs: 3-128 chars, alphanumeric + hyphen + underscore).
# Defense-in-depth contra T-SQL injection — em prática env var vem do Bicep, mas validar mesmo assim.
_MI_NAME_RE = re.compile(r"^[a-zA-Z0-9_-]+$")

# MSDN: msodbcsql.h — atributo para passar AAD access token diretamente
SQL_COPT_SS_ACCESS_TOKEN = 1256

# Paths relativos ao helpsphere/scripts/ (este arquivo está em scripts/sql_init.py)
SCRIPTS_DIR = Path(__file__).resolve().parent
HELPSPHERE_ROOT = SCRIPTS_DIR.parent
DATA_DIR = HELPSPHERE_ROOT / "data"


def _build_token_bytes(credential: AzureDeveloperCliCredential) -> bytes:
    """Empacota access token AAD para pyodbc attrs_before."""
    token = credential.get_token("https://database.windows.net/.default").token
    raw = token.encode("utf-16-le")
    return struct.pack(f"=i{len(raw)}s", len(raw), raw)


def _open_admin_connection(server: str, database: str) -> pyodbc.Connection:
    """Conecta como AAD admin (azd CLI user), autocommit ligado para DDL."""
    credential = AzureDeveloperCliCredential()
    token_bytes = _build_token_bytes(credential)

    dsn = (
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server=tcp:{server},1433;"
        f"Database={database};"
        "Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
    )
    conn = pyodbc.connect(dsn, attrs_before={SQL_COPT_SS_ACCESS_TOKEN: token_bytes})
    conn.autocommit = True
    return conn


def _validate_mi_name(mi_display_name: str) -> None:
    """T6 (Story 06.5c.4): regex whitelist defense-in-depth contra T-SQL injection."""
    if not _MI_NAME_RE.fullmatch(mi_display_name):
        raise ValueError(
            f"MI display name inválido (esperado [a-zA-Z0-9_-]+): {mi_display_name!r}"
        )


def _create_mi_user(
    cur: pyodbc.Cursor,
    mi_display_name: str,
    grants: list[str] | None = None,
) -> None:
    """Cria USER FROM EXTERNAL PROVIDER + aplica grants (idempotente).

    Story 06.5c.4 D3: parametrização de grants para suportar tickets MI scoped.

    Args:
        cur: cursor SQL Server (autocommit).
        mi_display_name: display name da Managed Identity no Entra (= ARM resource name).
            Validado por regex (`_validate_mi_name`) antes de uso em f-string T-SQL.
        grants: lista de statements GRANT object-level já formatados.
            Se None (default), aplica db_datareader + db_datawriter (backend Python — D1).
            Se list, aplica cada grant via cursor.execute (T-SQL GRANT é idempotente nativo).

    NOTA D1 (Story 06.5c.4): backend Python atualmente é chamado com grants=None preservando
    db_datareader/db_datawriter por compat. Story 06.5c.7 revogará e migrará para grants
    explícitos quando endpoints /api/tickets/* forem deprecados (return 410 Gone).
    """
    _validate_mi_name(mi_display_name)
    print(f"👤 Criando USER no banco para MI '{mi_display_name}' (idempotente)...")
    # USER FROM EXTERNAL PROVIDER referencia a Managed Identity pelo display name
    # no Entra (= nome do recurso da MI). Idempotência via IF NOT EXISTS.
    cur.execute(
        f"""
        IF NOT EXISTS (
            SELECT 1 FROM sys.database_principals WHERE name = N'{mi_display_name}'
        )
        BEGIN
            CREATE USER [{mi_display_name}] FROM EXTERNAL PROVIDER;
        END
        """
    )

    if grants is None:
        # Backend MI legacy path — db_datareader + db_datawriter (D1: até 06.5c.7 revogar)
        cur.execute(f"ALTER ROLE db_datareader ADD MEMBER [{mi_display_name}];")
        cur.execute(f"ALTER ROLE db_datawriter ADD MEMBER [{mi_display_name}];")
        print(
            f"✅ '{mi_display_name}' + db_datareader + db_datawriter (legacy backend MI — D1)"
        )
    else:
        # Tickets MI scoped path — object-level grants (idempotente nativo, sem IF NOT EXISTS)
        for grant_stmt in grants:
            cur.execute(grant_stmt)
        print(
            f"✅ '{mi_display_name}' + {len(grants)} object-level grants (scoped — least privilege)"
        )


def _verify_grants(
    cur: pyodbc.Cursor,
    mi_display_name: str,
    expected: set[tuple[str, str]],
) -> None:
    """T5 (Story 06.5c.4): verifica via sys.database_permissions que `mi_display_name`
    tem exatamente `expected` grants object-level. Fail-fast com diff em stderr se mismatch.

    Args:
        cur: cursor SQL Server.
        mi_display_name: display name da MI a verificar (já validado).
        expected: set de tuplas (object_name, permission_name), ex:
            {('tbl_tickets','SELECT'), ('tbl_tickets','INSERT'), ...}

    Raises:
        SystemExit(1) se actual != expected (Bicep typo, schema drift, etc.).
    """
    _validate_mi_name(mi_display_name)
    cur.execute(
        f"""
        SELECT OBJECT_NAME(major_id), permission_name
        FROM sys.database_permissions
        WHERE grantee_principal_id = USER_ID(N'{mi_display_name}')
            AND class = 1
            AND state_desc = 'GRANT'
        """
    )
    actual = {(row[0], row[1].strip()) for row in cur.fetchall()}
    if actual != expected:
        missing = expected - actual
        extra = actual - expected
        print(
            f"❌ Grants mismatch para '{mi_display_name}' em sys.database_permissions:",
            file=sys.stderr,
        )
        if missing:
            print(f"   Faltando: {sorted(missing)}", file=sys.stderr)
        if extra:
            print(f"   Inesperados: {sorted(extra)}", file=sys.stderr)
        sys.exit(1)
    print(
        f"✅ Verificação sys.database_permissions: {len(actual)}/{len(expected)} "
        f"grants object-level confirmados para '{mi_display_name}'"
    )


def _run_sql_file(cur: pyodbc.Cursor, sql_path: Path) -> None:
    """Executa arquivo .sql T-SQL respeitando GO como batch separator.

    GO não é instrução T-SQL, é separador do sqlcmd/SSMS. pyodbc precisa que
    cada batch seja um cursor.execute separado.
    """
    if not sql_path.exists():
        raise FileNotFoundError(f"Arquivo SQL não encontrado: {sql_path}")

    raw = sql_path.read_text(encoding="utf-8")
    # Split em batches por linha "GO" sozinha (com tolerância a CRLF e espaços)
    batches = []
    current: list[str] = []
    for line in raw.splitlines():
        if line.strip().upper() == "GO":
            if current:
                batches.append("\n".join(current))
                current = []
        else:
            current.append(line)
    if current:
        batches.append("\n".join(current))

    for batch in batches:
        if batch.strip():
            cur.execute(batch)


def main() -> int:
    server = os.environ.get("AZURE_SQL_SERVER", "").strip()
    database = os.environ.get("AZURE_SQL_DATABASE", "helpsphere").strip()
    backend_mi_name = os.environ.get("AZURE_SQL_BACKEND_MI_NAME", "").strip()
    tickets_mi_name = os.environ.get("AZURE_SQL_TICKETS_MI_NAME", "").strip()
    load_seed_data = os.environ.get("AZURE_LOAD_SEED_DATA", "true").lower() == "true"

    if not server:
        print("⏭️  AZURE_SQL_SERVER não setado — pulando sql_init (SQL Server desabilitado)")
        return 0
    if not backend_mi_name:
        print(
            "⚠️  AZURE_SQL_BACKEND_MI_NAME não setado — não consigo criar USER da backend MI.",
            file=sys.stderr,
        )
        print(
            "    Verifique se o Bicep foi aplicado e azd env tem o output AZURE_SQL_BACKEND_MI_NAME.",
            file=sys.stderr,
        )
        return 1
    if not tickets_mi_name:
        # Story 06.5c.4 AC 1: tickets MI é mandatório no hybrid (Decisão #16).
        print(
            "⚠️  AZURE_SQL_TICKETS_MI_NAME não setado — não consigo criar USER da tickets MI.",
            file=sys.stderr,
        )
        print(
            "    Verifique se o Bicep main.bicep tem output AZURE_SQL_TICKETS_MI_NAME (Story 06.5c.4)",
            file=sys.stderr,
        )
        print(
            "    e azd env get-value AZURE_SQL_TICKETS_MI_NAME retorna o display name da UMI tickets-identity.",
            file=sys.stderr,
        )
        return 1

    print(f"🔌 Conectando no Azure SQL: {server}/{database}")
    with _open_admin_connection(server, database) as conn:
        with conn.cursor() as cur:
            # Backend MI — legacy path (db_datareader + db_datawriter, D1)
            _create_mi_user(cur, backend_mi_name)

            # Tickets MI — scoped object-level grants (Story 06.5c.4)
            tickets_grants = [
                f"GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.tbl_tickets TO [{tickets_mi_name}];",
                f"GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.tbl_comments TO [{tickets_mi_name}];",
                f"GRANT SELECT ON dbo.tbl_tenants TO [{tickets_mi_name}];",
            ]
            _create_mi_user(cur, tickets_mi_name, grants=tickets_grants)

            # T5: verificação fail-fast — 9 grants esperados (4 tickets + 4 comments + 1 tenants)
            tickets_expected_grants: set[tuple[str, str]] = {
                ("tbl_tickets", "SELECT"),
                ("tbl_tickets", "INSERT"),
                ("tbl_tickets", "UPDATE"),
                ("tbl_tickets", "DELETE"),
                ("tbl_comments", "SELECT"),
                ("tbl_comments", "INSERT"),
                ("tbl_comments", "UPDATE"),
                ("tbl_comments", "DELETE"),
                ("tbl_tenants", "SELECT"),
            }
            _verify_grants(cur, tickets_mi_name, tickets_expected_grants)

            schema_file = DATA_DIR / "migrations" / "001_initial_schema.sql"
            print(f"📜 Executando schema: {schema_file.name}")
            _run_sql_file(cur, schema_file)
            print("✅ Schema aplicado (3 tabelas + 2 índices + 1 trigger)")

            if load_seed_data:
                # Decisão #15.7 (debug FK violation): print row count após cada seed
                table_for_seed = {
                    "tenants.sql": "dbo.tbl_tenants",
                    "tickets.sql": "dbo.tbl_tickets",
                    "comments.sql": "dbo.tbl_comments",
                }
                for seed_name in ("tenants.sql", "tickets.sql", "comments.sql"):
                    seed_file = DATA_DIR / "seed" / seed_name
                    print(f"🌱 Seed: {seed_name}")
                    _run_sql_file(cur, seed_file)
                    table = table_for_seed[seed_name]
                    cur.execute(f"SELECT COUNT(*) FROM {table}")
                    cnt = cur.fetchone()[0]
                    if seed_name == "tickets.sql":
                        cur.execute(f"SELECT MIN(ticket_id), MAX(ticket_id) FROM {table}")
                        mn, mx = cur.fetchone()
                        print(f"  → {cnt} rows em {table} (ticket_id range: {mn}..{mx})")
                    else:
                        print(f"  → {cnt} rows em {table}")
                print("✅ Seeds carregados (5 tenants Apex + 50 tickets pt-BR + 70 comments)")
            else:
                print("⏭️  AZURE_LOAD_SEED_DATA=false — seeds pulados")

    print("🎉 sql_init concluído com sucesso")
    return 0


if __name__ == "__main__":
    sys.exit(main())
