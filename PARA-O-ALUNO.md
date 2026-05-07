# PARA-O-ALUNO — Apex HelpSphere (Disciplina 06)

> Template HelpSphere **pré-pronto** — você clona no VSCode, roda `azd up`, e em ~15 minutos tem o SaaS rodando no Azure. **Sem CI/CD, sem Service Principal, sem GitHub Variables.** Só sua conta Azure local.
>
> IA stack **NÃO** é provisionada aqui — fica para os 3 labs (Inter/Final/Avançado), passo-a-passo Portal Azure.

---

## 🎯 Cenário (30 segundos)

A **Apex Group** — holding varejo brasileira fictícia — tem o HelpSphere em produção: 12 mil tickets/mês, R$ 102k/mês em tier 1. A CTO aprovou o **Programa Apex IA** e seu trabalho na disciplina é **acoplar IA dentro do HelpSphere existente** — não reconstruir.

Este repo é o HelpSphere base SaaS. Você clona, deploya local, e o turbina nos 3 labs da disciplina.

---

## ✅ Pré-requisitos

### Conta Azure
- **Pay-As-You-Go**, **Visual Studio Enterprise** ou **Free Trial $200 USD** com role **Owner** na subscription
- Free Trial **funciona para esta versão SaaS-only** (~$3-5/dia em westus3 = ~50 dias com $200 credit) porque IA stack está desligada (`DEPLOY_IA_STACK=false`). Se você for fazer os 3 labs (Inter/Final/Avançado) que provisionam Azure OpenAI, **converta para PAYG antes** — Free Trial bloqueia em quota de OpenAI.
- ⚠️ Se sua conta é `live.com` Visual Studio Enterprise, ela pode ter ABAC condition que bloqueia atribuição de Owner/UAA/RBAC Admin (Surpresa #31). Para SaaS-only via `azd up` direto isso não bloqueia, mas se você quiser CI/CD fork-by-student, vai precisar de TFTEC sub ou contornar.

### Conta GitHub
- Apenas para fork do repo (sem CI/CD nesta versão SaaS-only)

### Software local (instalação one-shot)

**Windows (PowerShell 7+):**

```powershell
# Instala TUDO em um único comando (winget)
winget install --id Microsoft.AzureCLI --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.Azd --accept-package-agreements --accept-source-agreements
winget install --id Git.Git --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements
winget install --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.msodbcsql.18 --accept-package-agreements --accept-source-agreements
winget install --id Python.Python.3.13 --accept-package-agreements --accept-source-agreements
winget install --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
```

**macOS (Homebrew):**

```bash
brew install azure-cli azd git docker python@3.13 node powershell
brew install --cask visual-studio-code docker
# ODBC Driver 18:
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
brew install msodbcsql18
```

**Linux (Ubuntu/Debian):**

```bash
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# azd
curl -fsSL https://aka.ms/install-azd.sh | bash

# Outros
sudo apt install -y git docker.io python3.13 nodejs npm
sudo snap install code --classic

# ODBC Driver 18
curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
sudo apt update && sudo ACCEPT_EULA=Y apt install -y msodbcsql18
```

### Versões mínimas validadas

| Ferramenta | Versão mínima | Função |
|------------|---------------|--------|
| **Azure CLI** | 2.60+ | Login Azure + comandos de role assignment |
| **azd** (Azure Developer CLI) | 1.10+ | Provision + build + deploy automatizado |
| **Git** | 2.40+ | Clone do repo |
| **VSCode** | última | IDE |
| **Docker Desktop** | última | Build das imagens (backend Python + tickets-service .NET) |
| **PowerShell** | 7.4+ | Scripts pwsh (preflight, auth_init) |
| **Python** | 3.13.x | `auth_init.py` no preprovision hook |
| **Node.js** | 20 LTS+ | Build do frontend Vite |
| **ODBC Driver 18 for SQL Server** | 18.x | `pyodbc` conexão com Azure SQL |

### Custo esperado

R$ 8-15 por sessão de 4-6h **se** você rodar `azd down --purge` no fim. Esquecer ligado 1 mês = R$ 80-120. **Não esqueça.**

---

## 🚀 Quick Start (6 passos · ~15 minutos)

### 1. Fork + clone no VSCode

1. Forke `tftec-guilherme/apex-helpsphere` na UI do GitHub para `SEU_USUARIO/apex-helpsphere`
2. No VSCode: **Ctrl+Shift+P** → **Git: Clone** → cole `https://github.com/SEU_USUARIO/apex-helpsphere.git` → escolha pasta local
3. Quando o clone terminar, VSCode pergunta "Open repository?" → **Open**

### 2. Pre-flight check (~30 segundos)

No terminal integrado do VSCode (**Ctrl+`**):

```powershell
# Windows PowerShell:
pwsh ./scripts/preflight.ps1

# macOS/Linux/WSL:
./scripts/preflight.sh
```

Valida ambiente local (PowerShell 7+, Long Path Win, Docker, ODBC Driver 18, Python 3.13.x, etc.). Sai com erro acionável se algo faltar.

#### Falhou? Troubleshooting dos 2 mais comuns

**`[2/8] Long Path habilitado (Windows)... FALHA`**

Long Path é registry e exige **PowerShell elevado**. Abra **Terminal (Admin)** (Win+X → "Terminal (Admin)") e cole:

```powershell
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -Value 1
```

Vale imediatamente para processos **novos** — feche o terminal onde rodou o preflight e reabra. Não precisa reboot.

**`[7/8] Python 3.13.x... FALHA (Python 3.14.x)`** (ou versão diferente)

Se você já tinha outra versão de Python instalada (ex: 3.14 default no PATH) **e** acabou de instalar 3.13 via winget, o `python` no PATH ainda resolve para a versão antiga. O preflight aceita 2 caminhos:
- `python --version` retornar `3.13.x` (Python 3.13 é o default no PATH), **OU**
- `py -3.13 --version` funcionar (Python launcher detecta 3.13 instalado em qualquer caminho)

Verifique se o launcher acha sua 3.13:

```powershell
py -0          # lista todas Python instaladas
py -3.13 --version   # deve mostrar 3.13.x
```

Se `py -3.13` funciona, o preflight passa automaticamente — sem mexer em PATH ou desinstalar nada. Se não funciona, reinstale: `winget install --id Python.Python.3.13 -e`.

### 3. Login Azure

```powershell
az login
azd auth login
```

Vão abrir 2 janelas de browser (Azure CLI + azd). Login com sua conta Azure em ambas.

```powershell
# Confirma que está na subscription certa
az account show --query "{name:name, id:id}" -o table
```

### 4. Criar environment azd + flags do Bicep

```powershell
azd env new helpsphere-saas-{seu-id}

# Flags pra deploy SaaS-only (sem IA — IA fica nos labs Inter/Final/Avancado)
azd env set DEPLOY_IA_STACK "false"
azd env set USE_MULTIMODAL "false"
azd env set SKIP_ROLE_ASSIGNMENTS "false"

# Flags do template
azd env set USE_AUTHENTICATION "true"
azd env set USE_SQL_SERVER "true"
azd env set AZURE_LOAD_SEED_DATA "true"
azd env set DEPLOYMENT_TARGET "containerapps"
azd env set AZURE_LOCATION "westus3"
```

> **Por que essas flags?** `DEPLOY_IA_STACK=false` desliga OpenAI / AI Search / Doc Intelligence / Vision / Speech / Cosmos. `USE_MULTIMODAL=false` reforça (vars do template upstream). `SKIP_ROLE_ASSIGNMENTS=false` mantém os MI grants automáticos (sua conta Owner consegue criar — non-Owner roles são permitidas). Resultado: **só SaaS** deploya.

### 5. `azd up`

```powershell
azd up
```

⏳ **9-14 minutos.** Faz 3 coisas em sequência:

1. **Provision** (Bicep) — App Service + 2 Container Apps (backend Python + tickets-service .NET) + SQL Database + Storage Account + Container Registry + App Insights + Log Analytics + Key Vault + Auth (App Registrations Server + Client criadas automaticamente via `auth_init.py` no preprovision hook)
2. **Build** — empacota frontend Vite + 2 imagens Docker (backend Python + tickets-service .NET)
3. **Deploy** — push das imagens pro ACR + atualiza Container Apps + roda migrations + seed (50 tickets pt-BR distribuídos em 5 tenants Apex)

URL pública aparece no log final do `azd up` (campo `(✓) Done: Deploying service backend`).

### 6. Abrir no navegador

Acesse a URL impressa pelo `azd up`:

1. **Login bloqueante** → `<LoginGate>` componente redireciona pra Microsoft Entra (`prompt: select_account`) → login
2. **Apex Executivo Dashboard** (`/`) → 4 KPI cards + 2 gráficos Recharts em tempo real
3. **Lista de tickets** (`/tickets`) → 50 tickets pt-BR distribuídos em 5 tenants (Apex Mart, Tech, Logistics, Finance, Brasil)
4. **Detalhe do ticket** (`/tickets/{id}`) → descrição + comments seedados

Se vir os 4, **funcionou**.

> **Apex Executivo design:** Fraunces (display) + Inter Tight (UI) + JetBrains Mono (code) · paleta off-white `#fafaf7` / navy `#0c1834` / accent gold `#a87b3f`. Identidade visual SaaS executivo brasileiro.

---

## 🧹 Cleanup (TODA sessão)

```powershell
azd down --purge
```

⚠️ **`--purge` é obrigatório.** Sem ele, Cognitive Services + Key Vault ficam soft-deleted por 90 dias e bloqueiam o próximo `azd up`.

---

## 🔄 Reset total (se algo deu errado)

Se uma execução parcial deixou state quebrado, limpe tudo e refaça:

```powershell
$AZURE_ENV_NAME = "helpsphere-saas-seu-id"   # nome que você usou no Step 4

# 1) Deleta App Registrations criadas pelo template
az ad app list --display-name "helpsphere" --query "[].id" -o tsv | ForEach-Object { az ad app delete --id $_ }
az ad app list --display-name "helpsphere-client" --query "[].id" -o tsv | ForEach-Object { az ad app delete --id $_ }

# 2) Deleta o Resource Group
az group delete --name "rg-$AZURE_ENV_NAME" --yes --no-wait

# 3) Purga Cognitive Services em soft-delete
az cognitiveservices account list-deleted --query "[?contains(name, 'helpsphere') || contains(name, 'apex')].{name:name, location:location, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json | ForEach-Object {
    az cognitiveservices account purge --name $_.name --resource-group $_.resourceGroup --location $_.location 2>$null
}

# 4) Limpa azd env local
azd env delete --no-prompt 2>$null
Remove-Item -Path .azure -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Reset completo. Volte para o Step 3 (Login Azure)."
```

---

## 🗺️ Os 3 labs da disciplina

A partir daqui, **cada lab é Portal-first manual** seguindo guias passo-a-passo. Você não precisa do `apex-helpsphere` rodando para fazê-los — cada lab cria seus próprios recursos isolados.

| Lab | Você adiciona | Guia |
|-----|---------------|------|
| **Lab Intermediário** (M02-M05) | Pipeline RAG: Document Intelligence + AI Search + chat com citations | `Disciplina_06_*/01_Aulas/Lab_Intermediario_RAG_HelpSphere_Guia_Portal.md` |
| **Lab Final** (M06) | Agentes Foundry + canal de voz Speech STT/TTS + n8n | `Disciplina_06_*/01_Aulas/Lab_Final_Agente_Workflow_Guia_Portal.md` |
| **Lab Avançado** (D06 IA produção) | CI/CD + APIM Developer + Content Safety + Azure Policy + circuit breaker | `Disciplina_06_*/01_Aulas/Lab_Avancado_IA_Producao_Guia_Portal.md` |

> **Chat dormente:** rota `/chat` está oculta em v2.1.0. Você habilita no Lab Intermediário via Bicep param `enableChat=true` (que vira env var `ENABLE_CHAT=true`).

---

## 📚 Quer ir mais fundo?

- **[`DECISION-LOG.md`](./DECISION-LOG.md)** — 23 decisões arquiteturais com defesa para audiência sênior
- **[`APPENDIX-SURPRESAS.md`](./APPENDIX-SURPRESAS.md)** — 35 surpresas pedagógicas que o template MS não documenta (gotchas + lições)
- **Estado canônico:** tag git [`helpsphere-v2.1.0`](https://github.com/tftec-guilherme/apex-helpsphere/releases/tag/helpsphere-v2.1.0)

---

## 🆘 Suporte

- **Dúvidas:** fórum AVA da disciplina
- **Bugs:** [issues no repo](https://github.com/tftec-guilherme/apex-helpsphere/issues)

**Prof. Guilherme Campos** · Pós-Graduação Avançada de Cloud com Azure

---

> **Lembrete final:** `azd down --purge` ao final de cada sessão. **Sempre.**
