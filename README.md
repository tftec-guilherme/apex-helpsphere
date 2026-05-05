<div align="center">

# HelpSphere — Apex Group

### Multi-tenant ITSM platform sobre Azure Container Apps com IA generativa modular

[![Deploy](https://github.com/tftec-guilherme/apex-helpsphere/actions/workflows/azure-dev.yml/badge.svg?branch=main)](https://github.com/tftec-guilherme/apex-helpsphere/actions/workflows/azure-dev.yml)
[![.NET tickets-service](https://github.com/tftec-guilherme/apex-helpsphere/actions/workflows/dotnet-test.yaml/badge.svg?branch=main)](https://github.com/tftec-guilherme/apex-helpsphere/actions/workflows/dotnet-test.yaml)
[![Frontend lint](https://github.com/tftec-guilherme/apex-helpsphere/actions/workflows/frontend.yaml/badge.svg?branch=main)](https://github.com/tftec-guilherme/apex-helpsphere/actions/workflows/frontend.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Azure architecture](https://img.shields.io/badge/Azure-architecture--center-0078D4?logo=microsoft-azure)](https://learn.microsoft.com/azure/architecture/)

**version-anchor:** Q2-2026 · **Status:** 🟢 Epic 06.5c **SHIP-READY** · qa-gate PASS · 8/9 stories Done

</div>

---

## Sumário

- [Sobre o Apex Group](#sobre-o-apex-group)
- [Business case](#business-case)
- [Arquitetura](#arquitetura)
- [Pilares de engenharia](#pilares-de-engenharia)
- [Stack tecnológico](#stack-tecnológico)
- [Production patterns implementados](#production-patterns-implementados)
- [Provisionamento](#provisionamento)
- [Quality gates](#quality-gates)
- [Operações & FinOps](#operações--finops)
- [Compliance & segurança](#compliance--segurança)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Documentação técnica](#documentação-técnica)
- [Material da Pós-Graduação](#material-da-pós-graduação)
- [License & atribuição](#license--atribuição)

---

## Sobre o Apex Group

**Apex Group** é uma holding fictícia de varejo brasileiro composta por **5 marcas** atendidas por uma operação de TI compartilhada:

| Marca | Segmento | Faturamento |
|---|---|---|
| Apex Express | Conveniência (lojas de bairro) | R$ 1.2 Bi/ano |
| Apex Mart | Hipermercados | R$ 4.8 Bi/ano |
| Apex Drug | Farmácias | R$ 800 Mi/ano |
| Apex Tech | E-commerce eletrônicos | R$ 600 Mi/ano |
| Apex Eats | Food service | R$ 400 Mi/ano |

A holding opera o **HelpSphere**, plataforma interna de ITSM (gestão de chamados de TI) que atende **~3.500 atendentes/operadores** com **12 mil tickets/mês**. Custo direto de tier 1 estimado em **R$ 102 mil/mês**.

> **Cenário pedagógico:** o nome, marcas, números e narrativa são ficcionais — construídos para representar uma holding brasileira realista de varejo (escala média, 5 unidades de negócio com TI compartilhada). A arquitetura, decisões e patterns são **production-grade reais**.

---

## Business case

### Problema atual (legado)

- Operação ITSM 100% manual: triagem humana, escalonamento por planilha, knowledge base esparsa
- **Tempo médio de resolução tier 1:** 47 minutos (vs benchmark setor 18 minutos)
- **Tempo de handoff:** 30% dos chamados ressincoclados ≥2 vezes (atrito multi-marca)
- **Custo unitário por ticket:** R$ 8,50

### Programa Apex IA — escopo

A CTO Carla aprovou o **Programa Apex IA** com 3 frentes incrementais:

1. **Pipeline RAG sobre KB** (62 PDFs Apex de procedimentos, políticas, runbooks) — reduz handoff e tempo de resolução
2. **Agentes Foundry** com tools (consulta de inventário, status de pedidos, integração SAP) — automatiza decisões repetíveis
3. **Canal de voz Speech** (atendente fala, agente transcreve, IA sugere ação) — reduz fricção em incidentes urgentes

**KPI primário:** redução de **30%** no custo unitário de tier 1 em 6 meses (R$ 8,50 → R$ 5,95).

### Princípio editorial

> **Não reconstruir.** O HelpSphere já existe em produção. A IA entra como camada incremental sobre a plataforma operacional, com governança e observabilidade desde o primeiro deploy.

---

## Arquitetura

![HelpSphere Architecture](docs/architecture.png)

> **Diagrama gerado por código** (`docs/architecture.py` · `mingrammer/diagrams` com biblioteca oficial Microsoft Azure). Versionado e regenerável — qualquer alteração de arquitetura é rastreável via diff em `architecture.py`.

### Componentes principais

| Camada | Componente | Tecnologia | Decisão arquitetural |
|---|---|---|---|
| **Apresentação** | SPA multi-tenant | React + Vite + TS + Fluent UI v9 | App Service B1 (Always-On) — [Decisão #5](DECISION-LOG.md#decisão-5) |
| **Compute (RAG)** | Backend Python | Quart + gunicorn (8 workers) + aioodbc | Container App + UMI scoped — [Decisão #5](DECISION-LOG.md#decisão-5), [#16](DECISION-LOG.md#decisão-16), [#17](DECISION-LOG.md#decisão-17) |
| **Compute (CRUD)** | tickets-service | .NET 10 Minimal API + Dapper + Microsoft.Data.SqlClient | Container App + UMI scoped — [Decisão #16](DECISION-LOG.md#decisão-16) |
| **Persistence** | Azure SQL Database | Serverless GP_S_Gen5_2 · `autoPauseDelay = -1` | [Decisão #18](DECISION-LOG.md#decisão-18) (FinOps trade-off explícito) |
| **Object storage** | Blob Storage | KB PDFs (62) + mocks Vision OCR (3) | MI auth · [Decisão #5](DECISION-LOG.md#decisão-5) |
| **AI Platform** | Azure OpenAI · AI Search · Document Intelligence · AI Vision | gpt-4.1-mini · text-embedding-3-large · semantic ranker | Consumido pelo backend Python (RAG) |
| **Identity** | 2 User-Assigned Managed Identities | `aca-identity` (backend) · `aca-tickets-identity` (tickets) | Least privilege real — [Decisão #16](DECISION-LOG.md#decisão-16) |
| **Observability** | Application Insights | Workspace-based · MI auth | OpenTelemetry middleware (Quart + ASP.NET Core) |
| **DevOps** | GitHub Actions | OIDC · azd CI/CD · 3 workflows | Deploy · `dotnet-test` · `python-test` · `frontend lint` |

### Fluxo de request crítico (ticket lifecycle)

```
1. Atendente autentica no SPA via Entra ID  →  JWT com claim app_tenant_id
2. SPA chama  /api/tickets/{id}      via VITE_API_TICKETS_URL  →  tickets-service .NET
3. tickets-service valida JWT + extrai tenant_id server-side  →  Dapper query com tenant filter
4. Microsoft.Data.SqlClient + UMI auth  →  Azure SQL DB  →  9 grants object-level scoped
5. Response 200 OK + body JSON
6. Telemetria → Application Insights via OpenTelemetry middleware
```

**Multi-tenancy enforced server-side** (zero possibilidade de bypass — frontend exibe `tenant_id` read-only). [Decisão #8](DECISION-LOG.md#decisão-8).

---

## Pilares de engenharia

### 1. Bounded contexts reais (Hybrid Microservices)

| Domain | Stack | Por quê |
|---|---|---|
| **RAG / AI** | Python (ecossistema Foundry, OpenAI SDK, langchain-azure, AI Search SDK) | Right tool — Python é a lingua franca da plataforma de IA Azure 2026 |
| **Tickets CRUD** | .NET 10 (Microsoft.Data.SqlClient native MI · Dapper performance) | Right tool — .NET tem auth MI in-process sem ODBC fragility ([Decisão #17](DECISION-LOG.md#decisão-17)) |

> **Anti-padrão rejeitado:** monolito Python servindo tudo (versão v1 do template). Sofreu 8 camadas de fragilidade pyodbc/aioodbc/UMI no ciclo de Sessão 5. Vide [Decisão #16](DECISION-LOG.md#decisão-16) para a defesa completa do split.

### 2. Least privilege real (verificável)

Não basta dizer "usa Managed Identity". Provamos:

```sql
-- Backend Python MI: APENAS 2 grants (CONNECT + SELECT em tbl_tenants)
SELECT name, type_desc FROM sys.database_principals WHERE name = 'helpsphere-actions-aca-identity';
SELECT permission_name, state_desc FROM sys.database_permissions
WHERE grantee_principal_id = USER_ID('helpsphere-actions-aca-identity');

-- Backend MI sem broad roles (db_datareader/db_datawriter REVOGADOS na Story 06.5c.7)
SELECT mp.name, rp.name AS role
FROM sys.database_role_members drm
JOIN sys.database_principals mp ON drm.member_principal_id = mp.principal_id
JOIN sys.database_principals rp ON drm.role_principal_id = rp.principal_id
WHERE mp.name = 'helpsphere-actions-aca-identity';
-- Returns: 0 rows (nenhuma role broad — least privilege real)

-- Tickets-service MI: 9 grants object-level scoped
-- (SELECT/INSERT/UPDATE/DELETE em tbl_tickets, tbl_comments + REFERENCES em tbl_tenants + EXECUTE em sys.fn_my_permissions)
```

Validação automatizada via `scripts/e2e-smoke-epic-06.5c.sh` (vide [qa-gate](docs/qa-gates/epic-06.5c-qa-gate.md) AC-4).

### 3. Deprecation pattern profissional (RFC 8288)

Endpoints legados retornam **HTTP 410 Gone** com `Link: <successor-uri>; rel="successor-version"`:

```http
HTTP/1.1 410 Gone
content-type: application/json
link: <https://capps-tickets-x.westus3.azurecontainerapps.io/api/tickets>; rel="successor-version"

{
  "error": "endpoint_deprecated",
  "message": "Este endpoint migrou para o tickets-service .NET (Decisão #16 hybrid microservices)",
  "successor_uri": "https://capps-tickets-x.westus3.azurecontainerapps.io/api/tickets",
  "since": "2026-05-04",
  "epic": "06.5c"
}
```

> Padrão alinhado com [RFC 9110 §15.5.11](https://www.rfc-editor.org/rfc/rfc9110#name-410-gone) + [RFC 8288](https://www.rfc-editor.org/rfc/rfc8288) (Web Linking). Anti-padrões rejeitados: 404 silencioso, 301 com keep-alive, soft-delete. [Decisão #16](DECISION-LOG.md#decisão-16) D2.

### 4. Authentication MI sem ODBC fragility ([Decisão #17](DECISION-LOG.md#decisão-17))

`Authentication=ActiveDirectoryMsi` no DSN do ODBC Driver 18 é **incompatível com User-Assigned MI em Linux Container Apps**. Solução adotada: token AAD obtido via `azure.identity.ManagedIdentityCredential(client_id=AZURE_CLIENT_ID)` e injetado via `SQL_COPT_SS_ACCESS_TOKEN` em `attrs_before` da pyodbc connection — abordagem MS-recomendada com token cache 50min. Defesa completa em [Decisão #17](DECISION-LOG.md#decisão-17).

### 5. FinOps com trade-off explícito ([Decisão #18](DECISION-LOG.md#decisão-18))

| SKU / Config | Custo baseline mensal | Rationale |
|---|---|---|
| App Service B1 (Always-On) | ~R$ 70 | Tier mínimo com Always-On (F1 não tem; P1 é overkill) |
| 2 Container Apps (consumption) | ~R$ 50-150 (carga variável) | Scale-to-zero quando idle |
| Azure SQL Serverless GP_S_Gen5_2, `autoPauseDelay = -1` | ~R$ 120-200 | Sempre Online — confiabilidade > FinOps em template pedagógico ([Decisão #18](DECISION-LOG.md#decisão-18)) |
| Application Insights (workspace-based) | ~R$ 30 | Tier basic + sampling default |
| AI Search Standard S0 | ~R$ 700 | Necessário para semantic ranker (Lab Intermediário) |
| Azure OpenAI (token-based) | Variável | gpt-4.1-mini + emb-3-large; provisão sob demanda |

> **Total operacional Apex em produção (estimado):** R$ 2.5-4 mil/mês para a plataforma base. ROI calculado contra os R$ 102 mil/mês de tier 1 manual.

### 6. Observability como first-class

- **OpenTelemetry middleware** instrumenta automaticamente: requisições HTTP (Quart + ASP.NET Core), chamadas SDK (OpenAI · aiohttp · httpx · SQL), logs de domínio
- **Distributed tracing** end-to-end: SPA → backend Python → tickets-service → SQL DB
- **App Insights workspace-based** com retention 30d default — extensível
- **Custom metrics** previstas para Lab Avançado (latência LLM, cost-per-call, token usage por tenant)

---

## Stack tecnológico

| Layer | Tecnologia | Versão | Notas |
|---|---|---|---|
| Cloud platform | Azure Container Apps | API 2024-03-01 | AVM modules |
| Backend RAG | Python | 3.13 | Quart + gunicorn 8 workers |
| Backend CRUD | .NET | 10 | Minimal API + Dapper 2.1.72 |
| Frontend | React 18 + Vite + TS | 5.4.x / 5.5.x | Fluent UI v9 |
| Database | Azure SQL DB Serverless | GP_S_Gen5_2 | Microsoft.Data.SqlClient (native MI .NET) · pyodbc 5.2.0 + ODBC Driver 18 (com workaround [#17](DECISION-LOG.md#decisão-17) Python) |
| AI/ML | Azure OpenAI | gpt-4.1-mini · text-embedding-3-large | API 2024-10-01 |
| Search | Azure AI Search Standard | S0 | semantic ranker free tier |
| Identity | Microsoft Entra ID | — | 2 User-Assigned MIs · azureADOnlyAuthentication=true no SQL |
| IaC | Bicep + Azure Verified Modules | latest | `bicep build` validado em CI |
| Orchestration | Azure Developer CLI (`azd`) | 1.10+ | OIDC federated credentials |
| CI/CD | GitHub Actions | — | Deploy + dotnet-test + python-test + frontend lint |

---

## Production patterns implementados

### Zero Trust + Managed Identity em tudo

- **Sem secrets nas connection strings** (zero rotação manual)
- **Entra ID Group** como SQL AAD admin (turnover-resilient · audit-friendly)
- **`azureADOnlyAuthentication=true`** no SQL Server — bloqueia auth tradicional
- **2 UMIs scoped** (uma por microserviço) com grants object-level

### Defense-in-depth no schema SQL

- `sys.database_permissions` validado por script de bootstrap (`sql_init.py`)
- Verificação dupla: object-level grants + ausência de role memberships broad
- Schema migration ordenada: `CREATE TABLE` → `CREATE USER FROM EXTERNAL PROVIDER` → `GRANT scoped`

### Auth gate em 100% dos endpoints

- `[Authorize]` obrigatório em todos endpoints REST do tickets-service
- `@authenticated` obrigatório em todos endpoints do backend Python (exceto `/`, `/health`, `/api/tickets/*` que retornam 410)
- Tenant resolution **server-side** via JWT claim — frontend não consegue forjar

### Idempotência nos hooks `azd`

- `prepdocs.{sh,ps1}` com guard PDF count (sem PDFs = no-op, não aborta deploy)
- `sql_init.py` 100% idempotente: `IF DATABASE_PRINCIPAL_ID(...) IS NOT NULL` em REVOKE; schema migration ANTES dos GRANTs object-level

### Smoke retry tolerante a cold-start

- `azure-dev.yml` smoke critical (tickets `/health`): 15 attempts × 20s (~7min)
- ACA cold-start de container .NET pode levar 30-60s; gunicorn Python + token MI cache + aioodbc pool warmup pode levar 1-3min
- Smoke informational (backend Python `/`): 5 attempts × 20s

---

## Provisionamento

### Pré-requisitos

- Subscription Azure **Pay-As-You-Go** (Free Trial USD 200 não funciona — Azure OpenAI exige PAYG)
- Quota Azure OpenAI aprovada para `gpt-4.1-mini` + `text-embedding-3-large` (1-3 dias úteis · `aka.ms/oai/access`)
- Azure CLI 2.x · Azure Developer CLI (`azd`) · Git · Docker Desktop
- Cartão de crédito internacional na subscription

### Comando único

```bash
azd auth login
azd env new <env-name>
azd up
```

**Tempo total:** 9-14 minutos (provision Bicep + build 2 imagens Docker + frontend + deploy + seed 50 tickets pt-BR + 70 comments + 5 tenants + grants scoped).

### Cleanup

```bash
azd down --purge
```

`--purge` é mandatório para evitar Cognitive Services soft-deleted bloqueando próximo provision por 90 dias.

### Para passo-a-passo de aluno → vide [PARA-O-ALUNO.md](PARA-O-ALUNO.md)

---

## Quality gates

### CI/CD Pipelines (GitHub Actions)

| Workflow | Trigger | Validação |
|---|---|---|
| `azure-dev.yml` (Deploy) | push `main` · workflow_dispatch | Bicep validate · OIDC login · `azd provision + deploy` · smoke tickets CRITICAL · smoke backend INFORMATIONAL · cleanup opcional |
| `dotnet-test.yaml` | push em `app/tickets-service/**` | .NET 10 SDK · `dotnet restore + build /warnaserror + test sqlite tier` · upload TestResults artifact |
| `python-test.yaml` | push em código Python · matrix 24 jobs (5 Python × 2 OS × 2 Node) | Frontend build · i18n check · ruff · ty · black · pytest com 90% coverage · diff-cover · Playwright E2E |
| `frontend.yaml` | push em `app/frontend/**` | prettier --check |

### Epic-level qa-gate

`docs/qa-gates/epic-06.5c-qa-gate.md` — verdict **PASS** consolidado:

- 10/12 ACs validados explícito · 2/12 deferred manual (frontend nav, coverage formal)
- 7/7 quality checks PASS (code review, tests, ACs, no regressions, performance, security, docs)
- Smoke E2E reproduzível: `bash scripts/e2e-smoke-epic-06.5c.sh`

---

## Operações & FinOps

### SLOs propostos (Apex Group)

| Métrica | Target | Janela |
|---|---|---|
| Disponibilidade frontend | 99.9% | Mensal |
| P95 latência tickets-service `/api/tickets` | < 250ms | 7 dias |
| P95 latência backend Python `/chat` | < 4s (com RAG) | 7 dias |
| Error rate (HTTP 5xx) | < 0.1% | 7 dias |

### Runbooks (incrementais)

- ✅ Smoke E2E manual: `bash scripts/e2e-smoke-epic-06.5c.sh`
- ✅ Restart de revisão sem downtime: `az containerapp revision restart -n <app> -g <rg>`
- ⏳ Failover regional (Lab Avançado): paired region + Front Door + Read Geo-Replica do SQL
- ⏳ Disaster recovery (Lab Avançado): backup automático SQL + Storage RA-GRS

### Cost guardrails

- **Budget alert** Azure (recomendado): R$ 5.000/mês com alerta em 50% / 80% / 100%
- **Auto-shutdown não-prod**: scheduled `azd down` em ambientes dev (vide `nightly-jobs.yaml`)
- **Tag policy**: todos os recursos com `azd-env-name`, `azd-service-name` para chargeback

---

## Compliance & segurança

### Princípios atendidos

| Princípio | Implementação |
|---|---|
| **Identity** | Entra ID + 2 UMIs scoped + JWT auth obrigatório · Group como SQL admin |
| **Network** | TLS 1.2+ · ACA ingress HTTPS-only · SQL `Encrypt=yes;TrustServerCertificate=no` · firewall com IP allowlist (ACA outbound static IP + dev IPs whitelisted) |
| **Data** | Encryption at-rest default (Azure-managed keys) · least privilege real verificável via `sys.database_permissions` |
| **Logging** | Application Insights workspace-based · retention 30d · sampling default · OpenTelemetry distributed tracing |
| **Secret management** | Zero secrets nas env vars · Key Vault disponível para extensões futuras |
| **Audit** | DECISION-LOG.md (18 decisões com contexto, alternativas avaliadas, anti-padrões rejeitados) · qa-gate doc por epic · CHANGES.md upstream diff |

### Próximos passos (backlog auditoria sênior)

- ⏳ Microsoft Defender for SQL · for App Service (Lab Avançado)
- ⏳ Azure Policy: deny non-MI auth · deny public IP · enforce TLS 1.2
- ⏳ Sentinel + log analytics workspace dedicado para SecOps
- ⏳ Threat modeling formal (STRIDE) sobre os 2 microserviços

---

## Estrutura do repositório

```
apex-helpsphere/
├── README.md                              ← este arquivo (audiência: arquiteto · executivo · auditor)
├── PARA-O-ALUNO.md                        ← entrypoint da Pós-Graduação D06
├── DECISION-LOG.md                        ← 18 decisões arquiteturais cravadas
├── CHANGES.md                             ← diff vs upstream Microsoft
├── azure.yaml                             ← orquestração azd (multi-app: backend + tickets-service)
│
├── app/
│   ├── backend/                           ← Python 3.13 — RAG, OpenAI, Vision, DocIntel, AI Search
│   │   └── repositories/_pool.py          ← Token AAD explícito (Decisão #17)
│   ├── tickets-service/                   ← .NET 10 — Minimal API + Dapper + Microsoft.Data.SqlClient
│   │   └── src/{Api,Domain,Infrastructure}/   tests/TicketsService.Tests/
│   ├── frontend/                          ← React + Vite + TS + Fluent UI v9 + i18next (en, ptBR)
│   └── functions/                         ← Azure Functions auxiliares (KB ingestion)
│
├── infra/
│   ├── main.bicep                         ← entrypoint Bicep (autoPauseDelay -1 · 2 ACA + 2 UMI)
│   ├── main.parameters.json
│   ├── core/                              ← módulos AVM-compat
│   └── app/                               ← módulos específicos
│
├── data/
│   ├── migrations/                        ← schema SQL (3 tabelas: tenants, tickets, comments)
│   ├── seed/                              ← 5 tenants Apex + 50 tickets pt-BR + 70 comments
│   └── mocks/                             ← 3 PNGs sintéticos para Vision OCR
│
├── scripts/
│   ├── sql_init.py                        ← Idempotent · 2 SQL users + 9 grants scoped + verificação
│   ├── prepdocs.sh                        ← Upload PDFs + indexação AI Search
│   └── e2e-smoke-epic-06.5c.sh            ← Smoke epic-level (12 ACs validados)
│
├── tests/                                 ← pytest (backend Python) + xUnit (.NET) + Playwright E2E
│
├── docs/
│   ├── architecture.py                    ← Diagram-as-code (mingrammer/diagrams)
│   ├── architecture.png                   ← Renderizado (referenciado neste README)
│   ├── architecture.svg                   ← Vetor para zoom
│   └── qa-gates/
│       └── epic-06.5c-qa-gate.md          ← Verdict PASS (Sessão 9.2)
│
└── .github/workflows/
    ├── azure-dev.yml                      ← Deploy + smoke E2E
    ├── dotnet-test.yaml                   ← .NET tickets-service build + test
    ├── python-test.yaml                   ← Python lint + tests + i18n + Playwright
    └── frontend.yaml                      ← prettier --check
```

---

## Documentação técnica

| Documento | Audiência | Conteúdo |
|---|---|---|
| [DECISION-LOG.md](DECISION-LOG.md) | Arquiteto sênior · auditor | 18 decisões arquiteturais com contexto, alternativas avaliadas, trade-offs explícitos, anti-padrões rejeitados |
| [docs/qa-gates/epic-06.5c-qa-gate.md](docs/qa-gates/epic-06.5c-qa-gate.md) | QA · arquiteto · PM | Verdict PASS · 12 ACs validados · 7 quality checks |
| [CHANGES.md](CHANGES.md) | Time mantenedor · upstream watcher | Diff completo vs `Azure-Samples/azure-search-openai-demo` |
| [SECURITY.md](SECURITY.md) | SecOps · auditor | Política de divulgação responsável (preservada do upstream MS) |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribuidor externo | Convenções de PR · processo de review |

---

## Material da Pós-Graduação

Este repositório também é o **template oficial da Disciplina 06** (IA e Automação no Azure · TFTEC + Anhanguera). Alunos forkam e turbinam ao longo de 3 labs incrementais:

- **Lab Intermediário (M02-M05):** Pipeline RAG + Speech + agentes
- **Lab Final (M06):** Foundry agents + Service Bus events + Adaptive Cards Teams
- **Lab Avançado (D04 sinergia):** APIM gateway + observability + Cost Management + Defender

**Para começar como aluno:** [PARA-O-ALUNO.md](PARA-O-ALUNO.md) — guia conciso fork → clone → `azd up` → primeiro ticket.

---

## License & atribuição

**License:** MIT (mantida do upstream — vide [LICENSE](LICENSE))

**Atribuição upstream:**

> Forked from [`Azure-Samples/azure-search-openai-demo`](https://github.com/Azure-Samples/azure-search-openai-demo) at commit `95ce0c9484b338b3819914d0c1a1fa8d19a3ff9b` (2026-04-21).

A defesa arquitetural completa do fork (vs build do zero) está em [DECISION-LOG.md Decisão #1](DECISION-LOG.md#decisão-1). Diff exato em [CHANGES.md](CHANGES.md).

---

<div align="center">

**Apex Group · TI Compartilhada** · *Programa Apex IA Q2-2026*
**Maintainer:** Prof. Guilherme Campos · `guilherme.campos@tftec.com.br`
TFTEC Treinamentos · Pós-Graduação em Arquitetura Cloud Azure

</div>
