 #!/bin/sh

USE_CLOUD_INGESTION=$(azd env get-value USE_CLOUD_INGESTION)
if [ "$USE_CLOUD_INGESTION" = "true" ]; then
  echo "Cloud ingestion is enabled, so we are not running the manual ingestion process."
  exit 0
fi

# HelpSphere — Story 06.5a Sessão 4 (Decisão #12):
# Guard PDF count. Template HelpSphere é entregue SEM PDFs em data/ (Decisão #3
# excluiu PDFs Zava do vendoring). prepdocs falha tentando processar nossos PNGs
# sintéticos (data/mocks/) via DocumentAnalysisParser figure extractor com erro
# "cannot write empty image". Aluno adiciona PDFs em data/ no Lab Intermediário
# e roda este script manualmente para popular o índice RAG.
PDF_COUNT=$(find ./data -name "*.pdf" -type f 2>/dev/null | wc -l)
if [ "$PDF_COUNT" -eq 0 ]; then
  echo "No PDFs found in ./data/ — skipping prepdocs (HelpSphere template é entregue vazio)."
  echo "Para popular o índice RAG, adicione PDFs em ./data/ e rode novamente: ./scripts/prepdocs.sh"
  exit 0
fi

. ./scripts/load_python_env.sh

echo "Running \"prepdocs.py\" — encontrados $PDF_COUNT PDFs em ./data/"

additionalArgs=""
if [ $# -gt 0 ]; then
  additionalArgs="$@"
fi

./.venv/bin/python ./app/backend/prepdocs.py './data/*' --verbose $additionalArgs
