# APPENDIX — 40 Surpresas pedagógicas

> Lições aprendidas que **o template Microsoft `azure-search-openai-demo` não documenta**. Todas estão **mitigadas no template SaaS-only** — você vai encontrar **MUITO MENOS** problemas que o professor encontrou. Custo pedagógico cumulativo: ~16h de debugging E2E real (Sessões 9.4-9.5) + cleanup final (Sessão 9.6) + maratona pivot SaaS local 12+h (Sessão 2026-05-06) + first-laptop multi-Python + smoke `azd up` real + cleanup pós-pivot (Sessão 2026-05-07).
>
> Defesa arquitetural completa de cada item em [`DECISION-LOG.md`](./DECISION-LOG.md).

---

## Surpresas operacionais (Sessões 1-5)

| # | Surpresa | Lição |
|---|----------|-------|
| **#1** | Free Trial USD 200 não roda Azure OpenAI | PAYG é mandatório. Não tente Free Trial — vai bloquear na quota. |
| **#2** | `eastus2` sem capacidade SQL/Search em Q2-2026 | Use **`westus3`** ou **`brazilsouth`** para HelpSphere. East US 2 só pra Foundry Hub depois. |
| **#3** | `pyodbc` 5.1.0 não compila em CPython 3.13 | Bump para `pyodbc==5.2.0` (tem wheel `cp313-cp313-manylinux`). Vide Decisão #14. |
| **#4** | `azd hooks` (preprovision/postprovision) **não leem env vars do shell** | Eles leem só do `.azure/<env>/.env`. Use `azd env set` antes de provision para garantir hooks veem o que precisam. Decisão #15. |
| **#5** | Smoke test 30s pega container em state `Activating` | Cold start de gunicorn + token MI pode levar 1-3min. Use retry loop, não single-shot. Decisão #15. |
| **#6** | "Backend MI tem acesso ao banco" ≠ least privilege real | Least privilege real é **9 grants object-level scoped a tabelas específicas**, verificável via `sys.database_permissions`. Decisão #16. |
| **#7** | Endpoints deprecated devem retornar **HTTP 410 Gone** + `Link: rel="successor-version"` (RFC 8288) | É o padrão profissional. Não use 404 (silencioso) nem 301 (mantém keep-alive). Decisão #16. |
| **#8** | `git ls-files` ignora arquivos do `.gitignore` raiz mesmo em monorepos | Auditar `git ls-files --others --ignored --exclude-standard` antes de extração de monorepo. Decisão #13. |
| **#9** | Cognitive Services soft-deleted bloqueiam re-provisão por 90 dias | Use `RESTORE_COGNITIVE_SERVICES=true` no workflow OU sempre `azd down --purge`. Decisão #11. |
| **#10** | Bicep AVM modules têm breaking changes não documentados | `bicep build` antes de PR (CodeRabbit não roda). Decisão #9. |

---

## Surpresas first-run no laptop (Sessões 9.1-9.2)

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

---

## Surpresas E2E auth + UI (Sessões 9.4-9.5)

Estas surpresas só aparecem quando você faz o **primeiro login real no browser** após `azd up`. Foram descobertas durante a sessão de 2026-05-05 que validou o fluxo end-to-end pela primeira vez. **Todas foram automatizadas no template v2.1.0** — você só vai ver se modificar o auth flow ou rodar com setup parcialmente quebrado.

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

---

---

## Surpresas first-bootstrap em conta `live.com` / Visual Studio Enterprise (Sessão 9.7)

Estas surpresas só aparecem quando você é o **primeiro a rodar o bootstrap** do template em uma conta pessoal Microsoft (`live.com#email@dominio.com`) com subscription Visual Studio Enterprise. Documentadas durante recording da disciplina em 2026-05-06 — todas têm fix automático no preflight do workflow `5. Deploy`.

| # | Surpresa | Lição |
|---|----------|-------|
| **#30** | Bootstrap script em Bash não roda em PowerShell. Sintaxe `VAR="valor"`, `$()` substitution, `cat <<EOF`, `> /dev/null` e `jq` são Bash-only — PS retorna `not recognized as a name of a cmdlet` | Toda doc bootstrap precisa de **2 versões: PowerShell + Bash**. PS usa `$VAR = "valor"`, `(comando)` em paréntese, `@"..."@` here-string, `Out-Null` em vez de `/dev/null`, `ConvertFrom-Json` em vez de `jq`. **Fix permanente:** PARA-O-ALUNO Step 3 tem ambas versões lado-a-lado. |
| **#31** | Conta `live.com` Owner tem ABAC condition que **bloqueia atribuir Owner / User Access Administrator / RBAC Administrator** (3 GUIDs específicos). Comando `az role assignment create --role Owner` retorna `AuthorizationFailed: ABAC condition that is not fulfilled` | Microsoft adicionou ABAC default em subscriptions Visual Studio Enterprise para **prevenir self-elevation acidental**. Owner/UAA/RBAC Admin ficam restritos ao próprio user. **Fix permanente:** scripts e workflows usam `Contributor` (que ABAC permite) em vez de Owner. Com Contributor, role assignments dentro do template falham — solução é dar `User Access Administrator` no escopo do RG específico, OU rodar em sub TFTEC sem ABAC. |
| **#32** | App Registration criada sem Service Principal companion (404 ao referenciar). `az ad app create` cria APENAS a App Reg; o SP precisa ser criado separadamente via `az ad sp create --id <appId>`. Se script falhar entre os 2 passos, App fica órfã | Bug não-óbvio. Pior cenário: script falha no `sp create` (rede), próxima execução re-encontra a App existente, assume que SP existe, quebra com 404 ao tentar acessar SP. **Fix permanente (preflight Check 6):** workflow detecta App Regs `helpsphere`/`helpsphere-client` sem SP e **AUTO-CRIA** o SP companion via `az ad sp create`. Aluno não vê o erro. |
| **#33** | Cache de auth do `az` CLI e do `azd` CLI **vivem separados** — `az login` em um tenant não muda o cache MSAL do `azd`. `az account show` retorna tenant correto, mas `azd provision` falha com "fetching current principal id" | `azd` usa MSAL próprio (não Azure CLI por default). **Fix:** `$env:AZD_AUTH_USE_AZCLI_AUTH = "true"` força `azd` reusar token do `az`. **Mais seguro:** sempre rodar `azd auth login --tenant-id <ID>` explicitamente no início. |
| **#34** | SP federated criado mas SEM role assignment na subscription. `azd provision` falha com `failed getting subscription` antes de qualquer Bicep. Causa: comando anterior `az role assignment create --role Owner` falhou silenciosamente (ABAC #31), script não verificou exit code | Antes de `azd provision`, **SP precisa de pelo menos `Contributor` na sub**. **Fix permanente (preflight Check 3):** workflow valida e falha cedo com mensagem `az role assignment create --assignee <SP> --role Contributor --scope /subscriptions/<SUB>`. |
| **#35** | Variável `AZURE_SQL_AAD_ADMIN_GROUP_OBJECT_ID` aponta para uma Entra group que **não existe no tenant atual** — só foi inventada num run anterior em outro tenant. Bicep do template usa essa group como AAD admin do Azure SQL Server. Sem ela existir, deploy quebra ou ninguém loga no SQL via Entra | Group precisa **EXISTIR no tenant onde o lab roda**, não ser ID herdado de outra subscription. **Fix permanente (preflight Check 5):** valida que group com Object ID configurado existe; se não, falha com comando `az ad group create` exato. **Documentação:** PARA-O-ALUNO Step 5.1 cobre o fix reativo (criar group + atualizar var) quando o preflight detecta a falta. |

---

## Surpresas first-laptop com Python multi-versão (Sessão 2026-05-07)

Estas surpresas aparecem quando você roda o preflight pela **primeira vez** num laptop que **já tinha Python instalado** antes (ex: 3.14 default no PATH) e/ou nunca habilitou Long Path no Windows. Documentadas durante o smoke do pivot SaaS local — todas têm fix automático no preflight ou comando admin exato.

| # | Surpresa | Lição |
|---|----------|-------|
| **#36** | Long Path Windows (`HKLM:\...\FileSystem\LongPathsEnabled`) não vem habilitado por default em Windows 11 Enterprise. Preflight Check 2 falha com `LongPathsEnabled=0` | Path > 260 chars quebra Docker build em containers Linux que clonam node_modules profundos. **Fix manual (uma vez):** PowerShell elevado → `Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -Value 1`. Vale para processos novos imediatamente — não precisa reboot. **Documentação:** PARA-O-ALUNO §2 troubleshooting tem o comando copy-paste. |
| **#37** | `python --version` resolve para versão antiga do PATH (ex: `C:\Python314\python.exe`) mesmo quando 3.13 está instalado em `%LOCALAPPDATA%\Programs\Python\Python313\`. Preflight original Check 7 falhava porque só consultava `python` direto, ignorando o `py` launcher | System PATH sempre vence User PATH; instalações user-scope do winget ficam atrás. **Fix permanente (preflight v2):** Check 7 aceita `python --version=3.13.x` **OU** `py -3.13 --version` funcional. Aluno com Python 3.14+ default no PATH passa sem precisar mexer em PATH ou desinstalar. **Custo:** ~10 linhas no preflight, valor: zero PATH disruption no laptop do aluno. |
| **#38** | Pivot SaaS local-first 2026-05-06 introduziu master flag `deployIaStack=false` no Bicep mas **não propagou guards a 10 references** dos outputs de `searchService`, `documentIntelligence`, `openAi` e `sqlServer` (este último com `sqlAadAdminGroupObjectId=""`). Smoke real do `azd up` falhava na fase de **Read** dos sub-deployments (`ResourceGroupNotFound` apesar do RG existir) porque ARM tentava ler `module.outputs.X` de módulos que nunca foram criados | `if (gate)` nas declarações dos `module` controla CREATE, não READ. Toda referência fora de bloco gateado precisa de **guard ternário próprio** (`gate ? mod!.outputs.X : ''`). **Fix permanente (10 edits em `infra/main.bicep`):** linhas 564, 597, 625, 634, 837 (appEnvVariables) + 1799, 1800, 1826, 1831, 1835 (file-level outputs) — todas wrapped com `deployIaStack ?` ou `useSqlServer && !empty(sqlAadAdminGroupObjectId) ?`. **TODO defensivo (não bloqueia smoke atual com `usePrivateEndpoint=false`):** linhas 879, 1655, 1668, 1705 — adicionar guards quando aluno habilitar private endpoints. |
| **#39** | Bicep params `openAiLocation` e `documentIntelligenceResourceGroupLocation` declarados **sem default** mesmo quando `deployIaStack=false`. `azd provision --preview` falhava com `2 required inputs are missing`. Aluno precisaria descobrir que tem que setar `AZURE_OPENAI_LOCATION` e `AZURE_DOCUMENTINTELLIGENCE_LOCATION` mesmo NÃO usando IA | Pivot deveria ter feito esses params opcionais. Quando módulo é gateado (`deployIaStack=false`), seus inputs ficam dead weight mas Bicep ainda exige. **Fix permanente:** `infra/main.bicep` linha 211 default `= 'eastus'` em `openAiLocation` + linha 231 default `= 'eastus'` em `documentIntelligenceResourceGroupLocation` + `infra/main.parameters.json` envSubst `${VAR=eastus}` em ambos. Aluno não precisa setar essas vars — vão ficar com `eastus` default mas são unused (módulos não deployam). |
| **#40** | SQL Server tem gate `useSqlServer && !empty(sqlAadAdminGroupObjectId)` — sem AAD group criado, SQL não deploya e tickets-service .NET retorna 500 em runtime. Setup do AAD group **não estava documentado** em PARA-O-ALUNO antes do step `azd up` | Boa prática Azure: SQL Server moderno usa **AAD admin** (group, não user direto) — não SQL auth. Bicep do template requer 1 group dedicado. **Fix permanente:** PARA-O-ALUNO ganhou novo §5 "Criar AAD group SQL admin" com 4 comandos (cria group `helpsphere-sql-admins`, add aluno como member, seta `AZURE_SQL_AAD_ADMIN_GROUP_OBJECT_ID`). Reordenou §5→§6 (azd up) e §6→§7 (abrir no navegador). Quick Start passou de 6 para 7 passos · ~17 min. |

---

## Política de revisão

Quando uma nova surpresa for descoberta em produção:

1. Documentar aqui com sintoma + causa raiz + fix permanente
2. Cravar Decisão correspondente em `DECISION-LOG.md` se for arquitetural
3. Bumpar contador no [`PARA-O-ALUNO.md`](./PARA-O-ALUNO.md) e [`README.md`](./README.md)
4. Tag de release nova (semver)

> **Total atual:** 40 surpresas → 40 fixes permanentes no template (29 do v2.1.0 + 6 da Sessão 9.7 first-bootstrap conta pessoal + 2 da Sessão 2026-05-07 first-laptop multi-Python + 3 da Sessão 2026-05-07 smoke `azd up` real com pivot SaaS).
>
> **Auto-fix em preflight ou no template (zero touch pro aluno):** 4 das 11 novas pós-v2.1.0 — #32 (App Reg sem SP, Check 6), #37 (Python via py launcher, Check 7 v2), #38 (Bicep guards refs vazadas), #39 (Bicep IA location defaults). As outras 7 precisam ação manual com comando exato fornecido (#30 PS vs Bash, #31 ABAC, #33 azd cache, #34 SP sem role, #35 AAD group ausente, #36 Long Path, #40 AAD group SQL admin — agora documentado em PARA-O-ALUNO §5).
