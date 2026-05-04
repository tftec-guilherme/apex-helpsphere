// Story 06.5c.2 T2.9 — TenantsRepository (Dapper)

using Dapper;
using TicketsService.Domain.Tenants;

namespace TicketsService.Infrastructure.Sql.Repositories;

public sealed class TenantsRepository(ISqlConnectionFactory connectionFactory) : ITenantsRepository
{
    private const int CommandTimeoutSeconds = 30;

    public async Task<Tenant?> GetByIdAsync(Guid tenantId, CancellationToken ct)
    {
        const string sql =
            "SELECT tenant_id, brand_name, created_at " +
            "FROM tbl_tenants " +
            "WHERE tenant_id = @tenantId;";

        await using var conn = await connectionFactory.CreateOpenConnectionAsync(ct);
        var row = await conn.QuerySingleOrDefaultAsync<TenantRow?>(
            new CommandDefinition(sql, new { tenantId },
                commandTimeout: CommandTimeoutSeconds, cancellationToken: ct));

        return row is null ? null : new Tenant(row.tenant_id, row.brand_name, row.created_at);
    }

#pragma warning disable IDE1006, CA1812 // snake_case + Dapper materializes via reflection
    private sealed class TenantRow
    {
        public Guid tenant_id { get; set; }
        public string brand_name { get; set; } = "";
        public DateTime created_at { get; set; }
    }
#pragma warning restore IDE1006, CA1812
}
