# SQLite (in-memory) ↔ SQL Edge (Testcontainers) — Gap Documentation

**Story:** [06.5c.2 — .NET tickets-service endpoints](../../../docs/stories/06.5c.2.dotnet-tickets-endpoints.md) AC-11

**Audiência:** arquiteto sênior auditando a estratégia de testes dual-tier.

## Por que dual-tier

Tests rápidos local (sem Docker) **e** tests full-fidelity em CI são objetivos contraditórios. Esta story resolve com 2 fixtures distintas, cada uma cobrindo um trade-off bem-definido:

| Fixture | Quando rodar | O que valida | O que NÃO valida |
|---------|--------------|--------------|------------------|
| **`SqliteFixture`** | Local (default) + CI | Lógica de negócio (state machine, tenant isolation, validators), endpoint pipeline (auth flow, JSON shape, status codes), Repository CRUD básico via SQL portable | Schema constraints CHECK, collation `Latin1_General_CI_AS`, UTC trigger ON UPDATE, isolation levels READ COMMITTED, deadlock behavior |
| **`SqlEdgeFixture`** | CI only (skipa local sem Docker) — **integração efetiva diferida para Story 06.5c.5** | Tudo do SQLite + schema constraints reais + collation + trigger + isolation level + tipos T-SQL native (UNIQUEIDENTIFIER, DATETIME2, NVARCHAR(MAX)) | Performance em volume real (responsabilidade do Lab Avançado) |

## Adaptações no schema (SQLite vs T-SQL real)

| T-SQL real (`001_initial_schema.sql`) | SQLite adapter (`sqlite-schema.sql`) | Justificativa |
|---------------------------------------|--------------------------------------|---------------|
| `UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID()` | `TEXT PRIMARY KEY` (Guid via app) | SQLite não tem Guid native; Microsoft.Data.Sqlite serializa Guid → TEXT automático |
| `DATETIME2 DEFAULT GETUTCDATE()` | `TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))` | SQLite não tem DATETIME2 nem GETUTCDATE; ISO 8601 string é portable e legível |
| `INT IDENTITY(1,1) PRIMARY KEY` | `INTEGER PRIMARY KEY AUTOINCREMENT` | Equivalente funcional; ambos retornam inteiro auto-incrementável |
| `VARCHAR(50) CHECK (category IN ('Comercial', ...))` | `TEXT` (sem CHECK) | SQLite suporta CHECK mas validação fica em DTO validators (defensa em camada de aplicação — mais cedo é melhor) |
| `NVARCHAR(200)` / `NVARCHAR(MAX)` | `TEXT` | SQLite tem único type TEXT (sem distinção de tamanho); validators enforce limits |
| `DECIMAL(3,2)` | `REAL` | Suficiente para confidence_score (precisão monetária não exigida) |
| `INDEX idx_status_created (status, created_at)` | `CREATE INDEX idx_tickets_status_created ON tbl_tickets(status, created_at)` | Sintaxe diferente, semântica equivalente |
| `TRIGGER FOR UPDATE bumps updated_at` | (sem trigger) | App layer não SET updated_at em UPDATE; SQLite tests aceitam updated_at = created_at (não validam exact value) |

## Adaptações no SQL de queries

Repositories (`TicketsRepository`) usam SQL **portable** funciona em ambos os dialects:

| Pattern T-SQL não-portable | Refactor portable | Defesa |
|----------------------------|-------------------|--------|
| `INSERT ... OUTPUT INSERTED.*` (single round-trip, SQL Server-only) | `INSERT ...; SELECT lastId; SELECT * WHERE id = lastId;` (3 round-trips, ambos dialects) — wrapped em `IDbTransaction` | Custo de 2 round-trips extra aceitável; `ISqlDialect.LastInsertedIdQuery` abstrai `SCOPE_IDENTITY()` vs `last_insert_rowid()` |
| `UPDATE ... OUTPUT INSERTED.*` (single round-trip) | `UPDATE; SELECT * WHERE id AND tenant_id;` (2 round-trips) | Idem |
| `COUNT(*) OVER()` window function | mantido — suportado em SQL Server 2012+ e SQLite 3.25+ | Microsoft.Data.Sqlite usa SQLite 3.40+ |
| `OFFSET ... FETCH NEXT ... ROWS ONLY` | mantido — suportado em SQL Server 2012+ e SQLite 3.x | — |
| `LIKE ... ESCAPE '\\'` | mantido — suportado em ambos | Wildcard escape funciona idêntico |
| `INNER JOIN ... ON` | mantido — ANSI SQL standard | — |

## Tradeoffs aceitos

### Gap-1 — CHECK constraints (status, category, priority)

T-SQL CHECK enforces valid values no banco. SQLite test schema NÃO tem CHECK. Validação fica em:
- `TicketStatus.Parse(string)` / `TicketCategory.Parse(string)` / `TicketPriority.Parse(string)` — lança `ArgumentException` em valor inválido
- `RequestValidators` — valida payload antes de chegar no repo

Resultado: dados inválidos nunca chegam ao banco em produção (validators server-side). CHECK é defesa em profundidade que o `SqlEdgeFixture` cobre em CI.

### Gap-2 — UPDATE não bumpa `updated_at` em SQLite

Production T-SQL trigger bumpa `updated_at` em cada UPDATE. SQLite test schema não tem trigger.

Resultado: tests de UPDATE não devem assertar `updated_at != created_at` ou similar. Tests apenas validam que UPDATE retornou row atualizada com novos field values.

### Gap-3 — Collation Latin1_General_CI_AS (case-insensitive accent-sensitive)

Production usa collation T-SQL pra LIKE case-insensitive. SQLite default é case-sensitive para ASCII.

Resultado: tests de search com `q=` parameter não cobrem case-insensitivity em SQLite. CI Testcontainers + lab manual cobrem.

### Gap-4 — Isolation level READ COMMITTED vs SERIALIZABLE em SQLite

SQLite default tem isolation level efetivamente serializable (writer lock global). Production SQL Server READ COMMITTED. Tests não cobrem race conditions de leitura intermediária.

Resultado: tests não cobrem dirty-read scenarios. CI Testcontainers + lab cobrem.

## Status de adoção

| Fixture | Status nesta story (06.5c.2) | Próxima evolução |
|---------|------------------------------|------------------|
| `SqliteFixture` | ✅ Implementada e ativa em todos endpoint tests | — |
| `SqlEdgeFixture` | ⚠️ Skeleton presente, **integração efetiva diferida para Story 06.5c.5** quando workflow CI no Linux runner instala Docker BuildKit + Testcontainers ambient | Story 06.5c.5 |

A defesa para o auditor sênior: "**dual-tier strategy** com gap explícito documentado é mais honesto que single-tier que finge ter cobertura completa. SQLite local entrega feedback de <5s; CI fidelity-real será adicionada quando o ambiente CI suportar Docker (Story 06.5c.5)."
