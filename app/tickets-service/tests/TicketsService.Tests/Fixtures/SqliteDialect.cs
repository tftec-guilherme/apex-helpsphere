// Story 06.5c.2 T7 — SqliteDialect (test-only ISqlDialect implementation)
// Substitui SqlServerDialect via DI override em SqliteFixture/factory.

using TicketsService.Infrastructure.Sql;

namespace TicketsService.Tests.Fixtures;

public sealed class SqliteDialect : ISqlDialect
{
    public string LastInsertedIdQuery => "SELECT last_insert_rowid();";
    public string PaginationClause => "LIMIT @page_size OFFSET @offset";
}
