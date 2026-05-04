// Story 06.5c.2 T2.10 — ValidationError struct para problem+json errors[]

namespace TicketsService.Domain.Common;

public sealed record ValidationError(string Field, string Message);
