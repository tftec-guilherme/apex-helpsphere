// HelpSphere tickets-service — Minimal API (Story 06.5c.1 + Story 06.5c.2)
// =============================================================================
// Defesa arquitetural (resumo — detalhes em apex-helpsphere/DECISION-LOG.md #16):
//
//   * Minimal API: boot ~5s, código denso, AOT-ready (vs Controllers verbose)
//   * Dapper: schema gerenciado por sql_init.sh em T-SQL puro (vs EF Core
//     Code-First que duplicaria source of truth)
//   * Microsoft.Data.SqlClient + ActiveDirectoryManagedIdentity: native MS,
//     in-process, token cache transparente — RESOLVE TODA a cadeia
//     pyodbc/aioodbc/HYT00 que provou frágil em 18 runs da Sessão 5 v1
//   * Microsoft.Identity.Web: enterprise JWT validation + token cache + OBO
//     ready (vs JwtBearer puro com mais boilerplate)
//
// Pedagogia D06 (Decisão #5 production-grade preservada):
//   * AAD-only auth — zero password
//   * JWT obrigatório em endpoints autenticados (exceto /health)
//   * MI scoped grants reais (tickets MI vê só tbl_tickets/comments + RO tenants)
//   * tenant_id resolvido server-side via JWT custom claim 'app_tenant_id' (Q1B)
//   * State machine ITSM canônico Open→InProgress→Resolved + Escalated cruzado (Q3B)
//   * Cross-tenant 404 (não 403) — OWASP A01:2021
//   * Transação atômica em /transitions (UPDATE status + INSERT auto-comment)
// =============================================================================

using System.Diagnostics;
using System.Text.Json;
using Dapper;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Identity.Web;
using TicketsService.Api.Endpoints;
using TicketsService.Api.Middleware;
using TicketsService.Domain.Tickets.Enums;
using TicketsService.Infrastructure.Auth;
using TicketsService.Infrastructure.Sql;
using TicketsService.Infrastructure.Sql.Repositories;

var builder = WebApplication.CreateBuilder(args);

// JWT validation via Entra ID (config em appsettings.json -> AzureAd, overridable
// via env vars AzureAd__TenantId, AzureAd__ClientId etc no ACA).
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));

builder.Services.AddAuthorization();

// HTTP context para resolver claims em ITenantContext / IUserContext (Story 06.5c.2 T3)
builder.Services.AddHttpContextAccessor();

// Snake_case JSON serialization (espelha v1 Python contract: subject, attachment_blob_paths, target_status)
// + smart enum converters explícitos (não depender de [JsonConverter] attribute em record primary ctor)
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower;
    options.SerializerOptions.DictionaryKeyPolicy = JsonNamingPolicy.SnakeCaseLower;
    options.SerializerOptions.Converters.Add(new TicketStatusJsonConverter());
    options.SerializerOptions.Converters.Add(new TicketCategoryJsonConverter());
    options.SerializerOptions.Converters.Add(new TicketPriorityJsonConverter());
});

// SQL connection (herdado da Story 06.5c.1)
builder.Services.AddSingleton<ISqlConnectionFactory, SqlConnectionFactory>();

// SQL dialect (Story 06.5c.2 D-disc — production = SqlServer; tests podem override SqliteDialect)
builder.Services.AddSingleton<ISqlDialect, SqlServerDialect>();

// Auth contexts (Scoped — depende de HttpContext per request)
builder.Services.AddScoped<ITenantContext, TenantContext>();
builder.Services.AddScoped<IUserContext, UserContext>();

// Repositories (Scoped — connection lifecycle por request)
builder.Services.AddScoped<ITicketsRepository, TicketsRepository>();
builder.Services.AddScoped<ICommentsRepository, CommentsRepository>();
builder.Services.AddScoped<ITenantsRepository, TenantsRepository>();

// Global exception handler (.NET 10 IExceptionHandler nativo)
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails();

var app = builder.Build();

// Register Dapper TypeHandlers para smart enums (TicketStatus, Category, Priority)
DapperTypeHandlerRegistration.RegisterAll();

app.UseExceptionHandler();
app.UseAuthentication();
app.UseAuthorization();

// AC-2 (06.5c.1): Health endpoint — sem auth, sem SQL (in-memory) — sobrevive smoke
// mesmo se SQL temporariamente indisponível.
app.MapGet("/health", () => Results.Ok(new
{
    status = "healthy",
    version = "1.0.0"
}))
.AllowAnonymous()
.WithName("Health");

// AC-3 (06.5c.1): SQL ping — exige JWT, executa SELECT 1 via Dapper, mede latência.
app.MapGet("/internal/sql-ping", async (
    ISqlConnectionFactory factory,
    CancellationToken ct) =>
{
    var sw = Stopwatch.StartNew();
    await using var conn = await factory.CreateOpenConnectionAsync(ct);
    var result = await conn.QuerySingleAsync<int>(
        new CommandDefinition("SELECT 1", commandTimeout: 30, cancellationToken: ct));
    sw.Stop();
    return Results.Ok(new
    {
        sql = result == 1 ? "reachable" : "unexpected",
        duration_ms = sw.ElapsedMilliseconds
    });
})
.RequireAuthorization()
.WithName("SqlPing");

// Story 06.5c.2 — 5 endpoints REST sob /api/tickets/*
app.MapTicketsEndpoints();

// Wave 3.E (v2.1.0) — GET /api/tickets/stats (Dashboard aggregations)
app.MapStatsEndpoints();

await app.RunAsync().ConfigureAwait(false);

// Required for WebApplicationFactory<Program> in tests
public partial class Program;
