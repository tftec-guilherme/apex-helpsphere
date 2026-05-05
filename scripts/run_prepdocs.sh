#!/bin/sh

# HelpSphere v2.1.0 (Sessão 9.5) — wrapper idempotente para prepdocs.sh
#
# Lê SKIP_PREPDOCS do azd env. Se "true", pula a ingestão (acelera azd up em
# ~3min). Caso contrário, delega para o prepdocs.sh original (template upstream
# preservado intacto pra facilitar merge futuro com Azure-Samples).
#
# Decisão #22: param Bicep `skipPrepdocs` controla esse comportamento via env
# var SKIP_PREPDOCS exportada em main.parameters.json.

SKIP_PREPDOCS=$(azd env get-value SKIP_PREPDOCS 2>/dev/null)
if [ "$SKIP_PREPDOCS" = "true" ]; then
  echo "SKIP_PREPDOCS=true — pulando prepdocs (chat/RAG só funciona após aluno rodar manual)."
  echo "Para popular o índice: azd env set SKIP_PREPDOCS false && ./scripts/prepdocs.sh"
  exit 0
fi

exec ./scripts/prepdocs.sh "$@"
