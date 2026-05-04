// Story 06.5c.2 T1.8 — Tenant domain record (read-only nesta story)
// Schema:
//   tenant_id UNIQUEIDENTIFIER PRIMARY KEY
//   brand_name NVARCHAR(100) NOT NULL
//   created_at DATETIME2 DEFAULT GETUTCDATE()

namespace TicketsService.Domain.Tenants;

public sealed record Tenant(
    Guid TenantId,
    string BrandName,
    DateTime CreatedAt);
