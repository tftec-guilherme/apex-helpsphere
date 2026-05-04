// Story 06.5c.2 T4.1 — POST /api/tickets request payload
// Snake_case JSON via global JsonNamingPolicy.SnakeCaseLower (configurado em Program.cs).
// tenant_id e author NÃO entram aqui — server-side via JWT (ignorados se vierem no body).

namespace TicketsService.Api.Endpoints.Models;

public sealed record CreateTicketRequest(
    string? Subject,
    string? Description,
    string? Category,
    string? Priority,
    IReadOnlyList<string>? AttachmentBlobPaths);
