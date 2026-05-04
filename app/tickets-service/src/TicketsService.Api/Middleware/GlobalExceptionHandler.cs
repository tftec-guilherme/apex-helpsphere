// Story 06.5c.2 T5.2 — GlobalExceptionHandler (.NET 10 IExceptionHandler nativo)
// Mapping:
//   ValidationException        → 400 problem+json com errors[]
//   InvalidTransitionException → 422 problem+json com allowed[]
//   NotFoundException          → 404 problem+json
//   UnauthorizedAccessException → 403 problem+json (auth passou, autorização falhou)
//   Outros                     → 500 com correlation id (Activity.Current?.Id)

using System.Diagnostics;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using TicketsService.Domain.Common;

namespace TicketsService.Api.Middleware;

public sealed partial class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    private const string ProblemBaseUri = "https://docs.helpsphere.example/probs/";

    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var problem = MapToProblemDetails(exception, httpContext);

        LogException(logger, exception.GetType().Name, problem.Status ?? 500, exception);

        httpContext.Response.StatusCode = problem.Status ?? StatusCodes.Status500InternalServerError;
        httpContext.Response.ContentType = "application/problem+json";

        await httpContext.Response.WriteAsJsonAsync(
            problem,
            options: null,
            contentType: "application/problem+json",
            cancellationToken).ConfigureAwait(false);

        return true;
    }

    private static ProblemDetails MapToProblemDetails(Exception exception, HttpContext context)
    {
        var instance = context.Request.Path.ToString();

        return exception switch
        {
            ValidationException ve => CreateValidationProblem(ve, instance),
            InvalidTransitionException ite => CreateInvalidTransitionProblem(ite, instance),
            NotFoundException nfe => CreateNotFoundProblem(nfe, instance),
            UnauthorizedAccessException uae => CreateForbiddenProblem(uae, instance),
            _ => CreateInternalServerErrorProblem(exception, instance)
        };
    }

    private static ProblemDetails CreateValidationProblem(ValidationException ve, string instance)
    {
        var problem = new ProblemDetails
        {
            Type = $"{ProblemBaseUri}validation",
            Title = "Validation failed",
            Status = StatusCodes.Status400BadRequest,
            Detail = ve.Message,
            Instance = instance
        };
        problem.Extensions["errors"] = ve.Errors
            .Select(e => new { field = e.Field, message = e.Message })
            .ToArray();
        return problem;
    }

    private static ProblemDetails CreateInvalidTransitionProblem(
        InvalidTransitionException ite, string instance)
    {
        var problem = new ProblemDetails
        {
            Type = $"{ProblemBaseUri}invalid-transition",
            Title = "Invalid status transition",
            Status = StatusCodes.Status422UnprocessableEntity,
            Detail = ite.Message,
            Instance = instance
        };
        problem.Extensions["from"] = ite.From.Value;
        problem.Extensions["to"] = ite.To.Value;
        problem.Extensions["allowed"] = ite.Allowed.Select(s => s.Value).ToArray();
        return problem;
    }

    private static ProblemDetails CreateNotFoundProblem(NotFoundException nfe, string instance) => new()
    {
        Type = $"{ProblemBaseUri}not-found",
        Title = "Resource not found",
        Status = StatusCodes.Status404NotFound,
        Detail = nfe.Message,
        Instance = instance
    };

    private static ProblemDetails CreateForbiddenProblem(
        UnauthorizedAccessException uae, string instance) => new()
        {
            Type = $"{ProblemBaseUri}forbidden",
            Title = "Forbidden",
            Status = StatusCodes.Status403Forbidden,
            Detail = uae.Message,
            Instance = instance
        };

    private static ProblemDetails CreateInternalServerErrorProblem(Exception ex, string instance)
    {
        var problem = new ProblemDetails
        {
            Type = $"{ProblemBaseUri}internal-server-error",
            Title = "Internal server error",
            Status = StatusCodes.Status500InternalServerError,
            Detail = "An unexpected error occurred. See correlation id for diagnostics.",
            Instance = instance
        };
        var correlationId = Activity.Current?.Id ?? "n/a";
        problem.Extensions["correlation_id"] = correlationId;
        problem.Extensions["exception_type"] = ex.GetType().FullName;
        return problem;
    }

    [LoggerMessage(
        EventId = 2001,
        Level = LogLevel.Warning,
        Message = "GlobalExceptionHandler caught {ExceptionType} → {StatusCode}")]
    private static partial void LogException(
        ILogger logger, string exceptionType, int statusCode, Exception ex);
}
