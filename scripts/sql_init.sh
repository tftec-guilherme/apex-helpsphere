 #!/bin/sh

# HelpSphere — Story 06.5a Sessão 2.3
# Postprovision hook: cria USER FROM EXTERNAL PROVIDER para backend MI,
# GRANT roles, executa migrations + seeds (se AZURE_LOAD_SEED_DATA=true).

# Decisão #15 (Sessão 5): defensive resolution. azd hooks NÃO leem shell env,
# só azd env file. Mas o workflow GH Actions seta USE_SQL_SERVER no shell.
# Estratégia: shell env → azd env file → default "true" (HelpSphere = SQL mandatório, Decisão #5).
USE_SQL_SERVER="${USE_SQL_SERVER:-$(azd env get-value USE_SQL_SERVER 2>/dev/null)}"
USE_SQL_SERVER="${USE_SQL_SERVER:-true}"
if [ "$USE_SQL_SERVER" != "true" ]; then
  echo "⏭️  USE_SQL_SERVER=$USE_SQL_SERVER — pulando sql_init"
  exit 0
fi
echo "✅ USE_SQL_SERVER=true — executando sql_init (cria SQL user para backend MI + grants + migrations + seeds)"

. ./scripts/load_python_env.sh

./.venv/bin/python ./scripts/sql_init.py
