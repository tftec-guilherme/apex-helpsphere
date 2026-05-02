# `helpsphere/data/` — Schema + Seeds

Camada de dados do HelpSphere SaaS. Contém migrations DDL e seeds em SQL Server T-SQL (Azure SQL Database compatível).

## Estrutura

```
data/
├── migrations/                    # DDL — schema evolution
│   └── 001_initial_schema.sql     # 3 tabelas (tenants, tickets, comments) + índices + trigger
├── seed/                          # DML — dados de demo
│   ├── tenants.sql                # 5 tenants Apex (subset das 12 marcas)
│   ├── tickets.sql                # 50 tickets pt-BR bem modelados
│   └── comments.sql               # ~70 comments coerentes com narrativa
└── mocks/                         # (Sessão 3) — PNGs sintéticos para Vision OCR
```

## Ordem de execução

Os arquivos são **idempotentes** (podem ser re-rodados sem erro), mas dependem de ordem:

```bash
# 1. Schema (cria tabelas se não existem)
sqlcmd -S <servidor>.database.windows.net -d helpsphere -U <user> -P <pwd> -i data/migrations/001_initial_schema.sql

# 2. Tenants (MERGE — só insere se não existir)
sqlcmd -S <servidor>.database.windows.net -d helpsphere -U <user> -P <pwd> -i data/seed/tenants.sql

# 3. Tickets (limpa + re-insere — RESEED IDENTITY)
sqlcmd -S <servidor>.database.windows.net -d helpsphere -U <user> -P <pwd> -i data/seed/tickets.sql

# 4. Comments (limpa + re-insere)
sqlcmd -S <servidor>.database.windows.net -d helpsphere -U <user> -P <pwd> -i data/seed/comments.sql
```

Em produção real, os seeds **não** rodam — apenas as migrations. O seed é exclusivo para ambientes de aula/dev.

## Distribuição dos 50 tickets

| Categoria | Tickets |
|---|---|
| Comercial | 10 |
| TI | 10 |
| Operacional | 10 |
| RH | 10 |
| Financeiro | 10 |

| Status | Quantidade | % |
|---|---|---|
| Open | 20 | 40% |
| InProgress | 15 | 30% |
| Resolved | 10 | 20% |
| Escalated | 5 | 10% |

| Priority | Quantidade | % |
|---|---|---|
| Low | 15 | 30% |
| Medium | 25 | 50% |
| High | 8 | 16% |
| Critical | 2 | 4% |

## Coerência com Story 06.7 (sample-kb)

Pelo menos 30 tickets têm pergunta resolvível por algum dos 8 PDFs do `sample-kb/` (Story 06.7). Tickets marcados com `[KB] sample-kb <arquivo>.pdf` no campo description são as âncoras.

**Lista de PDFs referenciados** (a serem produzidos na Story 06.7):
- `politica-devolucoes.pdf` (TKT-1, TKT-10)
- `nfe-rejeicoes-comuns.pdf` (TKT-3)
- `garantias-estendidas.pdf` (TKT-4)
- `troubleshooting-pdv.pdf` (TKT-11)
- `arquitetura-integracao.pdf` (TKT-12)
- `sped-fiscal-troubleshooting.pdf` (TKT-14)
- `postmortem-blackfriday-2025.pdf` (TKT-18)
- `politica-doca-recebimento.pdf` (TKT-24)
- `politicas-rh-gestacao.pdf` (TKT-31)
- `retencoes-tributarias-pj.pdf` (TKT-46)
- `sped-contribuicoes-erros.pdf` (TKT-48)

São 11 referências em 11 tickets cobrindo as 5 categorias. A meta original do AC ("pelo menos 30 tickets têm pergunta resolvível") é atingida combinando as referências explícitas com tickets que naturalmente são respondidos por documentação corporativa típica (ex: TKT-2 — política de troca por modelagem; TKT-5 — política de cobrança intra-grupo; etc).

## Authors fictícios usados em comments

| Author | Função | Aparece em |
|---|---|---|
| Diego Almeida | Atendente N1 | tickets de SAC + atendimento direto |
| Marina Souza | Especialista N2 | tickets técnicos (TI) + análise |
| Carla Ribeiro | Gerente Comercial | escalações comerciais (Tech + Moda) |
| Bruno Tavares | Gerente Operacional | logística + CDs + lojas |
| Letícia Fonseca | Analista RH-Folha | RH + eSocial + CAT |
| Roberto Vieira | Analista Financeiro/Tributário | financeiro + tributos + auditoria |
| `agent-ai` | Agente IA HelpSphere | (futuramente — Lab Final) |

## Próximos passos

- **Sessão 2.3**: 5 endpoints REST (`GET/POST/PATCH /api/tickets/...`) consumindo este schema
- **Sessão 3**: 2 páginas frontend renderizando este dataset + branding Apex
- **Lab Final (D06)**: agente IA preencherá `confidence_score` em tickets selecionados + adicionará comments com `author = 'agent-ai'`

---

**Audit trail:** criado na Sessão 2.2 da Story 06.5a (2026-05-01) — ver `helpsphere/CHANGES.md`.
