// HelpSphere tickets-service — HealthEndpointTests (Story 06.5c.1, T7.1)
// AC-2: GET /health retorna HTTP 200 com body {"status":"healthy","version":"1.0.0"}
// AC-2: /health NÃO requer auth, NÃO toca SQL.

using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace TicketsService.Tests;

public sealed class HealthEndpointTests : IClassFixture<TicketsServiceWebApplicationFactory>
{
    private readonly TicketsServiceWebApplicationFactory _factory;

    public HealthEndpointTests(TicketsServiceWebApplicationFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task HealthEndpoint_Returns200_WithHealthyStatus()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync(new Uri("/health", UriKind.Relative));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("\"status\":\"healthy\"", body, StringComparison.Ordinal);
        Assert.Contains("\"version\":\"1.0.0\"", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task HealthEndpoint_AllowsAnonymous_NoAuthHeaderRequired()
    {
        var client = _factory.CreateClient();

        // Sem header Authorization — não deve retornar 401
        var response = await client.GetAsync(new Uri("/health", UriKind.Relative));

        Assert.NotEqual(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
