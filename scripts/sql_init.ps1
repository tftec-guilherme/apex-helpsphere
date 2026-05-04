# HelpSphere - Story 06.5a Sessao 2.3
# Postprovision hook: cria USER FROM EXTERNAL PROVIDER para backend MI,
# GRANT roles, executa migrations + seeds (se AZURE_LOAD_SEED_DATA=true).

$USE_SQL_SERVER = (azd env get-value USE_SQL_SERVER 2>$null)
if ($USE_SQL_SERVER -ne "true" -and $USE_SQL_SERVER -ne $null -and $USE_SQL_SERVER -ne "") {
  if ($USE_SQL_SERVER -eq "false") {
    Write-Host "USE_SQL_SERVER=false - pulando sql_init"
    Exit 0
  }
}

. ./scripts/load_python_env.ps1

$venvPythonPath = "./.venv/scripts/python.exe"
if (Test-Path -Path "/usr") {
  # fallback to Linux venv path
  $venvPythonPath = "./.venv/bin/python"
}

Start-Process -FilePath $venvPythonPath -ArgumentList "./scripts/sql_init.py" -Wait -NoNewWindow
