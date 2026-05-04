// Story 06.5c.2 T8.3 — TicketsCreateTests
// AC-6: POST /api/tickets — happy 201 + Location, validation 400, tenant_id from JWT (ignored from body)

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using TicketsService.Api.Endpoints.Models;
using TicketsService.Domain.Tickets;
using TicketsService.Tests.Fixtures;
using Xunit;

namespace TicketsService.Tests.Endpoints;

public sealed class TicketsCreateTests : IClassFixture<SqliteFixture>, IClassFixture<TicketsServiceWebApplicationFactory>
{
    private readonly SqliteFixture _sqlite;
    private readonly TicketsServiceWebApplicationFactory _factory;

    public TicketsCreateTests(SqliteFixture sqlite, TicketsServiceWebApplicationFactory factory)
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
    public async Task Create_HappyPath_Returns201WithLocationAndBody()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var request = new CreateTicketRequest(
            Subject: "Novo ticket de teste integração",
            Description: "Descrição válida com mais de 10 caracteres",
            Category: "TI",
            Priority: "High",
            AttachmentBlobPaths: new[] { "blob/storage/path1.png" });

        var response = await client.PostAsJsonAsync(
            new Uri("/api/tickets", UriKind.Relative), request, TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.NotNull(response.Headers.Location);
        Assert.StartsWith("/api/tickets/", response.Headers.Location!.ToString(), StringComparison.Ordinal);

        var created = await response.Content.ReadFromJsonAsync<Ticket>(TestJsonOptions.SnakeCase);
        Assert.NotNull(created);
        Assert.Equal("Novo ticket de teste integração", created!.Subject);
        Assert.Equal("Open", created.Status.Value); // sempre cria Open
        Assert.Equal(_sqlite.SeedTenantId, created.TenantId); // server-side
    }

    [Fact]
    public async Task Create_SubjectTooShort_Returns400()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var request = new CreateTicketRequest(
            Subject: "abc", // < 5 chars
            Description: "Descrição válida",
            Category: "TI",
            Priority: "Medium",
            AttachmentBlobPaths: null);

        var response = await client.PostAsJsonAsync(
            new Uri("/api/tickets", UriKind.Relative), request, TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Create_InvalidCategory_Returns400()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var request = new CreateTicketRequest(
            Subject: "Subject válido",
            Description: "Descrição válida",
            Category: "InvalidCategory",
            Priority: "Medium",
            AttachmentBlobPaths: null);

        var response = await client.PostAsJsonAsync(
            new Uri("/api/tickets", UriKind.Relative), request, TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Create_MissingDescription_Returns400()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var request = new CreateTicketRequest(
            Subject: "Subject válido",
            Description: null,
            Category: "TI",
            Priority: "Medium",
            AttachmentBlobPaths: null);

        var response = await client.PostAsJsonAsync(
            new Uri("/api/tickets", UriKind.Relative), request, TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Create_DefaultsPriorityToMedium_WhenOmitted()
    {
        var client = CreateAuthenticatedClient(_sqlite.SeedTenantId);
        var request = new CreateTicketRequest(
            Subject: "Subject default priority",
            Description: "Descrição válida",
            Category: "RH",
            Priority: null,
            AttachmentBlobPaths: null);

        var response = await client.PostAsJsonAsync(
            new Uri("/api/tickets", UriKind.Relative), request, TestJsonOptions.SnakeCase);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var created = await response.Content.ReadFromJsonAsync<Ticket>(TestJsonOptions.SnakeCase);
        Assert.Equal("Medium", created!.Priority.Value);
    }
}
