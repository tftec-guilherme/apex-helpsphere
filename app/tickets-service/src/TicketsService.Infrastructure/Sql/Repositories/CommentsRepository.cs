// Story 06.5c.2 T2.8 — CommentsRepository (Dapper)

using System.Data.Common;
using Dapper;
using TicketsService.Domain.Comments;

namespace TicketsService.Infrastructure.Sql.Repositories;

public sealed class CommentsRepository(ISqlConnectionFactory connectionFactory) : ICommentsRepository
{
    private const int CommandTimeoutSeconds = 30;

    public async Task<IReadOnlyList<Comment>> GetByTicketIdAsync(int ticketId, CancellationToken ct)
    {
        const string sql =
            "SELECT comment_id, ticket_id, author, content, created_at " +
            "FROM tbl_comments " +
            "WHERE ticket_id = @ticketId " +
            "ORDER BY created_at ASC;";

        await using var conn = await connectionFactory.CreateOpenConnectionAsync(ct);
        var rows = await conn.QueryAsync<CommentRow>(
            new CommandDefinition(sql, new { ticketId },
                commandTimeout: CommandTimeoutSeconds, cancellationToken: ct));

        return rows.Select(r => new Comment(r.comment_id, r.ticket_id, r.author, r.content, r.created_at))
                   .ToList();
    }

    public async Task AddSystemCommentAsync(
        int ticketId,
        string author,
        string content,
        DbConnection connection,
        DbTransaction transaction,
        CancellationToken ct)
    {
        const string sql =
            "INSERT INTO tbl_comments (ticket_id, author, content) " +
            "VALUES (@ticketId, @author, @content);";

        await connection.ExecuteAsync(
            new CommandDefinition(sql, new { ticketId, author, content },
                transaction: transaction,
                commandTimeout: CommandTimeoutSeconds,
                cancellationToken: ct));
    }

#pragma warning disable IDE1006, CA1812 // snake_case + Dapper materializes via reflection
    private sealed class CommentRow
    {
        public int comment_id { get; set; }
        public int ticket_id { get; set; }
        public string author { get; set; } = "";
        public string content { get; set; } = "";
        public DateTime created_at { get; set; }
    }
#pragma warning restore IDE1006, CA1812
}
