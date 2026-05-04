# HelpSphere — Template Apex (Disciplina 06)

> **Sistema pré-pronto** que serve de base para os 3 Labs da Disciplina 06 (IA e Automação no Azure). Aluno **forka** este repositório, provisiona com `azd up` em 9-14 minutos e foca o tempo de lab em **acoplar IA**, não em reconstruir o backend.
>
> **Disciplina 06** · Pós-Graduação em Arquitetura Cloud Azure · TFTEC + Anhanguera · Prof. Guilherme Campos
>
> **Cenário:** Apex Group (holding varejo brasileira fictícia) precisa colocar IA dentro do HelpSphere já em produção.
>
> **version-anchor:** Q2-2026 · **Status:** 🟢 Stack hybrid Python+.NET operacional — Epic 06.5c **4/9 done · AC-4 + AC-5 fechados** (Sessão 8)

---

## 🚀 Para começar (aluno)

**Antes de qualquer coisa, leia:** [`PARA-O-ALUNO.md`](./PARA-O-ALUNO.md) — guia conciso fork → clone → `azd up` → primeiro ticket.

```bash
# 1) Fork (UI GitHub): tftec-guilherme/apex-helpsphere → SEU_USUARIO/apex-helpsphere
# 2) Clone do SEU fork
git clone https://github.com/SEU_USUARIO/apex-helpsphere.git
cd apex-helpsphere

# 3) Login + provisão
az login
azd auth login
azd env new helpsphere-demo-{seu-id}
azd up
```

Tempo total: 9-14 min · Resultado: HelpSphere rodando + 50 tickets seed pt-BR populados.

**Cleanup ao final da sessão:** `azd down --purge`

---

## ⚖️ Atribuição arquitetural (auditoria sênior)

Este projeto é um **fork adaptado** de:

> **`Azure-Samples/azure-search-openai-demo`**
> Commit base: `95ce0c9484b338b3819914d0c1a1fa8d19a3ff9b` (2026-04-21)
> Repositório original: https://github.com/Azure-Samples/azure-search-openai-demo
> License original: MIT (mantida — ver `LICENSE`)

### Por que partimos de fork em vez de construir do zero

Para audiência de pós-graduação em Arquitetura Cloud, **honestidade arquitetural é princípio editorial**:

1. **Não reinventamos a roda Microsoft.** A própria MS mantém esse template ativamente (push diário). Nossa contribuição pedagógica está nas **customizações HelpSphere** (domínio Apex + tickets MI + least privilege real) + **defesa arquitetural escrita**.
2. **Production-pattern visível** vem do template MS (Bicep modular, Managed Identity, App Insights, Entra login, citation rendering). Nosso job é **adaptar para o domínio Apex** mantendo o rigor.
3. **Manutenção continuada** — quando o MS atualiza o template upstream, podemos rebasear customizações. Reduz dívida técnica e risco de obsolescência.

Para a defesa completa de **por que essa decisão e não outras**, ver [`DECISION-LOG.md`](./DECISION-LOG.md) (16 decisões cravadas).

Para o diff exato vs upstream MS template, ver `CHANGES.md`.

---

## 🏗️ Arquitetura atual (pós-Sessão 8)

```
┌─────────────────────────────────────────────────────────────────────┐
│  Resource Group: rg-helpsphere-{env}                                │
│                                                                     │
│  ┌──────────────────┐         ┌──────────────────────────────────┐  │
│  │ Frontend (React) │ ───────▶│ Backend Python (Container App)   │  │
│  │ App Service B1   │  /chat  │ • RAG / OpenAI / Vision / Search │  │
│  │ Vite + Fluent UI │  /ask   │ • SELECT em tbl_tenants APENAS   │  │
│  └──────────────────┘  /upload│   (least privilege real)         │  │
│           │                   │ • /api/tickets → 410 Gone        │  │
│           │                   │   Link: </api/v2/tickets>;       │  │
│           │                   │   rel="successor-version"        │  │
│           │                   └──────────────────────────────────┘  │
│           │                                                         │
│           │  /api/tickets/*   ┌──────────────────────────────────┐  │
│           └──────────────────▶│ tickets-service (Container App)  │  │
│                               │ .NET 10 Minimal API + Dapper     │  │
│                               │ • Managed Identity dedicada      │  │
│                               │ • 9 grants object-level scoped:  │  │
│                               │   tbl_tickets/tbl_comments       │  │
│                               │   (verificável em sys.database_  │  │
│                               │    permissions)                  │  │
│                               └──────────────────────────────────┘  │
│                                            │                        │
│                               ┌────────────▼─────────────────────┐  │
│                               │ Azure SQL Database Serverless    │  │
│                               │ • tbl_tickets (50 seed pt-BR)    │  │
│                               │ • tbl_comments (80 seed)         │  │
│                               │ • tbl_tenants (5 marcas Apex)    │  │
│                               └──────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────┐  ┌──────────────────┐  ┌──────────────────────┐   │
│  │ Blob Storage │  │ App Insights     │  │ Entra ID + JWT       │  │
│  │ 62 PDFs KB   │  │ Workspace-based  │  │ tenant claim         │  │
│  └──────────────┘  └──────────────────┘  └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

**Ver decisão completa em** [`DECISION-LOG.md` Decisão #16](./DECISION-LOG.md) (Hybrid Microservices Python + .NET).

---

## 📦 O que esse projeto entrega

### Tecnicamente

- **`azd up` em 1 comando** provisiona em 9-14min:
  - App Service Plan B1 + App Service (frontend React + Vite)
  - **Container App `tickets-service`** (.NET 10 Minimal API + Dapper + Managed Identity)
  - **Container App `backend`** (Python — RAG, OpenAI, Vision, DocIntel, AI Search)
  - Azure SQL Database Serverless (3 tabelas + seeds pt-BR)
  - Azure Storage (62 PDFs KB + mocks Vision OCR)
  - Application Insights (instrumentado via Managed Identity)
  - Container Registry para as 2 imagens Docker
- **`azd down --purge`** limpa tudo sem orfãos
- **CI GitHub Actions** com OIDC (`azd pipeline config`) — runs reproduzíveis

### Domínio HelpSphere

- 3 tabelas: `tbl_tenants` (5 marcas Apex fictícias), `tbl_tickets` (50 seed pt-BR cobrindo 5 categorias), `tbl_comments` (80 seed)
- 5 endpoints REST tickets (em `tickets-service` .NET): `GET /api/tickets`, `GET /api/tickets/{id}`, `POST /api/tickets`, `PATCH /api/tickets/{id}`, `POST /api/tickets/{id}/comments`
- 2 páginas frontend: `/tickets` (lista com filters) + `/tickets/{id}` (detail + comments thread)
- 3 PNGs mock sintéticos pt-BR para o Vision OCR processar no Lab Intermediário

### Segurança production-grade (pedagogicamente visível)

- **Least privilege real:** tickets MI tem APENAS 9 grants object-level scoped (tbl_tickets/tbl_comments/tbl_tenants). Backend Python MI tem APENAS `SELECT em tbl_tenants`. Verificável via `sys.database_permissions` + `sys.database_role_members` (`DECISION-LOG.md` #16).
- **Multi-tenancy via JWT claim:** `tenant_id` resolvido server-side a partir do token Entra (não header arbitrário). Frontend exibe read-only (`DECISION-LOG.md` #8).
- **Authentication obrigatória** em todos endpoints REST (não público por default).
- **Entra Group como SQL AAD admin** (não user pessoal — auditoria-friendly).
- **Deprecation com padrão RFC 8288:** Python `/api/tickets/*` retorna `410 Gone` + `Link: rel="successor-version"` apontando pro .NET (`DECISION-LOG.md` #16).

---

## 📋 Pré-requisitos

- **Conta Azure Pay-As-You-Go** (Free Trial USD 200 NÃO funciona — Azure OpenAI exige PAYG)
- **Quota Azure OpenAI aprovada** para `text-embedding-3-large` + `gpt-4.1-mini` (necessária somente nos Labs Inter/Final, não para provisionar HelpSphere base)
- **Azure CLI 2.x** + **Azure Developer CLI (`azd`)** + **Git**
- **VS Code** com extensões Azure Tools + Bicep
- **Cartão de crédito internacional** vinculado à subscription
- **Conta GitHub** (para forkar este repo)

### Custo esperado

- **Provisionar e usar 1 sessão de lab (4-6h ligado, depois `azd down --purge`):** ~R$ 8-15 saindo do bolso
- **Esquecer ligado 1 mês inteiro:** ~R$ 80-120 (App Service B1 + 2 Container Apps idle + SQL Serverless idle)

**Regra de ouro:** `azd down --purge` ao final de cada sessão.

---

## 🛡️ Defesa arquitetural (resumo)

A defesa completa está em [`DECISION-LOG.md`](./DECISION-LOG.md) (16 decisões cravadas). Resumo:

| # | Decisão | Por quê |
|---|---------|---------|
| #1 | Fork de `azure-search-openai-demo` (não build do zero) | Padrão MS + manutenção ativa + production-pattern |
| #5 | Container Apps + JWT tenant + auth obrigatório | Production-grade defensável (review do professor) |
| #8 | `tenant_id` server-side via JWT claim | Zero bypass, audit-friendly |
| #9 | Bicep AVM-compatible | Compila clean, sem warnings |
| #10 | Repo público dedicado `apex-helpsphere` | OIDC simples + aluno consegue forkar |
| #15 | `sql_init.sh` defensive 3-tier + smoke retry | Hooks `azd` só leem azd env file, não shell env |
| **#16** | **Hybrid Python+.NET (B-PRACTICAL incremental)** | Mata pyodbc fragility; least privilege real granular; deprecation RFC 8288 |

### Por que App Service B1 (não F1, não P1)

B1 é o tier mínimo com **Always-On habilitável** + custom domain + SSL. F1 não tem Always-On (cold start = experiência ruim). P1 é overkill para template pedagógico.

### Por que SQL Database Serverless (não Basic, não Premium)

Serverless **auto-pausa** após 1h idle (custo zero quando não usado). Basic é fixo R$ 30/mês ligado 24/7. Premium é R$ 800+/mês — overkill.

### Por que Managed Identity em tudo (não service principal, não API key)

Service principal precisa rotacionar secret. API key é credencial de longa duração. **Managed Identity** zero-secret + zero-rotation + audit-friendly em Entra.

### Por que Bicep modular (não ARM, não Terraform, não single-file Bicep)

Bicep é **first-party Microsoft** + suporta AVM modules + diff legível em PR. ARM é JSON verboso. Terraform exige state backend separado. Single-file Bicep não escala.

---

## 📂 Estrutura de pastas

```
apex-helpsphere/
├── PARA-O-ALUNO.md                ← entrypoint do aluno (LEIA PRIMEIRO)
├── README.md                       ← este arquivo
├── DECISION-LOG.md                 ← 16 decisões arquiteturais cravadas
├── CHANGES.md                      ← diff vs upstream MS template
├── LICENSE                         ← MIT preservada do template MS
├── azure.yaml                      ← orquestração azd (multi-app: backend + tickets-service)
├── infra/
│   ├── main.bicep                  ← entrypoint Bicep
│   ├── main.parameters.json
│   ├── core/                       ← módulos AVM-compat (auth, host, monitor, search, etc)
│   └── app/                        ← módulos específicos da aplicação
├── app/
│   ├── backend/                    ← Python (RAG, OpenAI, Vision, DocIntel, AI Search)
│   ├── tickets-service/            ← .NET 10 Minimal API + Dapper (tickets MI)
│   ├── frontend/                   ← React + Vite + TS + Fluent UI v9
│   └── functions/                  ← functions auxiliares
├── data/
│   ├── migrations/                 ← schema SQL (3 tabelas)
│   ├── seed/                       ← 50 tickets pt-BR + 80 comments + 5 tenants
│   └── mocks/                      ← 3 PNGs mock para Vision OCR
├── scripts/
│   ├── sql_init.sh                 ← cria 2 SQL users (backend MI + tickets MI) + 9 grants scoped
│   └── prepdocs.sh                 ← upload PDFs + indexação AI Search
├── tests/                          ← pytest (template MS) + xUnit (.NET tickets-service)
└── .github/workflows/
    └── azure-dev.yml               ← CI azd (OIDC + bicep validation + smoke retry)
```

---

## 📞 Contato

**Prof. Guilherme Campos** — guilherme.campos@tftec.com.br
TFTEC Treinamentos · Pós-Graduação em Arquitetura Cloud Azure
