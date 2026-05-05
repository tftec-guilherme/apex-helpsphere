// Wave 3.E (v2.1.0) — StatsEndpoints
// Single read-only endpoint que serve o Dashboard frontend (Wave 3.G).
// Mesmo middleware auth dos demais (RequireAuthorization), tenant resolvido
// server-side via ITenantContext (claim 'app_tenant_id' do JWT — Decisão Q1B).

using TicketsService.Infrastructure.Auth;
using TicketsService.Infrastructure.Sql.Repositories;

namespace TicketsService.Api.Endpoints;

public static class StatsEndpoints
{
    public static IEndpointRouteBuilder MapStatsEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/tickets/stats")
            .RequireAuthorization()
            .WithTags("Stats");

        // GET /api/tickets/stats — aggregations para Dashboard
        group.MapGet("/", GetStatsAsync)
             .WithName("GetTicketStats");

        return app;
    }

    private static async Task<IResult> GetStatsAsync(
        ITicketsRepository repo,
        ITenantContext tenantCtx,
        CancellationToken ct)
    {
        var tenantId = tenantCtx.GetTenantId();
        var stats = await repo.GetStatsAsync(tenantId, ct);
        return Results.Ok(stats);
    }
}
