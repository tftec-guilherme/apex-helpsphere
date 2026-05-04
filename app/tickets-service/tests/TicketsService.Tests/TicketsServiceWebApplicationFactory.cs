// HelpSphere tickets-service — WebApplicationFactory (Story 06.5c.1 + 06.5c.2 v2)
//
// Versão atualizada para Story 06.5c.2:
//   - Mantém AzureAd test config (compatibilidade com 06.5c.1 tests)
//   - Adiciona WithSqlite(SqliteFixture) helper para registrar SQLite + dialect override
//   - Substitui auth scheme default por TestAuthHandler quando solicitado

using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using TicketsService.Infrastructure.Sql;
using TicketsService.Tests.Fixtures;

namespace TicketsService.Tests;

public sealed class TicketsServiceWebApplicationFactory : WebApplicationFactory<Program>
{
    private SqliteFixture? _sqliteFixture;
    private bool _useTestAuth;

    /// <summary>
    /// Override DI para usar SQLite in-memory + SqliteDialect + TestAuthHandler scheme.
    /// Retorna nova instância (cliente pode chainar CreateClient depois).
    /// </summary>
    public TicketsServiceWebApplicationFactory WithSqlite(SqliteFixture fixture)
    {
        _sqliteFixture = fixture;
        _useTestAuth = true;
        return this;
    }

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

        builder.ConfigureServices(services =>
        {
            if (_sqliteFixture is not null)
            {
                // Override ISqlConnectionFactory → adapter sobre SqliteFixture
                services.RemoveAll<ISqlConnectionFactory>();
                services.AddSingleton<ISqlConnectionFactory>(
                    _ => new SqliteConnectionFactoryAdapter(_sqliteFixture));

                // Override ISqlDialect → SqliteDialect
                services.RemoveAll<ISqlDialect>();
                services.AddSingleton<ISqlDialect, SqliteDialect>();
            }

            if (_useTestAuth)
            {
                // Substitui Microsoft.Identity.Web JWT por TestAuthHandler
                services.AddAuthentication(defaultScheme: TestAuthHandler.SchemeName)
                    .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                        TestAuthHandler.SchemeName, _ => { });
            }
        });
    }
}

/// <summary>
/// Adapter ISqlConnectionFactory que delega para SqliteFixture.CreateNewOpenConnectionAsync.
/// </summary>
internal sealed class SqliteConnectionFactoryAdapter(SqliteFixture fixture) : ISqlConnectionFactory
{
    public async Task<System.Data.Common.DbConnection> CreateOpenConnectionAsync(
        CancellationToken ct = default) =>
        await fixture.CreateNewOpenConnectionAsync();
}
