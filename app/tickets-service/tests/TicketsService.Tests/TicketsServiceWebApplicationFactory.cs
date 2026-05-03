// HelpSphere tickets-service — Custom WebApplicationFactory para tests (Story 06.5c.1)
// Provides AzureAd test config (Microsoft.Identity.Web requires non-empty TenantId/ClientId
// no startup, mesmo que JWT real não seja emitido nos tests in-memory).

using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;

namespace TicketsService.Tests;

public sealed class TicketsServiceWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureAppConfiguration((_, config) =>
        {
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                // Microsoft.Identity.Web exige authority válida no startup
                ["AzureAd:Instance"] = "https://login.microsoftonline.com/",
                ["AzureAd:TenantId"] = "00000000-0000-0000-0000-000000000000",
                ["AzureAd:ClientId"] = "11111111-1111-1111-1111-111111111111",
                ["AzureAd:Audience"] = "api://11111111-1111-1111-1111-111111111111"
            });
        });
    }
}
