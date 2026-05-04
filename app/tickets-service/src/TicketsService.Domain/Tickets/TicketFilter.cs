// Story 06.5c.2 T2.1 — TicketFilter param object para ITicketsRepository.ListAsync
// Status/Category nullable (opcional na query string)
// Q nullable (search subject)
// Page/PageSize com validation no endpoint (1+ e 1-100)

using TicketsService.Domain.Tickets.Enums;

namespace TicketsService.Domain.Tickets;

public sealed record TicketFilter(
    TicketStatus? Status,
    TicketCategory? Category,
    string? Query,
    int Page,
    int PageSize)
{
    public const int DefaultPageSize = 20;
    public const int MaxPageSize = 100;

    public static TicketFilter Default { get; } = new(null, null, null, 1, DefaultPageSize);
}
