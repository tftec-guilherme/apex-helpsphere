// Story 06.5c.2 T2.10 — InvalidTransitionException
// Lançada por TicketsRepository.TransitionStatusAsync quando state machine recusa.
// Mapeada para HTTP 422 Unprocessable Entity em GlobalExceptionHandler com `allowed[]`.

using TicketsService.Domain.Tickets.Enums;

namespace TicketsService.Domain.Common;

public sealed class InvalidTransitionException : Exception
{
    public TicketStatus From { get; }
    public TicketStatus To { get; }
    public IReadOnlyCollection<TicketStatus> Allowed { get; }

    public InvalidTransitionException(
        TicketStatus from,
        TicketStatus to,
        IReadOnlyCollection<TicketStatus> allowed)
        : base($"Cannot transition from '{from.Value}' to '{to.Value}'. Allowed: [{string.Join(", ", allowed.Select(s => s.Value))}]")
    {
        From = from;
        To = to;
        Allowed = allowed;
    }
}
