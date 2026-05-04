// Story 06.5c.2 T1.1 — Ticket domain record
// Mapeia colunas tbl_tickets exceto comments/tenant (esses ficam em TicketDetail).
// Schema completo:
//   ticket_id INT IDENTITY PRIMARY KEY
//   tenant_id UNIQUEIDENTIFIER FK
//   subject NVARCHAR(200)
//   description NVARCHAR(MAX)
//   category VARCHAR(50) CHECK (Comercial|TI|Operacional|RH|Financeiro)
//   language VARCHAR(5) DEFAULT 'pt-BR'
//   status VARCHAR(20) CHECK (Open|InProgress|Resolved|Escalated)
//   priority VARCHAR(10) CHECK (Low|Medium|High|Critical)
//   confidence_score DECIMAL(3,2) NULL  — preenchido pelo agente IA (Lab Final)
//   attachment_blob_paths NVARCHAR(MAX) NULL  — JSON array
//   created_at DATETIME2 DEFAULT GETUTCDATE()
//   updated_at DATETIME2 DEFAULT GETUTCDATE() (trigger UTC bumps)

using TicketsService.Domain.Tickets.Enums;

namespace TicketsService.Domain.Tickets;

public sealed record Ticket(
    int TicketId,
    Guid TenantId,
    string Subject,
    string Description,
    TicketCategory Category,
    string Language,
    TicketStatus Status,
    TicketPriority Priority,
    decimal? ConfidenceScore,
    IReadOnlyList<string> AttachmentBlobPaths,
    DateTime CreatedAt,
    DateTime UpdatedAt);
