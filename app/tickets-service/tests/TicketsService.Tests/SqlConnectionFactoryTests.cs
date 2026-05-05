// HelpSphere tickets-service — SqlConnectionFactoryTests (Story 06.5c.1, T7.2)
// v2.1.0 (Decisao #22): connection string NAO contem mais "Authentication=...".
// Token AAD e injetado em runtime via SqlConnection.AccessToken (paridade Decisao #17 Python).
// Tests focam em authMode resolution (MI vs Default) + fail-fast em env vars ausentes.

using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using TicketsService.Infrastructure.Sql;
using Xunit;

namespace TicketsService.Tests;

public sealed class SqlConnectionFactoryTests
{
    private static IConfiguration BuildConfig(IDictionary<string, string?> values) =>
        new ConfigurationBuilder().AddInMemoryCollection(values).Build();

    private static IHostEnvironment FakeEnv(string envName) =>
        new TestHostEnvironment { EnvironmentName = envName };

    [Fact]
    public void BuildConnectionString_InProduction_WithClientId_UsesMiAuth()
    {
        var config = BuildConfig(new Dictionary<string, string?>
        {
            ["AZURE_SQL_SERVER"] = "sql-test.database.windows.net",
            ["AZURE_SQL_DATABASE"] = "helpsphere",
            ["AZURE_CLIENT_ID"] = "test-client-id-mi"
        });

        var (connStr, authMode, server, db) =
            SqlConnectionFactory.BuildConnectionString(config, FakeEnv("Production"));

        Assert.Equal("MI", authMode);
        Assert.Equal("sql-test.database.windows.net", server);
        Assert.Equal("helpsphere", db);
        // Decisao #22: token explicit via SqlConnection.AccessToken — connection string
        // NAO inclui mais clausula Authentication=. Validamos apenas params seguros.
        Assert.DoesNotContain("Authentication=", connStr, StringComparison.Ordinal);
        Assert.Contains("Server=tcp:sql-test.database.windows.net,1433", connStr, StringComparison.Ordinal);
        Assert.Contains("Database=helpsphere", connStr, StringComparison.Ordinal);
        Assert.Contains("Encrypt=yes", connStr, StringComparison.Ordinal);
        Assert.Contains("Connection Timeout=30", connStr, StringComparison.Ordinal);
    }

    [Fact]
    public void BuildConnectionString_InDevelopment_UsesActiveDirectoryDefault()
    {
        var config = BuildConfig(new Dictionary<string, string?>
        {
            ["AZURE_SQL_SERVER"] = "sql-dev.database.windows.net",
            ["AZURE_SQL_DATABASE"] = "helpsphere"
        });

        var (connStr, authMode, _, _) =
            SqlConnectionFactory.BuildConnectionString(config, FakeEnv("Development"));

        Assert.Equal("Default", authMode);
        // Decisao #22: connection string sem Authentication= (token explicit AccessToken).
        Assert.DoesNotContain("Authentication=", connStr, StringComparison.Ordinal);
    }

    [Fact]
    public void BuildConnectionString_InProduction_WithoutClientId_Throws()
    {
        var config = BuildConfig(new Dictionary<string, string?>
        {
            ["AZURE_SQL_SERVER"] = "sql-test.database.windows.net",
            ["AZURE_SQL_DATABASE"] = "helpsphere"
        });

        var ex = Assert.Throws<InvalidOperationException>(() =>
            SqlConnectionFactory.BuildConnectionString(config, FakeEnv("Production")));

        Assert.Contains("AZURE_CLIENT_ID", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void BuildConnectionString_MissingServer_FailsFast()
    {
        var config = BuildConfig(new Dictionary<string, string?>
        {
            ["AZURE_SQL_DATABASE"] = "helpsphere"
        });

        var ex = Assert.Throws<InvalidOperationException>(() =>
            SqlConnectionFactory.BuildConnectionString(config, FakeEnv("Development")));

        Assert.Contains("AZURE_SQL_SERVER", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void BuildConnectionString_MissingDatabase_FailsFast()
    {
        var config = BuildConfig(new Dictionary<string, string?>
        {
            ["AZURE_SQL_SERVER"] = "sql-test.database.windows.net"
        });

        var ex = Assert.Throws<InvalidOperationException>(() =>
            SqlConnectionFactory.BuildConnectionString(config, FakeEnv("Development")));

        Assert.Contains("AZURE_SQL_DATABASE", ex.Message, StringComparison.Ordinal);
    }

    private sealed class TestHostEnvironment : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "Production";
        public string ApplicationName { get; set; } = "TicketsService.Tests";
        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;
        public Microsoft.Extensions.FileProviders.IFileProvider ContentRootFileProvider { get; set; } =
            new Microsoft.Extensions.FileProviders.NullFileProvider();
    }
}
