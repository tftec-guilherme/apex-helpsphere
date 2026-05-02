# CHANGES.md — HelpSphere vs `Azure-Samples/azure-search-openai-demo`

> Diff resumido entre o `helpsphere/` desta disciplina e o template Microsoft upstream do qual foi forkado.
>
> **Audiência:** arquiteto sênior auditando a defesa técnica + revisor anual do template upstream.
> **Última atualização:** 2026-05-01
> **Version-anchor:** Q2-2026

---

## Atribuição upstream

| Campo | Valor |
|---|---|
| Repo upstream | `Azure-Samples/azure-search-openai-demo` |
| Commit SHA forkado | `95ce0c9484b338b3819914d0c1a1fa8d19a3ff9b` |
| Data do fork | 2026-04-27 |
| Data deste vendoring | 2026-05-01 |
| License upstream | MIT (preservada — ver `LICENSE.upstream`) |
| Estratégia de fork | Vendoring **subset selectivo** (ver `DECISION-LOG.md` Decisão #2) |

---

## Sessão 2.1 — Vendoring inicial subset (2026-05-01)

### O que foi vendorado (whitelist) — 7.1MB total

| Path | Tamanho | Origem | Razão para incluir |
|---|---|---|---|
| `app/` | 1.5M | `app/` upstream | Código aplicação (backend Python Quart + frontend TS) — base que vamos customizar com domínio HelpSphere |
| `infra/` | 289K | `infra/` upstream | Bicep modular — defesa arquitetural Microsoft canônica (Managed Identity, App Insights, App Service, AOAI, AI Search) |
| `.github/` | 84K | `.github/` upstream | CI workflows GitHub Actions já testados pela MS |
| `scripts/` | 129K | `scripts/` upstream | azd hooks (prepdocs, auth setup, role assignment, ACL management) — necessários para `azd up` funcionar |
| `tests/` | 5.1M | `tests/` upstream | Framework pytest base + snapshots + fixtures. **Snapshots serão invalidados** quando customizarmos UI; re-baseline planejado para Sessão 4. |
| `azure.yaml` | 4K | upstream | Orquestração `azd up` — necessário |
| `pyproject.toml` | 1K | upstream | Configuração Python projeto |
| `requirements-dev.txt` | 1K | upstream | Dependências dev travadas |
| `LICENSE.upstream` | 1K | `LICENSE` upstream renomeado | MIT — atribuição obrigatória. Renomeado para `.upstream` para deixar explícito que é do template MS, não do azure-retail. |
| `SECURITY.md` | 3K | upstream | Boas práticas de segurança MS |
| `CONTRIBUTING.md` | 5K | upstream | Convenções de contribuição MS |
| `AGENTS.upstream.md` | 12K | `AGENTS.md` upstream renomeado | Code map do template MS (extremamente útil para orientação). Renomeado para `.upstream` para deixar claro que descreve o código original — nossas customizações pedagógicas vivem em outro lugar. |
| `.gitignore` | 2K | upstream | Padrão Python+TS MS |
| `.gitattributes` | <1K | upstream | LF normalization MS |

### O que NÃO foi vendorado (blacklist explícita) — 68MB economizados

| Path | Tamanho upstream | Razão para excluir |
|---|---|---|
| `.git/` | 22M | Histórico git do template — preservaríamos via SHA documentado, não via git history embarcado |
| `evals/` | 32M | Eval framework — Lab Avançado da D06 cobre observabilidade/evals separadamente. Se necessário em sessão futura, re-vendorar pontual. |
| `data/` | 4.4M | Documentos de demo "Zava" — irrelevante para HelpSphere/Apex. Substituiremos por `data/seed/` HelpSphere na Sessão 2.2. |
| `docs/` | 5.2M | Docs do upstream — temos nosso próprio `README.md` e `DECISION-LOG.md` com defesa arquitetural HelpSphere. Re-vendorar pontual se aluno precisar de docs específicos. |
| `.azdo/` | 8K | Azure DevOps pipelines — usamos GitHub Actions |
| `.devcontainer/` | 4K | Devcontainer config — não estritamente necessário para `azd up`. Adicionar sob demanda. |
| `.vscode/` | — | Config IDE local — manter limpo |
| `locustfile.py` | 3K | Load test — fora do escopo da 06.5a (production-grade visível ≠ load test) |
| `package-lock.json` (root) | <1K | npm root lock vazio — frontend tem seu próprio em `app/frontend/` |
| `ps-rule.yaml` | <1K | Azure Policy as Code — revisitar em sessão futura se necessário |
| `.markdownlint-cli2.jsonc` | <1K | Lint markdown opcional — adicionar sob demanda |
| `.pre-commit-config.yaml` | 1K | Pre-commit hooks opcional — usaremos hooks AIOX nativos |
| `README.md` (upstream) | 20K | Já temos nosso próprio `README.md` com defesa arquitetural HelpSphere |

### Snapshots tests — nota operacional

Os snapshots em `tests/snapshots/` (~1.3MB) refletem o estado upstream do template. **Serão invalidados** quando customizarmos:
- Branding/tema → snapshots de UI quebram
- Schema SQL HelpSphere → snapshots de payloads/responses quebram
- 5 endpoints HelpSphere (em vez dos endpoints AI Search MS) → snapshots de testes funcionais quebram

**Plano:** rodar pytest na Sessão 4 com `--snapshot-update` para re-baseline após customizações. Documentar quais snapshots sobreviveram (provavelmente nenhum) vs quais foram regenerados.

---

## Customizações HelpSphere planejadas (sessões futuras)

| Sessão | Customização | Resultado |
|---|---|---|
| 2.2 | Schema SQL HelpSphere (3 tabelas) + 50 tickets seed pt-BR | `app/data/migrations/` + `app/data/seed/` HelpSphere |
| 2.2 | 5 endpoints REST HelpSphere | `app/backend/` adaptado p/ tickets CRUD + suggest stub |
| 3 | 2 páginas frontend | `app/frontend/src/pages/` (`/tickets`, `/tickets/{id}`) |
| 3 | Branding HelpSphere/Apex | nomes RG, logos fictícios, paleta Apex |
| 3 | 3-5 PNGs mock para Vision OCR | `app/data/mocks/screenshots-mock/` |
| 4 | Smoke test `azd up` em conta limpa | < 15min, custo ≤ R$ 10 |
| 4 | Re-baseline pytest snapshots | `tests/snapshots/` regenerados pós-customização |
| 4 | Defesa arquitetural completa no README | seção "Por que essa stack" para arquiteto sênior |

---

## Plano de revisão anual vs upstream

**Frequência:** anual (Q2 cada ano).

**Procedimento sugerido (operacional):**
1. Comparar SHA atual deste fork (`95ce0c9...`) com `Azure-Samples/azure-search-openai-demo` HEAD
2. `git diff` filtrado pelos paths da whitelist (Sessão 2.1) — ver mudanças relevantes
3. Avaliar critical fixes (security, breaking changes em deps)
4. Decidir: rebase parcial ou stay frozen — registrar nova versão-âncora (ex: Q2-2027) no header
5. Atualizar este CHANGES.md com nova entry de sessão

**Trigger fora do schedule anual:**
- CVE crítica em dep do `requirements-dev.txt` ou `pyproject.toml`
- Breaking change em `azd` CLI que quebra `azure.yaml`
- Microsoft anuncia retire de algum dos serviços Azure usados no Bicep

---

## Sessão 2.2 — Schema SQL HelpSphere + seeds (2026-05-01)

### Adicionado

| Path novo | Tamanho | Descrição |
|---|---|---|
| `data/README.md` | 4K | Guia de execução das migrations + distribuição estatística + lista de PDFs cross-referenciados pela 06.7 |
| `data/migrations/001_initial_schema.sql` | 5K | Schema enxuto: 3 tabelas (`tbl_tenants`, `tbl_tickets`, `tbl_comments`) + 2 índices não-clustered + 1 trigger UTC. T-SQL idempotente. |
| `data/seed/tenants.sql` | 1K | 5 tenants Apex fictícios (Mercado, Tech, Moda, Casa, Logística) com GUIDs determinísticos pedagógicos. MERGE idempotente. |
| `data/seed/tickets.sql` | 32K | **50 tickets pt-BR bem modelados** (5 categorias × 10). Distribuição correta de status (40/30/20/10) e priority (30/50/16/4). Cenários realistas de retail brasileiro (NF-e, SPED, eSocial, PIX, ANTT, CAT). Sem AI-slop. 11 tickets têm âncora explícita `[KB]` p/ PDFs futuros da 06.7. |
| `data/seed/comments.sql` | 22K | **70 comments** coerentes com narrativa (ratio 1.4 vs target ~1.5). 6 personas fictícias consistentes (Diego, Marina, Carla, Bruno, Letícia, Roberto) + reservado `agent-ai` para Lab Final. |

### Decisões da Sessão 2.2

1. **Path `helpsphere/data/`** (raiz) escolhido em vez de `helpsphere/app/data/` — `data/` é orthogonal ao serviço deployado em `app/backend/`. Migrations + seeds não são código de aplicação, são governance de banco.
2. **GUIDs determinísticos** (`11111111-...`, `22222222-...`) usados nos tenants — escolha pedagógica explicitamente declarada no seed. Em produção real, default da coluna usa `NEWID()`.
3. **`agent-ai` reservado** como author placeholder — comments de IA serão inseridos pelo Lab Final ao processar tickets selecionados (não pré-popular para preservar semântica "IA processou X tickets").
4. **`[KB]` âncoras** em descriptions de 11 tickets (em vez de tabela separada de relacionamentos) — leve, legível, não bloqueia evolução do schema. Se Lab Final precisar de relação formal, criar `tbl_ticket_kb_refs` em migration futura.
5. **Tickets em `Resolved` têm narrativa de fechamento** dentro da própria description — fica claro que estão fechados sem precisar consultar comments. Production-pattern visível para auditor sênior.

### Não-fixes deliberados (gap atual)

- ⚠️ **Endpoints REST consumindo o schema:** Sessão 2.3
- ⚠️ **App não conecta ao SQL ainda:** o template MS upstream usa AI Search como datasource. Sessão 2.3 adiciona driver SQL (aioodbc) + connection pool + repository layer. Bicep do `infra/` ainda precisa receber recurso `Microsoft.Sql/servers/databases` (Sessão 2.3 ou 4).
- ⚠️ **Snapshots `tests/snapshots/`** continuam congelados em referencial upstream — re-baseline planejado para Sessão 4 quando todos endpoints + frontend estiverem customizados.

---

## Sessão 2.3 — Stack runtime + endpoints REST + Bicep SQL (✅ implementada — 2026-05-01)

### Decisões cravadas (ver `DECISION-LOG.md` Decisão #5)

| Aspecto | Decisão | Production-grade rationale |
|---|---|---|
| Deployment target | Container Apps (ACA) | Padrão MS canônico 2026 + Dockerfile entrega ODBC limpo |
| Tenant isolation | JWT claim `app_tenant_id` | Validada via Entra signature, sem forjabilidade |
| Endpoints auth | `@authenticated` em TODOS `/api/tickets/*` | `AZURE_USE_AUTHENTICATION=true` default |
| SQL AAD admin | Entra Group `aad-helpsphere-sql-admins` | Turnover-resilient, audit-friendly, CAF-aligned |
| Seeds em `azd up` | Automático com `AZURE_LOAD_SEED_DATA=true` | < 15min para ambiente populado |

### Escopo planejado (a entregar pelo @dev)

| Path | Mudança | Tipo |
|---|---|---|
| `app/backend/requirements.in` | + `aioodbc>=0.5.0` + `pyodbc>=5.1.0` | adição |
| `app/backend/requirements.txt` | regerar via `uv pip compile` | regenerado |
| `app/backend/Dockerfile` | + `RUN apt-get install -y msodbcsql18 unixodbc-dev` (após base image setup) | modificação |
| `app/backend/repositories/__init__.py` | novo — exporta `TicketsRepository`, `CommentsRepository`, `TenantsRepository` | novo arquivo |
| `app/backend/repositories/tickets.py` | classe async com métodos `list/get_with_comments/patch` (filtro tenant_id obrigatório via JWT claim) | novo arquivo |
| `app/backend/repositories/comments.py` | classe async com `add(ticket_id, author, content)` + `list_by_ticket(ticket_id)` | novo arquivo |
| `app/backend/repositories/tenants.py` | classe async com `get_by_id(tenant_id)` + `validate_user_tenant(jwt_claim)` | novo arquivo |
| `app/backend/repositories/_pool.py` | `aioodbc.create_pool(pool_recycle=3000, autocommit=True)` setup com Managed Identity AAD | novo arquivo |
| `app/backend/blueprints/tickets.py` | Quart Blueprint com **5 endpoints `@authenticated`**: `GET /api/tickets`, `GET /api/tickets/{id}`, `POST /api/tickets/{id}/comments`, `PATCH /api/tickets/{id}`, `POST /api/tickets/{id}/suggest` (501 stub para Lab Inter) | novo arquivo |
| `app/backend/app.py` | registrar blueprint + injetar repositories no `setup_clients` (espelhando BlobManager) | modificação |
| `app/backend/config.py` | + `CONFIG_TICKETS_REPO`, `CONFIG_COMMENTS_REPO`, `CONFIG_TENANTS_REPO`, `CONFIG_SQL_POOL` | adição constants |
| `infra/main.bicep` | + módulo `br/public:avm/res/sql/server:0.10.0` (DB Serverless GP_S_Gen5_2 + autoPause 60min) + admin `aad-helpsphere-sql-admins` (Entra Group) | adição módulo |
| `infra/main.parameters.json` | + parâmetros SQL Server | adição |
| `scripts/sql_init.py` | novo — postprovision hook: CREATE USER backend MI FROM EXTERNAL PROVIDER + GRANT roles + executar migrations + seeds (se flag) | novo arquivo |
| `azure.yaml` | + hook `postprovision` apontando para `scripts/sql_init.py` | modificação |
| `tests/test_tickets_repository.py` | unit tests com mock de pool aioodbc | novo arquivo |
| `tests/test_tickets_endpoints.py` | integration tests com Quart test client + JWT mock | novo arquivo |

### Smoke test final esperado

```bash
azd env set AZURE_USE_AUTHENTICATION true
azd env set AZURE_LOAD_SEED_DATA true
azd up
# Após ~12min: HelpSphere rodando em ACA, SQL populada com 5 tenants + 50 tickets + 70 comments
# Login Entra obrigatório no frontend; chamada autenticada a /api/tickets retorna lista filtrada por tenant
```

### Implementação efetiva (commits)

| Batch | Commit | Escopo | Linhas |
|---|---|---|---|
| Decisões | `cf3861b` | DECISION-LOG #5 + CHANGES.md planejamento | 87 |
| B1 | `f1b4cb9` | requirements.in/txt + Dockerfile (msodbcsql18) + repositories/ (5 arquivos novos: _pool, tickets, comments, tenants, __init__) + config.py constants + app.py injection | 496 |
| B2 | `d025922` | blueprints/tickets.py (6 endpoints `@authenticated`, Pydantic body validation) + app.py registra blueprint | 308 |
| B3 | `44d4fed` | infra/main.bicep (AVM SQL Server `br/public:avm/res/sql/server:0.10.0` + admin Entra Group + outputs) + main.parameters.json + scripts/sql_init.{py,sh,ps1} + azure.yaml estendido | 303 |
| B4 | `cb447e1` | tests/test_tickets_repository.py (14 unit tests com MockPool) + tests/test_tickets_endpoints.py (17 integration tests com Quart minimal app + AuthHelper mockado) | 768 |
| **Total Sessão 2.3** | | | **~1.962** |

---

## Sessão 3 — Branding HelpSphere/Apex + frontend tickets + mocks Vision OCR (✅ implementada — 2026-05-02)

### Decisões cravadas (ver `DECISION-LOG.md` Decisões #6, #7, #8)

| Aspecto | Decisão | Defesa para arquiteto sênior |
|---|---|---|
| Design system | Fluent UI v9 preservado + paleta Apex via CSS variables | Auditor reconhece padrão MS canônico em 30s; rebase vs upstream trivial |
| Roteamento | `/` Chat upstream **preservado** + 2 rotas lazy adicionadas | RAG do MS é necessário nos Labs Intermediário/Final |
| Multi-tenancy no client | `tenant_id` resolvido server-side via JWT, exibido read-only | Zero caminho de bypass; impossível forjar tenant via cliente |

### B1 — Branding HelpSphere/Apex (commit `02b3eca`, 9 arquivos, +319/-102)

| Arquivo | Mudança |
|---|---|
| `app/frontend/index.html` | `<title>` HelpSphere, lang pt-BR, meta description |
| `app/frontend/src/index.css` | Tokens `:root { --apex-* }` (paleta + radius + shadow) |
| `app/frontend/src/locales/ptBR/translation.json` | Bloco `helpsphere.*` com strings de tickets/filters/detail (preserva bloco RAG/Chat upstream) |
| `app/frontend/src/locales/en/translation.json` | Idem (fallback) |
| `app/frontend/src/components/HelpSphereLogo/` | SVG inline 32×32 com `currentColor` (esfera + meridianos) — novo |
| `app/frontend/src/pages/layout/Layout.tsx` | Logo + tagline + NavLink `/` e `/tickets` + `<Helmet>` para `<title>` dinâmico |
| `app/frontend/src/pages/layout/Layout.module.css` | Header com `var(--apex-primary)`, nav responsiva, hover/active states |
| `azure.yaml` | `name: helpsphere-template` (visível em `azd config show`); `metadata.template` preservado como linkagem semântica ao upstream |

### B2 — Página `/tickets` (lista) + API client (commit `69ee226`, 13 arquivos, +953)

| Arquivo | Mudança |
|---|---|
| `app/frontend/src/api/ticketsModels.ts` | Types `Ticket`, `TicketComment`, `TicketDetail`, `Tenant`, `TicketsListResponse`, `TicketsListFilters`, `TicketPatchBody`. Const arrays `TICKET_STATUSES/PRIORITIES/CATEGORIES` para iteração nos dropdowns. snake_case preservado (espelha contract do backend). |
| `app/frontend/src/api/tickets.ts` | 6 funções async: `listTicketsApi`, `getTicketApi`, `addCommentApi`, `patchTicketApi`, `suggestTicketApi` (501 esperado), `getMyTenantApi`. Bearer token via `getHeaders()` upstream. Erros HTTP leem body do backend (`error`/`detail`/`description`) com fallback. |
| `app/frontend/src/api/index.ts` | Re-exporta tickets + ticketsModels |
| `app/frontend/src/components/StatusBadge/` | Dot colorido + label i18n; tokens `--apex-status-*` (open/inprogress/resolved/escalated) |
| `app/frontend/src/components/PriorityBadge/` | Pill colorido com tokens `--apex-priority-*` (low/medium/high/critical) |
| `app/frontend/src/pages/tickets/Tickets.tsx` | URL state via `useSearchParams` (deep-linking); `useEffect` com cancellation guard contra race conditions; busca client-side por `subject` ou `ticket_id` sobre os items da página; paginação `Previous`/`Next`; row `tabIndex+role=link` para teclado; Skeleton ocioso em 1ª carga |
| `app/frontend/src/pages/tickets/Tickets.module.css` | Tabela semântica + paleta Apex; mobile responsive (esconde colId/colDate <768px) |
| `app/frontend/src/pages/tickets/TicketDetail.tsx` | Stub mínimo (substituído em B3) — necessário para rota `/tickets/:ticketId` não quebrar build |
| `app/frontend/src/index.tsx` | 2 rotas lazy (`/tickets` + `/tickets/:ticketId`) filhas do `LayoutWrapper` |

### B3 — Página `/tickets/{id}` (detail completo, commit `5487bf6`, 2 arquivos, +712/-5)

| Arquivo | Mudança |
|---|---|
| `app/frontend/src/pages/tickets/TicketDetail.tsx` | Layout grid 2 colunas (description+comments na main, metadata+actions na aside, mobile colapsa). Funcionalidades: GET ticket (LEFT JOIN no backend evita N+1), POST comment com append otimístico + reset, PATCH status via Dropdown, POST suggest exibe payload didático do stub 501, ConfidenceBar com `role=meter` + a11y, parse seguro de `attachment_blob_paths`, Skeleton + Error MessageBar com retry. |
| `app/frontend/src/pages/tickets/TicketDetail.module.css` | Cards com shadow-sm/border/radius; thread de comments em surface-alt; metadata `<dl>` grid; ConfidenceBar usa `--apex-status-resolved` (verde=alto); responsive 2col→1col em <960px |

### B4 — 3 PNGs mock Vision OCR + script Pillow (commit `4c8e8d5`, 5 arquivos, +456)

| Arquivo | Mudança |
|---|---|
| `helpsphere/data/mocks/generate_mocks.py` | Gerador determinístico via Pillow com fallback chain Arial/Segoe UI/DejaVu/default. 3 funções (uma por imagem). Reutilizável para gerar +2 mocks. |
| `helpsphere/data/mocks/screenshots-mock/pos-error-001.png` | 1280×720, ~62KB. Erro SITEF `0xFF-SITEF-7841`, valor R$ 247,90, NSU 84291734, ações F1-F4. Texto verde monospace em fundo dark. |
| `helpsphere/data/mocks/screenshots-mock/nfce-receipt-001.png` | 480×1024, ~41KB. Cupom fiscal NFC-e completo: CNPJ 12.345.678/0012-34, IE 110.123.456.789, série/número, 5 itens com EAN, total R$ 111,74, chave 44 dígitos formatada, QR placeholder, protocolo SEFAZ-SP. Material rico para Document Intelligence layout model. |
| `helpsphere/data/mocks/screenshots-mock/sap-screen-001.png` | 1366×768, ~68KB. SAP GUI FB03 — empresa Apex Group APX1, doc 2026-FI-094812, 3 posições com conta razão + centro custo + valor + DC, workflow WF-FI-7782 em status "Em aprovação". |
| `helpsphere/data/mocks/README.md` | Declara natureza sintética, lista campos extratíveis por OCR, anti-padrões (sem AI generativo no repo), plano de substituição na Story 06.6 (screenshots reais pós-Done). |

### Decisões secundárias da Sessão 3 (não cravam Decisão # nova)

1. **`Helmet` para `<title>`** dinâmico via i18n. Já dep do upstream (`react-helmet-async`).
2. **`createHashRouter` mantido** (não `createBrowserRouter`) — compatibilidade com static hosting do Container Apps sem `try_files` config no nginx.
3. **CSS Modules** para componentes HelpSphere — coerência com o resto do `app/frontend/`.
4. **`<NavLink>` em vez de `<Link>`** para nav header — feedback visual `active` automático.
5. **Search client-side** em `/tickets` — sobre os items da página atual (server filter já reduziu o dataset). Production-pattern aceitável para datasets <100 items.
6. **PATCH status no detail re-aproveita comments** do estado anterior (resposta do backend não traz comments). Production-pattern: API contract minimal (PATCH retorna ticket sem comments) + client merge.
7. **Confidence score render**: `null` → texto "noConfidence" italic; valor numérico → barra horizontal 0-100%. Verde por convenção (alto = bom).

### Não-fixes deliberados (gap atual — Sessão 4)

- ⚠️ **Smoke `azd up` em conta Azure limpa** ainda não executado (planejado Sessão 4)
- ⚠️ **Pytest snapshots upstream invalidados** após customizações UI — re-baseline planejado para Sessão 4 com `--snapshot-update`
- ⚠️ **Naming CAF detalhado dos recursos no Bicep** — minimal change na Sessão 3 (`azure.yaml name`); revisão completa de naming defensável fica para Sessão 4 junto com smoke
- ⚠️ **Defesa arquitetural escrita no README.md** ainda placeholder — completar na Sessão 4 com rationale de cada decisão (#1-#8)
- ⚠️ **Outros 8 locales** (da/es/fr/ja/nl/tr/it/pl) não receberam strings `helpsphere.*` — fallback `en` cobre. Adicionar conforme demanda.

### Implementação efetiva (commits)

| Batch | Commit | Escopo | Linhas |
|---|---|---|---|
| B1 | `02b3eca` | Branding HelpSphere/Apex frontend (CSS variables, i18n, Layout, logo SVG, azure.yaml name) | 319+ / 102- |
| B2 | `69ee226` | Página `/tickets` lista + API client tickets + Status/PriorityBadge | 953 |
| B3 | `5487bf6` | Página `/tickets/{id}` detail completa | 712 / 5- |
| B4 | `4c8e8d5` | 3 PNGs mock + script Pillow + README mocks | 456 |
| **Total Sessão 3** | | | **~2.840 linhas** |

---

## Audit trail

| Data | Sessão | Autor | Ação |
|---|---|---|---|
| 2026-05-01 | 2.1 | @aiox-master (Orion) com confirmação do professor | Vendoring inicial subset selectivo do template MS @ SHA `95ce0c9...` — 7.1MB total, 68MB economizados vs vendoring full |
| 2026-05-01 | 2.2 | @aiox-master (Orion) | Schema SQL HelpSphere completo (3 tabelas + 2 índices + 1 trigger) + 5 tenants Apex + 50 tickets pt-BR bem modelados + 70 comments coerentes + README da camada `data/`. ~64K SQL adicionados. Pronto para Sessão 2.3 (endpoints REST). |
| 2026-05-01 | 2.3 | @aiox-master (Orion) executando como @dev | **Sessão 2.3 implementada em 4 batches.** Decisão #5 production-grade do DECISION-LOG aplicada integralmente: Container Apps, JWT claim `app_tenant_id` para tenant isolation (NUNCA fallback silencioso), `@authenticated` obrigatório em todos `/api/tickets/*`, Entra Group como SQL AAD admin, seeds automáticos com `AZURE_LOAD_SEED_DATA=true`. Multi-tenancy enforced em TODOS os métodos do repository (WHERE tenant_id = ?). Anti-spoofing: author de comments vem do JWT `name`, não do body. Anti-N+1: `get_with_comments` em UMA query LEFT JOIN. ~1.962 linhas em 5 commits (`cf3861b`, `f1b4cb9`, `d025922`, `44d4fed`, `cb447e1`). Próxima sessão = 3 (branding HelpSphere/Apex + 2 páginas frontend + mocks Vision OCR). |
| 2026-05-02 | 3 | @aiox-master (Orion) executando como @dev | **Sessão 3 implementada em 4 batches (B1-B4).** Decisões #6, #7, #8 do DECISION-LOG aplicadas: Fluent UI v9 + paleta Apex via CSS variables (preserva pattern MS canônico, defendido em comitê), `/` Chat preservado + 2 rotas lazy `/tickets` e `/tickets/:ticketId`, multi-tenancy resolvido server-side via JWT (zero bypass no client). ~2.840 linhas em 4 commits (`02b3eca`, `69ee226`, `5487bf6`, `4c8e8d5`). 3 PNGs sintéticos pt-BR (POS error, NFC-e receipt, SAP FI screen — 170KB total) prontos para Vision OCR no Lab Intermediário. Próxima sessão = 4 (smoke `azd up` em conta limpa + re-baseline pytest snapshots + defesa arquitetural completa no README + handoff `@architect *qa-gate`). |

