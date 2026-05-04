// Story 06.5c.2 T2.10 — NotFoundException
// Lançada por endpoints quando recurso não existe OU é cross-tenant (defesa OWASP A01:2021).
// Mapeada para HTTP 404 em GlobalExceptionHandler.

namespace TicketsService.Domain.Common;

public sealed class NotFoundException : Exception
{
    public string Entity { get; }
    public string Identifier { get; }

    public NotFoundException(string entity, string identifier)
        : base($"{entity} '{identifier}' not found")
    {
        Entity = entity;
        Identifier = identifier;
    }
}
