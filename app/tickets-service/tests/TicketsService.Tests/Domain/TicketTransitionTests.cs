// Story 06.5c.2 T9.2 — TicketTransition state machine pure unit tests
// AC-8 (state machine canônica ITSM): Open→InProgress|Escalated, InProgress→Resolved|Escalated,
// Escalated→InProgress, Resolved→∅ (terminal)

using TicketsService.Domain.Tickets;
using TicketsService.Domain.Tickets.Enums;
using Xunit;

namespace TicketsService.Tests.Domain;

public sealed class TicketTransitionTests
{
    public static IEnumerable<object[]> AllTransitions()
    {
        // Format: from, to, expected
        // Open allows: InProgress, Escalated
        yield return new object[] { TicketStatus.Open, TicketStatus.InProgress, true };
        yield return new object[] { TicketStatus.Open, TicketStatus.Escalated, true };
        yield return new object[] { TicketStatus.Open, TicketStatus.Resolved, false };
        yield return new object[] { TicketStatus.Open, TicketStatus.Open, false };

        // InProgress allows: Resolved, Escalated
        yield return new object[] { TicketStatus.InProgress, TicketStatus.Resolved, true };
        yield return new object[] { TicketStatus.InProgress, TicketStatus.Escalated, true };
        yield return new object[] { TicketStatus.InProgress, TicketStatus.Open, false };
        yield return new object[] { TicketStatus.InProgress, TicketStatus.InProgress, false };

        // Escalated allows: InProgress
        yield return new object[] { TicketStatus.Escalated, TicketStatus.InProgress, true };
        yield return new object[] { TicketStatus.Escalated, TicketStatus.Resolved, false };
        yield return new object[] { TicketStatus.Escalated, TicketStatus.Open, false };
        yield return new object[] { TicketStatus.Escalated, TicketStatus.Escalated, false };

        // Resolved is terminal
        yield return new object[] { TicketStatus.Resolved, TicketStatus.Open, false };
        yield return new object[] { TicketStatus.Resolved, TicketStatus.InProgress, false };
        yield return new object[] { TicketStatus.Resolved, TicketStatus.Escalated, false };
        yield return new object[] { TicketStatus.Resolved, TicketStatus.Resolved, false };
    }

    [Theory]
    [MemberData(nameof(AllTransitions))]
    public void IsValid_StateMachine_MatchesCanonicalITSM(
        TicketStatus from,
        TicketStatus to,
        bool expected)
    {
        Assert.Equal(expected, TicketTransition.IsValid(from, to));
    }

    [Fact]
    public void AllowedFrom_Open_ReturnsInProgressAndEscalated()
    {
        var allowed = TicketTransition.AllowedFrom(TicketStatus.Open);
        Assert.Contains(TicketStatus.InProgress, allowed);
        Assert.Contains(TicketStatus.Escalated, allowed);
        Assert.Equal(2, allowed.Count);
    }

    [Fact]
    public void AllowedFrom_InProgress_ReturnsResolvedAndEscalated()
    {
        var allowed = TicketTransition.AllowedFrom(TicketStatus.InProgress);
        Assert.Contains(TicketStatus.Resolved, allowed);
        Assert.Contains(TicketStatus.Escalated, allowed);
        Assert.Equal(2, allowed.Count);
    }

    [Fact]
    public void AllowedFrom_Escalated_ReturnsOnlyInProgress()
    {
        var allowed = TicketTransition.AllowedFrom(TicketStatus.Escalated);
        Assert.Single(allowed);
        Assert.Contains(TicketStatus.InProgress, allowed);
    }

    [Fact]
    public void AllowedFrom_Resolved_IsTerminal_ReturnsEmpty()
    {
        var allowed = TicketTransition.AllowedFrom(TicketStatus.Resolved);
        Assert.Empty(allowed);
    }
}
