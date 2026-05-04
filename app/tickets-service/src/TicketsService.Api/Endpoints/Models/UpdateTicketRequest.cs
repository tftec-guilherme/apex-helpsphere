// Story 06.5c.2 T4.2 — PUT /api/tickets/{id} request payload
// Total replace de campos editáveis. status/category ignorados se vierem (immutable via PUT).

namespace TicketsService.Api.Endpoints.Models;

public sealed record UpdateTicketRequest(
    string? Subject,
    string? Description,
    string? Priority,
    IReadOnlyList<string>? AttachmentBlobPaths);
