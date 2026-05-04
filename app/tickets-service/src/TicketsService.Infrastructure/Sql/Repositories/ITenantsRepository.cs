// Story 06.5c.2 T2.9 — ITenantsRepository (read-only nesta story)

using TicketsService.Domain.Tenants;

namespace TicketsService.Infrastructure.Sql.Repositories;

public interface ITenantsRepository
{
    Task<Tenant?> GetByIdAsync(Guid tenantId, CancellationToken ct);
}
