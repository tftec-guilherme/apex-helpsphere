// Story 06.5c.2 T1.7 — Comment domain record (read-only nesta story)
// Schema:
//   comment_id INT IDENTITY PRIMARY KEY
//   ticket_id INT FK
//   author NVARCHAR(100) NOT NULL
//   content NVARCHAR(MAX) NOT NULL
//   created_at DATETIME2 DEFAULT GETUTCDATE()

namespace TicketsService.Domain.Comments;

public sealed record Comment(
    int CommentId,
    int TicketId,
    string Author,
    string Content,
    DateTime CreatedAt);
