// Story 06.5c.2 T3.2 — UserContext (anti-spoofing pattern de 06.5a v1 Python preservado)

using Microsoft.AspNetCore.Http;

namespace TicketsService.Infrastructure.Auth;

public sealed class UserContext(IHttpContextAccessor accessor) : IUserContext
{
    private const int MaxAuthorLength = 100; // NVARCHAR(100) em tbl_comments.author

    public string GetAuthor()
    {
        var user = accessor.HttpContext?.User;
        if (user is null)
        {
            return "unknown";
        }

        var author =
            user.FindFirst("name")?.Value
            ?? user.FindFirst("preferred_username")?.Value
            ?? user.FindFirst("oid")?.Value
            ?? "unknown";

        return author.Length > MaxAuthorLength ? author[..MaxAuthorLength] : author;
    }
}
