// Story 06.5c.2 T4.2 — POST /api/tickets/{id}/transitions request payload
// target_status validado contra TicketStatus.Parse + TicketTransition.IsValid.
// note opcional (1-1000 chars se preenchido, vira parte do auto-comment).

namespace TicketsService.Api.Endpoints.Models;

public sealed record TransitionRequest(
    string? TargetStatus,
    string? Note);
