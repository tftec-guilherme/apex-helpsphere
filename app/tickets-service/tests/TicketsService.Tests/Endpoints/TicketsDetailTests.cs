// Story 06.5c.2 T8.2 — TicketsDetailTests
// AC-5 + AC-9: GET /api/tickets/{id} detail, 404 invalid, 404 cross-tenant, comments included

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using TicketsService.Domain.Tickets;
using TicketsService.Tests.Fixtures;
using Xunit;

namespace TicketsService.Tests.Endpoints;

public sealed class TicketsDetailTests : IClassFixture<SqliteFixture>, IClassFixture<TicketsServiceWebApplicationFactory>
{
    private readonly SqliteFixture _sqlite;
    private readonly TicketsServiceWebApplicationFactory _factory;

    public TicketsDetailTests(SqliteFixture sqlite, TicketsServiceWebApplicationFactory factory)
    {
        _sqlite = sqlite;
        _factory = factory;
    }

    private HttpClient CreateAuthenticatedClient(Guid tenantId)
    {
        var client = _factory.WithSqlite(_sqlite).CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            TestAuthHandler.SchemeName, $"{tenantId}|tester");
        return client;
    }

    [Fact]
    public async Task GetById_HappyPath_ReturnsTicketDetailWithCommentsAndTenant()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        // Pegar um ID seed via list
        var listResp = await client.GetAsync(new Uri("/api/tickets", UriKind.Relative));
        var paged = await listResp.Content.ReadFromJsonAsync<TicketsService.Domain.Common.PagedResult<Ticket>>(TestJsonOptions.SnakeCase);
        var firstTicket = paged!.Items.First(t => t.Subject == SeedHelper.SeedTicket1Subject);

        var response = await client.GetAsync(new Uri($"/api/tickets/{firstTicket.TicketId}", UriKind.Relative));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var detail = await response.Content.ReadFromJsonAsync<TicketDetail>(TestJsonOptions.SnakeCase);
        Assert.NotNull(detail);
        Assert.Equal(firstTicket.TicketId, detail!.Ticket.TicketId);
        Assert.Equal(_sqlite.SeedTenantId, detail.Tenant.TenantId);
        Assert.Equal(2, detail.Comments.Count); // Ticket 1 tem 2 comments seed
    }

    [Fact]
    public async Task GetById_NotFoundId_Returns404()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);

        var response = await client.GetAsync(new Uri("/api/tickets/999999", UriKind.Relative));

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetById_CrossTenant_Returns404_NotForbidden()
    {
        // Pegar ticket id pertencente a SeedTenantId
        var seedClient = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var listResp = await seedClient.GetAsync(new Uri("/api/tickets", UriKind.Relative));
        var paged = await listResp.Content.ReadFromJsonAsync<TicketsService.Domain.Common.PagedResult<Ticket>>(TestJsonOptions.SnakeCase);
        var ticketId = paged!.Items.First().TicketId;

        // Tentar acessar como OtherTenantId
        var otherClient = CreateAuthenticatedClient(_sqlite.OtherTenantId);
        var response = await otherClient.GetAsync(new Uri($"/api/tickets/{ticketId}", UriKind.Relative));

        // Defesa OWASP A01:2021 — 404 para não vazar existência cross-tenant
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.NotEqual(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetById_CommentsOrderedByCreatedAtAsc()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var listResp = await client.GetAsync(new Uri("/api/tickets", UriKind.Relative));
        var paged = await listResp.Content.ReadFromJsonAsync<TicketsService.Domain.Common.PagedResult<Ticket>>(TestJsonOptions.SnakeCase);
        var ticket1 = paged!.Items.First(t => t.Subject == SeedHelper.SeedTicket1Subject);

        var response = await client.GetAsync(new Uri($"/api/tickets/{ticket1.TicketId}", UriKind.Relative));
        var detail = await response.Content.ReadFromJsonAsync<TicketDetail>(TestJsonOptions.SnakeCase);

        Assert.NotNull(detail);
        var comments = detail!.Comments.ToList();
        for (int i = 1; i < comments.Count; i++)
        {
            Assert.True(comments[i].CreatedAt >= comments[i - 1].CreatedAt,
                $"Comments must be ASC ordered. Comment {i} created at {comments[i].CreatedAt} < {comments[i - 1].CreatedAt}");
        }
    }
}
