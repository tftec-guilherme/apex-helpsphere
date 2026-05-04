// Story 06.5c.2 T8.5 — TicketsTransitionsTests
// AC-8: POST /api/tickets/{id}/transitions — state machine, 422 invalid, atomicity

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using TicketsService.Api.Endpoints.Models;
using TicketsService.Domain.Common;
using TicketsService.Domain.Tickets;
using TicketsService.Tests.Fixtures;
using Xunit;

namespace TicketsService.Tests.Endpoints;

public sealed class TicketsTransitionsTests : IClassFixture<SqliteFixture>, IClassFixture<TicketsServiceWebApplicationFactory>
{
    private readonly SqliteFixture _sqlite;
    private readonly TicketsServiceWebApplicationFactory _factory;

    public TicketsTransitionsTests(SqliteFixture sqlite, TicketsServiceWebApplicationFactory factory)
    {
        _sqlite = sqlite;
        _factory = factory;
    }

    private HttpClient CreateAuthenticatedClient(Guid tenantId, string author = "tester")
    {
        var client = _factory.WithSqlite(_sqlite).CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            TestAuthHandler.SchemeName, $"{tenantId}|{author}");
        return client;
    }

    private static async Task<int> CreateOpenTicketAsync(HttpClient client, string subject)
    {
        var req = new CreateTicketRequest(subject, "Descrição válida", "TI", "Medium", null);
        var resp = await client.PostAsJsonAsync(new Uri("/api/tickets", UriKind.Relative), req, TestJsonOptions.SnakeCase);
        var created = await resp.Content.ReadFromJsonAsync<Ticket>(TestJsonOptions.SnakeCase);
        return created!.TicketId;
    }

    [Fact]
    public async Task Transition_OpenToInProgress_Returns200()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var id = await CreateOpenTicketAsync(client, "T1: open->inprogress");

        var request = new TransitionRequest("InProgress", null);
        var response = await client.PostAsJsonAsync(
            new Uri($"/api/tickets/{id}/transitions", UriKind.Relative), request, TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var detail = await response.Content.ReadFromJsonAsync<TicketDetail>(TestJsonOptions.SnakeCase);
        Assert.Equal("InProgress", detail!.Ticket.Status.Value);
    }

    [Fact]
    public async Task Transition_OpenToEscalated_Returns200()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var id = await CreateOpenTicketAsync(client, "T2: open->escalated");

        var request = new TransitionRequest("Escalated", "urgência crítica");
        var response = await client.PostAsJsonAsync(
            new Uri($"/api/tickets/{id}/transitions", UriKind.Relative), request, TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var detail = await response.Content.ReadFromJsonAsync<TicketDetail>(TestJsonOptions.SnakeCase);
        Assert.Equal("Escalated", detail!.Ticket.Status.Value);
    }

    [Fact]
    public async Task Transition_OpenToResolved_Returns422_InvalidTransition()
    {
        // Open -> Resolved é inválido (deve ir via InProgress primeiro)
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var id = await CreateOpenTicketAsync(client, "T3: open->resolved invalid");

        var request = new TransitionRequest("Resolved", null);
        var response = await client.PostAsJsonAsync(
            new Uri($"/api/tickets/{id}/transitions", UriKind.Relative), request, TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.UnprocessableEntity, response.StatusCode);
    }

    [Fact]
    public async Task Transition_InProgressToResolved_FullCycleWorks()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId, "Diego");
        var id = await CreateOpenTicketAsync(client, "T4: full cycle");

        // Open -> InProgress
        await client.PostAsJsonAsync(
            new Uri($"/api/tickets/{id}/transitions", UriKind.Relative),
            new TransitionRequest("InProgress", null), TestJsonOptions.SnakeCase);

        // InProgress -> Resolved (com note)
        var resp2 = await client.PostAsJsonAsync(
            new Uri($"/api/tickets/{id}/transitions", UriKind.Relative),
            new TransitionRequest("Resolved", "Resolução final aplicada"), TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.OK, resp2.StatusCode);
        var detail = await resp2.Content.ReadFromJsonAsync<TicketDetail>(TestJsonOptions.SnakeCase);
        Assert.Equal("Resolved", detail!.Ticket.Status.Value);

        // Auto-comments criados — pelo menos 2 (uma transição cada)
        Assert.True(detail.Comments.Count >= 2, $"Expected >= 2 comments after 2 transitions, got {detail.Comments.Count}");
        Assert.All(detail.Comments, c => Assert.Equal("Diego", c.Author));
        Assert.Contains(detail.Comments, c => c.Content.Contains("Status alterado: Open → InProgress", StringComparison.Ordinal));
        Assert.Contains(detail.Comments, c => c.Content.Contains("Status alterado: InProgress → Resolved", StringComparison.Ordinal));
        Assert.Contains(detail.Comments, c => c.Content.Contains("Resolução final aplicada", StringComparison.Ordinal));
    }

    [Fact]
    public async Task Transition_FromResolved_Returns422_TerminalState()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var id = await CreateOpenTicketAsync(client, "T5: resolved terminal");

        // Move pra Resolved primeiro
        await client.PostAsJsonAsync(
            new Uri($"/api/tickets/{id}/transitions", UriKind.Relative),
            new TransitionRequest("InProgress", null), TestJsonOptions.SnakeCase);
        await client.PostAsJsonAsync(
            new Uri($"/api/tickets/{id}/transitions", UriKind.Relative),
            new TransitionRequest("Resolved", null), TestJsonOptions.SnakeCase);

        // Agora qualquer transição é inválida (Resolved é terminal)
        var resp = await client.PostAsJsonAsync(
            new Uri($"/api/tickets/{id}/transitions", UriKind.Relative),
            new TransitionRequest("InProgress", null), TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.UnprocessableEntity, resp.StatusCode);
    }

    [Fact]
    public async Task Transition_InvalidTargetStatus_Returns400()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var id = await CreateOpenTicketAsync(client, "T6: invalid target");

        var request = new TransitionRequest("NotAStatus", null);
        var response = await client.PostAsJsonAsync(
            new Uri($"/api/tickets/{id}/transitions", UriKind.Relative), request, TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Transition_CrossTenant_Returns404()
    {
        var seedClient = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var id = await CreateOpenTicketAsync(seedClient, "T7: cross tenant");

        var otherClient = CreateAuthenticatedClient(_sqlite.OtherTenantId);
        var response = await otherClient.PostAsJsonAsync(
            new Uri($"/api/tickets/{id}/transitions", UriKind.Relative),
            new TransitionRequest("InProgress", null), TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
