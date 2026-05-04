// Story 06.5c.2 T7.6 — TestAuthHandler (mock JWT for endpoint tests)
//
// Substitui Microsoft.Identity.Web.AddMicrosoftIdentityWebApi em test scope.
// Aceita header `Authorization: Test {tenant_id}|{author}` e popula claims:
//   - app_tenant_id (Decisão Q1B)
//   - name (UserContext extraction)
//
// Usage em testes:
//   client.DefaultRequestHeaders.Authorization = new("Test", $"{tenantId}|{author}");

using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace TicketsService.Tests.Fixtures;

public sealed class TestAuthHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "Test";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue("Authorization", out var headerValues))
        {
            return Task.FromResult(AuthenticateResult.Fail("Missing Authorization header"));
        }

        var header = headerValues.ToString();
        if (!header.StartsWith($"{SchemeName} ", StringComparison.Ordinal))
        {
            return Task.FromResult(AuthenticateResult.Fail("Invalid auth scheme"));
        }

        var payload = header[(SchemeName.Length + 1)..];
        var parts = payload.Split('|', 2);

        var claims = new List<Claim>();
        if (parts.Length > 0 && !string.IsNullOrWhiteSpace(parts[0]))
        {
            claims.Add(new Claim("app_tenant_id", parts[0]));
        }
        if (parts.Length > 1 && !string.IsNullOrWhiteSpace(parts[1]))
        {
            claims.Add(new Claim("name", parts[1]));
        }

        var identity = new ClaimsIdentity(claims, SchemeName);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, SchemeName);

        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
