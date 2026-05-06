# PARA-O-ALUNO — Disciplina 06 / Apex HelpSphere

> Bem-vindo. Este é o **entrypoint** do template HelpSphere que você vai turbinar com IA ao longo dos 3 Labs da Disciplina 06. Leia este arquivo na primeira passada — **não precisa ler tudo do README ou do DECISION-LOG agora.**

---

## 🎯 Cenário em 3 linhas

A **Apex Group** (holding varejo brasileira fictícia) já tem um sistema de tickets em produção: o **HelpSphere**. 12 mil tickets/mês, R$ 102 mil/mês em tempo de tier 1. A Carla (CTO) aprovou o **Programa Apex IA** e seu trabalho na disciplina é: **acoplar IA dentro do HelpSphere existente**, não reconstruir nada.

Esse repo é o **HelpSphere pré-pronto** — você roda `azd up`, ganha 9-14 minutos, e foca o tempo de lab no que importa: pipeline RAG, agentes, automação.

> ⭐ **Setup zero-friction v2.1.0:** **0 passos manuais no Portal Azure**. App Registrations (Server + Client), admin consent das 5 Microsoft Graph perms, e Directory Extension Property `app_tenant_id` são automatizados via `scripts/auth_init.py` no preprovision hook. Era ~6 passos manuais no v2.0.0 — virou zero. Estado canônico fixado na tag git [`helpsphere-v2.1.0`](https://github.com/tftec-guilherme/apex-helpsphere/releases/tag/helpsphere-v2.1.0).

---

## ✅ Pré-requisitos (checklist 1 minuto)

- [ ] Conta Azure **Pay-As-You-Go** (Free Trial USD 200 NÃO funciona — Azure OpenAI exige PAYG)
- [ ] Quota Azure OpenAI já aprovada via `aka.ms/oai/access` (1-3 dias úteis — só necessário a partir do Lab Intermediário)
- [ ] Cartão de crédito internacional vinculado à subscription
- [ ] **Azure CLI 2.x**, **Azure Developer CLI (`azd`)**, **Git**, **Docker Desktop** instalados
- [ ] Conta GitHub (para forkar este repo)

Custo esperado por sessão: **R$ 8-15** se você usar 4-6h e rodar `azd down --purge` no final.
Custo se esquecer ligado 1 mês: **R$ 80-120**. Não esqueça.

---

## 🚀 Quick Start (6 passos)

### 0. Pre-flight check

Antes de tudo, valide pré-condições do seu ambiente:

```bash
# Windows PowerShell:
pwsh ./scripts/preflight.ps1

# macOS/Linux/WSL:
./scripts/preflight.sh
```

O script valida em ~30s: PowerShell 7+ (Win), Long Path Win, Docker rodando, `az login`, `azd login`, ODBC Driver 18, Python 3.13.x, subscription ativa correta. Sai com erro acionável (`Long Path desabilitado — rode: gpedit.msc...`) se algo falhar.

> **Por que pre-flight?** Cada falha que ele detecta = 5-15min economizados de `azd up` falhar parcialmente. v2.1.0 documenta 29 armadilhas — pre-flight cobre as 6 mais comuns.

### 1. Fork + clone do **seu** fork

Forque este repositório na UI do GitHub: `tftec-guilherme/apex-helpsphere` → `SEU_USUARIO/apex-helpsphere`.

> **Por que fork primeiro?** Você vai customizar ao longo dos 3 labs (RAG, agentes, automação). Sem fork, você não tem permissão de `git push` no seu progresso.

```bash
git clone https://github.com/SEU_USUARIO/apex-helpsphere.git
cd apex-helpsphere
```

### 2. Login Azure

```bash
az login
azd auth login
```

### 3. Criar environment azd

```bash
azd env new helpsphere-demo-{seu-id}
```

Use um identificador único (ex: `helpsphere-demo-joao2026`). Esse nome vira sufixo dos recursos no Azure.

### 4. `azd up`

```bash
azd up
```

Espera ~9-14 minutos. O comando faz 3 coisas:

1. **Provision** — Bicep cria App Service + 2 Container Apps (Python backend + .NET tickets-service) + SQL + Storage + App Insights
2. **Build** — empacota frontend Vite + 2 imagens Docker
3. **Deploy** — sobe artefatos + roda migrations + seed (50 tickets pt-BR populados)

No final, o `azd up` imprime a URL pública. Acesse, faça login com sua conta Entra, e veja a fila de tickets.

### 5. Verificar que funcionou

Abra a URL pública impressa pelo `azd up` no navegador. O fluxo correto v2.1.0 é:

1. **Login bloqueante** — você cai na rota `/redirect` que serve um `<LoginGate>` componente; clique em **Sign in**, MSAL faz `loginRedirect` (não popup) pra Microsoft Entra com `prompt: select_account`, você loga
2. **Apex Executivo Dashboard (`/`)** — após login, você cai no dashboard executivo: **4 KPI cards** (open tickets, avg resolution time, satisfaction score, total tenants) + **2 Recharts** consumindo `/api/tickets/stats` em tempo real via Dapper `QueryMultipleAsync`
3. **Lista de tickets (`/tickets`)** — menu lateral → ver os **50 tickets pt-BR** distribuídos em **5 tenants** (Apex Mart, Apex Tech, Apex Logistics, Apex Finance, Apex Brasil)
4. **Detalhe do ticket (`/tickets/{id}`)** — clique em qualquer ticket pra ver descrição + 70 comments seedados + status

> **Apex Executivo design system:** o template v2.1.0 tem identidade visual própria — fontes **Fraunces** (display elegante serif) + **Inter Tight** (UI) + **JetBrains Mono** (code) · paleta **off-white `#fafaf7`** / **navy `#0c1834`** / **accent gold `#a87b3f`**. Não é mais o look do template Microsoft `azure-search-openai-demo` original — é um SaaS executivo com apresentação para C-level brasileiro.

Se quiser validar via API direto:

```bash
# Pegue o tickets-service URL
TICKETS_URL=$(azd env get-value TICKETS_BACKEND_URI)

# Liste os tickets (vai pedir token Entra — copie do DevTools do browser depois de logar no frontend)
curl -H "Authorization: Bearer $TOKEN" "$TICKETS_URL/api/tickets"
```

Você deve ver JSON com 50 tickets pt-BR. Se vir, **tudo funciona**.

---

## 🧹 Cleanup (toda sessão)

```bash
azd down --purge
```

`--purge` é importante — sem ele, recursos soft-deleted (Cognitive Services, Key Vault) ficam ocupando o nome por 90 dias e bloqueiam o próximo `azd up`.

---

## 🗺️ Próximos passos na disciplina

Cada lab adiciona uma camada nova ao HelpSphere. Sempre que possível há **dois caminhos**: o branch no seu fork (Bicep automation, validado em CI) **ou** o companion repo público com passo-a-passo Portal-first. Pattern arquitetural **"Bicep validates → Portal mirrors"** garante anti-drift: o Bicep no monorepo é ground truth técnico; o repo Portal-first é didático e atualizado quando UI do Azure muda.

| Lab | O que você adiciona | Repo destino (fork) | Companion Portal-first |
|-----|---------------------|---------------------|------------------------|
| **Lab Intermediário** (M02-M05) | Pipeline RAG: Document Intelligence (`prebuilt-layout`) + Azure AI Search (Basic) + skillset declarativo + chat com citation rendering. Curadoria: **8 PDFs sample-kb** corporativos pt-BR (subset pedagógico dos 62 PDFs Apex full KB) | seu fork (branch `lab-intermediario`) | [`tftec-guilherme/apex-rag-lab`](https://github.com/tftec-guilherme/apex-rag-lab) — **10 capítulos Portal Azure** + snippets + screenshots Q2-2026 |
| **Lab Final** (M06) | Agentes Foundry com tools + canal de voz (Speech STT/TTS) + automação confidence-based via n8n + integração com tickets | seu fork (branch `lab-final`) | (companion futuro Q3-2026) |
| **Lab Avançado** (D06 — IA em produção) | **Production-grade canônico isolado:** CI/CD GitHub Actions completo + APIM Developer tier + Content Safety guardrails (prompt shields) + Azure Policy + circuit breaker + observabilidade Application Insights end-to-end. **NÃO usa D04** (apesar de tecnologias próximas) — partimos sempre das melhorias do `apex-helpsphere` como base SaaS | seu fork (branch `lab-avancado`) | guia em [`Disciplina_06_*/01_Aulas/Lab_Avancado_IA_Producao_Guia_Portal.md`](https://github.com/tftec-guilherme/azure-retail) |

> **Chat / RAG no template:** A rota `/chat` está **dormente** no template v2.1.0 — sumida da nav lateral. Quando você fizer o **Lab Intermediário (M02-M05)**, vai habilitar via Bicep param `enableChat=true` (que vira env var `ENABLE_CHAT=true` no backend, exposta em `/auth_setup` pro frontend). Backend Python `/chat` está **funcional** (auth + OpenAI client setup), só falta o pipeline RAG (embeddings + AI Search index com docs Apex) que é justamente o escopo do lab. Por isso ele aparece sem opção na UI: evita "promessa quebrada" pro aluno e foca a v2.1.0 em **infraestrutura production-grade + tickets**.

---

## 💡 Surpresas pedagógicas que você vai encontrar (e que o template MS NÃO documenta)

Se algo der errado, antes de perguntar no fórum, dê uma olhada nestas lições aprendidas (todas com defesa arquitetural completa em [`DECISION-LOG.md`](./DECISION-LOG.md)):

### Surpresas operacionais (Sessões 1-5)

| # | Surpresa | Lição |
|---|----------|-------|
| **#1** | Free Trial USD 200 não roda Azure OpenAI | PAYG é mandatório. Não tente Free Trial — vai bloquear na quota. |
| **#2** | `eastus2` sem capacidade SQL/Search em Q2-2026 | Use **`westus3`** ou **`brazilsouth`** para HelpSphere. East US 2 só pra Foundry Hub depois. |
| **#3** | `pyodbc` 5.1.0 não compila em CPython 3.13 | Bump para `pyodbc==5.2.0` (tem wheel `cp313-cp313-manylinux`). Vide Decisão #14. |
| **#4** | `azd hooks` (preprovision/postprovision) **NÃO leem env vars do shell** | Eles leem só do `.azure/<env>/.env`. Use `azd env set` antes de provision para garantir hooks veem o que precisam. Decisão #15. |
| **#5** | Smoke test 30s pega container em state `Activating` | Cold start de gunicorn + token MI pode levar 1-3min. Use retry loop, não single-shot. Decisão #15. |
| **#6** | "Backend MI tem acesso ao banco" ≠ least privilege real | Least privilege real é **9 grants object-level scoped a tabelas específicas**, verificável via `sys.database_permissions`. Decisão #16. |
| **#7** | Endpoints deprecated devem retornar **HTTP 410 Gone** + `Link: rel="successor-version"` (RFC 8288) | É o padrão profissional. Não use 404 (silencioso) nem 301 (mantém keep-alive). Decisão #16. |
| **#8** | `git ls-files` ignora arquivos do `.gitignore` raiz mesmo em monorepos | Auditar `git ls-files --others --ignored --exclude-standard` antes de extração de monorepo. Decisão #13. |
| **#9** | Cognitive Services soft-deleted bloqueiam re-provisão por 90 dias | Use `RESTORE_COGNITIVE_SERVICES=true` no workflow OU sempre `azd down --purge`. Decisão #11. |
| **#10** | Bicep AVM modules têm breaking changes não documentados | `bicep build` antes de PR (CodeRabbit não roda). Decisão #9. |

### Surpresas first-run no laptop (Sessões 9.1-9.2)

Estas surpresas só aparecem quando você roda `azd up` **na primeira vez no seu laptop** (vs no CI do GitHub Actions). Foram documentadas pelo professor durante a primeira execução real fora do CI.

| # | Surpresa | Lição |
|---|----------|-------|
| **#11** | `prepdocs.ps1` e `sql_init.ps1` com acentos UTF-8 quebram em Windows PowerShell 5 | `pwsh` (PS7) não está no PATH por default no Windows; `azd` faz fallback pra `powershell.exe` (PS5). PS5 lê UTF-8 sem BOM em locale pt-BR como cp1252 → "string sem terminador" em palavras com `é`, `ã`, `ç`. **Fix permanente:** scripts pwsh do template já estão em ASCII puro. Lição: se editar scripts, mantenha ASCII ou explicite encoding. |
| **#12** | `sql_init.py` REVOKE falha em first-run | `ALTER ROLE db_datareader DROP MEMBER [backend-mi]` falha com 15151 porque o user MI ainda não foi criado no banco em first-run. **Fix permanente:** guard `IF DATABASE_PRINCIPAL_ID('{name}') IS NOT NULL` antes do ALTER ROLE. Lição: scripts de DB migration idempotentes precisam testar TANTO first-run QUANTO re-run. |
| **#13** | `sql_init.py` GRANT antes de schema migration falha | Ordem original `CREATE USER + GRANT → migrations` falhava com 15151 ("Cannot find object tbl_tenants"). **Fix permanente:** `CREATE TABLE` ANTES de `CREATE USER` ANTES de `GRANT scoped`. Lição: ordering de migrations + grants é não-trivial. |
| **#14** | ODBC Driver 18 + `Authentication=ActiveDirectoryMsi` + User-Assigned MI em Linux = `HYT00 Login timeout` | O driver não obtém token AAD corretamente do IMDS quando há UMI atribuída. **NÃO é bug de network/firewall** — é bug do driver. **Fix permanente (Decisão #17):** obter token via `azure.identity.ManagedIdentityCredential(client_id=AZURE_CLIENT_ID)` e injetar via `SQL_COPT_SS_ACCESS_TOKEN` em `attrs_before` da pyodbc connection. Tickets-service .NET nunca teve o bug porque `Microsoft.Data.SqlClient` resolve UMI corretamente. |
| **#15** | ODBC Driver 18 NÃO vem por default em Windows | Sintoma: `pyodbc.InterfaceError IM002 - Driver Manager - Nome da fonte de dados não encontrada`. **Solução:** `winget install --id Microsoft.msodbcsql.18 --silent --accept-package-agreements --accept-source-agreements`. |
| **#16** | `az account set --subscription` se perde entre janelas PowerShell novas | Sintoma: comando `az` aleatoriamente retorna `ResourceGroupNotFound` mesmo quando o RG existe. **Solução:** sempre rodar `az account set --subscription <SUB_ID>` no início de cada nova sessão PowerShell. |
| **#17** | ACA Outbound Static IP precisa estar no firewall do SQL Server (não basta `AllowAllAzureIPs`) | Sintoma: mesmo com `AllowAllAzureIPs` (0.0.0.0/0.0.0.0), Container App backend dá `HYT00 Login timeout`. **Solução:** descobrir o IP estático do ACA Environment e adicionar regra explícita: `az containerapp env show --query "properties.staticIp"` → `az sql server firewall-rule create --name "ACAOutboundIP" --start-ip-address $IP --end-ip-address $IP`. **Nota:** o template já configura essa regra automaticamente em `infra/main.bicep`. |
| **#18** | Azure SQL Serverless `autoPauseDelay` causa cold-start de 30-60s | Se DB pausada, primeira request leva 30-60s para resumir. Backend Python com `Connection Timeout=30s` falhava no resume; tickets-service .NET tinha primeira request lenta. **Fix permanente (Decisão #18):** `autoPauseDelay = -1` no Bicep (DB sempre Online; trade-off ~$15-30/mês vs interrupção em demo gravada) + Connection Timeout 60s no DSN. Aluno em produção real pode reverter para 60min se aceitar o trade-off. |

### Surpresas E2E auth + UI (Sessões 9.4-9.5)

Estas surpresas só aparecem quando você faz o **primeiro login real no browser**
após `azd up`. Foram descobertas durante a sessão de 2026-05-05 que validou o
fluxo end-to-end pela primeira vez. **Todas foram automatizadas no template
v2.1.0** — você só vai ver se modificar o auth flow ou rodar com setup
parcialmente quebrado.

| # | Surpresa | Lição |
|---|----------|-------|
| **#19** | Single-app pattern (1 App Registration servindo SPA + API) crasha com `AADSTS90009: application requesting token for itself` | Microsoft bloqueia self-token. **Two-app pattern obrigatório**: Server App expõe API + Client App SPA consome. `auth_init.py` v2.1.0 cria os 2 automaticamente — não tente "simplificar" pra 1 app. |
| **#20** | Bicep do template upstream (`azure-search-openai-demo`) seta `AzureAd__Audience: api://{clientAppId}` no tickets-service. Tokens emitidos com `aud=api://{serverAppId}` (correto) falham validação | Bug do template upstream. **Fix permanente:** `tickets-service` Bicep usa `serverAppId` no audience (Decisão #20). |
| **#21** | URL do tickets-service embarcada no bundle Vite via `VITE_API_TICKETS_URL` (build-time injection). Esquecer de exportar antes de `npm run build` = bundle com path relativo = backend retorna 410 Gone | Anti-pattern build-time pra config de env. **Fix permanente (Decisão #19):** backend expõe `ticketsApiBase` em runtime via `/auth_setup`. Mesmo bundle serve qualquer environment. |
| **#22** | MSAL.js `loginPopup` retorna `AADSTS650056: Misconfigured application` quando Client App não declara `Microsoft Graph` permissions (User.Read, openid, profile, email, offline_access) | OIDC scopes implícitos exigem Graph perms registradas. **Fix permanente:** `auth_init.py` v2.1.0 declara essas 5 perms no Client App + admin consent automático. |
| **#23** | Optional Claim com Directory Extension não aparece em **access token** se `Server App.api.requestedAccessTokenVersion != 2` (default null = v1) | v1 access tokens não emitem extension claims via optional claim mechanism. **Fix permanente:** `auth_init.py` v2.1.0 seta `accessTokenAcceptedVersion=2` no Server App. |
| **#24** | Token v2 emite audience como GUID puro (`{serverAppId}`), não `api://{serverAppId}` (v1 format). Tickets-service .NET configurado pra v1 rejeita com `IDX10214: Audience validation failed` | Format de `aud` muda entre v1 e v2. **Fix permanente (Decisão #20):** Bicep param `tokenAudienceFormat` com default `v2` → audience = GUID puro. Aceita `v1`/`both` se aluno quiser. |
| **#25** | Claim `app_tenant_id` chega no JWT em **3 formas diferentes** dependendo do tier de licença AAD: forma curta (`app_tenant_id`, requer Claims Mapping Policy P1+), forma longa em ID token (`extension_<serverAppIdNoHyphens>_app_tenant_id`), forma curta em access token v2 (`extn.app_tenant_id`) | Free tier AAD (Decisão Q1B preservada). **Fix permanente (Decisão #21):** `TenantContext.cs` (.NET) e `_resolve_tenant_id` (Python) aceitam as 3 formas. Aluno em qualquer tier funciona. |
| **#26** | Alpine .NET image (`mcr.microsoft.com/dotnet/aspnet:10.0-alpine`) tem `Globalization Invariant Mode` por default. `Microsoft.Data.SqlClient.SqlConnection.TryOpen` lança `NotSupportedException` sem ICU instalado | Imagem MS Alpine é minimal — falta ICU. **Fix permanente:** `Dockerfile` do tickets-service `apk add icu-libs icu-data-full` + `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false`. |
| **#27** | `Microsoft.Data.SqlClient` v6+ separou auth providers AAD (`ActiveDirectoryManagedIdentity` etc.) para package opcional `Microsoft.Data.SqlClient.Extensions.Azure`. Sem ele, `SqlConnection.OpenAsync` lança `ArgumentException: Cannot find an authentication provider for 'ActiveDirectoryManagedIdentity'` | Breaking change não-óbvio em SqlClient. **Fix permanente (Decisão #22):** `SqlConnectionFactory.cs` faz token explicit injection via `Azure.Identity` (paridade com Decisão #17 do backend Python). Bypassa auth provider system inteiramente, funciona em qualquer versão SqlClient. |
| **#28** | MSAL.js `loginPopup` engole erros silenciosamente quando popup é bloqueado pelo browser. User clica botão e nada acontece — erro só aparece no console F12 | Browser default em incognito bloqueia popups. **Fix permanente (Decisão #23):** trocar `loginPopup` → `loginRedirect` (navega janela inteira para AAD, robusto contra popup blockers). `LoginGate` componente bloqueante substitui "click no botão e talvez funcione". |
| **#29** | `loginRedirect` quebra silenciosamente se a rota `/redirect` retornar página em branco. Browser volta de Microsoft com `#code=...` no hash, mas React não monta → `handleRedirectPromise()` nunca processa o token | Template original assumia popup-only. **Fix permanente:** rota `/redirect` no backend serve `index.html` (não blank string). `index.tsx` chama `handleRedirectPromise()` no boot do MSAL e redireciona pra `/` após processar hash. |

> **Total cravado v2.1.0:** 29 surpresas → 29 lições aprendidas → 100% automatizadas no template. Você vai encontrar **MUITO MENOS** problemas que o professor encontrou. Custo pedagógico desta evolução: ~16h de debugging E2E real (Sessões 9.4-9.5) + cleanup final (Sessão 9.6 noite).
>
> **Estado canônico:** tag git [`helpsphere-v2.1.0`](https://github.com/tftec-guilherme/apex-helpsphere/releases/tag/helpsphere-v2.1.0). Use `git checkout helpsphere-v2.1.0` se quiser começar de um ponto exato reproduzível.

---

## ⚙️ Setup avançado (CI / GitHub Actions)

### Permissão Microsoft Graph para `auth_init.py` em CI

O workflow `.github/workflows/setup-aad.yml` (e o `azure-dev.yml` que chama `azd provision` → preprovision hook → `auth_init.py`) cria App Registrations no AAD via Microsoft Graph API. Pra isso funcionar em CI, o **federated SP** que GH Actions usa precisa de:

- **API permission Microsoft Graph `Application.ReadWrite.All`** (Application type, NÃO Delegated)
- **Admin consent** dessa permission

Configure 1 vez (depois de `azd pipeline config` criar o federated SP):

```bash
# Pegue o SP_APP_ID do federated SP (printado por azd pipeline config)
SP_APP_ID="<from-azd-pipeline-config>"

# Adiciona permission
az ad app permission add --id $SP_APP_ID \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9=Role

# Admin consent
az ad app permission admin-consent --id $SP_APP_ID
```

Sem isso, CI falha com `Insufficient privileges` ao tentar criar App Registrations.

---

## 🆘 Suporte

- **Dúvidas gerais:** fórum da disciplina no AVA
- **Bugs no template:** abra issue no [`tftec-guilherme/apex-helpsphere`](https://github.com/tftec-guilherme/apex-helpsphere/issues)
- **Defesa arquitetural** (audiência sênior): leia `DECISION-LOG.md` — 23 decisões cravadas com contexto, alternativas avaliadas e anti-padrões rejeitados

**Prof. Guilherme Campos** · Pós-Graduação Avançada de Cloud com Azure

---

> **Lembrete final:** `azd down --purge` ao final de cada sessão. Sempre.
