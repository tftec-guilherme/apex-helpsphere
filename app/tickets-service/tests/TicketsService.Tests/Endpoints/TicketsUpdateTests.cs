// Story 06.5c.2 T8.4 — TicketsUpdateTests
// AC-7: PUT /api/tickets/{id} — total replace 4 fields, 404 cross-tenant, validation, status NOT updatable

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using TicketsService.Api.Endpoints.Models;
using TicketsService.Domain.Common;
using TicketsService.Domain.Tickets;
using TicketsService.Tests.Fixtures;
using Xunit;

namespace TicketsService.Tests.Endpoints;

public sealed class TicketsUpdateTests : IClassFixture<SqliteFixture>, IClassFixture<TicketsServiceWebApplicationFactory>
{
    private readonly SqliteFixture _sqlite;
    private readonly TicketsServiceWebApplicationFactory _factory;

    public TicketsUpdateTests(SqliteFixture sqlite, TicketsServiceWebApplicationFactory factory)
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

    private static async Task<int> CreateTicketAsync(HttpClient client, string subject = "Subject for update test")
    {
        var req = new CreateTicketRequest(subject, "Descrição inicial", "TI", "Low", null);
        var resp = await client.PostAsJsonAsync(new Uri("/api/tickets", UriKind.Relative), req, TestJsonOptions.SnakeCase);
        var created = await resp.Content.ReadFromJsonAsync<Ticket>(TestJsonOptions.SnakeCase);
        return created!.TicketId;
    }

    [Fact]
    public async Task Update_HappyPath_Returns200WithUpdatedFields()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var id = await CreateTicketAsync(client, "Update happy path");

        var request = new UpdateTicketRequest(
            Subject: "Subject atualizado",
            Description: "Descrição atualizada",
            Priority: "Critical",
            AttachmentBlobPaths: new[] { "new/path.pdf" });

        var response = await client.PutAsJsonAsync(
            new Uri($"/api/tickets/{id}", UriKind.Relative), request, TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var updated = await response.Content.ReadFromJsonAsync<Ticket>(TestJsonOptions.SnakeCase);
        Assert.Equal("Subject atualizado", updated!.Subject);
        Assert.Equal("Critical", updated.Priority.Value);
        Assert.Equal("Open", updated.Status.Value); // status preservado (não muda via PUT)
    }

    [Fact]
    public async Task Update_NotFoundId_Returns404()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var request = new UpdateTicketRequest("Subject válido", "Descrição válida", "Medium", null);

        var response = await client.PutAsJsonAsync(
            new Uri("/api/tickets/999999", UriKind.Relative), request, TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Update_CrossTenant_Returns404()
    {
        var seedClient = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var id = await CreateTicketAsync(seedClient, "Update cross tenant test");

        var otherClient = CreateAuthenticatedClient(_sqlite.OtherTenantId);
        var request = new UpdateTicketRequest("Hijack subject", "Hijack description", "Medium", null);

        var response = await otherClient.PutAsJsonAsync(
            new Uri($"/api/tickets/{id}", UriKind.Relative), request, TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Update_InvalidPriority_Returns400()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var id = await CreateTicketAsync(client, "Update invalid priority");

        var request = new UpdateTicketRequest("Subject válido", "Descrição válida", "InvalidPriority", null);

        var response = await client.PutAsJsonAsync(
            new Uri($"/api/tickets/{id}", UriKind.Relative), request, TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
