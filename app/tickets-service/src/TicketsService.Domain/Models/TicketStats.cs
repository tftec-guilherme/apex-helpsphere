// Wave 3.E (v2.1.0) — TicketStats DTO
// Aggregations consumidas pelo Dashboard frontend (Wave 3.G).
// Contract espelhado em app/frontend/src/api/stats.ts (Wave 3.G).
//
// Defesa multi-tenant: TODA query subjacente filtra WHERE tenant_id = @TenantId
// (Decisão #16 — RLS-like, defesa em profundidade — TicketsRepository.GetStatsAsync).

namespace TicketsService.Domain.Models;

public sealed record TicketStats(
    int TotalOpen,
    decimal SlaBreachPct,
    int CriticalOpen,
    int Last24h,
    IReadOnlyList<StatusCount> ByStatus,
    IReadOnlyList<CategoryCount> ByCategory,
    IReadOnlyList<PriorityCount> ByPriority,
    IReadOnlyList<DailyVolume> DailyVolume7d
);

public sealed record StatusCount(string Status, int Count);
public sealed record CategoryCount(string Category, int Count);
public sealed record PriorityCount(string Priority, int Count);
public sealed record DailyVolume(string Date, int Count);
