// Story 06.5c.2 T10.2 — UserContextTests
// AC-3: claim chain name → preferred_username → oid → "unknown" + truncate 100

using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using TicketsService.Infrastructure.Auth;
using Xunit;

namespace TicketsService.Tests.Auth;

public sealed class UserContextTests
{
    private static UserContext BuildContext(params Claim[] claims)
    {
        var accessor = new HttpContextAccessor
        {
            HttpContext = new DefaultHttpContext
            {
                User = new ClaimsPrincipal(new ClaimsIdentity(claims, authenticationType: "Test"))
            }
        };
        return new UserContext(accessor);
    }

    [Fact]
    public void GetAuthor_WithNameClaim_ReturnsName()
    {
        var ctx = BuildContext(new Claim("name", "Diego"));

        Assert.Equal("Diego", ctx.GetAuthor());
    }

    [Fact]
    public void GetAuthor_WithoutNameButPreferredUsername_ReturnsPreferredUsername()
    {
        var ctx = BuildContext(new Claim("preferred_username", "diego@apex.example"));

        Assert.Equal("diego@apex.example", ctx.GetAuthor());
    }

    [Fact]
    public void GetAuthor_WithOnlyOid_ReturnsOid()
    {
        var ctx = BuildContext(new Claim("oid", "abc-123-def"));

        Assert.Equal("abc-123-def", ctx.GetAuthor());
    }

    [Fact]
    public void GetAuthor_WithoutAnyClaim_ReturnsUnknown()
    {
        var ctx = BuildContext();

        Assert.Equal("unknown", ctx.GetAuthor());
    }

    [Fact]
    public void GetAuthor_WithLongName_TruncatesTo100Chars()
    {
        var longName = new string('x', 200);
        var ctx = BuildContext(new Claim("name", longName));

        var result = ctx.GetAuthor();

        Assert.Equal(100, result.Length);
    }

    [Fact]
    public void GetAuthor_NameTakesPrecedenceOverPreferredUsername()
    {
        var ctx = BuildContext(
            new Claim("name", "Diego"),
            new Claim("preferred_username", "diego@apex.example"));

        Assert.Equal("Diego", ctx.GetAuthor());
    }
}
