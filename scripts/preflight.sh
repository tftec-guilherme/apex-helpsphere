#!/usr/bin/env bash
# HelpSphere — Pre-flight check antes de 'azd up' (Linux/Mac/WSL).
#
# Valida 8 pré-condições:
#   1. Bash 4+ (informativo se zsh)
#   2. (skip Long Path — Unix sem limite)
#   3. Docker rodando
#   4. Azure CLI logado (`az login`)
#   5. azd CLI logado (`azd auth login`)
#   6. ODBC Driver 18 for SQL Server instalado
#   7. Python 3.13.x disponível
#   8. Subscription Azure ativa (informativo)
#
# Exit code:
#   0 — todos os checks PASS
#   1 — pelo menos um check FAIL (com instrução de correção)
#
# Uso:
#   bash scripts/preflight.sh

set -u

# ANSI cores
if [[ -t 1 ]]; then
    GREEN=$'\033[0;32m'
    RED=$'\033[0;31m'
    YELLOW=$'\033[0;33m'
    CYAN=$'\033[0;36m'
    DIM=$'\033[2m'
    RESET=$'\033[0m'
else
    GREEN='' RED='' YELLOW='' CYAN='' DIM='' RESET=''
fi

failed=0

echo ""
echo "${CYAN}HelpSphere Pre-flight Check${RESET}"
echo "${CYAN}===========================${RESET}"
echo ""

# --- 1. Bash version ---
printf "[1/8] Bash version... "
if [[ -n "${BASH_VERSION:-}" ]]; then
    bash_major="${BASH_VERSION%%.*}"
    if (( bash_major >= 4 )); then
        echo "${GREEN}OK (bash ${BASH_VERSION})${RESET}"
    else
        echo "${YELLOW}AVISO (bash ${BASH_VERSION} — recomendado >= 4)${RESET}"
    fi
else
    # Provavelmente zsh ou outro shell — informativo
    echo "${YELLOW}NAO-BASH (continuando)${RESET}"
fi

# --- 2. Long Path (skipped on Unix) ---
printf "[2/8] Long Path (Unix)... "
echo "${DIM}N/A (Unix nao tem limite MAX_PATH)${RESET}"

# --- 3. Docker rodando ---
printf "[3/8] Docker rodando... "
if docker info >/dev/null 2>&1; then
    echo "${GREEN}OK${RESET}"
else
    echo "${RED}FALHA${RESET}"
    echo "  ${YELLOW}Inicie o Docker daemon (Docker Desktop ou systemctl start docker).${RESET}"
    echo "  ${YELLOW}Mac: 'open -a Docker'  |  Linux: 'sudo systemctl start docker'${RESET}"
    failed=1
fi

# --- 4. Azure CLI logado ---
printf "[4/8] Azure CLI logado (az)... "
if az_user=$(az account show --query user.name --output tsv 2>/dev/null) && [[ -n "$az_user" ]]; then
    echo "${GREEN}OK (${az_user})${RESET}"
else
    echo "${RED}FALHA${RESET}"
    echo "  ${YELLOW}Rode: az login${RESET}"
    echo "  ${YELLOW}Instalacao: https://learn.microsoft.com/cli/azure/install-azure-cli${RESET}"
    failed=1
fi

# --- 5. azd CLI logado ---
printf "[5/8] azd CLI logado... "
if azd auth login --check-status >/dev/null 2>&1; then
    echo "${GREEN}OK${RESET}"
else
    echo "${RED}FALHA${RESET}"
    echo "  ${YELLOW}Rode: azd auth login${RESET}"
    echo "  ${YELLOW}Instalacao: curl -fsSL https://aka.ms/install-azd.sh | bash${RESET}"
    failed=1
fi

# --- 6. ODBC Driver 18 ---
printf "[6/8] ODBC Driver 18 for SQL Server... "
if command -v odbcinst >/dev/null 2>&1; then
    if odbcinst -q -d 2>/dev/null | grep -qi "ODBC Driver 18 for SQL Server"; then
        echo "${GREEN}OK${RESET}"
    else
        echo "${RED}FALHA${RESET}"
        echo "  ${YELLOW}Instale msodbcsql18:${RESET}"
        echo "  ${YELLOW}  Debian/Ubuntu: https://learn.microsoft.com/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server${RESET}"
        echo "  ${YELLOW}  Mac (Homebrew): brew tap microsoft/mssql-release && brew install msodbcsql18${RESET}"
        failed=1
    fi
else
    echo "${RED}FALHA (odbcinst nao encontrado)${RESET}"
    echo "  ${YELLOW}Instale unixodbc + msodbcsql18:${RESET}"
    echo "  ${YELLOW}  Debian/Ubuntu: sudo apt-get install -y unixodbc-dev && siga docs MS para msodbcsql18${RESET}"
    echo "  ${YELLOW}  Docs: https://learn.microsoft.com/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server${RESET}"
    failed=1
fi

# --- 7. Python 3.13.x ---
printf "[7/8] Python 3.13.x... "
py_cmd=""
if command -v python3 >/dev/null 2>&1; then
    py_cmd="python3"
elif command -v python >/dev/null 2>&1; then
    py_cmd="python"
fi

if [[ -n "$py_cmd" ]]; then
    py_version=$("$py_cmd" --version 2>&1)
    if [[ "$py_version" =~ ^Python\ 3\.13\. ]]; then
        echo "${GREEN}OK (${py_version})${RESET}"
    else
        echo "${RED}FALHA (${py_version})${RESET}"
        echo "  ${YELLOW}Instale Python 3.13:${RESET}"
        echo "  ${YELLOW}  pyenv (recomendado): pyenv install 3.13 && pyenv local 3.13${RESET}"
        echo "  ${YELLOW}  Mac: brew install python@3.13${RESET}"
        echo "  ${YELLOW}  Ubuntu: sudo apt install python3.13 python3.13-venv${RESET}"
        failed=1
    fi
else
    echo "${RED}FALHA (python nao encontrado)${RESET}"
    echo "  ${YELLOW}Instale Python 3.13 via pyenv, brew ou apt.${RESET}"
    failed=1
fi

# --- 8. Subscription ativa (informativo) ---
printf "[8/8] Subscription Azure (informativo)... "
sub_name=$(az account show --query name --output tsv 2>/dev/null || true)
sub_id=$(az account show --query id --output tsv 2>/dev/null || true)
if [[ -n "$sub_name" ]]; then
    echo "${GREEN}${sub_name}${RESET}"
    echo "  ${DIM}(${sub_id})${RESET}"
    echo "  ${DIM}Se NAO eh a correta: az account set --subscription <id|name>${RESET}"
else
    echo "${YELLOW}(nao detectada)${RESET}"
    echo "  ${DIM}Use 'az account list -o table' e 'az account set --subscription <id>' para selecionar.${RESET}"
fi

# --- Final ---
echo ""
if (( failed )); then
    echo "${RED}Pre-flight FAILED. Corrija os itens acima antes de rodar 'azd up'.${RESET}"
    exit 1
fi
echo "${GREEN}Pre-flight PASSED — pronto para 'azd up'.${RESET}"
exit 0
