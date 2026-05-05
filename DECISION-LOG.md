# DECISION-LOG — HelpSphere Template

> Documenta as decisões arquiteturais que levaram à escolha do template-base e às customizações aplicadas. Audiência: arquiteto sênior auditando a defesa técnica da disciplina.
>
> **Story raiz:** [06.5a — HelpSphere Template (REUSE fork Microsoft)](../../../../docs/stories/06.5a.helpsphere-template.md)
> **Epic em curso:** [06.5c — Hybrid Microservices Python+.NET (B-PRACTICAL)](../../../../docs/stories/) · 9 stories · 5/9 Done · AC-4 + AC-5 fechados pós-Sessão 8 · backend Python crashloop RESOLVIDO pós-Sessão 9.2
> **Version-anchor:** Q2-2026
> **Última atualização:** 2026-05-04 (Sessão 9.2 — Decisões #17 + #18 cravadas)

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

## Decisão #15 — Workflow env passing + sql_init defensivo + smoke retry (Sessão 5, run #9 backend crashloop)

### Contexto

Run #9 (commit `eb20254` com fix da Decisão #14) avançou ainda mais: prebuild frontend ✅, Provision idempotente ✅ (~1min), **Deploy Application ✅** (pyodbc 5.2 instalou via wheel sem compile, ACA revision provisionada). Mas o **Smoke test (S4.F)** falhou em 30s com:

```
✅ Backend URI: https://capps-backend-yyowe3poxq7oc.wonderfulocean-e38df161.westus3.azurecontainerapps.io
curl: (28) Operation timed out after 30002 milliseconds with 0 bytes received
❌ Smoke test falhou — HTTP 000
```

Investigação pós-falha revelou que o backend ACA estava em **crashloop** com:

```
pyodbc.OperationalError: ('HYT00', '[HYT00] [Microsoft][ODBC Driver 18 for SQL Server]Login timeout expired (0) (SQLDriverConnect)')
ERROR - Application startup failed. Exiting.
ERROR - Worker (pid:15) exited with code 3.
ERROR - Reason: Worker failed to boot.
```

### Causa raiz (3 problemas combinados)

| # | Problema | Evidência | Defesa |
|---|---|---|---|
| 1 | **`sql_init.sh` SKIPPED silenciosamente** | Log do Provision: `⏭️  USE_SQL_SERVER=false — pulando sql_init` mesmo com `vars.USE_SQL_SERVER=true` setado no GitHub | azd hooks (preprovision/postprovision) leem env de `.azure/<env>/.env`, **NÃO** do shell. Workflow setava `USE_SQL_SERVER` apenas no shell env do runner. `azd env get-value USE_SQL_SERVER` retornava vazio → `"" != "true"` → skip. **Resultado: backend MI nunca virou SQL user via `CREATE USER FROM EXTERNAL PROVIDER`.** |
| 2 | **Backend crashloop** | `pyodbc.OperationalError HYT00 Login timeout` — server descarta TCP antes do TDS handshake completar (porque MI não é user SQL válido) | Login timeout pode ser network OU server-side reject precoce. Aqui é o último: server vê token MI desconhecido e fecha sem responder. Aparece como timeout, mas é auth implícita. |
| 3 | **Smoke test sem retry** | Roda 30s após `azd deploy`. Container está em state `Activating` (não `Running`), sem ingress responsivo ainda. Mesmo se backend tivesse subido, primeira request seria após cold start de gunicorn workers + aioodbc pool warm-up + token MI = 1-3min. | False negative — smoke falha mesmo com deploy correto se container não terminou cold start. |

### Decisão (3 fixes complementares)

**Fix A — `.github/workflows/azure-dev.yml`: novo step "Persist env to azd environment" antes de Provision**

Antes de `azd provision`, persistir env vars críticas no azd env file via `azd env set`:

```yaml
- name: Persist env to azd environment (Decisão #15)
  run: |
    azd env set USE_SQL_SERVER "${USE_SQL_SERVER:-true}"
    azd env set RESTORE_COGNITIVE_SERVICES "${RESTORE_COGNITIVE_SERVICES:-true}"
    azd env set USE_MULTIMODAL "${USE_MULTIMODAL:-true}"
    azd env set AZURE_LOAD_SEED_DATA "${AZURE_LOAD_SEED_DATA:-true}"
    azd env set DEPLOYMENT_TARGET "${DEPLOYMENT_TARGET:-containerapps}"
    azd env set AZURE_USE_AUTHENTICATION "${AZURE_USE_AUTHENTICATION:-false}"
    azd env set AZURE_SQL_DATABASE_NAME "${AZURE_SQL_DATABASE_NAME:-helpsphere}"
    azd env set AZURE_SQL_AAD_ADMIN_GROUP_NAME "${AZURE_SQL_AAD_ADMIN_GROUP_NAME}"
    azd env set AZURE_SQL_AAD_ADMIN_GROUP_OBJECT_ID "${AZURE_SQL_AAD_ADMIN_GROUP_OBJECT_ID}"
  shell: bash
```

Hooks azd agora veem essas vars via `azd env get-value`.

**Fix B — `scripts/sql_init.sh`: resolução defensiva 3-tier**

```sh
USE_SQL_SERVER="${USE_SQL_SERVER:-$(azd env get-value USE_SQL_SERVER 2>/dev/null)}"
USE_SQL_SERVER="${USE_SQL_SERVER:-true}"
```

Tier 1: shell env (caso execução local com env definido). Tier 2: azd env file (caso CI com Fix A). Tier 3: default `true` (HelpSphere = SQL mandatório por Decisão #5). **Nunca mais skip silencioso.**

**Fix C — `.github/workflows/azure-dev.yml`: smoke test com retry loop ~7min**

```sh
ATTEMPTS=15
for i in $(seq 1 $ATTEMPTS); do
  STATUS=$(curl -ksSL --max-time 10 -o /dev/null -w "%{http_code}" "$BACKEND_URI" || echo "000")
  echo "[smoke attempt $i/$ATTEMPTS] HTTP $STATUS"
  if [ "$STATUS" = "200" ] || [ "$STATUS" = "302" ] || [ "$STATUS" = "401" ]; then
    exit 0
  fi
  [ $i -lt $ATTEMPTS ] && sleep 20
done
exit 1
```

15 tentativas × (10s timeout + 20s sleep) = ~7min worst case. Sucesso early se 200/302/401 antes.

### Defesa arquitetural

| Aspecto | Decisão | Anti-padrão rejeitado |
|---|---|---|
| Camada do fix Fix A | Workflow YAML (uma vez, antes do provision) | Setar via `--env-arg` em cada azd command (verbose, espalhado) |
| Default em sql_init.sh | `true` (HelpSphere requer SQL) | `false` (default safe upstream) — quebraria HelpSphere a cada execução em ambiente novo |
| Smoke retry strategy | Loop com short attempts + sleep | Single shot com `--max-time 600` — daria timeout de 10min sem feedback intermediário |
| Logs no fail | Apenas curl status | `az containerapp logs show` no fim — `az` não tá auth no runner (workflow usa `azd auth login`, não `az login`) |

### Lição pedagógica (PARA-O-ALUNO.md S4.H — surpresa #10)

**`azd hooks` NÃO leem env vars do shell.** Eles leem só do azd env file (`.azure/<env_name>/.env`). Se você passa env via GH Actions `env:` block, a variável existe pro `azd provision` em si, mas não pros hooks (preprovision, postprovision, predeploy, postdeploy). **Use `azd env set` antes do provision para garantir hooks veem o que precisam.**

Também: **scripts de hook sempre devem ter default seguro para o contexto do projeto.** Se HelpSphere requer SQL, sql_init não pode skip silencioso quando flag tá vazia — tem que assumir o default que faz HelpSphere funcionar.

### Implementação

- `.github/workflows/azure-dev.yml` linhas 181+ (antes de Provision): novo step "Persist env to azd environment"
- `.github/workflows/azure-dev.yml` linhas 195-211 (Smoke test): substituído single curl por retry loop 15 attempts
- `scripts/sql_init.sh` linhas 7-11: defensive USE_SQL_SERVER resolution + log explícito quando executa
- Commit em `apex-helpsphere/main` (sem `[skip ci]` — disparar run #10)

---

## Decisão #16 — Hybrid Microservices Python + .NET (CRAVADA — Sessões 6-8, Epic 06.5c parcial)

> **Status:** CRAVADA · Forma: **Epic 06.5c** (9 stories, 4 done + 2 partial + 3 pending) · **AC-4 + AC-5 do epic FECHADOS pós-Sessão 8.**

### Contexto

A Decisão #15 fechou o caminho `Python → pyodbc → SQL com MI` com 3 fixes complementares, mas a fragilidade arquitetural ficou exposta. A Decisão #16 PLANEJADA propôs hybrid Python+.NET. O professor escolheu approach **B-PRACTICAL** (incremental, fases reversíveis), formalizado via `@pm *create-epic` como **epic 06.5c** com 9 stories.

### Trajetória de execução (Sessões 6-8)

**Sessão 6 — Stories 06.5c.1 + 06.5c.2** (commits `cdbf855`, `e87dcf4`)

- **06.5c.1** — `.NET 10 tickets-service` skeleton: Minimal API + Dapper + Managed Identity. Estrutura `app/tickets-service/` com `TicketsService.Api/` + `TicketsService.Tests/` (xUnit dual-tier sqlite + sqledge).
- **06.5c.2** — 5 endpoints REST (`GET /api/tickets`, `GET /api/tickets/{id}`, `POST /api/tickets`, `PATCH /api/tickets/{id}`, `POST /api/tickets/{id}/comments`) + JWT tenant claim resolution server-side + dual-tier tests passing.
- **Status:** 2/9 stories Done.

**Sessão 7 — Story 06.5c.3 partial** (commits `0c246c8`, `11b38cf`, `4cef3ec`)

- **B-PRACTICAL minimal hybrid wiring**: `infra/main.bicep` ganha 2ª Container App (`capps-tickets-${resourceToken}`) + 2ª Managed Identity (`mi-tickets`) + 2ª image no ACR.
- Bug fixes Dockerfile: `.slnx` em vez de `.sln` (.NET 10), exclusão de `tests/` no build context, `azure.yaml` `language=docker` para tickets-service (csproj em `src/`).
- **Status:** 06.5c.3 partial — refinements Bicep (path routing final, tags, retentionDays) ainda pendentes.

**Sessão 8 — Stories 06.5c.4 + 06.5c.7** (commits `d0ce22c`, `e5842e6`)

**06.5c.4 — sql_init scoped grants para tickets MI (AC-4 do epic FECHADO)**

`scripts/sql_init.sh` ganha 9 grants object-level scoped exclusivamente para o tickets MI:

| # | Grant | Objeto |
|---|-------|--------|
| 1-3 | SELECT, INSERT, UPDATE | `tbl_tickets` |
| 4-5 | SELECT, INSERT | `tbl_comments` |
| 6 | REFERENCES | `tbl_tenants` (FK check) |
| 7 | EXECUTE | `sys.fn_my_permissions` (verificação) |
| 8-9 | Reservados (extensão futura) |

**Verificação fail-fast:** se qualquer grant falhar, `sql_init.sh` aborta o Provision com mensagem explícita. Verificável em runtime via `sys.database_permissions` + `sys.database_role_members`. **Run #24 GREEN.**

**06.5c.7 — Deprecate Python `/api/tickets/*` + REVOKE backend MI (AC-5 do epic FECHADO)**

- Endpoints `/api/tickets/*` no `app/backend/` Python agora retornam **HTTP 410 Gone** com header `Link: </api/v2/tickets>; rel="successor-version"` (RFC 8288) apontando pro Container App `.NET tickets-service`.
- Backend Python MI teve **REVOKE** de `db_datareader` e `db_datawriter` — ficou com APENAS `SELECT em tbl_tenants` (necessário pra resolver config de tenants em request inicial).
- **Least privilege real cravado:** backend Python NÃO toca em `tbl_tickets` ou `tbl_comments` (nem leitura). Verificável via `SELECT * FROM sys.database_role_members WHERE member_principal = 'backend-mi'`. **Run #25 GREEN.**

### Estado final do epic 06.5c pós-Sessão 8

| Story | Status | AC do epic |
|-------|--------|-----------|
| 06.5c.1 — .NET 10 skeleton | ✅ Done | AC-1 |
| 06.5c.2 — 5 endpoints + JWT + dual tests | ✅ Done | AC-2 |
| 06.5c.3 — Bicep hybrid wiring | 🟡 Partial | AC-3 |
| **06.5c.4 — sql_init scoped grants** | ✅ Done | **AC-4 ✅** |
| 06.5c.5 — Workflow dotnet build/test | 🟡 Partial | AC-3 |
| 06.5c.6 — Frontend `VITE_API_TICKETS_URL` | ⏳ Pending | AC-6 |
| **06.5c.7 — Python deprecate + REVOKE backend** | ✅ Done | **AC-5 ✅** |
| 06.5c.8 — E2E smoke + qa-gate epic | ⏳ Pending | AC-7 |
| 06.5c.9 — DECISION-LOG #16 + docs | 🟡 Partial (esta sessão) | AC-8 |

**4/9 done · 2/9 partial · 3/9 pending · ~7h restantes.**

### Defesa arquitetural

| Aspecto | Decisão | Anti-padrão rejeitado |
|---|---|---|
| Approach geral | **B-PRACTICAL** incremental (9 stories pequenas) | Big-bang rewrite (alto risco, irreversível) |
| Bounded contexts | tickets em .NET, RAG mantém Python | Tudo em .NET (perde upstream MS) ou tudo em Python (mantém pyodbc fragility) |
| Identity para tickets | MI dedicada (`mi-tickets`) com scoped grants | MI compartilhada com backend Python (viola least privilege) |
| Granularidade dos grants | Object-level (9 grants em 3 objetos) | Role-level (`db_datawriter` na DB inteira) |
| Verificação | Fail-fast em sql_init + queries explícitas | Trust-only (assume que provisioning funcionou) |
| Deprecation Python tickets | HTTP 410 Gone + `Link: rel="successor-version"` (RFC 8288) | HTTP 404 (silencioso), 301 (mantém keep-alive), ou nenhuma resposta |
| Migração frontend | env var `VITE_API_TICKETS_URL` (story 06.5c.6) | URL hardcoded no bundle, sem migration path |
| Routing entre apps | 2 Container Apps com FQDNs distintos (sem APIM ainda) | APIM como gateway desde início (overkill pra epic) — fica como **backlog para D04 sinergia** |

### Lições pedagógicas (PARA-O-ALUNO.md)

- **Least privilege real é granular.** "MI tem acesso ao banco" não é least privilege. Least privilege real é **MI tem precisamente permission X em objeto Y**, verificável via `sys.database_permissions`. Diferença visível em audit security review.
- **Deprecation tem padrão (RFC 8288).** HTTP 410 Gone + `Link: <successor>; rel="successor-version"` é a forma limpa de deprecar endpoint sem quebrar clientes silenciosamente. Cliente humano vê o 410 + lê o Link e migra; cliente automatizado pode parsear.
- **B-PRACTICAL > Big-bang.** Rewrite em fases pequenas (skeleton → endpoints → wiring → grants → deprecation → frontend → E2E → docs) reduz risco e permite reverter qualquer fase. Cada commit é um checkpoint funcional.
- **Verificação fail-fast > trust-only.** Provisioning silencioso quando algo falha = bomba-relógio. Sempre prefira `set -e` + queries de verificação explícitas no final do script.

### Implementação (paths-chave)

- `app/tickets-service/` — .NET 10 Minimal API + Dapper + xUnit dual-tier
- `infra/main.bicep` — 2ª Container App + 2ª MI + ACR image
- `scripts/sql_init.sh` — 9 grants scoped + verificação fail-fast
- `app/backend/api.py` — `/api/tickets/*` retorna 410 Gone com Link header
- `.github/workflows/azure-dev.yml` — runs #24 e #25 GREEN

### Backlog técnico (não bloqueia AC-4/AC-5 fechados)

- **06.5c.3 remainder** (~30min): Bicep refinements (path routing final, tags retentionDays) — postponed (refinements vagos, ROI baixo, Bicep está funcional pós-Decisão #18)
- **06.5c.5 remainder** (~1h): workflow `dotnet build` + `dotnet test` step — **DONE Sessão 9.2** (`.github/workflows/dotnet-test.yaml` criado)
- **06.5c.6** (~2-2.5h): frontend `VITE_API_TICKETS_URL` — **DONE Sessão 9.1** (build-time injection via prebuild hook, commit `737fc22`)
- **06.5c.8** (~2h): E2E smoke + qa-gate epic-level
- **06.5c.9** finalização (~30min): **DONE pós-Sessão 9.2** (Decisões #17 + #18 cravadas neste documento)
- **APIM gateway** (D04 sinergia) — backlog futuro fora do epic 06.5c

---

## Decisão #17 — Token AAD explícito para User-Assigned MI no backend Python (Sessão 9.2)

> **Status:** CRAVADA · Forma: refator de `app/backend/repositories/_pool.py` (commit `7a4ffd5`) · **Epic 06.5c — backend Python crashloop RESOLVIDO**, viabiliza próximas stories.

### Contexto

Após `azd up` real do prof na Sessão 9.1 (env `helpsphere-actions`), backend Python entrou em crashloop com `pyodbc.OperationalError ('HYT00', 'Login timeout expired (0)')` durante `aioodbc.create_pool()` na startup do app. Sintoma intermitente, fácil de confundir com problema de network/firewall.

A primeira hipótese (registrada na memória como Surpresa #14) foi **"Bicep não injeta `AZURE_CLIENT_ID`"**. Sessão 9.2 investigou e descobriu que **estava equivocada** — Bicep injeta corretamente em ambos Container Apps (linhas 679 + 751 de `infra/main.bicep`). O env var sempre esteve presente.

### Diagnóstico cravado em Sessão 9.2

Investigação sistemática descartou hipóteses comuns:
- **Network/firewall**: regra `ACAOutboundIP` (20.171.204.29) liberada ✅; `AllowAllAzureIPs` ✅. Tickets-service .NET conectava no mesmo SQL Server.
- **Permissions**: `helpsphere-actions-aca-identity` tem `CONNECT` + `SELECT` em `tbl_tenants` (object-level grants da Story 06.5c.7) ✅.
- **SQL DB Serverless paused**: estava `Paused`, mas resume + `autoPauseDelay = -1` não resolveu o crashloop (vide Decisão #18).
- **Workers gunicorn race**: 8 workers × `minsize=2` parecia thundering herd, mas mesmo com restart limpo o problema persistiu.

**Root cause real:** `Authentication=ActiveDirectoryMsi;User Id={clientId}` no DSN do ODBC Driver 18 é **incompatível com User-Assigned Managed Identity em Linux Container Apps**. O driver não obtém token AAD corretamente do IMDS quando há UMI atribuída ao container. A query manual do laptop (com `attrs_before={SQL_COPT_SS_ACCESS_TOKEN: token}`) funcionava, validando que o problema é específico do modo `ActiveDirectoryMsi` do driver.

### Decisão

**Refatorar `app/backend/repositories/_pool.py`** para usar a abordagem **MS-recomendada**: obter token AAD via `azure.identity.ManagedIdentityCredential(client_id=AZURE_CLIENT_ID)` no Python e injetar via `SQL_COPT_SS_ACCESS_TOKEN` em `attrs_before` da pyodbc connection. Connection string fica SEM cláusula `Authentication=...`.

**Implementação:**

- Nova classe `MITokenConnectionFactory` substitui `aioodbc.Pool` (mesma API `async with factory.acquire() as conn` — repositories não mudam).
- Token cached via `threading.Lock` por **50min** (refresh antes do TTL real de 60min do AAD).
- **Eager token fetch** no startup: `await asyncio.to_thread(factory._get_token_struct)` valida que MI funciona ANTES de iniciar workers (fail-fast) — sem forçar conexão SQL.
- **Connection Timeout 30s → 60s** no DSN (defesa em profundidade caso DB cold-start, vide Decisão #18).
- Em dev local: `DefaultAzureCredential()` (azd auth login / az login / VS Code Azure ext).
- API mantida 100% compatível: `close()`, `wait_closed()`, `acquire()` — sem refactor de `tenants.py`.

### Por que essa solução vs alternativas

| Alternativa | Por que rejeitada |
|---|---|
| Trocar para `Authentication=ActiveDirectoryServicePrincipal` | Não resolve UMI; precisaria secret no DSN (anti-pattern) |
| Usar `ActiveDirectoryDefault` | Driver-side ainda — mesmo class de bug |
| Migrar para asyncpg + Postgres | Mudança de DB engine — escopo enorme, fora do epic |
| Usar `pyodbc.connect(... attrs_before=...)` em cada query (sem pool) | Performance ruim para workload >10 req/s; HelpSphere atende com fresh-conn-per-acquire mas keeping factory pattern para upgrade futuro |

A abordagem escolhida é **idiomática** para Python + Azure SQL + UMI, **documentada na Microsoft Learn**, e tem **drop-in compatibility** com a API existente.

### Trade-off aceito

- **Conexões fresh por request** (sem pool warm): aceitável para workload do HelpSphere (lookup esporádico em `tbl_tenants` para chat session validation). Performance ~50-100ms extra na primeira call por request — invisível em demo de aula.
- **Sem `setup` callback nativo do aioodbc**: workaround é wrapper minimal (~140 linhas). Mantém zero dependências novas.

### Lição pedagógica

Quando o ODBC Driver 18 retorna `Login timeout expired (0)`, NÃO assumir que é network sem antes testar com **token explícito**. O `(0)` no parêntese significa que o driver nem esperou — falhou na obtenção/parsing do token, não na conexão TCP. **Tickets-service .NET nunca teve o bug** porque `DefaultAzureCredential` do `Microsoft.Data.SqlClient` resolve UMI corretamente via env var `AZURE_CLIENT_ID` (mesmo padrão MS, implementação diferente).

### Files alterados

- `app/backend/repositories/_pool.py` — refator completo (commit `7a4ffd5`)

### Validação

- ✅ Local env do prof (`helpsphere-actions`): backend `/` → 200 (604ms), `/api/tenants/me` sem JWT → 403 (596ms), 8 workers gunicorn boot OK
- ✅ CI fresh provision (run `25349888625`): smoke backend Python (INFORMATIONAL) passou ao primeiro try em env limpo

---

## Decisão #18 — Azure SQL Serverless `autoPauseDelay = -1` no template (Sessão 9.2)

> **Status:** CRAVADA · Forma: patch de 1 linha em `infra/main.bicep` (commit `7a4ffd5`)

### Contexto

A Decisão #5 da Sessão 2.3 escolheu `GP_S_Gen5_2` (Serverless) com `autoPauseDelay: 60` (1h) como FinOps win — DB pausa quando ociosa. Sessão 9.2 descobriu que isso **causa cold-start de 30-60s** quando o app tenta conectar após período de inatividade (ex: 30min de teoria entre 2 demos numa aula gravada).

Backend Python com `Connection Timeout=30s` falhava no resume; tickets-service .NET tinha primeira request lenta após pausa.

### Decisão

**`autoPauseDelay: 60 → -1`** no Bicep — DB sempre Online.

```bicep
// Sessão 9.2 (Decisão #18): autoPauseDelay = -1 (DESABILITADO).
// Trade-off: ~$15-30/mês a mais vs interrupção do app durante demo.
// Cold-start de Serverless paused leva 30-60s; backend Python (Connection
// Timeout=60s) cobre, mas tickets-service .NET pode ter primeira request
// lenta. Para ambiente de aula gravada, confiabilidade > FinOps savings.
// Aluno em produção pode mudar para 60min aceitando o trade-off.
autoPauseDelay: -1
```

### Trade-off explícito

| Cenário | `autoPauseDelay: 60` (anterior) | `autoPauseDelay: -1` (cravado) |
|---|---|---|
| Custo baseline | ~$5-10/mês (DB pausada maior parte do tempo) | ~$25-40/mês (DB sempre Online) |
| Primeira request após pausa | 30-60s | <1s |
| Demo de aula (intermitência 10min ON / 30min OFF) | ❌ App pode bater no auto-pause no meio | ✅ Sempre responsiva |
| Aluno em produção real (24/7 traffic) | ✅ Não bate auto-pause | Custo extra desnecessário |

**Para template pedagógico** o trade-off é claro: ~$15-30/mês > qualquer interrupção visível em demo gravada que vai ficar anos no ar.

### Files alterados

- `infra/main.bicep` — autoPauseDelay 60 → -1 + comment explicando trade-off (commit `7a4ffd5`)

### Como o aluno reverte (se quiser FinOps)

Edit `infra/main.bicep`:
```diff
- autoPauseDelay: -1
+ autoPauseDelay: 60
```

E aceitar que a primeira request após 1h de inatividade vai levar 30-60s (cold-start do Serverless resume).

---

## Decisão #19 — Runtime config via `/auth_setup.ticketsApiBase` (Sessão 9.4)

> **Status:** CRAVADA · Forma: backend `/auth_setup` expõe `ticketsApiBase` em runtime; frontend `authConfig.ts` usa top-level await no boot; build-time `VITE_API_TICKETS_URL` removido do `azure.yaml`

### Contexto

A Story 06.5c.6 introduziu `VITE_API_TICKETS_URL` como **build-time injection** — env var lida durante `npm run build` e fixada no bundle JS final. Sessão 9.4 (primeiro login E2E real do prof no laptop) descobriu que o aluno esquece de exportar a env var antes de `npm run build` → bundle ships com path relativo `/api/tickets` → backend Python responde **HTTP 410 Gone** (deprecação cravada na Decisão #16) e o frontend mostra erro genérico difícil de correlacionar com missing env var.

Diagnosticar isso requer: abrir DevTools, verificar Network tab, ver que request foi para origin errado, inferir que VITE_API_TICKETS_URL não foi setado no build. Etapa pedagógica caríssima para quem está vendo o template pela primeira vez.

### Decisão

**Backend Python expõe `ticketsApiBase` em runtime** via endpoint `/auth_setup` (lendo de env `TICKETS_BACKEND_URI`, setada pelo Bicep como output do tickets-service Container App).

**Frontend `authConfig.ts`** lê do `/auth_setup` no boot via top-level await (mesmo pattern já usado pelo template MS para configurar MSAL).

**Mesmo bundle JS** serve qualquer environment — dev local, fork do aluno, fork de outro aluno, branch de feature, todos descobrem o tickets URL em runtime.

```python
# app/backend/app.py — /auth_setup handler
return {
    "useLogin": auth_helper.use_authentication,
    "requireAccessControl": ...,
    "msalConfig": {...},
    "loginRequest": {...},
    "tokenRequest": {...},
    "ticketsApiBase": os.environ.get("TICKETS_BACKEND_URI", ""),  # NEW
    "enableChat": os.environ.get("ENABLE_CHAT", "false").lower() == "true",  # NEW (Decisão #23)
}
```

```ts
// app/frontend/src/authConfig.ts (top of file)
const authSetup = await fetch("/auth_setup").then(r => r.json());
export const ticketsApiBase: string = authSetup.ticketsApiBase || "";
export const enableChat: boolean = authSetup.enableChat === true;
```

### Alternativas avaliadas

| Alternativa | Veredicto |
|---|---|
| Manter build-time injection + melhorar docs (PARA-O-ALUNO + comment no `azure.yaml`) | ❌ Rejeitada — aluno continua bater. Documentação não substitui defaults seguros. |
| Service worker / `window.__CONFIG__` injetado por backend HTML template | ❌ Rejeitada — overengineering. MSAL.js já faz top-level await em `/auth_setup`, reaproveitamos a infra. |
| Backend Python proxy reverso `/api/tickets/*` → tickets-service (transparent proxy) | ❌ Rejeitada — refactor pesado, perde decoupling Python↔.NET, viola Decisão #16 (separação clara dos 2 microservices) |

### Anti-padrões rejeitados

❌ **Environment-coupling em build artifact** — bundle JS deve ser environment-agnostic. Onde foi buildado ≠ onde será deployado.
❌ **Falha silenciosa em UX crítico** — request com origin errado → 410 Gone genérico → debug humano caríssimo.

### Files alterados

- `app/backend/app.py` — `/auth_setup` ganha `ticketsApiBase` + `enableChat`
- `app/frontend/src/authConfig.ts` — top-level await + named exports `ticketsApiBase`, `enableChat`
- `app/frontend/src/api/tickets.ts` — usa `ticketsApiBase` import (não mais `import.meta.env.VITE_API_TICKETS_URL`)
- `azure.yaml` — remove hook `prebuild` que setava `VITE_API_TICKETS_URL`

---

## Decisão #20 — Audience GUID puro (v2) no Bicep do tickets-service (Sessão 9.4)

> **Status:** CRAVADA · Forma: param Bicep `tokenAudienceFormat` (default `v2`); tickets-service Container App env `AzureAd__Audience = serverAppId` (GUID puro, sem `api://` prefix)

### Contexto

Bicep do template upstream (`azure-search-openai-demo`) seta `AzureAd__Audience: api://${clientAppId}` (linha 763-764 do `main.bicep` original). Two-app pattern (Decisão Q1B + Sessão 9.4) emite tokens com `aud=api://${serverAppId}` (correto, server-app é o resource owner). Mismatch causa `IDX10214: Audience validation failed: ... did not match: validationParameters.ValidAudience` na primeira chamada autenticada do frontend ao tickets-service.

Adicionalmente, em token v2 com `accessTokenAcceptedVersion=2` (cravado em `auth_init.py` Sessão 9.4), audience é emitida como **GUID puro** (`${serverAppId}` sem `api://` prefix). Esse é o formato canônico do Microsoft Identity Platform v2 — `api://` é legado v1.

### Decisão

**`AzureAd__Audience` no Bicep do tickets-service usa `serverAppId` (GUID puro, v2 native) por default.**

```bicep
// infra/main.bicep — tickets-service Container App
@allowed(['v1', 'v2', 'both'])
param tokenAudienceFormat string = 'v2'

var audienceValue = tokenAudienceFormat == 'v1'
  ? 'api://${serverAppId}'
  : tokenAudienceFormat == 'both'
    ? 'api://${serverAppId},${serverAppId}'  // CSV, .NET aceita lista
    : serverAppId  // v2 default

// env vars do tickets-service Container App
{
  name: 'AzureAd__Audience'
  value: audienceValue
}
```

Param `tokenAudienceFormat` permite override em fluxos de migração (legacy clients ainda emitindo v1 tokens) sem quebrar a defesa arquitetural canônica.

### Alternativas avaliadas

| Alternativa | Veredicto |
|---|---|
| `api://${serverAppId}` (v1 prefix) por default | ❌ Rejeitada — força token v1 que não suporta Directory Extensions em **access tokens** (v1 só suporta extension em ID tokens, e tickets-service valida access token). |
| Lista CSV `api://${serverAppId},${serverAppId}` por default | ❌ Rejeitada — aceito como param `both` opcional, NÃO default. Dilui a mensagem arquitetural ("audience é GUID puro v2"). Override consciente, não default obscuro. |

### Anti-padrões rejeitados

❌ **Audience hardcoded** sem param — bloqueia migração futura.
❌ **Audience misalignment frontend↔backend** — frontend pede token para audience X, backend valida audience Y, falha silenciosa de auth.

### Files alterados

- `infra/main.bicep` — param `tokenAudienceFormat` + `audienceValue` derivado + `AzureAd__Audience` no tickets-service env

### Como o aluno reverte (se quiser v1 tokens)

Edit `infra/main.bicep`:
```diff
- param tokenAudienceFormat string = 'v2'
+ param tokenAudienceFormat string = 'v1'
```

E aceitar que Directory Extension `app_tenant_id` só virá no ID token (não no access token), forçando outro caminho de tenant resolution server-side.

---

## Decisão #21 — Claim `app_tenant_id` aceita 3 formas (Sessão 9.4)

> **Status:** CRAVADA · Forma: fallback chain em `TenantContext.cs` (.NET) e `_resolve_tenant_id` (Python) — aceita 3 variantes do claim conforme tier de licença AAD do aluno

### Contexto

Free tier AAD não inclui **Claims Mapping Policy** (feature P1+/P2). Directory Extension é o único pattern free pra custom claim em token. Mas o **formato emitido** difere por tipo de token e por presença de Claims Mapping Policy:

| Cenário | Tipo de token | Claim name emitido |
|---|---|---|
| Free tier, Directory Extension | ID token v2 | `extension_<serverAppIdNoHyphens>_app_tenant_id` (forma longa) |
| Free tier, Directory Extension | Access token v2 | `extn.app_tenant_id` (forma curta com prefix) |
| P1+/P2 com Claims Mapping Policy | Access token v2 | `app_tenant_id` (forma curta sem prefix) |

Hardcodar uma única forma quebra para alunos em outro tier ou contexto. Validar todas as 3 forms aceita o template em qualquer assinatura AAD, do free ao P2.

### Decisão

**`TenantContext.cs` (.NET) e `_resolve_tenant_id` (Python) aceitam as 3 formas com fallback chain.**

```csharp
// app/tickets-service/Auth/TenantContext.cs
var tenantClaim =
    user.FindFirst("app_tenant_id")?.Value
    ?? user.FindFirst("extn.app_tenant_id")?.Value
    ?? user.Claims
        .FirstOrDefault(c => c.Type.EndsWith("app_tenant_id", StringComparison.Ordinal))
        ?.Value;

if (string.IsNullOrWhiteSpace(tenantClaim))
{
    throw new UnauthorizedAccessException("Token missing tenant claim (app_tenant_id).");
}
```

```python
# app/backend/auth/tenant.py
def _resolve_tenant_id(claims: dict[str, Any]) -> str:
    # Try short form first (P1+ Claims Mapping Policy)
    if "app_tenant_id" in claims:
        return claims["app_tenant_id"]
    # Try access token v2 short form with prefix
    if "extn.app_tenant_id" in claims:
        return claims["extn.app_tenant_id"]
    # Fallback to long form (free tier ID token v2)
    for key, value in claims.items():
        if key.endswith("app_tenant_id"):
            return value
    raise PermissionError("Token missing tenant claim (app_tenant_id).")
```

### Alternativas avaliadas

| Alternativa | Veredicto |
|---|---|
| Apenas forma curta `app_tenant_id` (assume P1+) | ❌ Rejeitada — força aluno a comprar Premium AAD para template rodar. Viola "zero-friction setup". |
| Apenas Directory Extension longa `extension_<id>_app_tenant_id` | ❌ Rejeitada — quebra se aluno tem P1+ e configura Claims Mapping Policy (que normaliza pra forma curta). |
| Refactor pra App Roles com `value=tenantId` (Roles em vez de Extension) | ❌ Rejeitada — viola Decisão Q1B (claim específico anti-spoofing claim-based). App Roles são para autorização (RBAC), não para identidade de tenant. Misturar dimensões. |

### Anti-padrões rejeitados

❌ **Assumir tier de licença AAD** do aluno — template tem que funcionar no free tier.
❌ **Single-form rigid match** — frágil a evoluções do Microsoft Identity Platform e a configurações legítimas (Claims Mapping).

### Files alterados

- `app/tickets-service/Auth/TenantContext.cs` — fallback chain 3-tier
- `app/backend/auth/tenant.py` — `_resolve_tenant_id` com fallback chain 3-tier
- `app/tickets-service/tests/Auth/TenantContextTests.cs` — testes parametrizados para as 3 formas
- `app/backend/tests/auth/test_tenant.py` — testes pytest parametrizados para as 3 formas

---

## Decisão #22 — Token explicit injection no SqlClient .NET (paridade Decisão #17 Python) (Sessão 9.4)

> **Status:** CRAVADA · Forma: `SqlConnectionFactory.cs` injeta token AAD via `SqlConnection.AccessToken` antes de `OpenAsync`; package `Microsoft.Data.SqlClient.Extensions.Azure` REMOVIDO; substituído por `Azure.Identity 1.13.1`

### Contexto

`Microsoft.Data.SqlClient` v6+ separou auth providers AAD (`ActiveDirectoryManagedIdentity`, `ActiveDirectoryDefault`) para **package opcional** `Microsoft.Data.SqlClient.Extensions.Azure`. Sem o package, `SqlConnection.OpenAsync()` lança:

```
ArgumentException: Cannot find an authentication provider for 'ActiveDirectoryManagedIdentity'.
```

Plus, o package `Extensions.Azure` requer **registro explícito** via `SqlAuthenticationProvider.SetProvider(...)` no startup, e tem **incompat de versão com SqlClient 7.x** (versão única `1.0.0` foi publicada e não recebeu update). Ficar dependendo dele é frágil — risco de quebrar em update transitivo do SqlClient.

Idêntico em natureza ao problema que a Decisão #17 resolveu para o backend Python (ODBC Driver 18 + `Authentication=ActiveDirectoryMsi` em User-Assigned MI Linux Container Apps).

### Decisão

**`SqlConnectionFactory.cs` (.NET) faz token explicit injection via `Azure.Identity`** — bypassa o auth provider system inteiramente.

```csharp
// app/tickets-service/Data/SqlConnectionFactory.cs
public class SqlConnectionFactory
{
    private readonly TokenCredential _credential;
    private readonly string _connectionString;

    public SqlConnectionFactory(IConfiguration config, IHostEnvironment env)
    {
        _connectionString = config.GetConnectionString("Sql")!;
        _credential = env.IsDevelopment()
            ? new DefaultAzureCredential()
            : new ManagedIdentityCredential(config["AZURE_CLIENT_ID"]);
    }

    public async Task<SqlConnection> OpenAsync(CancellationToken ct = default)
    {
        var token = await _credential.GetTokenAsync(
            new TokenRequestContext(new[] { "https://database.windows.net/.default" }),
            ct);

        var conn = new SqlConnection(_connectionString)
        {
            AccessToken = token.Token  // bypass auth provider system
        };
        await conn.OpenAsync(ct);
        return conn;
    }
}
```

**Paridade arquitetural com Decisão #17** (backend Python faz mesmo pattern via `SQL_COPT_SS_ACCESS_TOKEN` em `attrs_before` do pyodbc). Mesmo modelo mental para os dois microservices: nunca dependa de auth provider built-in do driver para User-Assigned MI; sempre obtenha token explicitamente via Azure Identity SDK e injete diretamente.

### Alternativas avaliadas

| Alternativa | Veredicto |
|---|---|
| Adicionar `Microsoft.Data.SqlClient.Extensions.Azure 1.0.0` + registrar provider | ❌ Rejeitada — versão única disponível, incompat com SqlClient 7.x (bumps de SqlClient quebram). Frágil long-term. |
| Downgrade SqlClient 5.x (auth providers built-in) | ❌ Rejeitada — perde features 7.x (TLS 1.3, perf), breaking changes em refactors futuros. |
| App Roles + impersonation server-side | ❌ Rejeitada — não resolve auth a SQL, só authz a tickets. Problema é distinto. |

### Anti-padrões rejeitados

❌ **Dependência em package opcional frágil** — package que não evolui junto com o package principal é dívida técnica garantida.
❌ **Auth via connection string flag** (`Authentication=ActiveDirectoryManagedIdentity;User Id=...`) para User-Assigned MI Linux — driver-side gera erros opacos, debugging caríssimo.

### Files alterados

- `app/tickets-service/Data/SqlConnectionFactory.cs` — token explicit injection via `Azure.Identity`
- `app/tickets-service/HelpSphere.Tickets.csproj` — adiciona `Azure.Identity 1.13.1`, REMOVE `Microsoft.Data.SqlClient.Extensions.Azure`
- `app/tickets-service/Program.cs` — registra `SqlConnectionFactory` como Scoped DI

---

## Decisão #23 — Login redirect flow + chat dormente (Sessão 9.4)

> **Status:** CRAVADA · Forma: `loginRedirect` substitui `loginPopup` em todo frontend; `LoginGate` componente bloqueante; backend `/redirect` serve `index.html`; rota `/chat` mantida mas escondida da nav (Bicep param `enableChat=false` por default)

### Contexto

**Parte A (login redirect):** MSAL `loginPopup` engole erros silenciosamente em browsers que bloqueiam popups (default em incognito do Edge/Chrome/Firefox). User clica botão de login e nada acontece — sem mensagem, sem erro visível, sem indicação. Plus, o template upstream assumia popup-only flow: rota `/redirect` no backend retornava blank string (era apenas um landing transitório que fechava via `window.opener`), incompatível com `loginRedirect` flow que precisa servir SPA real para hidratar e processar o `#code=...` hash.

**Parte B (chat dormente):** A rota `/chat` (UI completa do template upstream com chat RAG) continua presente no código mas SEM pipeline RAG funcional ainda (prepdocs precisa rodar com PDFs reais, embeddings configurados, índice search populado — escopo Lab Intermediário, não v2.1.0). Mostrar nav link "Chat" ativo com feature parcialmente quebrada antes do Lab Intermediário ativar = "promessa quebrada" pedagógica que confunde aluno.

### Decisão

**Parte A:** Trocar `loginPopup` → `loginRedirect` em `LoginGate` e `LoginButton`. Adicionar `handleRedirectPromise()` no boot do MSAL (`index.tsx`). Backend `/redirect` agora serve `index.html` (não blank). Após `handleRedirectPromise()` consumir hash `#code=...`, redireciona manualmente para `/` (root do hashRouter).

```ts
// app/frontend/src/index.tsx
await msalInstance.initialize();
const result = await msalInstance.handleRedirectPromise();
if (result?.account) {
  msalInstance.setActiveAccount(result.account);
  window.location.hash = "#/";  // hashRouter root
}
```

```python
# app/backend/app.py
@bp.route("/redirect")
async def redirect():
    return await send_from_directory("static", "index.html")
```

**Parte B (chat dormente):** Rota `/chat` mantida no React Router (Lab Intermediário ativa via Bicep param `enableChat=true` → vira env var `ENABLE_CHAT=true` no Container App backend → exposta em `/auth_setup` pro frontend renderizar nav link). v2.1.0 sai com `enableChat=false` por default — chat ainda não tem pipeline RAG funcional. Aluno vê apenas Tickets + Dashboard até Lab Intermediário ativar prepdocs+RAG.

```bicep
// infra/main.bicep
@description('Enable RAG chat feature. Set to true after Lab Intermediário activates prepdocs+RAG pipeline.')
param enableChat bool = false

// backend Container App env
{ name: 'ENABLE_CHAT', value: string(enableChat) }
```

```ts
// app/frontend/src/components/Sidebar.tsx
{enableChat && <NavLink to="/chat">Chat</NavLink>}
```

### Alternativas avaliadas

| Alternativa (Parte A) | Veredicto |
|---|---|
| Manter `loginPopup` + melhorar error handling (toast em catch) | ❌ Rejeitada — popup blocker é comportamento default em incognito, não-resolvível por código JS no popup-mode. |
| Detectar popup blocker e fallback para redirect | ❌ Rejeitada — overengineering. Redirect funciona em 100% dos browsers, popup em ~70%. |

| Alternativa (Parte B) | Veredicto |
|---|---|
| Deletar rota `/chat` do código | ❌ Rejeitada — Lab Intermediário precisa do code base reusável (RAG UI, citation rendering, tracing). Re-vendorar do upstream depois é trabalho duplicado. |
| `enableChat=true` por default + UI estado vazio ("Chat indisponível, ative prepdocs") | ❌ Rejeitada — exibe feature parcialmente quebrada antes de prepdocs+RAG. Aluno vê "Chat" na nav, clica, vê estado vazio = perda de confiança no template. |
| Lazy load do bundle `/chat` (não baixa JS) | ⚠️ Complementar — implementado via React.lazy mas independente da decisão de mostrar/esconder. |

### Anti-padrões rejeitados

❌ **Silent failures em UX crítico** — login que não funciona sem feedback é o pior bug pedagógico possível (aluno acha que template está quebrado).
❌ **Features visíveis sem implementação completa** — toda nav link clicável tem que entregar o que promete; se não, esconde até estar pronto.

### Files alterados

- `app/frontend/src/index.tsx` — `msalInstance.initialize()` + `handleRedirectPromise()` + redirect manual pra hashRouter root
- `app/frontend/src/components/LoginGate.tsx` — NEW (componente bloqueante com call-to-action)
- `app/frontend/src/components/LoginButton.tsx` — `loginPopup` → `loginRedirect`; remove `console.log` silencioso do catch
- `app/frontend/src/components/Sidebar.tsx` — `{enableChat && <NavLink to="/chat">}`
- `app/frontend/src/authConfig.ts` — exporta `enableChat` lido de `/auth_setup` (Decisão #19)
- `app/backend/app.py` — `/redirect` serve `index.html`; `/auth_setup` expõe `enableChat`
- `infra/main.bicep` — param `enableChat bool = false` + env `ENABLE_CHAT` no Container App backend

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
| 2026-05-03 | @aiox-master (Orion) executando como @devops (Gage) | **Sessão 5 — Decisão #15 cravada (run #9 deploy passou ✅, mas backend crashloop).** Frontend prebuild OK ✅, Provision idempotente OK ✅, Deploy Application OK ✅ (pyodbc 5.2 wheel funcionou), MAS Smoke test falhou em 30s: backend ACA em crashloop com `pyodbc HYT00 Login timeout` durante `aioodbc.connect()` na startup. **3 problemas combinados identificados:** (1) `sql_init.sh` foi SKIPPED silenciosamente em postprovision com `⏭️ USE_SQL_SERVER=false` — porque azd hooks NÃO leem shell env, só azd env file, e workflow setava USE_SQL_SERVER apenas no shell GH Actions; (2) backend MI nunca virou SQL user via `CREATE USER FROM EXTERNAL PROVIDER` → server fecha TCP antes do TDS handshake → aparece como login timeout; (3) smoke test single-shot 30s pega container em state Activating, sem chance de cold start completar. **Fix 3 frentes:** (A) novo step "Persist env to azd" antes de Provision com `azd env set USE_SQL_SERVER` etc; (B) `sql_init.sh` defensive resolution 3-tier (shell env → azd env → default true); (C) smoke test retry loop 15 attempts × 20s (~7min total). **Decisão #16 BACKLOG planejada:** Hybrid Python+.NET para Sessão 6 — mata pyodbc, sinergia D04 Service Bus. ~20-25h, requer @pm épico + @architect design. Lição pedagógica: surpresa #10 (azd hooks só veem azd env, não shell env — use `azd env set` antes de provision). |
| 2026-05-04 | @aiox-master (Orion) orquestrando @dev/@devops/@qa (multi-agent SDC) | **Sessões 6-7 — Epic 06.5c B-PRACTICAL hybrid wiring.** Stories 06.5c.1, 06.5c.2 done (skeleton .NET 10 + 5 endpoints + JWT tenant + dual-tier tests). Story 06.5c.3 partial (Bicep multi-app: 2ª Container App `capps-tickets` + 2ª MI + 2ª image ACR). Bug fixes Dockerfile (.slnx em vez de .sln, exclusão tests/, `language=docker`). 2/9 do epic Done. |
| 2026-05-04 | @aiox-master (Orion) orquestrando 2 SDC chains | **Sessão 8 — AC-4 + AC-5 do epic 06.5c FECHADOS.** Story 06.5c.4 (commit `d0ce22c`, run #24 GREEN): `sql_init.sh` ganha 9 grants object-level scoped exclusivamente para tickets MI (SELECT/INSERT/UPDATE em tbl_tickets, SELECT/INSERT em tbl_comments, REFERENCES em tbl_tenants, EXECUTE em sys.fn_my_permissions) + verificação fail-fast. Verificável via `sys.database_permissions`. Story 06.5c.7 (commit `e5842e6`, run #25 GREEN): Python `/api/tickets/*` agora retorna **HTTP 410 Gone** com header `Link: </api/v2/tickets>; rel="successor-version"` (RFC 8288); REVOKE de `db_datareader` + `db_datawriter` do backend MI — ficou apenas com `SELECT em tbl_tenants`. **Decisão #16 PASSOU DE PLANEJADA → CRAVADA** com trajetória completa Sessões 6-8 documentada. 4/9 stories Done · 2/9 partial · 3/9 pending. Lição pedagógica: least privilege real é granular (object-level), deprecation tem padrão (RFC 8288 Link header), B-PRACTICAL > Big-bang. |
| 2026-05-04 | @aiox-master (Orion) executando docs Sessão 9.1 | **Sessão 9.1 — docs cravadas para gravação slide 13+.** Decisão #16 movida de "Backlog futuro PLANEJADA" → CRAVADA com seção comprehensive (Sessões 6-8 trajetória + estado final epic + defesa arquitetural + 4 lições pedagógicas). README v2 do apex-helpsphere reflete stack real (Container App .NET tickets MI + Python /api/tickets 410 Gone). PARA-O-ALUNO.md criado como entrypoint do aluno (fork → clone → azd up). Slides 13-14 do `azure-retail/02_Apresentação/` corrigidos (URL fork, fork-first workflow, abstração "API serverless" no slide 13 — Opção A). |
| 2026-05-04 | @aiox-master (Orion) executando como @dev/@devops post-Sessão 9.1 | **Sessão 9.2 — backend Python crashloop RESOLVIDO + Decisões #17 e #18 cravadas (commits `7a4ffd5` + `a776cc5`).** Investigação sistemática descobriu que **Surpresa #14 da memória estava equivocada** (Bicep sempre injetou `AZURE_CLIENT_ID` corretamente — linhas 679 + 751 de main.bicep). Root cause real: ODBC Driver 18 + `Authentication=ActiveDirectoryMsi;User Id={clientId}` é incompatível com User-Assigned MI em Linux Container Apps — driver não obtém token AAD corretamente. **Decisão #17 cravada:** refator de `app/backend/repositories/_pool.py` para abordagem MS-recomendada (token via `azure.identity.ManagedIdentityCredential` + injeção via `SQL_COPT_SS_ACCESS_TOKEN` em `attrs_before`). Token cached 50min, Connection Timeout 30s→60s, eager fetch fail-fast. API mantida compatível — repositories não mudaram. **Decisão #18 cravada:** `autoPauseDelay: 60 → -1` em `infra/main.bicep` (DB sempre Online; trade-off ~$15-30/mês vs interrupção em demo gravada). **Story 06.5c.5 fechada** (commit `+a776cc5`): novo workflow `.github/workflows/dotnet-test.yaml` para build + test do tickets-service .NET 10 a cada PR/push em `app/tickets-service/**`. **Validação:** local env do prof + CI fresh provision (run `25349888625`) ambos GREEN nos smokes backend Python + tickets .NET. Epic progress: 5/9 Done (06.5c.1, .2, .4, .6, .7) + 1 Done nesta sessão (.5) → **6/9 Done** + 1 partial (.3) + 2 pending (.8, .9). Lição pedagógica: token explícito > driver-side MSI auth para User-Assigned MI em Linux. |
| 2026-05-02 | @aiox-master (Orion) executando como @devops (Gage) | **Sessão 4 PIVOT — extração para repo público + Actions OIDC.** Decisões #10, #11, #12 cravadas. Após blockers locais (Python 3.14 vs Dockerfile 3.13, pyodbc não compila), professor questionou: por que não Actions desde início? Pivot: descartar approach local, criar repo público dedicado **`tftec-guilherme/apex-helpsphere`**, configurar OIDC via `azd pipeline config` (User Managed Identity `msi-helpsphere-template` + 2 federated credentials), enriquecer `azure-dev.yml` com bicep validation + smoke test + cleanup steps. **6 runs do workflow, cada falha cirurgicamente diferente:** (#1) `.sh` permission denied → `git update-index --chmod=+x`; (#2) mesmo race; (#3) eastus2 sem capacidade SQL/Search → westus3; (#4) SQL DB zoneRedundant não suportado em PAYG → `zoneRedundant: false` explícito; (#5) Cog Services soft-deleted → `RESTORE_COGNITIVE_SERVICES=true`; (#6) RG Deleting (race cleanup); (#6-bis ~run #6 reexecutado) provisionou TODOS os 15 recursos com sucesso em westus3 mas falhou em prepdocs com "cannot write empty image" → guard PDF count em `prepdocs.{sh,ps1}` (Decisão #12). **Sessão pausada antes do run #7** com fix `prepdocs` commitado e pushed (`99e288a` com `[skip ci]` para não trigger workflow enquanto cleanup do RG run #6 ainda em curso). Próxima sessão: aguardar cleanup terminar, disparar `gh workflow run azure-dev.yml --ref main` (run #7), monitor, smoke endpoints, re-baseline pytest, README defesa, handoff @architect *qa-gate. |
| 2026-05-05 | @aiox-master (Orion) orquestrando 11 subagents em 4 ondas (Sessões 9.4-9.5) | **HelpSphere v2.1.0 — Setup Zero-Friction Production-Grade. Decisões #19, #20, #21, #22, #23 cravadas.** Primeiro release com fluxo `azd up` end-to-end FUNCIONAL pra aluno (login real no browser + tickets carregando + dashboard executivo). Resolve 11 surpresas pedagógicas novas descobertas no primeiro teste E2E real do prof. **#19 — Runtime config via `/auth_setup.ticketsApiBase`:** elimina build-time injection `VITE_API_TICKETS_URL` (aluno esquecia → bundle quebrado → 410 Gone genérico). Mesmo bundle serve qualquer environment. **#20 — Audience GUID puro v2 no Bicep do tickets-service:** corrige `IDX10214 Audience validation failed` causado pelo `api://${clientAppId}` legado v1 do template upstream. Param `tokenAudienceFormat` (v1/v2/both, default v2) permite override em migrações. **#21 — Claim `app_tenant_id` aceita 3 formas:** fallback chain em `TenantContext.cs` (.NET) e `_resolve_tenant_id` (Python) cobre forma curta P1+ (`app_tenant_id`), forma curta access token v2 (`extn.app_tenant_id`), forma longa free tier ID token v2 (`extension_<id>_app_tenant_id`). Template funciona em qualquer tier AAD. **#22 — Token explicit injection no SqlClient .NET:** paridade arquitetural com Decisão #17 Python — `Azure.Identity` + `SqlConnection.AccessToken` em vez de `Microsoft.Data.SqlClient.Extensions.Azure 1.0.0` (frágil, incompat com SqlClient 7.x). Mesmo modelo mental para os 2 microservices. **#23 — Login redirect flow + chat dormente:** `loginPopup` → `loginRedirect` (popup blocker engole erros silenciosamente em incognito) + `LoginGate` componente bloqueante + `/redirect` serve `index.html` + `prompt: select_account`. Rota `/chat` mantida no router mas escondida da nav até Lab Intermediário ativar via Bicep param `enableChat=true`. **Bonus entregas:** Dashboard executivo `/` (4 KPIs + 2 charts Recharts via novo endpoint `/api/tickets/stats` com Dapper QueryMultipleAsync 5-selects single round-trip) · Apex Executivo design system (off-white #fafaf7, navy #0c1834, gold #a87b3f, Fraunces+Inter Tight+JetBrains Mono) · Shell layout 240px sidebar + topbar contextual · `auth_init.py` rewrite 716 linhas (two-app pattern + Graph perms automatizadas + Directory Extension + Optional Claim + admin consent automático) · `scripts/preflight.{ps1,sh}` 8 pré-condições · `scripts/setup_search_index.*` cria `gptkbindex` idempotentemente · `.github/workflows/setup-aad.yml` standalone para recriar AAD apps. **Estado pós-release:** 29 surpresas catalogadas (era 18 na v2.0.0), 0 passos manuais no portal Azure, setup zero-friction <15min. |
