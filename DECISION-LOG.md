# DECISION-LOG — HelpSphere Template

> Documenta as decisões arquiteturais que levaram à escolha do template-base e às customizações aplicadas. Audiência: arquiteto sênior auditando a defesa técnica da disciplina.
>
> **Story:** [06.5a — HelpSphere Template (REUSE fork Microsoft)](../../../../docs/stories/06.5a.helpsphere-template.md)
> **Version-anchor:** Q2-2026
> **Última atualização:** 2026-04-27

---

## Decisão #1 — Template-base escolhido

### Decisão

**Forked from:** `Azure-Samples/azure-search-openai-demo`
**Commit SHA:** `95ce0c9484b338b3819914d0c1a1fa8d19a3ff9b`
**Date of fork:** 2026-04-27
**License original:** MIT (mantida)

### Por que esse template

Avaliamos 4 candidatos em spike inicial (~3h):

| Candidato | Stars | Last push | Stack | Veredicto |
|---|---|---|---|---|
| **`azure-search-openai-demo`** ⭐ | 7.640 | 2026-04-27 (push diário) | Python + TS frontend + Bicep + azd | **Escolhido** |
| `contoso-chat` | 759 | 2025-10-03 (~7 meses) | Bicep + Python + Prompty + Foundry | Rejeitado: WARNING preview features no README ⚠️ + manutenção esfriando |
| `azure-search-openai-javascript` | 318 | 2025-10-11 (~6 meses) | TypeScript + LangChain JS + Bicep + azd | Rejeitado: comunidade ~24× menor + manutenção esfriando |
| Build do zero | — | — | livre | Rejeitado: 75-135h vs 12-15h com fork (course-correction master 2026-04-27) |

### 4 razões fundamentais (para defesa em comitê arquitetural)

1. **Manutenção ativa diária** — push em 2026-04-27 (ontem). Para uma disciplina que fica anos no ar, escolher template estável = mitigação de risco de obsolescência.
2. **Padrão "ouro" Microsoft** — 7.640 stars + 4 ports oficiais (Python aqui, JS, .NET, Java) significa que o time MS está investido. Bugs corrigidos em dias, não meses.
3. **Production-pattern visível** já embedado: Bicep modular, Managed Identity, App Insights, Entra login, citation rendering, performance tracing. Audiência sênior reconhece os padrões em 30s de leitura.
4. **Stack Python alinha com 06.5b** — FastMCP é Python-first. Coerência interna da disciplina (HelpSphere SaaS Python ↔ MCP Server Python).

### Trade-off aceito

❌ **Descontinuidade da stack Node.js da D04.** Aluno que veio da D04 (Function App Node.js + React+Vite+TS+Tailwind) encontra agora Python backend.

✅ **Mitigação:** Python é a stack canônica de IA na Azure em 2026 (Foundry SDK Python-first, FastMCP Python, MS Entra exemplos OAuth são majority Python). Para arquiteto sênior, essa transição "engenheiro full-stack → engenheiro de IA" é natural na carreira. Frontend continua TypeScript (template MS já entrega TS frontend), então não é descontinuidade total.

---

## Decisão #2 — Estratégia de vendoring

### Decisão (CONFIRMADA pelo professor em 2026-05-01)

**Vendoring SUBSET SELECTIVO** — copiar do template MS apenas as pastas/arquivos estritamente necessários para azd up funcional + customização HelpSphere. NÃO vendorar conteúdo de demo, eval framework, multimodal/speech opcionais ou load test.

### Por que subset selectivo (em vez de full)

| Estratégia | Pro | Contra | Veredicto |
|---|---|---|---|
| Vendoring full (~80MB) | Captura tudo de uma vez. Rollback = `git revert`. | Aluno + auditor sênior leem `git log` e veem "75% do commit é dump MS que removemos no commit seguinte" — fica feio. Repo cresce permanentemente. | ❌ |
| **Subset selectivo (~15-25MB)** ✅ | Commit inicial defensável. CHANGES.md lista exatamente o que foi mantido e por quê. Remoções da Decisão #3 já mapeadas — converter "remover depois" em "não vendorar agora" é zero esforço extra. | Risco baixo de quebrar dep interna (mitigado: rodar `azd provision --preview` no smoke da Sessão 4). | ✅ |
| Fork remoto MS | Mantém histórico upstream | Aluno clona 2 repos. Customizações fora do azure-retail. | ❌ |
| Git submodule | Parcial — mantém upstream linkado | Aluno precisa entender submodules. Complexidade pedagógica desnecessária. | ❌ |

### Conteúdo a vendorar (whitelist explícita)

| Path do template MS | Razão |
|---|---|
| `app/` | Código aplicação (backend Python + frontend TS) — base que vamos customizar |
| `infra/` | Bicep modular — defesa arquitetural Microsoft canônica |
| `azure.yaml` | Orquestração azd — necessário para `azd up` |
| `.github/workflows/` | CI testado MS — preservar |
| `tests/` | Framework pytest base — vamos adicionar nossos testes |
| `pyproject.toml`, `requirements*.txt` | Dependências travadas — anti-obsolescência |
| `LICENSE` | MIT — atribuição obrigatória |
| `SECURITY.md`, `CONTRIBUTING.md` | Boas práticas MS — preservar |
| `.gitignore` | Padrão Python+TS MS — base |

### Conteúdo a NÃO vendorar (não copiar do clone temp)

Ver Decisão #3 abaixo (lista única consolidada).

---

## Decisão #3 — Componentes a NÃO vendorar (CONFIRMADA pela Decisão #2)

Como Decisão #2 = subset selectivo, esses componentes simplesmente **não são copiados** do clone temp para `helpsphere/`. Não há "remover depois" — eles nunca chegam ao nosso commit.

| Componente do template | Razão para excluir do vendoring |
|---|---|
| `.git/` | Histórico do template — preservaríamos via SHA documentado no README, não via git history embarcado |
| `.azdo/` | Usamos GitHub Actions, não Azure DevOps |
| `evals/` (eval framework) | Lab Avançado da D06 cobre isso separadamente — duplicaria escopo |
| `data/` (Zava demo dataset) | Não usamos cenário Zava (nosso é Apex/HelpSphere) — substituiremos por seed HelpSphere em sessão futura |
| Modules `multimodal_*` em `app/backend/` (se isolados) | Lab Intermediário tem Vision como sub-feature dedicada — não precisa no template-base |
| Modules `speech_*` em `app/backend/` (se isolados) | Lab Final tem Speech como subsection — não precisa no template-base |
| `locustfile.py` (load test) | Fora do escopo da 06.5a (production-grade visível ≠ load test) |
| `README.md` (do template) | Já temos nosso próprio README.md com defesa arquitetural HelpSphere |
| `.devcontainer/`, `docs/` (do template, se existirem) | Não estritamente necessários para `azd up` — adicionados sob demanda em sessão futura se necessário |

**Nota operacional:** se durante o smoke `azd provision --preview` (Sessão 4) algum módulo do `app/` referenciar deps que removemos, reavaliar (poderia precisar trazer modules opcionais). Documentar em CHANGES.md.

**Manter explicitamente:**
- Estrutura `app/` (código aplicação)
- `infra/` (Bicep modular — vamos customizar, não deletar)
- `azure.yaml` (orquestração azd — vamos customizar tema)
- `.github/` (CI já testado MS)
- `tests/` (framework pytest — vamos adicionar nossos testes)
- `pyproject.toml`, `requirements*.txt` (dependências travadas)
- `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md` (atribuição MS preservada)

---

## Decisão #4 — Componentes a adicionar (proposta — sessões futuras)

| Componente | Origem | Sessão |
|---|---|---|
| Schema SQL HelpSphere (3 tabelas: tenants, tickets, comments) | Story 06.5a AC | Sessão 2 |
| 50 tickets seed em pt-BR | Story 06.5a AC | Sessão 2 |
| 5 endpoints REST adaptados (CRUD tickets + comments + suggest stub) | Story 06.5a AC | Sessão 2 |
| 2 páginas frontend (`/tickets` e `/tickets/{id}`) | Story 06.5a AC | Sessão 3 |
| 3-5 PNGs mock para Vision OCR | Story 06.5a AC | Sessão 3 |
| README defesa arquitetural | Story 06.5a AC | Sessão 3 |
| CHANGES.md (diff vs upstream) | Story 06.5a AC | Sessão 3 |

---

## Decisão #5 — Stack runtime + auth + multi-tenancy + admin + seeds (Sessão 2.3)

### Decisão consolidada (CONFIRMADA pelo professor em 2026-05-01)

**Premissa pedagógica:** Disciplina 06 é pós-graduação cloud avançada — alunos são profissionais sênior. Atalhos didáticos (header não-validado, endpoints públicos, user pessoal como admin) foram **explicitamente rejeitados pelo professor**. Default sempre = pattern production-grade defensável em comitê C-level.

| Aspecto | Decisão production-grade | Anti-padrão rejeitado |
|---|---|---|
| **Deployment target** | **Container Apps (ACA)** | App Service Linux (ODBC instalável só via SiteExtension/startup script frágil) |
| **Tenant isolation** | **JWT claim customizada `app_tenant_id`** (validada via Entra) | Header arbitrário `X-Tenant-Id` (forjável) |
| **Auth dos endpoints** | **`@authenticated` decorator obrigatório em TODOS `/api/tickets/*`**. `AZURE_USE_AUTHENTICATION=true` no default | Endpoints públicos com flag opcional para abrir |
| **SQL AAD admin** | **Entra Group** `aad-helpsphere-sql-admins` | User pessoal azd-logged (turnover-broken, sem audit-friendly) |
| **Seeds em `azd up`** | **Automático com `AZURE_LOAD_SEED_DATA=true` flag** ✅ | Manual via comando separado |

### Por que cada uma

1. **Container Apps (ACA):** pattern Microsoft canônico 2026 para apps cloud-native. Driver MS ODBC 18 instalado limpo via Dockerfile (1 linha `apt`). KEDA scale-to-zero para FinOps. Coerência com Lab Avançado da D06 que já usa ACA. App Service ficou como destino de migração lift-and-shift, não green-field architecture defensável em 2026.
2. **JWT claim:** header arbitrário pode ser forjado por qualquer atacante (incluindo o próprio aluno copiando curl). JWT valida assinatura Entra, audience, expiration. Claim `app_tenant_id` vem de App Roles, custom claims (extension attribute), ou group membership Entra → mapeada no token. Isolation REAL.
3. **`@authenticated` sempre:** segurança não é opcional numa pós-graduação cloud. Endpoint exposto sem auth é incidente esperando acontecer. `AZURE_USE_AUTHENTICATION=true` no default; aluno aprende integração Entra como ponto de partida, não como exercício opcional.
4. **Entra Group como SQL admin:** turnover-resilient (não amarra ao indivíduo), audit-friendly (logs mostram membership do grupo, não nome), padrão MS Cloud Adoption Framework. Adicionar/remover admin = mudança de membership, não T-SQL.
5. **Seeds automático:** `azd up` entrega ambiente populado em < 15min — aluno vê HelpSphere funcionando logo. Quem quiser ambiente vazio: `azd env set AZURE_LOAD_SEED_DATA false`.

### Implicações implementação

- `requirements.in` ganha `aioodbc>=0.5.0` + `pyodbc>=5.1.0`
- `Dockerfile` (Container Apps) ganha `RUN apt-get install -y msodbcsql18 unixodbc-dev`
- Repository pattern como **classes injetadas via `current_app.config`** (espelha BlobManager/SearchClient)
- Bicep adota AVM SQL: `br/public:avm/res/sql/server:0.10.0` + DB Serverless GP_S_Gen5_2
- `scripts/sql_init.py` rodado como `azd postprovision` hook: cria USER FROM EXTERNAL PROVIDER para a MI do backend, GRANT db_datareader+db_datawriter, executa `data/migrations/001_initial_schema.sql`, executa seeds se flag true
- `azure.yaml` ganha hook `postprovision` apontando para `scripts/sql_init.py`

---

## Decisão #6 — Design system frontend (Sessão 3)

### Decisão (CONFIRMADA implícita ao manter o stack do template MS)

**Preservar Fluent UI v9 + CSS Modules** do template upstream. **Adicionar paleta Apex** apenas via **CSS variables** (`--apex-*` tokens em `:root`). **Não introduzir** Tailwind, styled-components, Emotion, ou outro framework adicional.

### Por que (defesa para arquiteto sênior)

| Opção considerada | Veredicto |
|---|---|
| **Fluent UI v9 + CSS variables Apex** ✅ | Preserva pattern Microsoft canônico; tokens Apex coexistem com `webLightTheme`; rebase futuro vs upstream MS template é trivial (CSS variables são aditivas). |
| Tailwind + remover Fluent | Aluno+arquiteto enxergariam re-skin completo — perde-se o "este é o template MS oficial" em 30s de leitura. Rebase futuro vs upstream vira esforço grande. |
| Migrar para outro design system (Radix, MUI) | Mesma objeção. Adiciona dep tree pesada. |
| Substituir CSS Modules por outro padrão | Quebra coerência com o resto do `app/frontend/`. Sem ganho. |

**Premissa editorial vinculante:** o auditor sênior precisa **reconhecer Fluent UI** ao olhar para o app — é parte do "production-pattern Microsoft real" que defende a Story 06.5a.

### Implementação

- `src/index.css` ganhou bloco `:root { --apex-* }` (paleta + radius + shadow tokens)
- Componentes HelpSphere usam `var(--apex-*)` em CSS Modules; componentes Fluent (Button, Input, Dropdown, Skeleton, MessageBar) continuam consumindo `webLightTheme`
- Logo `HelpSphereLogo.tsx` é SVG inline com `currentColor` (herda cor do header)
- `react-helmet-async` (já dep do upstream) usado para `<title>` dinâmico via i18n
- Strings adicionadas no bloco `helpsphere.*` em `locales/ptBR/translation.json` e `en/translation.json`; bloco RAG/Chat upstream **preservado** para a página `/` (Chat) continuar funcional

---

## Decisão #7 — Roteamento e separação de páginas (Sessão 3)

### Decisão

**Adicionar 2 rotas** ao `createHashRouter` existente, **sem remover** `/` (Chat upstream):

| Rota | Pattern | Componente | Estratégia |
|---|---|---|---|
| `/` | `index: true` | `<Chat />` (upstream) | **Preservada** — vira "Assistente IA" da HelpSphere via branding i18n |
| `/tickets` | child path | `Tickets.tsx` | **Lazy-loaded** (`Component` export, igual `NoPage`) |
| `/tickets/:ticketId` | child path | `TicketDetail.tsx` | Lazy-loaded |
| `*` | catch-all | `NoPage` (upstream) | Preservada |

### Por que preservar `/` = `<Chat />`

1. **Honestidade pedagógica:** o RAG/Chat do template MS é o que o professor vai demonstrar nos Labs Intermediário/Final. Apagá-lo agora forçaria reescrever no Lab — duplicação de esforço.
2. **Defesa arquitetural:** auditor sênior abre a página inicial e vê **a mesma demo MS canônica** que ele já conhece — ganha-se credibilidade imediata.
3. **Branding via i18n é não-destrutivo:** strings RAG ("Pergunte aos seus dados", etc.) viram parte da experiência HelpSphere ("Assistente IA HelpSphere") sem código novo.

### Implicações

- `index.tsx` ganhou 2 entries `lazy: () => import(...)`
- Cada página exporta `function Component()` + `Component.displayName` (pattern do template)
- `<NavLink to="/tickets">` no header dá deep-linking nativo
- `useSearchParams` em `Tickets.tsx` permite URL deep-link de filtros/paginação

---

## Decisão #8 — Multi-tenancy do tenant_id no client (Sessão 3)

### Decisão

**Não armazenar `tenant_id` em estado client-side global.** O backend resolve isolation via JWT claim `app_tenant_id` (Decisão #5). O frontend **mostra** o tenant_id no detail do ticket apenas como **metadado read-only** (truncado para 8 caracteres + tooltip com o GUID completo).

### Por que

| Opção | Veredicto |
|---|---|
| **Tenant_id resolvido server-side via JWT, exibido read-only no client** ✅ | Frontend nunca envia `tenant_id` em request body / URL — impossível forjar. Audit-friendly: token Entra é a única fonte de verdade. |
| Storar `tenant_id` em Context client-side e enviar em todo request | Cria caminho de bypass (cliente malicioso edita o context). Dobra a superfície de ataque. |
| Permitir frontend trocar de tenant via dropdown | Para Story 06.5a (foco MVP), tenant do usuário é fixo via JWT. Multi-tenant switching fica para roadmap futuro (com auth flow específico). |

### Implementação

- `getMyTenantApi()` exposto no API client (consulta `/api/tenants/me`) — **opcional**, usado apenas se a UI precisar exibir `brand_name` legível.
- `Tickets.tsx` e `TicketDetail.tsx` **nunca** enviam `tenant_id` em requests; backend resolve.

---

## Decisão #9 — Bicep SQL Server AVM compatibility (Sessão 3.5)

### Contexto

Sessão 4 smoke `azd provision --preview` falhou com **5 erros + 1 warning + 1 erro de limit**:

| Código | Linha original | Tipo |
|---|---|---|
| BCP053 (×2) | 578, 1695 | `fullyQualifiedDomainName` não existe nos outputs do AVM `sql/server:0.10.0` |
| BCP062 (×3) | 615, 667, 723 | Cascade do BCP053 (declaração `appEnvVariables` quebrada por erro acima) |
| BCP037 (warning) | 1146 | `properties` não permitido em SQL DB sub-objeto (interface AVM = flat) |
| max-outputs | 1608 | 68 outputs (limite Bicep = 64) |

### Causa raiz

Customização HelpSphere da Sessão 2.3 introduzida pelo @dev (Dex) trouxe 3 incompatibilidades simultâneas com `br/public:avm/res/sql/server:0.10.0`:

1. **Output assumido errado:** assumiu `fullyQualifiedDomainName` no módulo — outputs reais são `name, location, resourceId, exportedSecrets, privateEndpoints, resourceGroupName, systemAssignedMIPrincipalId`.
2. **Interface DB mudou para flat:** passou `properties: { autoPauseDelay, minCapacity, maxSizeBytes }` ao DB sub-objeto, mas AVM agora aceita essas props no nível do objeto database (não dentro de `properties`).
3. **Adicionou 4 outputs `AZURE_SQL_*`** sem reduzir a herança do template MS — passou de 64 (limite Bicep para um único módulo).

### Lição aprendida (recomendação CI)

**CodeRabbit não roda `bicep build`** por default — a Sessão 2.3 passou pelo gate de pre-commit/PR sem detectar nenhum desses 5 erros.

**Recomendação:** adicionar step `bicep build infra/main.bicep` no `.github/workflows/azure-dev.yml` (ou criar workflow dedicado `bicep-validate.yml` que rode em PR). Custo: 30s por run. Benefício: bloqueia futuros bugs Bicep antes de `azd up`.

> **Backlog:** abrir issue/PR no upstream do AIOX-core ou story 06.5b adicionando esse step. Não é escopo da 06.5a.

### Patches aplicados

| Patch | O que mudou | Defesa |
|---|---|---|
| **P1, P2** | FQDN construído via `'${sqlServer!.outputs.name}${environment().suffixes.sqlServerHostname}'` (linhas 578 e 1695) | Cloud-aware (`.database.windows.net` no Public, `.usgovcloudapi.net` no Gov). Padrão MS canônico para FQDN sem depender de output do módulo. |
| **P3** | DB props (`autoPauseDelay`, `minCapacity`, `maxSizeBytes`) movidas para nível flat do objeto database (linhas 1141-1150) | Conforme `Permissible properties` listadas pelo próprio compilador no warning BCP037. |
| **P4** | Removidos 5 outputs não-usados: `AZURE_SPEECH_SERVICE_ID/LOCATION` (Sessão 3.5 não usa Speech), `AZURE_AI_PROJECT` (zero consumers), `AZURE_VPN_CONFIG_DOWNLOAD_LINK` (apenas log de error, fallback gracioso), `AZURE_CHAT_HISTORY_VERSION` (constante hardcoded) | Total: 68 → 63 outputs (margem de 1 abaixo do limite). Cada remoção validada contra `app.py`, `tests/`, `prepdocs.py`, workflows CI. |
| **P5** | Esta Decisão #9 + comentários inline em todas as linhas modificadas referenciando "Decisão #9" para audit trail | Reabertura futura (rebase upstream MS) tem rastreabilidade de **por que** o trecho diverge do template. |

### Validação

`azd provision --preview` pós-patch: ✅ Bicep compila sem erros nem warnings. Próxima falha (env vars `AZURE_DOCUMENTINTELLIGENCE_LOCATION` + `AZURE_OPENAI_LOCATION` faltando) é escopo de S4.2, não Bicep.

---

## Decisão #10 — Extração para repositório público dedicado (Sessão 4)

### Decisão

`helpsphere/` extraído de `tftec-guilherme/azure-retail` (repo monorepo privado da disciplina) para repositório público dedicado **`tftec-guilherme/apex-helpsphere`**, validado via **GitHub Actions OIDC** (não mais via `azd up` local).

### Causa raiz da extração

Sessão 4 começou com approach `azd up` local. Em sequência rápida apareceram blockers de **ambiente local** que NÃO existem no runner GitHub Actions:

1. Python 3.14 (default do user) vs Python 3.13 (Dockerfile produção): pyodbc 5.1.0 não compila local
2. PowerShell 5.1 vs pwsh 7 warnings
3. Driver msodbcsql não instalado local
4. Tempo de feedback longo (cada falha ~15-30min de output local)

Professor questionou: **por que não GitHub Actions desde o início?** Validação via Actions:
- ✅ Runner Linux limpo + controlado (Python preinstalado, az CLI atualizada)
- ✅ Mesmo path que aluno vai seguir (clone repo público + workflow)
- ✅ Audit trail no GitHub (cada deploy = run logado)
- ✅ Article II Constitution: `@devops` é EXCLUSIVE owner de CI/CD

### Por que repo público dedicado (não monorepo)

| Opção | Veredicto |
|---|---|
| Manter `helpsphere/` em `azure-retail` (monorepo privado) | ❌ Aluno teria que clonar repo privado da disciplina (não pode); workflow Actions precisaria filtrar paths; não valida real experiência do aluno |
| **Repo público dedicado `apex-helpsphere`** ✅ | ✅ Aluno faz `git clone` ou `gh repo fork` direto; workflow rola na raiz; experiência alinhada com README D06 que fala em "GitHub público com template do aluno" |
| Submodule | ❌ Complexidade pedagógica desnecessária (aluno precisa entender submodules) |

### Estratégia de extração (cópia fresca)

Subtree split rejeitado (chars Unicode em paths Windows quebram o tar). Cópia fresca via `git ls-files` + `Copy-Item`:
- ✅ 416/419 arquivos versionados copiados
- ⚠️ 3 PDFs test-data multilíngue do upstream MS (`tests/test-data/ja_*.pdf`, `ko_*.pdf`, `zh_*.pdf`) **skipados** por incompatibilidade chars Unicode em paths Windows. Não-crítico (cenário HelpSphere é pt-BR; esses eram demo RAG MS). Backlog: re-importar via clone Linux.
- ✅ `.gitignore` herdado (node_modules, .venv, __pycache__ excluídos)
- ✅ Initial commit `f1e2f0e` na branch `main`

**Audit trail completo do helpsphere ANTES da Sessão 4** permanece em `azure-retail/Disciplina_06_*/03_Aplicações/helpsphere/` (history das Sessões 1, 2.1, 2.2, 2.3, 3, 3.5). Repo público começa com snapshot Sessão 3.5.

### Backlog (Sessão futura)

- Decidir se `azure-retail/.../helpsphere/` vira **submodule** apontando pro repo público (eliminação da duplicação) OU é **deletado e linkado via README** com URL.
- Re-importar 3 PDFs multilíngue test-data via clone Linux (azure-retail).

---

## Decisão #11 — Configuração Sessão 4 GitHub Actions (region/SKU/auth)

### Decisão consolidada (Sessão 4 — 5 sub-decisões operacionais)

Configuração do smoke run via Actions exigiu 5 ajustes além das Decisões anteriores. Documentadas aqui em conjunto porque são operacionais (não arquiteturais), todas com audit trail no commit history do `apex-helpsphere`.

| # | Decisão | Motivo |
|---|---|---|
| 11.1 | **Região: `westus3`** (não `eastus2`) | eastus2 retornou `InsufficientResourcesAvailable` para AI Search + `ProvisioningDisabled` para SQL Server na sub Partner. westus3 valida como alternativa robusta (testado: gpt-4o-mini, Container Apps, AI Search, SQL Server todos disponíveis) |
| 11.2 | **`zoneRedundant: false`** explícito no SQL DB | AVM `sql/server:0.10.0` default é `null` → resolve para `true` em westus3 → sub Partner retorna `ProvisioningDisabled: Provisioning of zone redundant database/pool is not supported`. Para sub Enterprise + capacidade adequada, mudar para `true`. |
| 11.3 | **`AZURE_USE_AUTHENTICATION=false`** no smoke (default `true` em prod) | Hook `auth_init.{sh,ps1}` é interativo (cria App Registration Entra com browser consent) — quebra em runner Linux headless. Auth real validado em step manual (Lab Intermediário). Trade-off documentado: smoke não testa endpoints `/api/tickets/*` autenticados. |
| 11.4 | **`RESTORE_COGNITIVE_SERVICES=true`** | Cleanup `--no-wait` deixa Cog Services em soft-delete por 48h. Sem `restore=true`, próximo provision com mesmo nome falha com `FlagMustBeSetForRestore`. Aceito como default no `apex-helpsphere` para resiliência operacional. |
| 11.5 | **`chmod +x` em todos `.sh`** via `git update-index --chmod=+x` | Cópia fresca de `azure-retail` (Windows) não preservou bit executável. Runner Linux falhou com `Permission denied` (exit 126) no preprovision hook. Fix permanente no git stored mode (100644 → 100755) — independe de filesystem. |

### Lição pedagógica (para alunos)

Aluno em sub PAYG normal vai encontrar **mesmas 5 surpresas** ao rodar `azd up` pela primeira vez. Documentação `PARA-O-ALUNO.md` (próxima sessão) inclui troubleshooting para cada uma:
- "Sua região não tem capacidade hoje? Tente outra (lista alternativa)"
- "SQL com zoneRedundant: por que `false` em PAYG"
- "Auth: como ativar depois (script manual)"
- "Cog Services soft-delete: 48h ou purge"
- "Windows clone: `git update-index --chmod=+x scripts/*.sh` antes do primeiro `azd up`"

Esse troubleshooting é parte do que torna o template **pedagógico canônico** (não um happy-path falso).

---

## Decisão #12 — `prepdocs` guard PDF count (smoke mode)

### Contexto

Run #6 (workflow `25264966004`) provisionou TODOS os 15 recursos com sucesso em westus3, mas falhou no postprovision hook `prepdocs.sh` com:

```
File ".../prepdocslib/pdfparser.py", line 285, in crop_image_from_pdf_page
    img.save(bytes_io, format="PNG")
ValueError: cannot write empty image
```

### Causa raiz

`prepdocs.sh` roda `python prepdocs.py './data/*' --verbose`. O glob inclui:
- `data/migrations/*.sql` — não-processáveis (não disparam erro)
- `data/seed/*.sql` — idem
- `data/mocks/screenshots-mock/*.png` — **3 PNGs sintéticos** (Sessão 3 B4)

Os PNGs sintéticos do Pillow (sem header complexo) são roteados para `DocumentAnalysisParser.figure_to_image()` que tenta croppar uma "figura" e salvar como PNG via PIL — falha com "cannot write empty image".

**Por que isso aconteceu:** Decisão #3 excluiu PDFs Zava do vendoring. Template HelpSphere é entregue **sem PDFs em `data/`**. Prepdocs não tinha o que processar legitimamente, processou nossos PNGs por erro de escopo.

### Decisão

**Guard "skip if no PDFs" em `prepdocs.{sh,ps1}`:**

```sh
PDF_COUNT=$(find ./data -name "*.pdf" -type f 2>/dev/null | wc -l)
if [ "$PDF_COUNT" -eq 0 ]; then
  echo "No PDFs found in ./data/ — skipping prepdocs (HelpSphere template é entregue vazio)."
  echo "Para popular o índice RAG, adicione PDFs em ./data/ e rode: ./scripts/prepdocs.sh"
  exit 0
fi
```

### Defesa pedagógica

| Aspecto | Decisão production-grade | Anti-padrão rejeitado |
|---|---|---|
| Comportamento padrão | Skip + mensagem instrutiva | Falhar `azd up` por falta de dado opcional |
| Feedback ao aluno | "Adicione PDFs e rode `./scripts/prepdocs.sh`" | Aluno fica perdido com stack trace PIL |
| Compatibilidade upstream | Mantém `prepdocs.py` intocado (só wrapper sh/ps1 mudou) | Modificar prepdocs.py = afasta de upstream MS |
| Lab Intermediário | Aluno tem PDFs próprios → guard passa direto, comportamento idêntico ao upstream | — |

### Implementação

- `scripts/prepdocs.sh`: guard 5 linhas após `USE_CLOUD_INGESTION` check, antes de `load_python_env.sh`
- `scripts/prepdocs.ps1`: guard 6 linhas equivalente
- Comentários inline citam Decisão #12 para audit trail futuro

---

## Decisão #13 — Restaurar `package.json` perdido na extração (Sessão 5, run #7 falhou)

### Contexto

Run #7 do `azure-dev.yml` no `apex-helpsphere` (commit `6f3971a`, primeiro run com todos os 7 fixes acumulados das Decisões #10/#11/#12) progrediu até o step **Deploy Application (azd deploy)** e falhou imediatamente com:

```
ERROR: failed building service 'backend': prebuild hook failed exit 254
npm error enoent /home/runner/work/apex-helpsphere/apex-helpsphere/app/frontend/package.json
```

`Validate Bicep` ✅, OIDC login ✅, **Provision Infrastructure** ✅ (15 recursos provisionados em westus3, incluindo Cog Services restored via `RESTORE_COGNITIVE_SERVICES=true`). Falha **antes** mesmo do prepdocs do run #6-bis.

### Causa raiz

`.gitignore` na raiz do repo `azure-retail` (monorepo origem da extração da Decisão #10) tem nas linhas 42-43:

```gitignore
# Node (root)
package.json
package-lock.json
```

Regra **global** intencional para evitar commit acidental de Node.js stuff dos labs de outras disciplinas (D04 `lab-avancado-dashboard` usa Node), mas se aplica recursivamente a **TODOS** os subdiretórios — incluindo `Disciplina_06_*/03_Aplicações/helpsphere/app/frontend/`.

A extração da Decisão #10 foi via `git ls-files | xargs cp` (subtree split rejeitado por chars Unicode em paths Windows). Como `package.json` e `package-lock.json` nunca estiveram trackados em `azure-retail`, **não foram listados pelo `ls-files` e não foram copiados** para o `apex-helpsphere`. Os arquivos existem em disco no checkout local, mas só na working copy.

### Decisão

**Restaurar `app/frontend/package.json` + `app/frontend/package-lock.json`** copiando do disco do `azure-retail` (working copy não-trackada) diretamente para o `apex-helpsphere`, e commitar lá. Repo `apex-helpsphere` foi vendorado do template MS upstream — `.gitignore` próprio NÃO bloqueia esses arquivos (verificado via `git check-ignore`).

### Defesa arquitetural

| Aspecto | Decisão | Anti-padrão rejeitado |
|---|---|---|
| Fonte | Working copy local `azure-retail` (já tem qualquer customização Sessão 3) | Re-fetch do upstream MS (perderia paleta Apex CSS / rotas /tickets) |
| Local fix | `.gitignore` raiz `azure-retail` permanece como está | Remover regra global → contaminação cross-disciplina |
| Long-term | Audit checklist na extração de qualquer subprojeto: `git ls-files vs ls-files --others --ignored --exclude-standard` para detectar arquivos legítimos perdidos por gitignore upstream | Checklist informal só |

### Lição pedagógica (PARA-O-ALUNO.md S4.H)

**Surpresa #8 — Quando você extrair código de um monorepo, o `.gitignore` do monorepo é uma mina terrestre invisível.** Sempre rode `git ls-files --others --ignored --exclude-standard <subdir>` antes da extração para auditar arquivos legítimos que foram silenciosamente ignorados.

### Implementação

- `cp` de 2 arquivos do `azure-retail/Disciplina_06_*/03_Aplicações/helpsphere/app/frontend/` para `apex-helpsphere/app/frontend/`
- `package.json`: 1.495 bytes (Vite + React 19.2.4 + Fluent UI v9.73.3 + MSAL + i18next, customizações Sessão 3 preservadas)
- `package-lock.json`: 239.936 bytes
- Commit em `apex-helpsphere/main` (sem `[skip ci]` desta vez — queremos disparar run #8)

---

## Decisão #14 — Bump `pyodbc` 5.1.0 → 5.2.0 (Sessão 5, run #8 falhou)

### Contexto

Run #8 do `azure-dev.yml` (commit `0b62fdd` com fix da Decisão #13) avançou bem além do #7: prebuild do frontend ✅ (`package.json` restaurado funcionou), Provision idempotente ✅ (~1min vs 11min do run #7), `azd deploy` iniciou o build do container backend. Falhou no step **Deploy Application** durante `python -m pip install -r requirements.txt` dentro do Docker:

```
src/params.cpp:250:36: error: too few arguments to function
  '_PyLong_AsByteArray(PyLongObject*, unsigned char*, size_t, int, int, int)'
ERROR: Failed building wheel for pyodbc
```

`pyodbc==5.1.0` tentou compilar do source porque não há wheel `cp313` publicado para essa versão. A compilação falhou: assinatura de `_PyLong_AsByteArray` mudou em CPython 3.13.

### Causa raiz

Dois fatores combinados:

| Fator | Origem | Defesa |
|---|---|---|
| Dockerfile usa `python:3.13-bookworm` | **Herdado do upstream MS** (`Azure-Samples/azure-search-openai-demo @ 95ce0c9`). Verificado: o Dockerfile original já é 3.13. | Não mudar — manter alinhado com upstream para facilitar rebases futuros |
| `pyodbc==5.1.0` (sem wheel cp313) | **Adicionado pela Sessão 2.3** (driver SQL Server). Upstream MS NÃO usa pyodbc (template é Search+OpenAI puro, sem SQL Server). | **Bump trivial:** pyodbc 5.2.0 (lançado 2024-10) e 5.3.0 (latest) ambos têm wheel `cp313-cp313-manylinux_2_17_x86_64`. |

`pyodbc 5.2.0` matrix de wheels (verificado via PyPI JSON API):

```
pyodbc-5.2.0-cp313-cp313-manylinux_2_17_x86_64.manylinux2014_x86_64.whl  ✓ (alvo: Debian 12 = glibc 2.36)
pyodbc-5.2.0-cp313-cp313-manylinux_2_17_aarch64.manylinux2014_aarch64.whl
pyodbc-5.2.0-cp313-cp313-musllinux_*  / win* / macos*
```

### Decisão

**Bump `pyodbc>=5.2.0` em `requirements.in` + `pyodbc==5.2.0` em `requirements.txt`** (compiled).

### Defesa arquitetural

| Aspecto | Decisão | Anti-padrão rejeitado |
|---|---|---|
| Versão escolhida | **5.2.0** (não 5.3.0 latest) | ~6 meses extras de track record vs 5.3.0; bump mínimo (1 minor); evita "pegar latest sem necessidade" |
| Pin Python | **Manter 3.13** (igual upstream) | Pin 3.12 → divergência do upstream → conflitos em rebase + sinaliza falsamente que 3.13 não funciona |
| Refactor backend | **Não** — pyodbc continua sendo o driver | Trocar por `aiomssql`/`asyncpg` seria over-engineering; pyodbc 5.2 funciona nativamente em 3.13 |

### Lição pedagógica (PARA-O-ALUNO.md S4.H — surpresa #9)

**Quando você adiciona uma nova dependência Python a um Dockerfile baseado em uma imagem Python recente, audite proativamente se a dep tem wheel para essa versão de CPython.** Sem wheel binário, o pip cai em compile do source — e source code pode não compilar em CPython recente devido a ABI changes (ex: `_PyLong_AsByteArray` em 3.13).

Comando para auditar:
```sh
curl -s https://pypi.org/pypi/<package>/json | jq '.urls[] | select(.filename | contains("cp313")) | .filename'
```

### Implementação

- `app/backend/requirements.in` linha 16: `pyodbc>=5.1.0` → `pyodbc>=5.2.0  # 5.2.0+ tem wheel cp313 manylinux (Decisão #14, Sessão 5)`
- `app/backend/requirements.txt` linha 341: `pyodbc==5.1.0` → `pyodbc==5.2.0`
- Commit em `apex-helpsphere/main` (sem `[skip ci]` — disparar run #9)

---

## Audit trail

| Data | Autor | Decisão registrada |
|---|---|---|
| 2026-04-27 | @dev (Dex) via @aiox-master orchestration | Decisão #1 (template), Decisão #2 (estratégia preliminar = vendoring full), Decisão #3 (proposta de remoções), Decisão #4 (proposta de adições) |
| 2026-05-01 | @aiox-master (Orion) com confirmação do professor | **Decisão #2 revisada: subset selectivo confirmado** (em vez de vendoring full). Decisão #3 reformulada: lista de exclusão consolidada (não mais "remover depois", agora "não vendorar"). Próximos passos atualizados para Sessão 2.1 (vendoring) + checkpoint antes de Sessão 2.2 (schema/seeds). |
| 2026-05-01 | @aiox-master (Orion) | **Sessão 2.2 concluída: Schema SQL + Seeds completos.** Decisões secundárias documentadas em `CHANGES.md` Sessão 2.2: (a) path `data/` na raiz do helpsphere/ em vez de dentro de app/, (b) GUIDs determinísticos pedagógicos para tenants, (c) `agent-ai` reservado para Lab Final, (d) referências `[KB]` em descriptions em vez de tabela de relacionamentos, (e) tickets Resolved com narrativa de fechamento na própria description. 50 tickets pt-BR + 70 comments + 5 tenants. Próximo: Sessão 2.3 (5 endpoints REST + driver SQL + Bicep p/ Microsoft.Sql/servers/databases). |
| 2026-05-01 | @architect (Aria) review + @aiox-master (Orion) consolidação + professor revisão | **Decisão #5 cravada — Stack Sessão 2.3 production-grade.** Recomendações iniciais Aria foram **revisadas pelo professor para padrão production-grade defensável**: (a) Container Apps (não App Service), (b) tenant isolation via **JWT claim** (não header arbitrário), (c) `@authenticated` **obrigatório** em todos endpoints (não público por default), (d) **Entra Group** como SQL AAD admin (não user pessoal), (e) seeds automático com flag (mantida). Próximo: @dev implementa Sessão 2.3 com essas decisões. |
| 2026-05-02 | @aiox-master (Orion) executando como @dev | **Sessão 3 concluída em 4 batches (B1-B4).** Decisões #6, #7, #8 cravadas: (#6) Fluent UI v9 preservado + paleta Apex via CSS variables — defesa: rebase futuro vs upstream trivial; (#7) `/`=Chat upstream **preservado** + 2 rotas lazy `/tickets` e `/tickets/:ticketId` adicionadas — defesa: RAG do MS necessário no Lab Inter/Final; (#8) `tenant_id` resolvido server-side via JWT, frontend exibe read-only — defesa: zero caminho de bypass, audit-friendly. ~2.840 linhas adicionadas em 4 commits + 3 PNGs sintéticos pt-BR para Vision OCR. Próximo: Sessão 4 (smoke `azd up` + re-baseline pytest snapshots + defesa arquitetural completa no README + handoff para @architect *qa-gate). |
| 2026-05-02 | @aiox-master (Orion) executando como @dev | **Sessão 3.5 concluída — bug fix Bicep SQL Server AVM compatibility.** Decisão #9 cravada. 5 patches no `infra/main.bicep` (P1-P4) + audit trail (P5). Bicep compila ✅. Lição aprendida documentada: CodeRabbit não roda `bicep build` — recomendação backlog: adicionar step CI. Próximo: retomar Sessão 4 a partir de S4.2 (env vars adicionais identificadas: `AZURE_DOCUMENTINTELLIGENCE_LOCATION`, `AZURE_OPENAI_LOCATION`). |
| 2026-05-03 | @aiox-master (Orion) executando como @devops (Gage) | **Sessão 5 — Decisão #13 cravada (run #7 falhou em Deploy Application).** Provision OK ✅ (15 recursos em westus3, Cog Services restored), mas hook `prebuild` do `azd deploy` falhou com `npm enoent app/frontend/package.json`. Causa raiz: `.gitignore` raiz `azure-retail` (L42-43) ignora `package.json` globalmente → `git ls-files` da extração #10 perdeu `package.json` + `package-lock.json` do helpsphere/frontend. Fix: restaurar 2 arquivos do disco azure-retail → apex-helpsphere local, commit, push, run #8. Lição pedagógica: surpresa #8 para PARA-O-ALUNO.md (auditar `git ls-files --others --ignored --exclude-standard` antes de extração de monorepo). |
| 2026-05-03 | @aiox-master (Orion) executando como @devops (Gage) | **Sessão 5 — Decisão #14 cravada (run #8 falhou em Deploy Application).** Frontend prebuild OK ✅ (fix #13 funcionou), Provision idempotente OK ✅ (~1min), mas `pip install` no Docker falhou em **`pyodbc==5.1.0`** porque não há wheel `cp313` publicado e o source não compila em CPython 3.13 (`_PyLong_AsByteArray` mudou de assinatura). Causa raiz combinada: Dockerfile herda `python:3.13-bookworm` do upstream MS (que NÃO usa pyodbc — adicionamos na Sessão 2.3 sem revalidar wheel matrix). Fix: bump `pyodbc>=5.2.0` em `requirements.in` + `pyodbc==5.2.0` em `requirements.txt` (5.2.0 tem `cp313-cp313-manylinux_2_17_x86_64.whl` pronto). Decisão consciente de manter Python 3.13 alinhado com upstream. Lição pedagógica: surpresa #9 para PARA-O-ALUNO.md (auditar `curl pypi.org/.../json \| jq '.urls[] \| select(.filename \| contains("cp313"))'` antes de adicionar dep Python a um Dockerfile). |
| 2026-05-02 | @aiox-master (Orion) executando como @devops (Gage) | **Sessão 4 PIVOT — extração para repo público + Actions OIDC.** Decisões #10, #11, #12 cravadas. Após blockers locais (Python 3.14 vs Dockerfile 3.13, pyodbc não compila), professor questionou: por que não Actions desde início? Pivot: descartar approach local, criar repo público dedicado **`tftec-guilherme/apex-helpsphere`**, configurar OIDC via `azd pipeline config` (User Managed Identity `msi-helpsphere-template` + 2 federated credentials), enriquecer `azure-dev.yml` com bicep validation + smoke test + cleanup steps. **6 runs do workflow, cada falha cirurgicamente diferente:** (#1) `.sh` permission denied → `git update-index --chmod=+x`; (#2) mesmo race; (#3) eastus2 sem capacidade SQL/Search → westus3; (#4) SQL DB zoneRedundant não suportado em PAYG → `zoneRedundant: false` explícito; (#5) Cog Services soft-deleted → `RESTORE_COGNITIVE_SERVICES=true`; (#6) RG Deleting (race cleanup); (#6-bis ~run #6 reexecutado) provisionou TODOS os 15 recursos com sucesso em westus3 mas falhou em prepdocs com "cannot write empty image" → guard PDF count em `prepdocs.{sh,ps1}` (Decisão #12). **Sessão pausada antes do run #7** com fix `prepdocs` commitado e pushed (`99e288a` com `[skip ci]` para não trigger workflow enquanto cleanup do RG run #6 ainda em curso). Próxima sessão: aguardar cleanup terminar, disparar `gh workflow run azure-dev.yml --ref main` (run #7), monitor, smoke endpoints, re-baseline pytest, README defesa, handoff @architect *qa-gate. |
