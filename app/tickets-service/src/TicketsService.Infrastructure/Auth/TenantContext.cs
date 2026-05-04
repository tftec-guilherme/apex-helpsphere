// Story 06.5c.2 T3.1 — TenantContext (resolve tenant_id do JWT custom claim)
// Decisão Q1B Pre-Flight: claim 'app_tenant_id' (preserva Decisão #8 D06)
//   - frontend NUNCA envia tenant_id em payload/query/header
//   - server-side resolution único — anti-spoofing
//   - failure modes: claim ausente / vazio / não-Guid → 403 (autorização)

using Microsoft.AspNetCore.Http;

namespace TicketsService.Infrastructure.Auth;

public sealed class TenantContext(IHttpContextAccessor accessor) : ITenantContext
{
    public const string ClaimType = "app_tenant_id";

    public Guid GetTenantId()
    {
        var user = accessor.HttpContext?.User
            ?? throw new UnauthorizedAccessException("No HttpContext available");

        var claim = user.FindFirst(ClaimType)?.Value;

        if (string.IsNullOrWhiteSpace(claim))
        {
            throw new UnauthorizedAccessException(
                $"Missing required claim '{ClaimType}' in JWT");
        }

        if (!Guid.TryParse(claim, out var tenantId))
        {
            throw new UnauthorizedAccessException(
                $"Claim '{ClaimType}' is not a valid Guid: '{claim}'");
        }

        return tenantId;
    }
}
