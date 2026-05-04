// Story 06.5c.2 T1.6 — TicketTransition state machine pura
// Decisão Q3B (Pre-Flight): ITSM canônico
//   Open       → InProgress, Escalated
//   InProgress → Resolved, Escalated
//   Escalated  → InProgress (re-active após análise)
//   Resolved   → ∅ (terminal — closed-loop, sem reabertura silenciosa)
// Defesa: zero I/O, fully unit-testável, ~16 casos exaustivos via [Theory]

using TicketsService.Domain.Tickets.Enums;

namespace TicketsService.Domain.Tickets;

public static class TicketTransition
{
    private static readonly Dictionary<TicketStatus, IReadOnlySet<TicketStatus>> AllowedTransitions = new()
    {
        [TicketStatus.Open] = new HashSet<TicketStatus> { TicketStatus.InProgress, TicketStatus.Escalated },
        [TicketStatus.InProgress] = new HashSet<TicketStatus> { TicketStatus.Resolved, TicketStatus.Escalated },
        [TicketStatus.Escalated] = new HashSet<TicketStatus> { TicketStatus.InProgress },
        [TicketStatus.Resolved] = new HashSet<TicketStatus>(), // terminal — closed-loop
    };

    public static bool IsValid(TicketStatus from, TicketStatus to) =>
        AllowedTransitions.TryGetValue(from, out var allowed) && allowed.Contains(to);

    public static IReadOnlyCollection<TicketStatus> AllowedFrom(TicketStatus current) =>
        AllowedTransitions.TryGetValue(current, out var allowed)
            ? [.. allowed]
            : [];
}
