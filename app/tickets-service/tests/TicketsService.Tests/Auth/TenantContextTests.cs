// Story 06.5c.2 T10.1 — TenantContextTests
// AC-3: claim 'app_tenant_id' presente OK, ausente → throw, malformado → throw

using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using TicketsService.Infrastructure.Auth;
using Xunit;

namespace TicketsService.Tests.Auth;

public sealed class TenantContextTests
{
    private static TenantContext BuildContext(params Claim[] claims)
    {
        var accessor = new HttpContextAccessor
        {
            HttpContext = new DefaultHttpContext
            {
                User = new ClaimsPrincipal(new ClaimsIdentity(claims, authenticationType: "Test"))
            }
        };
        return new TenantContext(accessor);
    }

    [Fact]
    public void GetTenantId_WithValidClaim_ReturnsParsedGuid()
    {
        var expected = Guid.NewGuid();
        var ctx = BuildContext(new Claim(TenantContext.ClaimType, expected.ToString()));

        var actual = ctx.GetTenantId();

        Assert.Equal(expected, actual);
    }

    [Fact]
    public void GetTenantId_WithoutClaim_ThrowsUnauthorized()
    {
        var ctx = BuildContext();

        var ex = Assert.Throws<UnauthorizedAccessException>(() => ctx.GetTenantId());
        Assert.Contains(TenantContext.ClaimType, ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void GetTenantId_WithMalformedClaim_ThrowsUnauthorized()
    {
        var ctx = BuildContext(new Claim(TenantContext.ClaimType, "not-a-guid"));

        var ex = Assert.Throws<UnauthorizedAccessException>(() => ctx.GetTenantId());
        Assert.Contains("not a valid Guid", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void GetTenantId_WithEmptyClaimValue_ThrowsUnauthorized()
    {
        var ctx = BuildContext(new Claim(TenantContext.ClaimType, ""));

        Assert.Throws<UnauthorizedAccessException>(() => ctx.GetTenantId());
    }
}
