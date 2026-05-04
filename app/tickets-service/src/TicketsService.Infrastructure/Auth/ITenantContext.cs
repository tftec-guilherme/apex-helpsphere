// Story 06.5c.2 T3.1 — ITenantContext
// Resolve tenant_id Guid do JWT claim 'app_tenant_id' (Decisão Q1B).
// Lança UnauthorizedAccessException se claim ausente/malformado → 403 problem+json.

namespace TicketsService.Infrastructure.Auth;

public interface ITenantContext
{
    /// <summary>
    /// Retorna tenant_id Guid do claim 'app_tenant_id' do usuário corrente.
    /// </summary>
    /// <exception cref="UnauthorizedAccessException">
    /// Quando claim ausente, vazio, ou não-Guid. HTTP 403 (autorização falhou — auth passou).
    /// </exception>
    Guid GetTenantId();
}
