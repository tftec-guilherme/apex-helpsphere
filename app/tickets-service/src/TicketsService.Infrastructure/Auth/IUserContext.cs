// Story 06.5c.2 T3.2 — IUserContext (resolve author do JWT)

namespace TicketsService.Infrastructure.Auth;

public interface IUserContext
{
    /// <summary>
    /// Retorna author string do JWT claim chain: name → preferred_username → oid → "unknown".
    /// Truncado em 100 chars (constraint tbl_comments.author NVARCHAR(100)).
    /// </summary>
    string GetAuthor();
}
