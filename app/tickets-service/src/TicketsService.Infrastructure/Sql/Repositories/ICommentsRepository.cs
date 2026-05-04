// Story 06.5c.2 T2.7 — ICommentsRepository
// Read-only nesta story (POST /comments user-driven fica para 06.5c.6 frontend).
// AddSystemCommentAsync é internal helper chamado por TicketsRepository.TransitionStatusAsync.

using System.Data;
using System.Data.Common;
using TicketsService.Domain.Comments;

namespace TicketsService.Infrastructure.Sql.Repositories;

public interface ICommentsRepository
{
    /// <summary>
    /// Lista comments do ticket ORDER BY created_at ASC (mais antigos primeiro — feed thread).
    /// </summary>
    Task<IReadOnlyList<Comment>> GetByTicketIdAsync(int ticketId, CancellationToken ct);

    /// <summary>
    /// INSERT comment dentro de transação existente (chamado por TransitionStatusAsync).
    /// Não abre conexão própria — usa connection + transaction passados.
    /// </summary>
    Task AddSystemCommentAsync(
        int ticketId,
        string author,
        string content,
        DbConnection connection,
        DbTransaction transaction,
        CancellationToken ct);
}
