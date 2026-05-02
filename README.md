# HelpSphere — SaaS de Central de Atendimento (template para Disciplina 06)

> **Sistema pré-pronto** que serve de base para os 3 Labs da Disciplina 06 (IA e Automação no Azure). Aluno provisiona com `azd up` em 9-14 minutos e foca o tempo de lab em **acoplar IA**, não em construir o backend.
>
> **Disciplina 06** · Pós-Graduação em Arquitetura Cloud Azure · TFTEC + Anhanguera · Prof. Guilherme Campos
>
> **Cenário:** Apex Group (holding varejo brasileira fictícia) precisa colocar IA dentro do HelpSphere já em produção.
>
> **version-anchor:** Q2-2026 · **Status:** 🚧 em desenvolvimento (Story 06.5a InProgress)

---

## ⚖️ Atribuição (audiência sênior — leia esta seção primeiro)

Este projeto é um **fork adaptado** de:

> **`Azure-Samples/azure-search-openai-demo`**
> Commit base: `95ce0c9484b338b3819914d0c1a1fa8d19a3ff9b` (2026-04-21)
> Repositório original: https://github.com/Azure-Samples/azure-search-openai-demo
> License original: MIT (mantida — ver `LICENSE`)

### Por que partimos de fork em vez de construir do zero

Para audiência de pós-graduação em Arquitetura Cloud, **honestidade arquitetural é princípio editorial**:

1. **Não reinventamos a roda Microsoft.** A própria MS mantém esse template ativamente (push diário). Nossa contribuição pedagógica está nas **customizações HelpSphere** + **defesa arquitetural escrita**.
2. **Production-pattern visível** vem do template MS (Bicep modular, Managed Identity, App Insights, Entra login, citation rendering). Nosso job é **adaptar para o domínio Apex** mantendo o rigor.
3. **Manutenção continuada** — quando o MS atualiza o template upstream, podemos rebasear customizações. Reduz dívida técnica e risco de obsolescência.

Para a defesa completa de **por que essa decisão e não outras**, ver [`DECISION-LOG.md`](./DECISION-LOG.md).

Para o diff exato vs upstream MS template, ver `CHANGES.md` (a ser criado em sessão futura).

---

## 🚧 Status atual da implementação

**Story 06.5a InProgress** — esta sessão (2026-04-27) cobriu:
- ✅ DECISION-LOG.md (decisões arquiteturais documentadas)
- ✅ README.md inicial (este arquivo, com atribuição explícita)
- ⏸️ **HALT antes de vendor 80MB do template** — aguardando validação do professor sobre estratégia de vendoring (ver `DECISION-LOG.md` Decisão #2)

**Próximas sessões:**

| Sessão | Entregável | Esforço estimado |
|---|---|---|
| **Sessão 2** | Vendoring + remoções iniciais + Schema SQL HelpSphere + 50 tickets seed pt-BR | ~3-4h |
| **Sessão 3** | 5 endpoints REST adaptados + 2 páginas frontend customizadas + mocks Vision OCR | ~3-4h |
| **Sessão 4** | Smoke test `azd up` em conta Azure limpa + ajustes finais + CHANGES.md + defesa arquitetural completa | ~2-3h |

Total alvo da story 06.5a: **12-15h** distribuídos em ~4 sessões.

---

## 🎯 O que esse projeto entrega quando completo

### Tecnicamente

- **`azd up` em 1 comando** provisiona em 9-14min:
  - App Service Plan B1 + App Service (frontend React)
  - Function App (API REST de tickets)
  - Azure SQL Database Serverless (tickets + comments + tenants)
  - Azure Storage (mocks Vision OCR + futuros assets do Lab Inter)
  - Application Insights (instrumentado via Managed Identity)
  - Bicep modular preservado do template MS, customizado para HelpSphere
- **`azd down --purge`** limpa tudo sem orfãos
- **CI GitHub Actions** preservado do template MS (lint + Bicep what-if)

### Domínio HelpSphere

- 3 tabelas: `tbl_tenants` (5 marcas Apex fictícias), `tbl_tickets` (50 seed em pt-BR cobrindo 5 categorias), `tbl_comments` (~80 seed)
- 5 endpoints REST: list/detail/comment/update/suggest (suggest = stub para o RAG do Lab Inter preencher)
- 2 páginas frontend: `/tickets` (lista com filters) + `/tickets/{id}` (detail + comments thread)
- 3-5 PNGs mock sintéticos para o Vision OCR processar no Lab Intermediário

---

## 📋 Pré-requisitos (alvo final)

> ⚠️ Esta seção será expandida quando a implementação atingir Sessão 4. Por enquanto é roadmap.

- Conta Azure Pay-As-You-Go (Free Trial USD 200 NÃO funciona — Azure OpenAI exige PAYG)
- Quota Azure OpenAI aprovada para `text-embedding-3-large` + `gpt-4.1-mini` (necessária somente nos Labs Inter/Final, não para provisionar HelpSphere base)
- Azure CLI 2.x + Azure Developer CLI (`azd`) + Git
- VS Code com extensões Azure Tools + Bicep
- Cartão de crédito internacional vinculado à subscription

### Custo esperado

> ⚠️ Valores serão validados na Sessão 4 com smoke test real.

- **Provisionar e usar 1 sessão de lab (4-6h ligado, depois `azd down --purge`):** ~R$ 5-10 saindo do bolso
- **Esquecer ligado 1 mês inteiro:** ~R$ 60-80 (App Service B1 + SQL Serverless idle = baixo)

**Regra de ouro (igual aos labs):** `azd down --purge` ao final de cada sessão.

---

## 🚀 Como provisionar (alvo final)

> ⚠️ Comando real será disponibilizado ao final da Sessão 4. Por enquanto é placeholder.

```bash
# Pré-requisitos
az login
azd auth login

# Provisão completa (9-14 min)
git clone https://github.com/tftec-guilherme/azure-retail.git
cd azure-retail/Disciplina_06_*/03_Aplicações/helpsphere/
azd env new helpsphere-demo-{seu-id}
azd up

# Cleanup ao final da sessão
azd down --purge
```

---

## 🛡️ Defesa arquitetural (será expandida na Sessão 4)

> Esta seção é o que o **arquiteto sênior vai ler antes de tudo** — defesa em linguagem de comitê.

### Por que App Service B1 (não F1, não P1)
> _A ser preenchido na Sessão 4 com base no Bicep customizado._

### Por que SQL Database Serverless (não Basic, não Premium)
> _A ser preenchido na Sessão 4._

### Por que Managed Identity em tudo (não service principal, não API key)
> _A ser preenchido na Sessão 4._

### Por que Bicep modular (não ARM, não Terraform, não single-file Bicep)
> _A ser preenchido na Sessão 4 — herdado do template MS, customizado para HelpSphere._

---

## 📂 Estrutura de pastas (alvo final)

> Estrutura final virá do template MS após vendoring (Sessão 2). Placeholder por enquanto:

```
helpsphere/
├── DECISION-LOG.md              ← decisões arquiteturais (audit trail)
├── README.md                    ← este arquivo
├── CHANGES.md                   ← diff vs upstream MS (Sessão 4)
├── LICENSE                      ← MIT preservada do template MS
├── azure.yaml                   ← orquestração azd customizada para HelpSphere
├── infra/                       ← Bicep modular customizado (de template MS)
│   ├── main.bicep
│   └── modules/
├── app/                         ← código aplicação (de template MS, customizado)
│   ├── backend/                 ← Function App Python
│   └── frontend/                ← React + Vite + TS + Tailwind
├── data/                        ← seed HelpSphere (substitui dataset Zava do template)
│   ├── migrations/              ← schema SQL (3 tabelas)
│   ├── seed/                    ← 50 tickets pt-BR + 80 comments + 5 tenants
│   └── mocks/                   ← 3-5 PNGs mock para Vision OCR
├── tests/                       ← pytest (template MS) + testes HelpSphere
└── .github/workflows/           ← CI preservado do template MS
```

---

## 📞 Contato

**Prof. Guilherme Campos** — guilherme.campos@tftec.com.br
TFTEC Treinamentos · Pós-Graduação em Arquitetura Cloud Azure
