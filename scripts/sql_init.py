"""sql_init.py — postprovision hook para HelpSphere SQL.

Story 06.5a — Sessão 2.3.

Executa após `azd provision` (Bicep) ter criado:
- Azure SQL Server + Database `helpsphere`
- Backend Managed Identity (User-Assigned para Container Apps)
- Entra Group como AAD admin do SQL Server

Operações (em ordem, idempotentes):

1. Conecta no Azure SQL como AAD admin (azd CLI user — pertencente ao grupo
   `sqlAadAdminGroupName` configurado no Bicep).
2. Cria USER no banco `helpsphere` para a Managed Identity do backend
   (`CREATE USER [<MI-display-name>] FROM EXTERNAL PROVIDER`).
3. GRANT roles `db_datareader` + `db_datawriter` à MI.
4. Executa `data/migrations/001_initial_schema.sql` (3 tabelas + 2 índices + 1 trigger).
5. Se `AZURE_LOAD_SEED_DATA=true` (default), executa seeds em ordem:
   tenants.sql → tickets.sql → comments.sql.

Pré-requisitos no host (autossuficiente via venv `./.venv/`):
- Python 3.10+ com `pyodbc`, `azure-identity` (em requirements-dev ou requirements)
- MS ODBC Driver 18 for SQL Server
- `azd` CLI logado (azd auth login + az login)

Production-grade rationale (Decisão #5):
- AAD-only auth: nenhuma password gerenciada no banco.
- USER FROM EXTERNAL PROVIDER: backend autentica via Managed Identity.
- Idempotência via `IF NOT EXISTS` e MERGE nos seeds — pode rodar N vezes sem erro.
"""
from __future__ import annotations

import os
import struct
import sys
from pathlib import Path

import pyodbc
from azure.identity import AzureDeveloperCliCredential

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


def _create_mi_user(cur: pyodbc.Cursor, mi_display_name: str) -> None:
    """Cria USER FROM EXTERNAL PROVIDER + concede db_datareader + db_datawriter (idempotente)."""
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
    cur.execute(f"ALTER ROLE db_datareader ADD MEMBER [{mi_display_name}];")
    cur.execute(f"ALTER ROLE db_datawriter ADD MEMBER [{mi_display_name}];")
    print(f"✅ USER + roles concedidas (db_datareader, db_datawriter)")


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
    load_seed_data = os.environ.get("AZURE_LOAD_SEED_DATA", "true").lower() == "true"

    if not server:
        print("⏭️  AZURE_SQL_SERVER não setado — pulando sql_init (SQL Server desabilitado)")
        return 0
    if not backend_mi_name:
        print(
            "⚠️  AZURE_SQL_BACKEND_MI_NAME não setado — não consigo criar USER da MI.",
            file=sys.stderr,
        )
        print(
            "    Verifique se o Bicep foi aplicado e azd env tem o output AZURE_SQL_BACKEND_MI_NAME.",
            file=sys.stderr,
        )
        return 1

    print(f"🔌 Conectando no Azure SQL: {server}/{database}")
    with _open_admin_connection(server, database) as conn:
        with conn.cursor() as cur:
            _create_mi_user(cur, backend_mi_name)

            schema_file = DATA_DIR / "migrations" / "001_initial_schema.sql"
            print(f"📜 Executando schema: {schema_file.name}")
            _run_sql_file(cur, schema_file)
            print("✅ Schema aplicado (3 tabelas + 2 índices + 1 trigger)")

            if load_seed_data:
                for seed_name in ("tenants.sql", "tickets.sql", "comments.sql"):
                    seed_file = DATA_DIR / "seed" / seed_name
                    print(f"🌱 Seed: {seed_name}")
                    _run_sql_file(cur, seed_file)
                print("✅ Seeds carregados (5 tenants Apex + 50 tickets pt-BR + 70 comments)")
            else:
                print("⏭️  AZURE_LOAD_SEED_DATA=false — seeds pulados")

    print("🎉 sql_init concluído com sucesso")
    return 0


if __name__ == "__main__":
    sys.exit(main())
