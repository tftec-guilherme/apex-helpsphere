// Story 06.5c.2 T2.4 — NewTicket DTO interno (entre validators e TicketsRepository.CreateAsync)
// Pós-validação: language default "pt-BR" pode ser injetado aqui.
// tenant_id e author NÃO entram aqui — passados como params separados em CreateAsync (server-side).

using TicketsService.Domain.Tickets.Enums;

namespace TicketsService.Domain.Tickets;

public sealed record NewTicket(
    string Subject,
    string Description,
    TicketCategory Category,
    TicketPriority Priority,
    IReadOnlyList<string> AttachmentBlobPaths);
