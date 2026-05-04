// Story 06.5c.2 T7.5 — SeedHelper (seed determinístico para fixtures)
// 1 tenant principal (SeedTenantId) + 1 tenant alterativo (OtherTenantId — sem tickets para teste cross-tenant)
// + 3 tickets variando status (Open, InProgress, Resolved) + 5 comments distribuídos

using System.Data.Common;
using Dapper;

namespace TicketsService.Tests.Fixtures;

public static class SeedHelper
{
    public const string SeedTicket1Subject = "Erro POS terminal SITEF";
    public const string SeedTicket2Subject = "NF-e rejeição SEFAZ";
    public const string SeedTicket3Subject = "Inventário divergente WMS";

    public static async Task SeedAsync(DbConnection conn, Guid seedTenantId, Guid otherTenantId)
    {
        // Tenants
        await conn.ExecuteAsync(
            "INSERT INTO tbl_tenants (tenant_id, brand_name) VALUES (@Id, @Brand);",
            new { Id = seedTenantId, Brand = "Apex Mercado" });

        await conn.ExecuteAsync(
            "INSERT INTO tbl_tenants (tenant_id, brand_name) VALUES (@Id, @Brand);",
            new { Id = otherTenantId, Brand = "Apex Tech (other tenant)" });

        // Tickets para SeedTenantId — 3 com status diversos
        await conn.ExecuteAsync(
            "INSERT INTO tbl_tickets (tenant_id, subject, description, category, status, priority) VALUES (@T, @S, @D, @C, @St, @P);",
            new
            {
                T = seedTenantId,
                S = SeedTicket1Subject,
                D = "Terminal POS-04 retorna erro 0xFF-SITEF-7841 ao tentar TEF débito",
                C = "Operacional",
                St = "Open",
                P = "High"
            });

        await conn.ExecuteAsync(
            "INSERT INTO tbl_tickets (tenant_id, subject, description, category, status, priority) VALUES (@T, @S, @D, @C, @St, @P);",
            new
            {
                T = seedTenantId,
                S = SeedTicket2Subject,
                D = "Lote NF-e rejeitado pelo SEFAZ-SP com cStat=204",
                C = "Financeiro",
                St = "InProgress",
                P = "Critical"
            });

        await conn.ExecuteAsync(
            "INSERT INTO tbl_tickets (tenant_id, subject, description, category, status, priority) VALUES (@T, @S, @D, @C, @St, @P);",
            new
            {
                T = seedTenantId,
                S = SeedTicket3Subject,
                D = "WMS reportou divergência de 23 unidades no inventário cíclico",
                C = "TI",
                St = "Resolved",
                P = "Medium"
            });

        // Comments — 5 distribuídos: 2 no ticket #1, 2 no ticket #2, 1 no ticket #3
        var t1 = await GetSeedTicketIdAsync(conn, seedTenantId, SeedTicket1Subject);
        var t2 = await GetSeedTicketIdAsync(conn, seedTenantId, SeedTicket2Subject);
        var t3 = await GetSeedTicketIdAsync(conn, seedTenantId, SeedTicket3Subject);

        await conn.ExecuteAsync(
            "INSERT INTO tbl_comments (ticket_id, author, content) VALUES (@T, @A, @C);",
            new { T = t1, A = "Diego", C = "Reproduzido em loja 17, terminal #4." });
        await conn.ExecuteAsync(
            "INSERT INTO tbl_comments (ticket_id, author, content) VALUES (@T, @A, @C);",
            new { T = t1, A = "Marina", C = "SITEF reiniciado, aguardando análise." });

        await conn.ExecuteAsync(
            "INSERT INTO tbl_comments (ticket_id, author, content) VALUES (@T, @A, @C);",
            new { T = t2, A = "Carla", C = "cStat=204 = duplicidade. Verificando lote anterior." });
        await conn.ExecuteAsync(
            "INSERT INTO tbl_comments (ticket_id, author, content) VALUES (@T, @A, @C);",
            new { T = t2, A = "Bruno", C = "Confirmado lote duplicado por race condition no batch." });

        await conn.ExecuteAsync(
            "INSERT INTO tbl_comments (ticket_id, author, content) VALUES (@T, @A, @C);",
            new { T = t3, A = "Letícia", C = "Inventário corrigido. Causa: WMS sync delay." });
    }

    public static Task<int> GetSeedTicketIdAsync(DbConnection conn, Guid tenantId, string subject) =>
        conn.QuerySingleAsync<int>(
            "SELECT ticket_id FROM tbl_tickets WHERE tenant_id = @T AND subject = @S;",
            new { T = tenantId, S = subject });
}
