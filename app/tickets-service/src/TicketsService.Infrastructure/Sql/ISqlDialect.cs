// Story 06.5c.2 D-disc — ISqlDialect abstraction
// Permite portabilidade SQL Server ↔ SQLite onde sintaxe diverge:
//   - SCOPE_IDENTITY() (SQL Server) vs last_insert_rowid() (SQLite)
// Production = SqlServerDialect (default). Tests = SqliteDialect (override via DI).

namespace TicketsService.Infrastructure.Sql;

public interface ISqlDialect
{
    /// <summary>
    /// Query que retorna ID do último INSERT na connection corrente.
    /// SQL Server: "SELECT CAST(SCOPE_IDENTITY() AS INT);"
    /// SQLite:     "SELECT last_insert_rowid();"
    /// </summary>
    string LastInsertedIdQuery { get; }

    /// <summary>
    /// SQL fragment para paginação (após ORDER BY).
    /// SQL Server: "OFFSET @offset ROWS FETCH NEXT @page_size ROWS ONLY"
    /// SQLite:     "LIMIT @page_size OFFSET @offset"
    /// </summary>
    string PaginationClause { get; }
}

public sealed class SqlServerDialect : ISqlDialect
{
    public string LastInsertedIdQuery => "SELECT CAST(SCOPE_IDENTITY() AS INT);";
    public string PaginationClause => "OFFSET @offset ROWS FETCH NEXT @page_size ROWS ONLY";
}
