 #!/bin/sh

# HelpSphere — Story 06.5a Sessão 2.3
# Postprovision hook: cria USER FROM EXTERNAL PROVIDER para backend MI,
# GRANT roles, executa migrations + seeds (se AZURE_LOAD_SEED_DATA=true).

USE_SQL_SERVER=$(azd env get-value USE_SQL_SERVER 2>/dev/null || echo "true")
if [ "$USE_SQL_SERVER" != "true" ]; then
  echo "⏭️  USE_SQL_SERVER=false — pulando sql_init"
  exit 0
fi

. ./scripts/load_python_env.sh

./.venv/bin/python ./scripts/sql_init.py
