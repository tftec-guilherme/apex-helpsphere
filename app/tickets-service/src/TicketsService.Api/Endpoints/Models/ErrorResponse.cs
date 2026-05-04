// Story 06.5c.2 T4.2 — ErrorResponse contract (RFC 7807 problem+json shape)
// Esta record documenta o shape esperado da response de erro (testes podem deserializar).
// Em runtime, GlobalExceptionHandler usa Microsoft.AspNetCore.Mvc.ProblemDetails (idiomático .NET 10).

namespace TicketsService.Api.Endpoints.Models;

public sealed record ErrorResponse(
    string Type,
    string Title,
    int Status,
    string? Detail,
    string? Instance,
    IReadOnlyList<ValidationErrorItem>? Errors,
    IReadOnlyList<string>? Allowed);

public sealed record ValidationErrorItem(string Field, string Message);
