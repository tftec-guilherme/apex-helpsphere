# PARA-O-ALUNO — Apex HelpSphere (Disciplina 06)

> Você forka o repo, configura **5 variáveis** no GitHub, e dá `git push`. CI deploya tudo no Azure em ~15 minutos. Nenhum passo manual no Portal Azure.
>
> Alternativa: `azd up` local da sua máquina (mesma duração, sem CI).

---

## 🎯 Cenário (30 segundos)

A **Apex Group** — holding varejo brasileira fictícia — tem o HelpSphere em produção: 12 mil tickets/mês, R$ 102k/mês em tier 1. A CTO aprovou o **Programa Apex IA** e seu trabalho na disciplina é **acoplar IA dentro do HelpSphere existente** — não reconstruir.

Este repo é o HelpSphere base pré-pronto. Você forka, deploya, e o turbina nos 3 labs.

---

## ✅ Pré-requisitos

- Conta Azure **Pay-As-You-Go** (Free Trial $200 NÃO funciona)
- Conta GitHub
- Acesso a um Azure tenant onde você pode criar Service Principal

**Custo:** R$ 8-15 por sessão de 4-6h se você rodar `azd down --purge` no fim. Esquecer ligado 1 mês = R$ 80-120.

---

## 🤖 Caminho A — GitHub Actions (RECOMENDADO pra disciplina)

### 1. Fork

Clique em **Fork** no canto superior direito do repo `tftec-guilherme/apex-helpsphere`. Cria seu fork em `SEU_USUARIO/apex-helpsphere`.

### 2. Habilitar Actions

No seu fork → aba **Actions** → botão **"I understand my workflows, go ahead and enable them"**.

> Forks vêm com Actions desabilitado por default — proteção contra fork-PRs maliciosos.

### 3. Criar o Service Principal federated (1 vez)

Escolha sua plataforma. **PowerShell é recomendado para Windows** (todos os exemplos foram testados em PS5+ e PS7).

#### 3a. PowerShell (Windows / pwsh)

```powershell
# 1) Configure as 2 variaveis de entrada
$GITHUB_USER = "SEU_USUARIO_GITHUB"
$SUB_ID = (az account show --query id -o tsv)
$TENANT_ID = (az account show --query tenantId -o tsv)

# 2) Cria App Registration + Service Principal companion
$SP_NAME = "sp-apex-helpsphere-$GITHUB_USER"
$APP_OUTPUT = (az ad app create --display-name $SP_NAME --query "{appId:appId, id:id}" -o json) | ConvertFrom-Json
$APP_ID = $APP_OUTPUT.appId
$APP_OBJECT_ID = $APP_OUTPUT.id
az ad sp create --id $APP_ID | Out-Null

# 3) Federated credential (GitHub Actions OIDC)
$fedJson = @"
{
  "name": "github-$GITHUB_USER-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:$GITHUB_USER/apex-helpsphere:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}
"@
$fedJson | Out-File -FilePath "$env:TEMP\fed.json" -Encoding utf8
az ad app federated-credential create --id $APP_OBJECT_ID --parameters "@$env:TEMP\fed.json"

# 4) Role assignment — Contributor (sempre permitido por ABAC, ver aviso abaixo)
az role assignment create --assignee $APP_ID --role "Contributor" --scope "/subscriptions/$SUB_ID"

# 5) Microsoft Graph Application.ReadWrite.All + admin consent
az ad app permission add --id $APP_ID --api 00000003-0000-0000-c000-000000000000 --api-permissions 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9=Role
az ad app permission admin-consent --id $APP_ID

# 6) Imprime os 3 IDs pra colar nas Variables do fork
Write-Host ""
Write-Host "AZURE_CLIENT_ID=$APP_ID"
Write-Host "AZURE_TENANT_ID=$TENANT_ID"
Write-Host "AZURE_SUBSCRIPTION_ID=$SUB_ID"
```

#### 3b. Bash (Linux / macOS / WSL / Cloud Shell)

```bash
GITHUB_USER="SEU_USUARIO_GITHUB"
SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
SP_NAME="sp-apex-helpsphere-${GITHUB_USER}"

# 1) App + SP
APP_OUTPUT=$(az ad app create --display-name "$SP_NAME" --query "{appId:appId, id:id}" -o json)
APP_ID=$(echo $APP_OUTPUT | jq -r '.appId')
APP_OBJECT_ID=$(echo $APP_OUTPUT | jq -r '.id')
az ad sp create --id "$APP_ID" > /dev/null

# 2) Federated credential
cat > /tmp/fed.json <<EOF
{
  "name": "github-${GITHUB_USER}-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_USER}/apex-helpsphere:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF
az ad app federated-credential create --id "$APP_OBJECT_ID" --parameters @/tmp/fed.json

# 3) Role + Graph perm + consent
az role assignment create --assignee "$APP_ID" --role "Contributor" --scope "/subscriptions/$SUB_ID"
az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9=Role
az ad app permission admin-consent --id "$APP_ID"

# 4) Print
echo ""
echo "AZURE_CLIENT_ID=$APP_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID=$SUB_ID"
```

#### ⚠️ 3 avisos importantes (lições da Sessão 9.7)

**1. ABAC condition em conta `live.com`:** Se você está logado com conta `live.com#email@dominio.com` (Visual Studio Enterprise pessoal), seu Owner tem ABAC condition que **bloqueia atribuir Owner / User Access Administrator / RBAC Administrator**. **Por isso o script usa `Contributor`** — não troque para `Owner` mesmo se a doc Microsoft sugerir.

**2. Admin consent precisa Global Admin:** O `permission admin-consent` requer que VOCÊ seja **Global Admin** ou **Cloud Application Administrator** no tenant. Se não for:
- Peça para um admin do tenant rodar este comando, OU
- Faça via Portal: Entra ID → App registrations → buscar `sp-apex-helpsphere-*` → API permissions → **Grant admin consent for {tenant}**

**3. Workflow tem preflight com auto-fix:** Se este script falhar no meio (ex: rede caiu na criação do SP companion), App Registrations órfãs ficam no tenant. **Não precisa rodar o script de novo.** Workflow `5. Deploy` tem **preflight Check 6** que detecta órfãs e cria SPs automaticamente. Você pode pular direto para o passo 5.

#### 🔬 Validação (opcional, recomendado antes de configurar Variables)

```powershell
# Confirma SP criado
az ad sp show --id $APP_ID --query "{name:displayName, appId:appId}" -o table

# Confirma Contributor na sub
az role assignment list --assignee $APP_ID --scope "/subscriptions/$SUB_ID" --query "[].roleDefinitionName" -o tsv

# Confirma Graph perm + admin consent
az ad app permission list-grants --id $APP_ID --output table
```

**Esperado:**
- SP existe com nome `sp-apex-helpsphere-{USER}`
- Role list contém `Contributor`
- Permission list mostra `Microsoft Graph` com scope contendo `Application.ReadWrite.All`

⏳ Tudo isso é **uma vez na vida do tenant**. Próxima execução do workflow vai consumir esses recursos.

### 4. Configurar 5 Variables no fork

No seu fork → **Settings** → **Secrets and variables** → **Actions** → aba **Variables** (NÃO Secrets!) → **New repository variable**, 5 vezes:

| Variable name | Valor |
|---------------|-------|
| `AZURE_CLIENT_ID` | (do passo 3) |
| `AZURE_TENANT_ID` | (do passo 3) |
| `AZURE_SUBSCRIPTION_ID` | (do passo 3) |
| `AZURE_ENV_NAME` | `helpsphere-actions` |
| `AZURE_LOCATION` | `westus3` |

> **Por que Variables e não Secrets?** São 5 IDs identificadores (não senhas). Federated OIDC dispensa secret estático — o token é trocado em runtime.

### 5. Trigger deploy

No fork → **Actions** → workflow **"5. Deploy (Azure Container Apps)"** → **Run workflow** → branch `main` → **Run workflow**.

⏳ **~15 minutos.** O workflow:

1. Provision (Bicep) — App Service + 2 Container Apps + SQL + Storage + App Insights
2. Setup AAD — cria Server App + Client App + admin consent automaticamente (via `auth_init.py` no preprovision hook)
3. Build — frontend Vite + 2 imagens Docker
4. Deploy — sobe artefatos + migrations + seed (50 tickets pt-BR)

URL pública aparece no log do step "Show app URL".

### 5.1. Se preflight falhar com "AAD group não encontrada"

O preflight do workflow pode falhar com mensagem tipo:

```
::error::Group <GUID> nao foi encontrada no tenant
::error::Fix: criar a group OU atualizar var AZURE_SQL_AAD_ADMIN_GROUP_OBJECT_ID
```

Significa que o Bicep precisa de uma **Entra group** como AAD admin do SQL Server e ela não existe no seu tenant. Crie agora (PowerShell, comando único):

```powershell
$group = (az ad group create --display-name "aad-helpsphere-sql-admins" --mail-nickname "aad-helpsphere-sql-admins" --description "SQL admins do HelpSphere — D06 lab" -o json) | ConvertFrom-Json
Write-Host "Object ID: $($group.id)"
```

Adicione seu usuário como membro (pra logar via Entra no SQL depois):

```powershell
$ME = (az ad signed-in-user show --query id -o tsv); az ad group member add --group $group.id --member-id $ME
```

Atualize a var no GitHub:

```powershell
gh variable set AZURE_SQL_AAD_ADMIN_GROUP_OBJECT_ID --body $group.id --repo SEU_USUARIO/apex-helpsphere
```

Re-trigger workflow. Próxima execução passa Check 5.

**Bash equivalente (linha única em variáveis sequenciais):**

```bash
GROUP_ID=$(az ad group create --display-name "aad-helpsphere-sql-admins" --mail-nickname "aad-helpsphere-sql-admins" --description "SQL admins do HelpSphere — D06 lab" --query id -o tsv)
ME=$(az ad signed-in-user show --query id -o tsv)
az ad group member add --group "$GROUP_ID" --member-id "$ME"
gh variable set AZURE_SQL_AAD_ADMIN_GROUP_OBJECT_ID --body "$GROUP_ID" --repo SEU_USUARIO/apex-helpsphere
echo "Object ID: $GROUP_ID"
```

> **Por que reativo (em 5.1) e não preventivo (em 3.5)?** A primeira execução do template **pode** ter a var `AZURE_SQL_AAD_ADMIN_GROUP_OBJECT_ID` já configurada com group existente. Só falha quando ID aponta pra group inexistente — o preflight Check 5 te avisa exatamente quando isso acontece.

### 6. Abrir no navegador

Acesse a URL. Você vai ver:

1. **Login bloqueante** → Microsoft Entra (`prompt: select_account`) → faça login
2. **Dashboard Executivo** (`/`) → 4 KPI cards + 2 gráficos consumindo `/api/tickets/stats`
3. **Lista de tickets** (`/tickets`) → 50 tickets pt-BR em 5 tenants (Apex Mart, Tech, Logistics, Finance, Brasil)
4. **Detalhe** (`/tickets/{id}`) → comments seedados

Se vir os 4 → **funcionou**.

---

## 💻 Caminho B — Local (alternativa rápida pra desenvolvimento)

```bash
git clone https://github.com/SEU_USUARIO/apex-helpsphere.git
cd apex-helpsphere
./scripts/preflight.sh         # ou pwsh ./scripts/preflight.ps1
az login && azd auth login
azd env new helpsphere-demo-{seu-id}
azd up
```

⏳ 9-14 min. Não precisa das 5 vars do GitHub. Mas você não tem CI/CD automático — só local.

---

## 🧹 Cleanup (TODA sessão)

**Caminho A (CI):** Actions → workflow **"5. Deploy"** → **Run workflow** → marque ✅ **destroy** input → Run.

**Caminho B (local):**
```bash
azd down --purge
```

⚠️ `--purge` é obrigatório. Sem ele, Cognitive Services + Key Vault ficam soft-deleted 90 dias.

---

## 🔄 Reset total (se algo deu errado e você quer começar do zero)

Use estes comandos se uma execução parcial deixou state quebrado (App Regs órfãs, SP sem role, RG com recursos não-completos). PowerShell:

```powershell
# Configure
$GITHUB_USER = "SEU_USUARIO"
$SUB_ID = (az account show --query id -o tsv)
$RG_NAME = "rg-d06-dev-001"   # ou seu AZURE_ENV_NAME

# 1) Lista App Registrations criadas pelo template (auditoria visual antes de deletar)
az ad app list --display-name "helpsphere" --query "[].{name:displayName, appId:appId, id:id}" -o table
az ad app list --display-name "helpsphere-client" --query "[].{name:displayName, appId:appId, id:id}" -o table
az ad app list --display-name "sp-apex-helpsphere-$GITHUB_USER" --query "[].{name:displayName, appId:appId, id:id}" -o table

# 2) Deleta as 3 App Regs (deletando App, SP companion e federated cred caem juntos)
az ad app list --display-name "helpsphere" --query "[].id" -o tsv | ForEach-Object { az ad app delete --id $_ }
az ad app list --display-name "helpsphere-client" --query "[].id" -o tsv | ForEach-Object { az ad app delete --id $_ }
az ad app list --display-name "sp-apex-helpsphere-$GITHUB_USER" --query "[].id" -o tsv | ForEach-Object { az ad app delete --id $_ }

# 3) Deleta o Resource Group
$RG_EXISTS = az group exists --name $RG_NAME
if ($RG_EXISTS -eq "true") {
    az group delete --name $RG_NAME --yes --no-wait
    Write-Host "RG $RG_NAME marcado pra delecao em background."
}

# 4) Purga Cognitive Services em soft-delete (libera nomes <90 dias)
$DELETED_COG = az cognitiveservices account list-deleted --query "[?contains(name, 'helpsphere') || contains(name, 'apex')].{name:name, location:location, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json
foreach ($cog in $DELETED_COG) {
    Write-Host "Purgando $($cog.name)..."
    az cognitiveservices account purge --name $cog.name --resource-group $cog.resourceGroup --location $cog.location 2>$null
}

# 5) Deleta o azd env local
azd env delete --no-prompt 2>$null
Remove-Item -Path .azure -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Reset completo. Volte para o passo 3 (criar SP) e refaca do zero."
Write-Host "Os GitHub Variables ja configuradas continuam valendo se voce vai recriar com mesma identidade."
```

**Após reset:** volte para [Passo 3 — Criar Service Principal](#3-criar-o-service-principal-federated-1-vez). O preflight do workflow vai validar 8 checks e te guiar passo a passo se algo falhar.

---

## 🗺️ Os 3 labs da disciplina

| Lab | Você adiciona | Companion público |
|-----|---------------|-------------------|
| **Lab Intermediário** (M02-M05) | Pipeline RAG: Document Intelligence + AI Search + chat com citations | [`apex-rag-lab`](https://github.com/tftec-guilherme/apex-rag-lab) — 10 capítulos passo-a-passo |
| **Lab Final** (M06) | Agentes Foundry + Speech STT/TTS + n8n | (Q3-2026) |
| **Lab Avançado** (D06 IA produção) | CI/CD + APIM + Content Safety + Azure Policy + circuit breaker | guia em [`azure-retail`](https://github.com/tftec-guilherme/azure-retail) |

> **Chat dormente:** rota `/chat` está oculta em v2.1.0. Você habilita no Lab Intermediário via Bicep param `enableChat=true`.

---

## 📚 Quer ir mais fundo?

- [`DECISION-LOG.md`](./DECISION-LOG.md) — 23 decisões arquiteturais
- [`APPENDIX-SURPRESAS.md`](./APPENDIX-SURPRESAS.md) — 29 surpresas pedagógicas + lições
- [`APPENDIX-CI.md`](./APPENDIX-CI.md) — detalhes do federated SP + Microsoft Graph perms
- Tag canônica: [`helpsphere-v2.1.0`](https://github.com/tftec-guilherme/apex-helpsphere/releases/tag/helpsphere-v2.1.0)

---

## 🆘 Suporte

- **Dúvidas:** fórum AVA da disciplina
- **Bugs no template:** [issues no repo](https://github.com/tftec-guilherme/apex-helpsphere/issues)

**Prof. Guilherme Campos** · Pós-Graduação Avançada de Cloud com Azure

> **Lembrete final:** sempre cleanup ao final de cada sessão.
