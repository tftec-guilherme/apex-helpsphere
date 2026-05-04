// Story 06.5c.2 T2.10 — ValidationException
// Lançada por RequestValidators quando payload viola constraints (subject < 5 chars, etc).
// Mapeada para HTTP 400 em GlobalExceptionHandler com errors[].

namespace TicketsService.Domain.Common;

public sealed class ValidationException : Exception
{
    public IReadOnlyList<ValidationError> Errors { get; }

    public ValidationException(IReadOnlyList<ValidationError> errors)
        : base($"Validation failed with {errors.Count} error(s)")
    {
        Errors = errors;
    }
}
