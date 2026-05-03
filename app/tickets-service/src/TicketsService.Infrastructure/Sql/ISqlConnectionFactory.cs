// HelpSphere tickets-service — ISqlConnectionFactory (Story 06.5c.1, T4.1)
// Decisão #16 ADR-1: Microsoft.Data.SqlClient nativo elimina cadeia pyodbc/aioodbc/HYT00.
// Token caching/refresh transparente do driver — sem código manual de auth.

using Microsoft.Data.SqlClient;

namespace TicketsService.Infrastructure.Sql;

public interface ISqlConnectionFactory
{
    /// <summary>
    /// Cria e abre uma <see cref="SqlConnection"/> usando AAD authentication
    /// (ActiveDirectoryManagedIdentity em prod, ActiveDirectoryDefault em dev).
    /// O caller é responsável pelo disposal da connection (using/await using).
    /// </summary>
    Task<SqlConnection> CreateOpenConnectionAsync(CancellationToken ct = default);
}
