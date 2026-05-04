// Story 06.5c.2 T7.4 — SqlEdgeFixture (Testcontainers SQL Edge — CI only)
//
// Estado nesta story: SKELETON. Integração efetiva (image pull + schema apply via
// `helpsphere/data/migrations/001_initial_schema.sql`) diferida para Story 06.5c.5
// quando workflow CI Linux runner terá Docker BuildKit + Testcontainers ambient.
//
// Tests que precisariam dessa fidelity (CHECK constraints, trigger updated_at,
// collation Latin1_General_CI_AS) ficam documentados em concerns para Story 06.5c.5.

using Testcontainers.MsSql;

namespace TicketsService.Tests.Fixtures;

public sealed class SqlEdgeFixture : IAsyncLifetime
{
    private MsSqlContainer? _container;

    public string ConnectionString => _container?.GetConnectionString() ?? string.Empty;

    public static bool IsAvailable => Environment.GetEnvironmentVariable("CI") == "true";

    public async Task InitializeAsync()
    {
        if (!IsAvailable)
        {
            // Local sem Docker — pular initialização. Tests que dependem desta fixture
            // devem checar IsAvailable e Skip se false (xUnit não tem [Fact(Skip)] dinâmico).
            return;
        }

        // TODO Story 06.5c.5: substituir mssql:2022-latest por mcr.microsoft.com/azure-sql-edge:latest
        // quando CI runner suportar (testcontainers tem suporte explícito a SQL Edge via WithImage()).
        _container = new MsSqlBuilder()
            .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
            .Build();

        await _container.StartAsync();

        // TODO Story 06.5c.5: aplicar schema do helpsphere/data/migrations/001_initial_schema.sql
        // + popular seed determinístico (1 tenant + 3 tickets + 5 comments via SeedHelper).
    }

    public async Task DisposeAsync()
    {
        if (_container is not null)
        {
            await _container.DisposeAsync();
        }
    }
}
