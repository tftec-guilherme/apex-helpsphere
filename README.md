<div align="center">

# HelpSphere

**Template pedagógico Azure production-grade — multi-tenant ITSM com IA modular.**

Pós-Graduação em Arquitetura Cloud Azure · Disciplina 06.

[![Deploy](https://github.com/tftec-guilherme/apex-helpsphere/actions/workflows/azure-dev.yml/badge.svg?branch=main)](https://github.com/tftec-guilherme/apex-helpsphere/actions/workflows/azure-dev.yml)
[![.NET](https://github.com/tftec-guilherme/apex-helpsphere/actions/workflows/dotnet-test.yaml/badge.svg?branch=main)](https://github.com/tftec-guilherme/apex-helpsphere/actions/workflows/dotnet-test.yaml)
[![Frontend](https://github.com/tftec-guilherme/apex-helpsphere/actions/workflows/frontend.yaml/badge.svg?branch=main)](https://github.com/tftec-guilherme/apex-helpsphere/actions/workflows/frontend.yaml)
[![Python](https://github.com/tftec-guilherme/apex-helpsphere/actions/workflows/python-test.yaml/badge.svg?branch=main)](https://github.com/tftec-guilherme/apex-helpsphere/actions/workflows/python-test.yaml)
[![Release](https://img.shields.io/github/v/release/tftec-guilherme/apex-helpsphere?include_prereleases&color=0078D4)](https://github.com/tftec-guilherme/apex-helpsphere/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## O que é

Plataforma operacional de tickets do **Apex Group** (holding fictícia de varejo, 5 marcas, ~3.500 atendentes, 12k tickets/mês). Você roda `azd up` e ganha **9-14 minutos** para focar no que importa: pipeline RAG, agentes Foundry, automação.

> **Pedagógico, não brinquedo.** Auth two-app Microsoft Entra ID, Managed Identity, RLS-like multi-tenancy, Bicep IaC, observabilidade OpenTelemetry, container deploy. Decisões de arquitetura defendíveis em audiência sênior — documentadas no [`DECISION-LOG.md`](./DECISION-LOG.md) (23 decisões cravadas).

## Quick start (aluno)

```bash
# 1. Fork em https://github.com/tftec-guilherme/apex-helpsphere
git clone https://github.com/SEU_USUARIO/apex-helpsphere.git
cd apex-helpsphere

# 2. Pre-flight check (~30s, 8 validações)
pwsh ./scripts/preflight.ps1   # Windows
./scripts/preflight.sh          # macOS/Linux/WSL

# 3. azd auth + env
azd auth login
azd env new helpsphere-demo

# 4a. Push pra CI deployar (recomendado v2.1.0)
azd pipeline config              # cria federated SP + GitHub secrets/vars
git push origin main             # CI faz tudo

# 4b. OU rodar local
azd up                           # ~9-14min
```

📘 **Detalhes completos + 29 surpresas pedagógicas catalogadas:** [`PARA-O-ALUNO.md`](./PARA-O-ALUNO.md)

## Arquitetura

![Arquitetura HelpSphere](./docs/architecture.png)

| Formato | Arquivo | Quando usar |
|---|---|---|
| **Diagrama editável** | [`docs/architecture.drawio`](./docs/architecture.drawio) | Edição via [draw.io](https://app.diagrams.net) ou desktop |
| **PNG 2x retina** | [`docs/architecture.png`](./docs/architecture.png) | Embed em README, slides, docs |
| **HTML interativo (v2)** | [`docs/helpsphere_architecture_v2.html`](./docs/helpsphere_architecture_v2.html) | Navegação pedagógica em apresentações |
| **SVG** | [`docs/architecture.svg`](./docs/architecture.svg) | Web/scaling |

**7 camadas:** Edge · Apresentação · Container Apps Env · AI Platform · Identity · Observabilidade/DevOps · Persistence.

**Princípios não-negociáveis (v2.1.0):**

- **CI-first:** todo ciclo via GitHub Actions. `azd up` local é dev avançado, opcional.
- **Parametrização:** Bicep params + `azd env` + GitHub vars (zero hardcode entre tenants).
- **Production-grade pedagogicamente defendível:** sem atalhos de segurança "para o aluno entender mais rápido".

## Stack

| Camada | Tech |
|---|---|
| **Frontend** | React 18 + Vite + TypeScript · Apex Executivo design system (Fraunces + Inter Tight + JetBrains Mono) · Recharts |
| **Backend** | Python 3.13 + Quart (auth, /chat dormente, /tenants/me, /auth_setup runtime config) |
| **Tickets API** | .NET 10 Minimal API + Dapper · Token explicit injection ([Decisão #22](./DECISION-LOG.md)) |
| **IaC** | Azure Bicep (25+ recursos parametrizados) · `azd` v1.23+ |
| **Auth** | Microsoft Entra ID two-app pattern · Directory Extension `app_tenant_id` ([Decisão #19-#21](./DECISION-LOG.md)) |
| **Data** | Azure SQL Serverless (5 tenants seed Apex, 50 tickets pt-BR, 70 comments) |
| **AI Platform** | Azure OpenAI (gpt-4.1-mini · text-embedding-3-large) · AI Search · Document Intelligence · Vision |
| **Compute** | Azure Container Apps + ACR (build remoto via ACR Tasks) |
| **Telemetria** | Application Insights + Log Analytics + dashboard pré-provisionado |

## Estrutura

```
apex-helpsphere/
├── app/
│   ├── backend/                  # Python Quart — auth + /chat (Lab Intermediário ativa) + tenants
│   ├── frontend/                 # React + Vite — Apex Executivo design system
│   ├── tickets-service/          # .NET 10 Minimal API + Dapper — endpoints CRUD + /stats
│   └── functions/                # Azure Functions — RAG cloud ingestion (Lab Avançado)
├── infra/
│   ├── main.bicep                # 6 params expostos · CORS dinâmico · audience v2
│   └── main.parameters.json
├── scripts/
│   ├── preflight.{ps1,sh}        # 8 validações ~30s antes de azd up
│   ├── auth_init.py              # 2 App Registrations + Directory Extension idempotente
│   ├── auth_update.py            # redirect URIs + extension value no user
│   ├── setup_search_index.py     # cria gptkbindex idempotente (postprovision)
│   └── run_prepdocs.{ps1,sh}     # wrapper honrando SKIP_PREPDOCS
├── data/
│   ├── migrations/               # SQL Server schema (idempotente)
│   └── seed/                     # 5 tenants Apex + 50 tickets pt-BR + 70 comments
├── docs/
│   ├── architecture.{drawio,png,svg}
│   ├── helpsphere_architecture_v2.html
│   └── plans/v2.1.0-execution.md
└── .github/workflows/
    ├── azure-dev.yml             # Deploy completo (azd provision + deploy)
    ├── azure-dev-validation.yaml # Bicep validate em PR
    ├── python-test.yaml          # ruff + black + pytest (matrix simplificada v2.1.0)
    ├── frontend.yaml             # prettier + tsc + vite build
    ├── dotnet-test.yaml          # build + xunit
    └── setup-aad.yml             # workflow_dispatch standalone para AAD recreate
```

## Documentação

| Doc | Quando ler |
|---|---|
| [`PARA-O-ALUNO.md`](./PARA-O-ALUNO.md) | Quick start + 29 surpresas pedagógicas + checklist pré-requisitos |
| [`DECISION-LOG.md`](./DECISION-LOG.md) | 23 decisões cravadas com contexto, alternativas avaliadas, anti-padrões rejeitados |
| [`CHANGELOG.md`](./CHANGELOG.md) | Histórico de releases (v2.0.0 → v2.1.0) |
| [`docs/plans/v2.1.0-execution.md`](./docs/plans/v2.1.0-execution.md) | Plano multiagent v2.1.0 (4 ondas, 11 subagents, ~6h wall-clock) |
| [`docs/qa-gates/`](./docs/qa-gates/) | Verdicts QA por épico (PASS/CONCERNS/FAIL/WAIVED) |
| [`SECURITY.md`](./SECURITY.md) | Política de segurança e disclosure |
| [`CHANGES.md`](./CHANGES.md) | Diff vs upstream `azure-search-openai-demo` |

## Roadmap pedagógico

| Fase | Lab | O que adiciona |
|---|---|---|
| **v2.1.0** (atual) | Setup base | Infra + auth two-app + tickets + dashboard executivo + telemetria |
| Próximo | **Lab Intermediário** (M02-M05) | Pipeline RAG: AI Search index custom + embeddings + chat com citation rendering sobre 62 PDFs Apex |
| Depois | **Lab Final** (M06) | Agentes Foundry com tools + Speech STT/TTS + integração com tickets |
| Sinergia D04 | **Lab Avançado** | Tickets-service publica `TicketStatusChanged` no Service Bus + Logic App reage + dashboard tempo real |

## Contribuir / Reportar bugs

- **Issues:** [GitHub Issues](https://github.com/tftec-guilherme/apex-helpsphere/issues)
- **PRs:** convenção `feat:` / `fix:` / `docs:` / `chore:` + referência a Decisões `#N` quando aplicável (ver `DECISION-LOG.md`)

## License & atribuição

[MIT](./LICENSE) · Forked from [Azure-Samples/azure-search-openai-demo](https://github.com/Azure-Samples/azure-search-openai-demo) (template upstream original — ver `LICENSE.upstream`).

---

<div align="center">

**Prof. Guilherme Campos** · Pós-Graduação em Arquitetura Cloud Azure

</div>
