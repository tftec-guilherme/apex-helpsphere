# Changelog — HelpSphere Template

All notable changes to this template are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Note:** Architectural decisions are catalogued separately in [`DECISION-LOG.md`](./DECISION-LOG.md). Pedagogical surprises are catalogued in [`PARA-O-ALUNO.md`](./PARA-O-ALUNO.md).

---

## [Unreleased]

### Added — Story 06.10 Lab Intermediário Parte 8 (RAG ChatPanel + proxy)

- **Bicep params** — `ragEnabled` (bool, default `false`), `ragFunctionUrl` (string), `ragFunctionKey` (secure string). Propagados como env vars `RAG_ENABLED` / `RAG_FUNCTION_URL` / `RAG_FUNCTION_KEY` no Container App backend (e nos AppSettings do App Service quando `deploymentTarget=appservice`).
- **Backend `/chat/rag`** — novo blueprint (`app/backend/blueprints/rag_chat.py`) com proxy autenticado para a Function App externa de RAG criada na Parte 7 do Lab Intermediário. Gated por `RAG_ENABLED`; quando `false` retorna 503 didático. Quando `true`, faz POST para `${RAG_FUNCTION_URL}/api/tickets/eval/suggest` com `x-functions-key` e propaga JSON `{suggested_response, confidence, citations}`. Valida `app_tenant_id` (multi-tenant safe). Erros upstream propagam como 502.
- **Backend `/auth_setup`** — agora expõe `ragEnabled` (lido de env `RAG_ENABLED`), espelhando o padrão de `enableChat`.
- **Frontend `<ChatPanel />`** — painel flutuante (canto inferior direito) com formulário simples (ticket # + descrição), result box com sugestão + confidence + citações. Usa design tokens Apex Executivo. Inclui botão minimizar (vira FAB redondo) e fechar.
- **Flag de runtime `?chat=1`** — Shell detecta query param tanto em `window.location.search` quanto em `location.hash` (HashRouter), e monta `<ChatPanel />` apenas quando `ragEnabled && enableChat && ?chat=1` simultaneamente — zero overhead nos demais casos.
- **Tests** — `tests/test_rag_chat.py` com 12 cases (503 disabled, 415 não-JSON, 400 body inválido, 403 sem tenant claim, 500 quando URL ausente, 200/502 proxy success/error, trailing slash strip).

### Notes

- Endpoint `/api/tickets/{id}/suggest` permanece como stub 501 (path complementar para extensões futuras dentro do contexto do ticket); o proxy RAG vive em `/chat/rag` para evitar conflito com o `/chat` upstream do `azure-search-openai-demo`.
- Guia do Lab Intermediário (linha 1796) cita `POST $BACKEND_URI/chat` — atualizar para `/chat/rag` na próxima passada de doc.

---

## [v2.1.0] — 2026-05-05

### Sessões 9.4-9.5 — Setup Zero-Friction Production-Grade

Primeiro release com fluxo `azd up` end-to-end FUNCIONAL pra aluno (login real no browser + tickets carregando + dashboard executivo). Resolve **11 surpresas pedagógicas novas** descobertas no primeiro teste E2E real.

### Added

- **`<LoginGate>` componente** — tela de login bloqueante com call-to-action explícito antes de qualquer rota; substitui falha silenciosa do botão login no topbar
- **`BrandMark` SVG** — logomark "esfera concêntrica" production-grade (navy + accent gold)
- **Dashboard executivo `/`** — 4 KPI cards + 2 charts Recharts (Volume por categoria, Volume 7 dias) consumindo novo endpoint `/api/tickets/stats` (.NET tickets-service)
- **Apex Executivo design system** — paleta refinada (off-white #fafaf7, navy #0c1834, accent gold #a87b3f), tipografia editorial (Fraunces display + Inter Tight body + JetBrains Mono code)
- **Shell layout** — sidebar 240px com nav sections (Operação/Inteligência) + topbar contextual com kicker accent + h1 + subtitle dinâmico por rota
- **Tickets list redesign** — TicketRow grid 7-cols, filtros sticky pills + selects + search, EmptyState com InboxIcon, paginação numérica
- **TicketDetail redesign** — layout 2-col, sidebar SLA countdown live, CommentTimeline vertical, status switcher pills
- **Endpoint `/api/tickets/stats`** — agregações com Dapper QueryMultipleAsync (5 selects single round-trip), `WHERE tenant_id` em todas (RLS-like)
- **Bicep params parametrizados** — `pythonVersion`, `additionalCorsOrigins`, `skipPrepdocs`, `enableChat`, `tokenAudienceFormat`, `sqlAutoPauseDelay`
- **`scripts/preflight.{ps1,sh}`** — pré-validação de 8 pré-condições (~30s)
- **`scripts/setup_search_index.{py,ps1,sh}`** — cria `gptkbindex` idempotentemente no postprovision (antes de `prepdocs`)
- **`scripts/run_prepdocs.{ps1,sh}`** — wrapper honrando `SKIP_PREPDOCS=true`
- **`.github/workflows/setup-aad.yml`** — workflow standalone `workflow_dispatch` para recriar AAD apps
- **`.python-version`** (3.13)

### Changed

- **`auth_init.py`** rewrite (716 linhas): two-app pattern (Server + Client), Microsoft Graph perms automatizadas, Directory Extension `app_tenant_id`, Optional Claim, `accessTokenAcceptedVersion=2`, admin consent automático para Graph + Server scopes
- **`auth_update.py`** rewrite (165 linhas): atualiza redirect URIs com FQDN do env, seta valor extension no user atual (Apex Mercado tenant default `11111111-...`)
- **`SqlConnectionFactory.cs`** refactor: token explicit injection via `Azure.Identity` (paridade Decisão #17 Python). Bypassa SqlClient auth provider system.
- **`TenantContext.cs` (.NET) + `_resolve_tenant_id` (Python)**: aceitam as 3 formas de claim (`app_tenant_id`, `extn.app_tenant_id`, `extension_<id>_app_tenant_id`)
- **Backend `/auth_setup`**: expõe `ticketsApiBase` (runtime config) + `enableChat` (lido de env)
- **Backend `/redirect`**: serve `index.html` (não blank) — necessário para `loginRedirect` flow
- **Frontend MSAL**: `loginPopup` → `loginRedirect` + `handleRedirectPromise()` no boot + `prompt: select_account`
- **Bicep `tickets-service`**: `AzureAd__Audience=serverAppId` (GUID puro v2), `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false`, CORS allowedOrigins via `union(legacy, [backendFqdn], additionalCorsOrigins)`
- **Bicep backend**: `pythonVersion` ligado a param (era hardcoded 3.11)
- **Bicep SQL**: `autoPauseDelay` ligado a param `sqlAutoPauseDelay`
- **Dockerfile tickets-service**: `apk add icu-libs icu-data-full` + `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false`
- **`azure.yaml` postprovision**: `setup_search_index` rodando ANTES de `prepdocs`, `prepdocs` virou wrapper `run_prepdocs` honrando `SKIP_PREPDOCS`
- **`Microsoft.Data.SqlClient.Extensions.Azure`**: removido (frágil); substituído por `Azure.Identity 1.13.1`

### Removed

- Build-time injection `VITE_API_TICKETS_URL` no `azure.yaml` prebuild hook (substituído por runtime config)
- Chat link da nav lateral (rota mantida; ativada via Bicep `enableChat=true` no Lab Intermediário)
- `console.log` silencioso no `LoginButton.catch` (substituído por `loginRedirect` + `handleRedirectPromise` no boot)

### Fixed

- **AADSTS90009** (single-app self-token): two-app pattern obrigatório implementado
- **AADSTS650056** (Microsoft Graph perms missing): Client App declara perms + admin consent automático
- **IDX10214** (audience validation failed): Bicep usa GUID puro v2
- **`Globalization Invariant Mode is not supported`**: Alpine .NET com `icu-libs`
- **`Cannot find an authentication provider for 'ActiveDirectoryManagedIdentity'`**: token explicit injection
- **HTTP 410 Gone em `/api/tickets`**: runtime config `ticketsApiBase` no `/auth_setup`
- **Login silenciosamente quebrado em incognito**: `loginRedirect` + `LoginGate` componente bloqueante
- **`/redirect` blank em redirect flow**: rota agora serve `index.html`
- **Token MSAL cached entre contas**: `prompt: select_account` força seletor sempre
- **Backend Python crashloop sem `gptkbindex`**: `setup_search_index.py` no postprovision

### Documentation

- `PARA-O-ALUNO.md`: 11 surpresas novas (#19-#29) + Quick Start passo 0 (preflight) + nota chat dormente + nota `Application.ReadWrite.All` para CI
- `DECISION-LOG.md`: 5 decisões novas (#19-#23)
- `docs/plans/v2.1.0-execution.md`: plano de execução multiagent (4 ondas, 11 subagents, ~6h wall-clock vs ~16-21h sequencial)
- Diagrama `docs/architecture.{drawio,png}` reescrito (Sessão 9.3, commit `269bac7`)

### Pedagogical impact

- **29 surpresas catalogadas** (era 18 na v2.0.0) — todas com fix permanente automatizado
- **0 passos manuais no portal Azure** (era ~6 com criação de app reg + admin consent + extension property)
- **Setup zero-friction**: pre-flight (~30s) → fork → secrets → `git push` ou `azd up` local → app rodando em <15min

---

## [v2.0.0] — 2026-05-04

### Sessão 9.2 — Backend Python Crashloop RESOLVIDO

Primeiro release SHIP-READY do template. Epic 06.5c B-PRACTICAL fechado com qa-gate PASS (10/12 ACs validados, 2 manual deferred). CI 100% verde.

### Added

- Hybrid Microservices Python + .NET (Epic 06.5c)
- `.github/workflows/dotnet-test.yaml` para build + test do tickets-service .NET 10
- `scripts/e2e-smoke-epic-06.5c.sh` smoke E2E reproduzível
- README enterprise (Apex Group focus) + diagrama arquitetural
- `PARA-O-ALUNO.md` com 18 surpresas pedagógicas catalogadas
- `DECISION-LOG.md` com 18 decisões cravadas

### Changed

- `app/backend/repositories/_pool.py` — token AAD explícito via `azure.identity.ManagedIdentityCredential` + injeção via `SQL_COPT_SS_ACCESS_TOKEN` (Decisão #17)
- `infra/main.bicep` — `autoPauseDelay: 60 → -1` (Decisão #18)
- 9 grants object-level scoped exclusivamente para tickets MI

### Fixed

- Backend Python crashloop com `pyodbc HYT00 Login timeout` em User-Assigned MI Linux Container Apps
- Cold-start de Serverless paused (~30-60s) durante demos

---
