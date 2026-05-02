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

## Audit trail

| Data | Autor | Decisão registrada |
|---|---|---|
| 2026-04-27 | @dev (Dex) via @aiox-master orchestration | Decisão #1 (template), Decisão #2 (estratégia preliminar = vendoring full), Decisão #3 (proposta de remoções), Decisão #4 (proposta de adições) |
| 2026-05-01 | @aiox-master (Orion) com confirmação do professor | **Decisão #2 revisada: subset selectivo confirmado** (em vez de vendoring full). Decisão #3 reformulada: lista de exclusão consolidada (não mais "remover depois", agora "não vendorar"). Próximos passos atualizados para Sessão 2.1 (vendoring) + checkpoint antes de Sessão 2.2 (schema/seeds). |
| 2026-05-01 | @aiox-master (Orion) | **Sessão 2.2 concluída: Schema SQL + Seeds completos.** Decisões secundárias documentadas em `CHANGES.md` Sessão 2.2: (a) path `data/` na raiz do helpsphere/ em vez de dentro de app/, (b) GUIDs determinísticos pedagógicos para tenants, (c) `agent-ai` reservado para Lab Final, (d) referências `[KB]` em descriptions em vez de tabela de relacionamentos, (e) tickets Resolved com narrativa de fechamento na própria description. 50 tickets pt-BR + 70 comments + 5 tenants. Próximo: Sessão 2.3 (5 endpoints REST + driver SQL + Bicep p/ Microsoft.Sql/servers/databases). |
| 2026-05-01 | @architect (Aria) review + @aiox-master (Orion) consolidação + professor revisão | **Decisão #5 cravada — Stack Sessão 2.3 production-grade.** Recomendações iniciais Aria foram **revisadas pelo professor para padrão production-grade defensável**: (a) Container Apps (não App Service), (b) tenant isolation via **JWT claim** (não header arbitrário), (c) `@authenticated` **obrigatório** em todos endpoints (não público por default), (d) **Entra Group** como SQL AAD admin (não user pessoal), (e) seeds automático com flag (mantida). Próximo: @dev implementa Sessão 2.3 com essas decisões. |
| 2026-05-02 | @aiox-master (Orion) executando como @dev | **Sessão 3 concluída em 4 batches (B1-B4).** Decisões #6, #7, #8 cravadas: (#6) Fluent UI v9 preservado + paleta Apex via CSS variables — defesa: rebase futuro vs upstream trivial; (#7) `/`=Chat upstream **preservado** + 2 rotas lazy `/tickets` e `/tickets/:ticketId` adicionadas — defesa: RAG do MS necessário no Lab Inter/Final; (#8) `tenant_id` resolvido server-side via JWT, frontend exibe read-only — defesa: zero caminho de bypass, audit-friendly. ~2.840 linhas adicionadas em 4 commits + 3 PNGs sintéticos pt-BR para Vision OCR. Próximo: Sessão 4 (smoke `azd up` + re-baseline pytest snapshots + defesa arquitetural completa no README + handoff para @architect *qa-gate). |
| 2026-05-02 | @aiox-master (Orion) executando como @dev | **Sessão 3.5 concluída — bug fix Bicep SQL Server AVM compatibility.** Decisão #9 cravada. 5 patches no `infra/main.bicep` (P1-P4) + audit trail (P5). Bicep compila ✅. Lição aprendida documentada: CodeRabbit não roda `bicep build` — recomendação backlog: adicionar step CI. Próximo: retomar Sessão 4 a partir de S4.2 (env vars adicionais identificadas: `AZURE_DOCUMENTINTELLIGENCE_LOCATION`, `AZURE_OPENAI_LOCATION`). |
