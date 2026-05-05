// HelpSphere tickets-service — SqlConnectionFactory (Story 06.5c.1, T4.2-T4.6)
// Defesa Decisao #16 + Decisao #17: AAD-only auth via token explicit injection.
// Production = ManagedIdentityCredential (UMI clientId via AZURE_CLIENT_ID).
// Development = DefaultAzureCredential (azd auth login / az login / VS).
// Bypassa auth provider system do SqlClient (que mudou de stable para package
// opcional fragil em SqlClient v6+ — Microsoft.Data.SqlClient.Extensions.Azure).
// Paridade com backend Python que faz mesmo pattern via SQL_COPT_SS_ACCESS_TOKEN.
// Decisao #5 D06: zero password, zero connection string com SQL Auth.

using System.Data.Common;
using Azure.Core;
using Azure.Identity;
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
    private static readonly string[] SqlScope = ["https://database.windows.net/.default"];

    public async Task<DbConnection> CreateOpenConnectionAsync(CancellationToken ct = default)
    {
        var (connStr, authMode, server, database) = BuildConnectionString(config, env);
        LogOpeningConnection(logger, server, database, authMode);

        var conn = new SqlConnection(connStr);

        // Token explicit injection (Decisao #17) — pega AAD token via Azure.Identity
        // e injeta em SqlConnection.AccessToken antes de abrir.
        var clientId = config["AZURE_CLIENT_ID"];
        TokenCredential credential = env.IsProduction()
            ? new ManagedIdentityCredential(clientId)
            : new DefaultAzureCredential();
        var tokenResult = await credential.GetTokenAsync(
            new TokenRequestContext(SqlScope), ct).ConfigureAwait(false);
        conn.AccessToken = tokenResult.Token;

        await conn.OpenAsync(ct).ConfigureAwait(false);
        return conn;
    }

    /// <summary>
    /// Construção pura da connection string (testável sem abrir conexão real).
    /// Retorna tupla com connection string + authMode (MI/Default) + server + database para logging.
    /// SEM clausula Authentication= (token e injetado via SqlConnection.AccessToken).
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

        var clientId = config["AZURE_CLIENT_ID"];

        var authMode = (env.IsProduction(), string.IsNullOrWhiteSpace(clientId)) switch
        {
            (true, false) => "MI",
            (true, true) => throw new InvalidOperationException(
                "AZURE_CLIENT_ID ausente em Production — backend MI nao pode autenticar."),
            (false, _) => "Default"
        };

        var connStr =
            $"Server=tcp:{server},1433;" +
            $"Database={database};" +
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
