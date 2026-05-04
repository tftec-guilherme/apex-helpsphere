// Story 06.5c.2 T4.3-T4.8 — TicketsEndpoints (5 endpoints REST + MapTicketsEndpoints extension)
//
// Todos endpoints sob /api/tickets/* exigem JWT (RequireAuthorization no group).
// tenant_id e author resolvidos server-side via ITenantContext / IUserContext.
// 404 cross-tenant (não 403) — defesa OWASP A01:2021 Broken Access Control.

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using TicketsService.Api.Endpoints.Models;
using TicketsService.Api.Validation;
using TicketsService.Domain.Common;
using TicketsService.Infrastructure.Auth;
using TicketsService.Infrastructure.Sql.Repositories;

namespace TicketsService.Api.Endpoints;

public static class TicketsEndpoints
{
    public static IEndpointRouteBuilder MapTicketsEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/tickets")
            .RequireAuthorization()
            .WithTags("Tickets");

        // AC-4: GET /api/tickets — list com filter + pagination
        group.MapGet("/", ListTicketsAsync)
             .WithName("ListTickets");

        // AC-5: GET /api/tickets/{id} — detail
        group.MapGet("/{id:int}", GetTicketAsync)
             .WithName("GetTicket");

        // AC-6: POST /api/tickets — create
        group.MapPost("/", CreateTicketAsync)
             .WithName("CreateTicket");

        // AC-7: PUT /api/tickets/{id} — total replace de campos editáveis
        group.MapPut("/{id:int}", UpdateTicketAsync)
             .WithName("UpdateTicket");

        // AC-8: POST /api/tickets/{id}/transitions — state machine
        group.MapPost("/{id:int}/transitions", TransitionTicketAsync)
             .WithName("TransitionTicket");

        return app;
    }

    // -----------------------------------------------------------------------
    // Handlers
    // -----------------------------------------------------------------------

    private static async Task<IResult> ListTicketsAsync(
        [FromQuery] string? status,
        [FromQuery] string? category,
        [FromQuery] string? q,
        [FromQuery] int? page,
        [FromQuery(Name = "page_size")] int? pageSize,
        ITicketsRepository repo,
        ITenantContext tenantCtx,
        CancellationToken ct)
    {
        var filter = RequestValidators.ValidateAndBuildFilter(status, category, q, page, pageSize);
        var result = await repo.ListAsync(tenantCtx.GetTenantId(), filter, ct);
        return Results.Ok(result);
    }

    private static async Task<IResult> GetTicketAsync(
        int id,
        ITicketsRepository repo,
        ITenantContext tenantCtx,
        CancellationToken ct)
    {
        var detail = await repo.GetByIdAsync(id, tenantCtx.GetTenantId(), ct);
        if (detail is null)
        {
            // 404 cross-tenant defense (não 403 — não vazar existência)
            throw new NotFoundException("Ticket", id.ToString(System.Globalization.CultureInfo.InvariantCulture));
        }
        return Results.Ok(detail);
    }

    private static async Task<IResult> CreateTicketAsync(
        CreateTicketRequest request,
        ITicketsRepository repo,
        ITenantContext tenantCtx,
        CancellationToken ct)
    {
        var newTicket = RequestValidators.ValidateAndBuildNewTicket(request);
        var created = await repo.CreateAsync(newTicket, tenantCtx.GetTenantId(), ct);
        return Results.Created($"/api/tickets/{created.TicketId}", created);
    }

    private static async Task<IResult> UpdateTicketAsync(
        int id,
        UpdateTicketRequest request,
        ITicketsRepository repo,
        ITenantContext tenantCtx,
        CancellationToken ct)
    {
        var update = RequestValidators.ValidateAndBuildUpdateTicket(request);
        var updated = await repo.UpdateAsync(id, update, tenantCtx.GetTenantId(), ct);
        if (updated is null)
        {
            throw new NotFoundException("Ticket", id.ToString(System.Globalization.CultureInfo.InvariantCulture));
        }
        return Results.Ok(updated);
    }

    private static async Task<IResult> TransitionTicketAsync(
        int id,
        TransitionRequest request,
        ITicketsRepository repo,
        ITenantContext tenantCtx,
        IUserContext userCtx,
        CancellationToken ct)
    {
        var (targetStatus, note) = RequestValidators.ValidateTransitionRequest(request);
        var detail = await repo.TransitionStatusAsync(
            id,
            targetStatus,
            note,
            userCtx.GetAuthor(),
            tenantCtx.GetTenantId(),
            ct);

        if (detail is null)
        {
            throw new NotFoundException("Ticket", id.ToString(System.Globalization.CultureInfo.InvariantCulture));
        }

        return Results.Ok(detail);
    }
}
