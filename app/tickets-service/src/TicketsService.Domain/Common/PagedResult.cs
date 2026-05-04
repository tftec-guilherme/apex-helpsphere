// Story 06.5c.2 T1.9 — PagedResult<T> response envelope para list endpoints
// Production-pattern: items + total + page + page_size para client paginar com confidence

namespace TicketsService.Domain.Common;

public sealed record PagedResult<T>(
    IReadOnlyList<T> Items,
    int Total,
    int Page,
    int PageSize);
