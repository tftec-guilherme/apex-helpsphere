// HelpSphere tickets-service — AuthenticationTests (Story 06.5c.1, T7.3)
// AC-4: Endpoint protegido (/internal/sql-ping) sem token → HTTP 401
// AC-4: Header WWW-Authenticate: Bearer presente

using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace TicketsService.Tests;

public sealed class AuthenticationTests : IClassFixture<TicketsServiceWebApplicationFactory>
{
    private readonly TicketsServiceWebApplicationFactory _factory;

    public AuthenticationTests(TicketsServiceWebApplicationFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task ProtectedEndpoint_WithoutToken_Returns401()
    {
        var client = _factory.CreateClient();

        // Sem header Authorization — JWT middleware deve rejeitar
        var response = await client.GetAsync(new Uri("/internal/sql-ping", UriKind.Relative));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ProtectedEndpoint_Returns401_WithWwwAuthenticateBearerHeader()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync(new Uri("/internal/sql-ping", UriKind.Relative));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Contains("Bearer", string.Join(",", response.Headers.WwwAuthenticate),
            StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ProtectedEndpoint_WithInvalidToken_Returns401()
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", "invalid-token-xyz");

        var response = await client.GetAsync(new Uri("/internal/sql-ping", UriKind.Relative));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
