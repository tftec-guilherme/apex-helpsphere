# HelpSphere - Story 06.5c.9 Sessao 9.5 (Decisao #21)
# Postprovision hook: cria indice gptkbindex (schema minimo) ANTES de prepdocs.py
# pra garantir que backend Python sobe mesmo se prepdocs falhar/nao rodar.
# Idempotente: skip se indice ja existe.

$AZURE_USE_AUTHENTICATION = (azd env get-value AZURE_USE_AUTHENTICATION 2>$null)
if ($AZURE_USE_AUTHENTICATION -ne "true") {
  Write-Host "AZURE_USE_AUTHENTICATION nao e true - skip setup_search_index (backend nao valida schema sem auth)."
  Exit 0
}

. ./scripts/load_python_env.ps1

$venvPythonPath = "./.venv/scripts/python.exe"
if (Test-Path -Path "/usr") {
  # fallback to Linux venv path
  $venvPythonPath = "./.venv/bin/python"
}

Start-Process -FilePath $venvPythonPath -ArgumentList "./scripts/setup_search_index.py" -Wait -NoNewWindow
