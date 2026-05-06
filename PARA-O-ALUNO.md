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

Cole no Cloud Shell ou terminal local com `az` logado:

```bash
# Substitua os 2 valores abaixo
GITHUB_USER="SEU_USUARIO"
SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# Cria App Registration + Service Principal
SP_NAME="sp-apex-helpsphere-${GITHUB_USER}"
APP_OUTPUT=$(az ad app create --display-name "$SP_NAME" --query "{appId:appId, id:id}" -o json)
APP_ID=$(echo $APP_OUTPUT | jq -r '.appId')
APP_OBJECT_ID=$(echo $APP_OUTPUT | jq -r '.id')
az ad sp create --id "$APP_ID" > /dev/null

# Federated credential (GitHub Actions OIDC)
cat > /tmp/fed.json <<EOF
{
  "name": "github-${GITHUB_USER}-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_USER}/apex-helpsphere:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF
az ad app federated-credential create --id "$APP_OBJECT_ID" --parameters @/tmp/fed.json

# Grants do SP
az role assignment create --assignee "$APP_ID" --role "Owner" --scope "/subscriptions/$SUB_ID"
az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9=Role
az ad app permission admin-consent --id "$APP_ID"

# Imprime os 3 valores que você precisa colar no GitHub
echo ""
echo "AZURE_CLIENT_ID=$APP_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID=$SUB_ID"
```

⏳ ~30 segundos. Saída imprime os 3 IDs.

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
