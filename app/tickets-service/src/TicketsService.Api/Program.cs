// HelpSphere tickets-service — Minimal API skeleton (Story 06.5c.1)
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
//   * tenant_id resolvido server-side via JWT claim (Story 06.5c.2)
// =============================================================================

using System.Diagnostics;
using Dapper;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Identity.Web;
using TicketsService.Infrastructure.Sql;

var builder = WebApplication.CreateBuilder(args);

// JWT validation via Entra ID (config em appsettings.json -> AzureAd, overridable
// via env vars AzureAd__TenantId, AzureAd__ClientId etc no ACA).
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));

builder.Services.AddAuthorization();

builder.Services.AddSingleton<ISqlConnectionFactory, SqlConnectionFactory>();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// AC-2: Health endpoint — sem auth, sem SQL (in-memory) — sobrevive smoke test
// mesmo se SQL temporariamente indisponível.
app.MapGet("/health", () => Results.Ok(new
{
    status = "healthy",
    version = "1.0.0"
}))
.AllowAnonymous()
.WithName("Health");

// AC-3: SQL ping — exige JWT, executa SELECT 1 via Dapper, mede latência.
// Endpoint de smoke pós-deploy para validar conectividade SQL + MI auth.
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

await app.RunAsync().ConfigureAwait(false);

// Required for WebApplicationFactory<Program> in tests
public partial class Program;
