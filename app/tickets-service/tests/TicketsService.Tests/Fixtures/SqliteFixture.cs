// Story 06.5c.2 T7.3 — SqliteFixture (in-memory SQLite com Cache=Shared)
//
// Pattern xUnit IClassFixture: 1 fixture por test class, vida útil = test class.
// Conexão "keep-alive" mantida aberta para preservar in-memory database.
// Multiple connections via factory referenciam o mesmo named in-memory DB via Cache=Shared.

using System.Data;
using System.Data.Common;
using Dapper;
using Microsoft.Data.Sqlite;

namespace TicketsService.Tests.Fixtures;

public sealed class SqliteFixture : IAsyncLifetime, IDisposable
{
    private static int _typeHandlersRegistered;
    private SqliteConnection? _keepAlive;
    private bool _disposed;

    public string ConnectionString { get; }

    /// <summary>Tenant principal — todos os 3 tickets seed pertencem a ele.</summary>
    public Guid SeedTenantId { get; } = Guid.Parse("00000000-0000-0000-0000-000000000001");

    /// <summary>Tenant isolado — usado para validar cross-tenant 404 (sem tickets seed).</summary>
    public Guid OtherTenantId { get; } = Guid.Parse("00000000-0000-0000-0000-000000000002");

    public SqliteFixture()
    {
        // Named in-memory DB com Cache=Shared — múltiplas connections vêem o mesmo schema/data
        var unique = $"helpsphere-test-{Guid.NewGuid():N}";
        ConnectionString = $"Data Source={unique};Mode=Memory;Cache=Shared";
    }

    public async Task InitializeAsync()
    {
        // Registrar TypeHandlers SQLite-aware (Guid e DateTime ↔ TEXT) — global mas idempotent
        if (Interlocked.Exchange(ref _typeHandlersRegistered, 1) == 0)
        {
            SqlMapper.AddTypeHandler(new SqliteGuidTypeHandler());
            SqlMapper.AddTypeHandler(new SqliteDateTimeTypeHandler());
            SqlMapper.AddTypeHandler(new SqliteNullableDateTimeTypeHandler());
        }

        _keepAlive = new SqliteConnection(ConnectionString);
        await _keepAlive.OpenAsync();

        await ApplySchemaAsync(_keepAlive);
        await SeedHelper.SeedAsync(_keepAlive, SeedTenantId, OtherTenantId);
    }

    public async Task DisposeAsync()
    {
        if (_keepAlive is not null && !_disposed)
        {
            await _keepAlive.DisposeAsync();
            _disposed = true;
        }
    }

    public void Dispose()
    {
        if (_keepAlive is not null && !_disposed)
        {
            _keepAlive.Dispose();
            _disposed = true;
        }
        GC.SuppressFinalize(this);
    }

    /// <summary>
    /// Cria uma nova conexão (open) ao mesmo in-memory DB. Chamado pela factory de tests.
    /// </summary>
    public async Task<DbConnection> CreateNewOpenConnectionAsync()
    {
        var conn = new SqliteConnection(ConnectionString);
        await conn.OpenAsync();
        return conn;
    }

    private static async Task ApplySchemaAsync(SqliteConnection conn)
    {
        var schemaPath = Path.Combine(AppContext.BaseDirectory, "Fixtures", "sqlite-schema.sql");
        var schema = await File.ReadAllTextAsync(schemaPath);
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = schema;
        await cmd.ExecuteNonQueryAsync();
    }
}

/// <summary>Dapper TypeHandler para Guid ↔ TEXT em SQLite (storage padrão do Microsoft.Data.Sqlite).</summary>
internal sealed class SqliteGuidTypeHandler : SqlMapper.TypeHandler<Guid>
{
    public override Guid Parse(object value) => value switch
    {
        Guid g => g,
        string s => Guid.Parse(s),
        _ => throw new InvalidCastException($"Cannot parse Guid from {value?.GetType().Name}")
    };

    public override void SetValue(IDbDataParameter parameter, Guid value)
    {
        parameter.Value = value.ToString();
        parameter.DbType = DbType.String;
    }
}

/// <summary>Dapper TypeHandler para DateTime ↔ TEXT ISO 8601 em SQLite.</summary>
internal sealed class SqliteDateTimeTypeHandler : SqlMapper.TypeHandler<DateTime>
{
    public override DateTime Parse(object value) => value switch
    {
        DateTime dt => dt,
        string s => DateTime.Parse(s, System.Globalization.CultureInfo.InvariantCulture,
            System.Globalization.DateTimeStyles.RoundtripKind),
        _ => throw new InvalidCastException($"Cannot parse DateTime from {value?.GetType().Name}")
    };

    public override void SetValue(IDbDataParameter parameter, DateTime value)
    {
        parameter.Value = value.ToString("O", System.Globalization.CultureInfo.InvariantCulture);
        parameter.DbType = DbType.String;
    }
}

/// <summary>Dapper TypeHandler para DateTime? nullable ↔ TEXT em SQLite.</summary>
internal sealed class SqliteNullableDateTimeTypeHandler : SqlMapper.TypeHandler<DateTime?>
{
    public override DateTime? Parse(object value) => value switch
    {
        null => null,
        DateTime dt => dt,
        string s => DateTime.Parse(s, System.Globalization.CultureInfo.InvariantCulture,
            System.Globalization.DateTimeStyles.RoundtripKind),
        _ => throw new InvalidCastException($"Cannot parse DateTime? from {value.GetType().Name}")
    };

    public override void SetValue(IDbDataParameter parameter, DateTime? value)
    {
        parameter.Value = value?.ToString("O", System.Globalization.CultureInfo.InvariantCulture)
            ?? (object)DBNull.Value;
        parameter.DbType = DbType.String;
    }
}
