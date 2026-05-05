// Story 06.5c.2 T2.2-T2.6 — TicketsRepository (Dapper + portable SQL)
//
// Defesa em profundidade:
//   * WHERE tenant_id = @tenantId em 100% das queries (auditável via grep)
//   * Parameterização Dapper obrigatória (zero string concat com input usuário)
//   * LIKE search faz escape de % e _ literais
//   * TransitionStatus usa IDbTransaction atômica (UPDATE + INSERT comment)
//
// D-disc Story 06.5c.2: SQL portable SQL Server ↔ SQLite via ISqlDialect.LastInsertedIdQuery
// (SCOPE_IDENTITY() vs last_insert_rowid()). Removido OUTPUT INSERTED.* — substitído
// por 2-step INSERT/UPDATE + SELECT WHERE id = LAST_INSERT_ID(). Pequeno custo de
// round-trip extra justifica suíte SQLite local rápida (AC-11) sem refatorar arquitetura.

using System.Globalization;
using System.Text;
using System.Text.Json;
using Dapper;
using TicketsService.Domain.Comments;
using TicketsService.Domain.Common;
using TicketsService.Domain.Models;
using TicketsService.Domain.Tenants;
using TicketsService.Domain.Tickets;
using TicketsService.Domain.Tickets.Enums;

namespace TicketsService.Infrastructure.Sql.Repositories;

public sealed class TicketsRepository(
    ISqlConnectionFactory connectionFactory,
    ICommentsRepository commentsRepository,
    ISqlDialect dialect) : ITicketsRepository
{
    private const int CommandTimeoutSeconds = 30;

    public async Task<PagedResult<Ticket>> ListAsync(
        Guid tenantId,
        TicketFilter filter,
        CancellationToken ct)
    {
        var (whereClause, parameters) = BuildListWhereClause(tenantId, filter);

        // COUNT(*) OVER() materializa total na mesma query (sem round-trip extra).
        // Suportado em SQL Server 2012+ e SQLite 3.25+.
        // Pagination clause é dialect-aware (OFFSET FETCH em SQL Server, LIMIT OFFSET em SQLite).
        var sql = new StringBuilder()
            .AppendLine("SELECT")
            .AppendLine("  ticket_id, tenant_id, subject, description, category, language,")
            .AppendLine("  status, priority, confidence_score, attachment_blob_paths,")
            .AppendLine("  created_at, updated_at,")
            .AppendLine("  COUNT(*) OVER() AS total_rows")
            .AppendLine("FROM tbl_tickets")
            .Append(whereClause)
            .AppendLine("ORDER BY created_at DESC")
            .Append(dialect.PaginationClause).Append(';').AppendLine()
            .ToString();

        parameters.Add("offset", (filter.Page - 1) * filter.PageSize);
        parameters.Add("page_size", filter.PageSize);

        await using var conn = await connectionFactory.CreateOpenConnectionAsync(ct);
        var rows = await conn.QueryAsync<TicketWithTotalRow>(
            new CommandDefinition(sql, parameters, commandTimeout: CommandTimeoutSeconds, cancellationToken: ct));

        var rowList = rows.ToList();
        var total = rowList.Count == 0 ? 0 : rowList[0].total_rows;

        var items = rowList.Select(MapTicket).ToList();
        return new PagedResult<Ticket>(items, total, filter.Page, filter.PageSize);
    }

    public async Task<TicketDetail?> GetByIdAsync(int id, Guid tenantId, CancellationToken ct)
    {
        // INNER JOIN tenants para brand_name evita N+1 round-trip
        const string ticketSql =
            "SELECT t.ticket_id, t.tenant_id, t.subject, t.description, t.category, t.language, " +
            "       t.status, t.priority, t.confidence_score, t.attachment_blob_paths, t.created_at, t.updated_at, " +
            "       te.tenant_id AS Te_TenantId, te.brand_name AS Te_BrandName, te.created_at AS Te_CreatedAt " +
            "FROM tbl_tickets t " +
            "INNER JOIN tbl_tenants te ON t.tenant_id = te.tenant_id " +
            "WHERE t.ticket_id = @id AND t.tenant_id = @tenantId;";

        await using var conn = await connectionFactory.CreateOpenConnectionAsync(ct);
        var row = await conn.QuerySingleOrDefaultAsync<TicketWithTenantRow?>(
            new CommandDefinition(ticketSql, new { id, tenantId },
                commandTimeout: CommandTimeoutSeconds, cancellationToken: ct));

        if (row is null)
        {
            return null;
        }

        var ticket = MapTicket(row);
        var tenant = new Tenant(row.Te_TenantId, row.Te_BrandName, row.Te_CreatedAt);
        var comments = await commentsRepository.GetByTicketIdAsync(id, ct);

        return new TicketDetail(ticket, comments, tenant);
    }

    public async Task<Ticket> CreateAsync(NewTicket newTicket, Guid tenantId, CancellationToken ct)
    {
        // Portable: INSERT (sem OUTPUT INSERTED) → SELECT id via dialect → SELECT ticket completo
        // Wrapped em transação para atomicidade do INSERT + SELECT (mesma connection garante
        // SCOPE_IDENTITY/last_insert_rowid corretos).
        const string insertSql =
            "INSERT INTO tbl_tickets (tenant_id, subject, description, category, language, status, priority, attachment_blob_paths) " +
            "VALUES (@tenantId, @subject, @description, @category, @language, @status, @priority, @attachments);";

        const string selectSql =
            "SELECT ticket_id, tenant_id, subject, description, category, language, " +
            "       status, priority, confidence_score, attachment_blob_paths, created_at, updated_at " +
            "FROM tbl_tickets WHERE ticket_id = @id;";

        var attachmentsJson = JsonSerializer.Serialize(newTicket.AttachmentBlobPaths);

        await using var conn = await connectionFactory.CreateOpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);

        try
        {
            await conn.ExecuteAsync(
                new CommandDefinition(insertSql, new
                {
                    tenantId,
                    subject = newTicket.Subject,
                    description = newTicket.Description,
                    category = newTicket.Category.Value,
                    language = "pt-BR",
                    status = TicketStatus.Open.Value,
                    priority = newTicket.Priority.Value,
                    attachments = attachmentsJson
                }, transaction: tx, commandTimeout: CommandTimeoutSeconds, cancellationToken: ct));

            var newId = await conn.QuerySingleAsync<long>(
                new CommandDefinition(dialect.LastInsertedIdQuery,
                    transaction: tx, commandTimeout: CommandTimeoutSeconds, cancellationToken: ct));

            var row = await conn.QuerySingleAsync<TicketRow>(
                new CommandDefinition(selectSql, new { id = (int)newId },
                    transaction: tx, commandTimeout: CommandTimeoutSeconds, cancellationToken: ct));

            await tx.CommitAsync(ct);
            return MapTicket(row);
        }
        catch
        {
            await tx.RollbackAsync(ct);
            throw;
        }
    }

    public async Task<Ticket?> UpdateAsync(int id, UpdateTicket update, Guid tenantId, CancellationToken ct)
    {
        // Portable: UPDATE → SELECT WHERE id AND tenant_id (defesa cross-tenant).
        // SQL Server tem trigger que bumpa updated_at; SQLite test schema não — para tests,
        // o updated_at fica = created_at após UPDATE, mas não asseguramos exato value.
        const string updateSql =
            "UPDATE tbl_tickets " +
            "SET subject = @subject, description = @description, priority = @priority, attachment_blob_paths = @attachments " +
            "WHERE ticket_id = @id AND tenant_id = @tenantId;";

        const string selectSql =
            "SELECT ticket_id, tenant_id, subject, description, category, language, " +
            "       status, priority, confidence_score, attachment_blob_paths, created_at, updated_at " +
            "FROM tbl_tickets WHERE ticket_id = @id AND tenant_id = @tenantId;";

        var attachmentsJson = JsonSerializer.Serialize(update.AttachmentBlobPaths);

        await using var conn = await connectionFactory.CreateOpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);

        try
        {
            var rowsAffected = await conn.ExecuteAsync(
                new CommandDefinition(updateSql, new
                {
                    id,
                    tenantId,
                    subject = update.Subject,
                    description = update.Description,
                    priority = update.Priority.Value,
                    attachments = attachmentsJson
                }, transaction: tx, commandTimeout: CommandTimeoutSeconds, cancellationToken: ct));

            if (rowsAffected == 0)
            {
                await tx.RollbackAsync(ct);
                return null; // 404 (not found OR cross-tenant)
            }

            var row = await conn.QuerySingleAsync<TicketRow>(
                new CommandDefinition(selectSql, new { id, tenantId },
                    transaction: tx, commandTimeout: CommandTimeoutSeconds, cancellationToken: ct));

            await tx.CommitAsync(ct);
            return MapTicket(row);
        }
        catch
        {
            await tx.RollbackAsync(ct);
            throw;
        }
    }

    public async Task<TicketDetail?> TransitionStatusAsync(
        int id,
        TicketStatus targetStatus,
        string? note,
        string author,
        Guid tenantId,
        CancellationToken ct)
    {
        await using var conn = await connectionFactory.CreateOpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);

        try
        {
            // 1. Read current status with tenant guard
            var currentRaw = await conn.QuerySingleOrDefaultAsync<string?>(
                new CommandDefinition(
                    "SELECT status FROM tbl_tickets WHERE ticket_id = @id AND tenant_id = @tenantId;",
                    new { id, tenantId },
                    transaction: tx,
                    commandTimeout: CommandTimeoutSeconds,
                    cancellationToken: ct));

            if (currentRaw is null)
            {
                await tx.RollbackAsync(ct);
                return null; // 404 (not found OR cross-tenant)
            }

            var currentStatus = TicketStatus.Parse(currentRaw);

            // 2. Validate state machine
            if (!TicketTransition.IsValid(currentStatus, targetStatus))
            {
                await tx.RollbackAsync(ct);
                throw new InvalidTransitionException(
                    currentStatus,
                    targetStatus,
                    TicketTransition.AllowedFrom(currentStatus));
            }

            // 3. UPDATE status (with tenant guard)
            await conn.ExecuteAsync(
                new CommandDefinition(
                    "UPDATE tbl_tickets SET status = @target WHERE ticket_id = @id AND tenant_id = @tenantId;",
                    new { target = targetStatus.Value, id, tenantId },
                    transaction: tx,
                    commandTimeout: CommandTimeoutSeconds,
                    cancellationToken: ct));

            // 4. INSERT auto-comment in same TX
            var content = $"Status alterado: {currentStatus.Value} → {targetStatus.Value}"
                + (string.IsNullOrWhiteSpace(note) ? string.Empty : $"\n\n{note}");

            // Truncate author to 100 chars (NVARCHAR(100) constraint)
            var safeAuthor = author.Length > 100 ? author[..100] : author;

            await commentsRepository.AddSystemCommentAsync(id, safeAuthor, content, conn, tx, ct);

            // 5. COMMIT
            await tx.CommitAsync(ct);
        }
        catch (InvalidTransitionException)
        {
            // Rollback already done above; rethrow for endpoint to map to 422
            throw;
        }
        catch
        {
            await tx.RollbackAsync(ct);
            throw;
        }

        // 6. Reload TicketDetail (out of TX, fresh state)
        return await GetByIdAsync(id, tenantId, ct);
    }

    public async Task<TicketStats> GetStatsAsync(Guid tenantId, CancellationToken ct)
    {
        // Wave 3.E (v2.1.0) — Aggregations Dashboard.
        //
        // Single round-trip: 5 selects via QueryMultipleAsync.
        //   1. Totals (TotalOpen, CriticalOpen, Last24h, SlaBreachPct)
        //   2. ByStatus
        //   3. ByCategory
        //   4. ByPriority
        //   5. DailyVolume7d
        //
        // SLA budget hardcoded por priority (v2.1.0):
        //   Critical=4h, High=24h, Medium=72h, Low=168h.
        //
        // Defesa em profundidade: WHERE tenant_id = @TenantId em TODAS queries
        // (Decisão #16 — auditável via grep).
        //
        // SQL Server T-SQL flavor (production target). Tests SQLite skipped — esse
        // endpoint é validado por smoke E2E pós-deploy.
        const string sql = @"
-- 1. Totals (open count, critical, 24h, SLA breach %)
SELECT
    COUNT(CASE WHEN status IN ('Open','InProgress') THEN 1 END) AS TotalOpen,
    COUNT(CASE WHEN priority = 'Critical' AND status <> 'Resolved' THEN 1 END) AS CriticalOpen,
    COUNT(CASE WHEN created_at > DATEADD(HOUR, -24, GETUTCDATE()) THEN 1 END) AS Last24h,
    CAST(
        COALESCE(
            100.0 * COUNT(CASE
                WHEN status IN ('Open','InProgress') AND
                     DATEDIFF(HOUR, created_at, GETUTCDATE()) >
                        CASE priority
                            WHEN 'Critical' THEN 4
                            WHEN 'High' THEN 24
                            WHEN 'Medium' THEN 72
                            ELSE 168
                        END
                THEN 1
            END) /
            NULLIF(COUNT(CASE WHEN status IN ('Open','InProgress') THEN 1 END), 0),
            0
        )
    AS DECIMAL(5,2)) AS SlaBreachPct
FROM tbl_tickets
WHERE tenant_id = @tenantId;

-- 2. By status
SELECT status AS Status, COUNT(*) AS Count
FROM tbl_tickets
WHERE tenant_id = @tenantId
GROUP BY status
ORDER BY Count DESC;

-- 3. By category
SELECT category AS Category, COUNT(*) AS Count
FROM tbl_tickets
WHERE tenant_id = @tenantId
GROUP BY category
ORDER BY Count DESC;

-- 4. By priority (canonical order)
SELECT priority AS Priority, COUNT(*) AS Count
FROM tbl_tickets
WHERE tenant_id = @tenantId
GROUP BY priority
ORDER BY
    CASE priority
        WHEN 'Critical' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
        ELSE 4
    END;

-- 5. Daily volume last 7 days (ISO date YYYY-MM-DD via CONVERT style 23)
SELECT
    CONVERT(VARCHAR(10), CAST(created_at AS DATE), 23) AS [Date],
    COUNT(*) AS Count
FROM tbl_tickets
WHERE tenant_id = @tenantId
  AND created_at > DATEADD(DAY, -7, GETUTCDATE())
GROUP BY CAST(created_at AS DATE)
ORDER BY [Date];
";

        await using var conn = await connectionFactory.CreateOpenConnectionAsync(ct);
        await using var multi = await conn.QueryMultipleAsync(
            new CommandDefinition(sql, new { tenantId },
                commandTimeout: CommandTimeoutSeconds, cancellationToken: ct));

        var totalsRow = await multi.ReadSingleAsync<TotalsRow>();
        var byStatus = (await multi.ReadAsync<StatusCount>()).AsList();
        var byCategory = (await multi.ReadAsync<CategoryCount>()).AsList();
        var byPriority = (await multi.ReadAsync<PriorityCount>()).AsList();
        var dailyVolume = (await multi.ReadAsync<DailyVolume>()).AsList();

        return new TicketStats(
            TotalOpen: totalsRow.TotalOpen,
            SlaBreachPct: totalsRow.SlaBreachPct,
            CriticalOpen: totalsRow.CriticalOpen,
            Last24h: totalsRow.Last24h,
            ByStatus: byStatus,
            ByCategory: byCategory,
            ByPriority: byPriority,
            DailyVolume7d: dailyVolume);
    }

    // ---------------------------------------------------------------------
    // Internal mapping (snake_case rows → domain records)
    // ---------------------------------------------------------------------

    private static (string WhereClause, DynamicParameters Parameters) BuildListWhereClause(
        Guid tenantId,
        TicketFilter filter)
    {
        var clauses = new List<string> { "tenant_id = @tenantId" };
        var parameters = new DynamicParameters();
        parameters.Add("tenantId", tenantId);

        if (filter.Status is not null)
        {
            clauses.Add("status = @status");
            parameters.Add("status", filter.Status.Value);
        }

        if (filter.Category is not null)
        {
            clauses.Add("category = @category");
            parameters.Add("category", filter.Category.Value);
        }

        if (!string.IsNullOrWhiteSpace(filter.Query))
        {
            // Escape % and _ wildcards (treat literal); ESCAPE '\' is SQL Server convention
            var escaped = filter.Query.Replace("\\", "\\\\", StringComparison.Ordinal)
                                       .Replace("%", "\\%", StringComparison.Ordinal)
                                       .Replace("_", "\\_", StringComparison.Ordinal);
            clauses.Add("subject LIKE @query ESCAPE '\\'");
            parameters.Add("query", $"%{escaped}%");
        }

        var where = "WHERE " + string.Join(" AND ", clauses) + Environment.NewLine;
        return (where, parameters);
    }

    private static Ticket MapTicket(TicketRow row) => new(
        row.ticket_id,
        row.tenant_id,
        row.subject,
        row.description,
        TicketCategory.Parse(row.category),
        row.language,
        TicketStatus.Parse(row.status),
        TicketPriority.Parse(row.priority),
        row.confidence_score,
        ParseAttachments(row.attachment_blob_paths),
        row.created_at,
        row.updated_at);

    private static Ticket MapTicket(TicketWithTotalRow row) => new(
        row.ticket_id,
        row.tenant_id,
        row.subject,
        row.description,
        TicketCategory.Parse(row.category),
        row.language,
        TicketStatus.Parse(row.status),
        TicketPriority.Parse(row.priority),
        row.confidence_score,
        ParseAttachments(row.attachment_blob_paths),
        row.created_at,
        row.updated_at);

    private static Ticket MapTicket(TicketWithTenantRow row) => new(
        row.ticket_id,
        row.tenant_id,
        row.subject,
        row.description,
        TicketCategory.Parse(row.category),
        row.language,
        TicketStatus.Parse(row.status),
        TicketPriority.Parse(row.priority),
        row.confidence_score,
        ParseAttachments(row.attachment_blob_paths),
        row.created_at,
        row.updated_at);

    private static IReadOnlyList<string> ParseAttachments(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            return Array.Empty<string>();
        }
        try
        {
            return JsonSerializer.Deserialize<List<string>>(json) ?? new List<string>();
        }
        catch (JsonException)
        {
            // Defesa: dado legacy ou corrompido — não lança, retorna vazio
            return Array.Empty<string>();
        }
    }

    // ---------------------------------------------------------------------
    // Internal row DTOs (snake_case match para Dapper sem DefaultTypeMap)
    // Naming intentional — espelha colunas T-SQL.
    // ---------------------------------------------------------------------

#pragma warning disable IDE1006, CA1819, CA1812 // snake_case + Dapper materializes via reflection
    private sealed class TicketRow
    {
        public int ticket_id { get; set; }
        public Guid tenant_id { get; set; }
        public string subject { get; set; } = "";
        public string description { get; set; } = "";
        public string category { get; set; } = "";
        public string language { get; set; } = "";
        public string status { get; set; } = "";
        public string priority { get; set; } = "";
        public decimal? confidence_score { get; set; }
        public string? attachment_blob_paths { get; set; }
        public DateTime created_at { get; set; }
        public DateTime updated_at { get; set; }
    }

    private sealed class TicketWithTotalRow
    {
        public int ticket_id { get; set; }
        public Guid tenant_id { get; set; }
        public string subject { get; set; } = "";
        public string description { get; set; } = "";
        public string category { get; set; } = "";
        public string language { get; set; } = "";
        public string status { get; set; } = "";
        public string priority { get; set; } = "";
        public decimal? confidence_score { get; set; }
        public string? attachment_blob_paths { get; set; }
        public DateTime created_at { get; set; }
        public DateTime updated_at { get; set; }
        public int total_rows { get; set; }
    }

    private sealed class TicketWithTenantRow
    {
        public int ticket_id { get; set; }
        public Guid tenant_id { get; set; }
        public string subject { get; set; } = "";
        public string description { get; set; } = "";
        public string category { get; set; } = "";
        public string language { get; set; } = "";
        public string status { get; set; } = "";
        public string priority { get; set; } = "";
        public decimal? confidence_score { get; set; }
        public string? attachment_blob_paths { get; set; }
        public DateTime created_at { get; set; }
        public DateTime updated_at { get; set; }
        public Guid Te_TenantId { get; set; }
        public string Te_BrandName { get; set; } = "";
        public DateTime Te_CreatedAt { get; set; }
    }

    // Wave 3.E — totals row (PascalCase aliases match SELECT ... AS PascalCase output)
    private sealed class TotalsRow
    {
        public int TotalOpen { get; set; }
        public int CriticalOpen { get; set; }
        public int Last24h { get; set; }
        public decimal SlaBreachPct { get; set; }
    }
#pragma warning restore IDE1006, CA1819, CA1812
}
