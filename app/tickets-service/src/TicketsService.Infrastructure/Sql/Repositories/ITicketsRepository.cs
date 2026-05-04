// Story 06.5c.2 T2.1 — ITicketsRepository
// 5 métodos cobrindo os 5 endpoints REST.
// Tenant_id sempre passado como param (server-side, nunca do payload).

using TicketsService.Domain.Tickets;
using TicketsService.Domain.Tickets.Enums;
using TicketsService.Domain.Common;

namespace TicketsService.Infrastructure.Sql.Repositories;

public interface ITicketsRepository
{
    /// <summary>
    /// Lista tickets do tenant atual com filter + pagination.
    /// Sempre inclui WHERE tenant_id = @tenantId (defesa em profundidade — AC-9).
    /// </summary>
    Task<PagedResult<Ticket>> ListAsync(
        Guid tenantId,
        TicketFilter filter,
        CancellationToken ct);

    /// <summary>
    /// Retorna TicketDetail (Ticket + Comments + Tenant) ou null se não existe OU cross-tenant.
    /// 404 cross-tenant é defesa OWASP A01:2021 (não vazar existência).
    /// </summary>
    Task<TicketDetail?> GetByIdAsync(int id, Guid tenantId, CancellationToken ct);

    /// <summary>
    /// Cria novo ticket. Retorna Ticket com IDENTITY id real do banco.
    /// </summary>
    Task<Ticket> CreateAsync(NewTicket newTicket, Guid tenantId, CancellationToken ct);

    /// <summary>
    /// Total replace dos campos editáveis (subject + description + priority + attachments).
    /// Retorna Ticket atualizado ou null se não existe OU cross-tenant.
    /// </summary>
    Task<Ticket?> UpdateAsync(int id, UpdateTicket update, Guid tenantId, CancellationToken ct);

    /// <summary>
    /// Executa transição de status com state machine + INSERT auto-comment em transação atômica.
    /// Lança InvalidTransitionException se state machine recusa.
    /// Retorna TicketDetail atualizado ou null se ticket não existe OU cross-tenant.
    /// </summary>
    Task<TicketDetail?> TransitionStatusAsync(
        int id,
        TicketStatus targetStatus,
        string? note,
        string author,
        Guid tenantId,
        CancellationToken ct);
}
