// Story 06.5c.2 T8.1 — TicketsListTests
// AC-4 + AC-9: GET /api/tickets list, filter, search, pagination, tenant isolation

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using TicketsService.Domain.Common;
using TicketsService.Domain.Tickets;
using TicketsService.Tests.Fixtures;
using Xunit;

namespace TicketsService.Tests.Endpoints;

public sealed class TicketsListTests : IClassFixture<SqliteFixture>, IClassFixture<TicketsServiceWebApplicationFactory>
{
    private readonly SqliteFixture _sqlite;
    private readonly TicketsServiceWebApplicationFactory _factory;

    public TicketsListTests(SqliteFixture sqlite, TicketsServiceWebApplicationFactory factory)
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

    [Fact]
    public async Task List_HappyPath_Returns200WithSeedTickets()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);

        var response = await client.GetAsync(new Uri("/api/tickets", UriKind.Relative));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<PagedResult<Ticket>>(TestJsonOptions.SnakeCase);
        Assert.NotNull(body);
        Assert.Equal(3, body!.Total);
        Assert.Equal(3, body.Items.Count);
    }

    [Fact]
    public async Task List_FilterByStatusOpen_ReturnsOnlyOpenTickets()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);

        var response = await client.GetAsync(new Uri("/api/tickets?status=Open", UriKind.Relative));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<PagedResult<Ticket>>(TestJsonOptions.SnakeCase);
        Assert.NotNull(body);
        Assert.All(body!.Items, t => Assert.Equal("Open", t.Status.Value));
    }

    [Fact]
    public async Task List_FilterByCategoryFinanceiro_ReturnsMatching()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);

        var response = await client.GetAsync(new Uri("/api/tickets?category=Financeiro", UriKind.Relative));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<PagedResult<Ticket>>(TestJsonOptions.SnakeCase);
        Assert.NotNull(body);
        Assert.Single(body!.Items);
        Assert.Equal("Financeiro", body.Items[0].Category.Value);
    }

    [Fact]
    public async Task List_SearchBySubject_ReturnsMatching()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);

        var response = await client.GetAsync(new Uri("/api/tickets?q=POS", UriKind.Relative));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<PagedResult<Ticket>>(TestJsonOptions.SnakeCase);
        Assert.NotNull(body);
        Assert.Single(body!.Items);
        Assert.Contains("POS", body.Items[0].Subject, StringComparison.Ordinal);
    }

    [Fact]
    public async Task List_TenantIsolation_OtherTenantSeesNoTickets()
    {
        // OtherTenantId tem 0 tickets seed; SeedTenantId tem 3.
        var client = CreateAuthenticatedClient(_sqlite.OtherTenantId);

        var response = await client.GetAsync(new Uri("/api/tickets", UriKind.Relative));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<PagedResult<Ticket>>(TestJsonOptions.SnakeCase);
        Assert.NotNull(body);
        Assert.Equal(0, body!.Total);
        Assert.Empty(body.Items);
    }

    [Fact]
    public async Task List_PageSizeTooLarge_Returns400()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);

        var response = await client.GetAsync(new Uri("/api/tickets?page_size=500", UriKind.Relative));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task List_InvalidStatusFilter_Returns400()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);

        var response = await client.GetAsync(new Uri("/api/tickets?status=InvalidStatus", UriKind.Relative));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task List_WithoutAuth_Returns401()
    {
        var client = _factory.WithSqlite(_sqlite).CreateClient();
        // Sem header Authorization

        var response = await client.GetAsync(new Uri("/api/tickets", UriKind.Relative));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
