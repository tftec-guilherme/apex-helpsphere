// Story 06.5c.2 T2.5 — UpdateTicket DTO interno (entre validators e TicketsRepository.UpdateAsync)
// Total replace de campos editáveis: subject + description + priority + attachment_blob_paths
// Status NÃO está aqui (muda via /transitions).
// Category NÃO está aqui (immutable após create).

using TicketsService.Domain.Tickets.Enums;

namespace TicketsService.Domain.Tickets;

public sealed record UpdateTicket(
    string Subject,
    string Description,
    TicketPriority Priority,
    IReadOnlyList<string> AttachmentBlobPaths);
