// Story 06.5c.2 T1.2 — TicketDetail (Ticket + Comments[] + Tenant)
// Retornado por GET /api/tickets/{id} via single-query LEFT JOIN no Repository (evita N+1).

using TicketsService.Domain.Comments;
using TicketsService.Domain.Tenants;

namespace TicketsService.Domain.Tickets;

public sealed record TicketDetail(
    Ticket Ticket,
    IReadOnlyList<Comment> Comments,
    Tenant Tenant);
