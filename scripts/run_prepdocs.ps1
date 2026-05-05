# HelpSphere v2.1.0 (Sessao 9.5) - wrapper idempotente para prepdocs.ps1
#
# Le SKIP_PREPDOCS do azd env. Se "true", pula a ingestao (acelera azd up em
# ~3min). Caso contrario, delega para o prepdocs.ps1 original (template upstream
# preservado intacto pra facilitar merge futuro com Azure-Samples).
#
# Decisao #22: param Bicep `skipPrepdocs` controla esse comportamento via env
# var SKIP_PREPDOCS exportada em main.parameters.json.

$SKIP_PREPDOCS = (azd env get-value SKIP_PREPDOCS 2>$null)
if ($SKIP_PREPDOCS -eq "true") {
  Write-Host "SKIP_PREPDOCS=true - pulando prepdocs (chat/RAG so funciona apos aluno rodar manual)."
  Write-Host "Para popular o indice: azd env set SKIP_PREPDOCS false; ./scripts/prepdocs.ps1"
  Exit 0
}

& ./scripts/prepdocs.ps1 @args
