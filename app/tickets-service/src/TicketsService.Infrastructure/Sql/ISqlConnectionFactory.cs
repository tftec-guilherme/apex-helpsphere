// HelpSphere tickets-service — ISqlConnectionFactory (Story 06.5c.1 T4.1 + 06.5c.2 D-disc)
// Decisão #16 ADR-1: Microsoft.Data.SqlClient nativo elimina cadeia pyodbc/aioodbc/HYT00.
// Token caching/refresh transparente do driver — sem código manual de auth.
//
// Story 06.5c.2 D-disc: return DbConnection (não SqlConnection concreto) para permitir
// override em tests com SqliteConnection/outras implementações DbProviderFactory.

using System.Data.Common;

namespace TicketsService.Infrastructure.Sql;

public interface ISqlConnectionFactory
{
    /// <summary>
    /// Cria e abre uma <see cref="DbConnection"/> usando AAD authentication
    /// (ActiveDirectoryManagedIdentity em prod, ActiveDirectoryDefault em dev).
    /// Implementação prod retorna Microsoft.Data.SqlClient.SqlConnection;
    /// tests podem injetar SqliteConnection via DI override.
    /// O caller é responsável pelo disposal (await using/using).
    /// </summary>
    Task<DbConnection> CreateOpenConnectionAsync(CancellationToken ct = default);
}
