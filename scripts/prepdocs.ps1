if ((azd env get-values) -match "USE_CLOUD_INGESTION=""true""") {
  Write-Host "Cloud ingestion is enabled, so we are not running the manual ingestion process."
  Exit 0
}

# HelpSphere - Story 06.5a Sessao 4 (Decisao #12):
# Guard PDF count. Template HelpSphere e entregue SEM PDFs em data/ (Decisao #3
# excluiu PDFs Zava do vendoring). prepdocs falha tentando processar nossos PNGs
# sinteticos (data/mocks/) via DocumentAnalysisParser figure extractor com erro
# "cannot write empty image". Aluno adiciona PDFs em data/ no Lab Intermediario
# e roda este script manualmente para popular o indice RAG.
$pdfCount = (Get-ChildItem -Path ./data -Filter *.pdf -Recurse -ErrorAction SilentlyContinue).Count
if ($pdfCount -eq 0) {
  Write-Host "No PDFs found in ./data/ - skipping prepdocs (HelpSphere template e entregue vazio)."
  Write-Host "Para popular o indice RAG, adicione PDFs em ./data/ e rode novamente: ./scripts/prepdocs.ps1"
  Exit 0
}

Write-Host "Encontrados $pdfCount PDFs em ./data/, executando prepdocs.py..."

./scripts/load_python_env.ps1

$venvPythonPath = "./.venv/scripts/python.exe"
if (Test-Path -Path "/usr") {
  # fallback to Linux venv path
  $venvPythonPath = "./.venv/bin/python"
}

Write-Host 'Running "prepdocs.py"'


$cwd = (Get-Location)
$dataArg = "`"$cwd/data/*`""
$additionalArgs = ""
if ($args) {
  $additionalArgs = "$args"
}

$argumentList = "./app/backend/prepdocs.py $dataArg --verbose $additionalArgs"

$argumentList

Start-Process -FilePath $venvPythonPath -ArgumentList $argumentList -Wait -NoNewWindow
