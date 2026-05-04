// HelpSphere tickets-service — SqlConnectionFactory (Story 06.5c.1, T4.2-T4.6)
// Defesa Decisão #16: env-aware connection string com AAD-only auth.
// Production = ActiveDirectoryManagedIdentity (driver pega token do IMDS).
// Development = ActiveDirectoryDefault (fallback azd auth login / az login / VS code).
// Decisão #5 D06: zero password, zero connection string com SQL Auth.

using System.Data.Common;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace TicketsService.Infrastructure.Sql;

public sealed partial class SqlConnectionFactory(
    IConfiguration config,
    IHostEnvironment env,
    ILogger<SqlConnectionFactory> logger) : ISqlConnectionFactory
{
    private const int ConnectionTimeoutSeconds = 30;

    public async Task<DbConnection> CreateOpenConnectionAsync(CancellationToken ct = default)
    {
        var (connStr, authMode, server, database) = BuildConnectionString(config, env);
        LogOpeningConnection(logger, server, database, authMode);
        var conn = new SqlConnection(connStr);
        await conn.OpenAsync(ct).ConfigureAwait(false);
        return conn;
    }

    /// <summary>
    /// Construção pura da connection string (testável sem abrir conexão real).
    /// Retorna tupla com connection string + authMode (MI/Default) + server + database para logging.
    /// </summary>
    public static (string ConnectionString, string AuthMode, string Server, string Database)
        BuildConnectionString(IConfiguration config, IHostEnvironment env)
    {
        var server = config["AZURE_SQL_SERVER"]
            ?? throw new InvalidOperationException(
                "AZURE_SQL_SERVER env var ausente — fail-fast no startup. " +
                "Configure via env var no ACA ou azd env.");

        var database = config["AZURE_SQL_DATABASE"]
            ?? throw new InvalidOperationException(
                "AZURE_SQL_DATABASE env var ausente — fail-fast no startup.");

        var clientId = config["AZURE_CLIENT_ID"]; // só usado em prod (UMI clientId)

        var (authClause, authMode) = (env.IsProduction(), string.IsNullOrWhiteSpace(clientId)) switch
        {
            (true, false) => ($"Authentication=ActiveDirectoryManagedIdentity;User Id={clientId};", "MI"),
            (true, true) => throw new InvalidOperationException(
                "AZURE_CLIENT_ID ausente em Production — backend MI não pode autenticar."),
            (false, _) => ("Authentication=ActiveDirectoryDefault;", "Default")
        };

        var connStr =
            $"Server=tcp:{server},1433;" +
            $"Database={database};" +
            $"{authClause}" +
            $"Encrypt=yes;TrustServerCertificate=no;" +
            $"Connection Timeout={ConnectionTimeoutSeconds};";

        return (connStr, authMode, server, database);
    }

    // CA1848 production-grade: LoggerMessage source generator (zero-alloc, compile-time)
    [LoggerMessage(
        EventId = 1001,
        Level = LogLevel.Information,
        Message = "Opening SQL connection | server={Server} | db={Db} | auth={AuthMode}")]
    private static partial void LogOpeningConnection(
        ILogger logger, string server, string db, string authMode);
}
