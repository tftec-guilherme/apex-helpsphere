#!/bin/sh

# HelpSphere — Story 06.5c.9 Sessão 9.5 (Decisão #21)
# Postprovision hook: cria índice gptkbindex (schema mínimo) ANTES de prepdocs.py
# pra garantir que backend Python sobe mesmo se prepdocs falhar/não rodar.
# Idempotente: skip se índice já existe.

AZURE_USE_AUTHENTICATION=$(azd env get-value AZURE_USE_AUTHENTICATION 2>/dev/null)
if [ "$AZURE_USE_AUTHENTICATION" != "true" ]; then
  echo "AZURE_USE_AUTHENTICATION não é true — skip setup_search_index (backend não valida schema sem auth)."
  exit 0
fi

. ./scripts/load_python_env.sh

./.venv/bin/python ./scripts/setup_search_index.py
