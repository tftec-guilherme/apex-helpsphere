// Story 06.5c.2 T5.1 — Validators manuais (sem FluentValidation, skeleton compacto)
// Decisão @dev: manual switch + ValidationException — menos deps, código denso.
// Lança ValidationException com lista completa de erros (não para no primeiro).

using TicketsService.Api.Endpoints.Models;
using TicketsService.Domain.Common;
using TicketsService.Domain.Tickets;
using TicketsService.Domain.Tickets.Enums;

namespace TicketsService.Api.Validation;

public static class RequestValidators
{
    private const int SubjectMinLength = 5;
    private const int SubjectMaxLength = 200;
    private const int DescriptionMaxLength = 16000; // sanity cap (NVARCHAR(MAX))
    private const int MaxAttachments = 10;
    private const int AttachmentPathMaxLength = 500;
    private const int NoteMaxLength = 1000;

    public static NewTicket ValidateAndBuildNewTicket(CreateTicketRequest req)
    {
        var errors = new List<ValidationError>();

        // Subject
        if (string.IsNullOrWhiteSpace(req.Subject))
        {
            errors.Add(new ValidationError("subject", "subject is required"));
        }
        else if (req.Subject.Length is < SubjectMinLength or > SubjectMaxLength)
        {
            errors.Add(new ValidationError(
                "subject",
                $"subject must be between {SubjectMinLength} and {SubjectMaxLength} characters"));
        }

        // Description
        if (string.IsNullOrWhiteSpace(req.Description))
        {
            errors.Add(new ValidationError("description", "description is required"));
        }
        else if (req.Description.Length > DescriptionMaxLength)
        {
            errors.Add(new ValidationError(
                "description",
                $"description must not exceed {DescriptionMaxLength} characters"));
        }

        // Category (required, must be valid enum)
        TicketCategory? category = null;
        if (string.IsNullOrWhiteSpace(req.Category))
        {
            errors.Add(new ValidationError("category", "category is required"));
        }
        else if (!TicketCategory.TryParse(req.Category, out category))
        {
            errors.Add(new ValidationError(
                "category",
                $"category must be one of: {string.Join(", ", TicketCategory.All.Select(c => c.Value))}"));
        }

        // Priority (optional, default Medium)
        TicketPriority? priority = TicketPriority.Medium;
        if (!string.IsNullOrWhiteSpace(req.Priority))
        {
            if (!TicketPriority.TryParse(req.Priority, out priority))
            {
                errors.Add(new ValidationError(
                    "priority",
                    $"priority must be one of: {string.Join(", ", TicketPriority.All.Select(p => p.Value))}"));
            }
        }

        // Attachments (optional)
        var attachments = ValidateAttachments(req.AttachmentBlobPaths, errors);

        ThrowIfErrors(errors);

        return new NewTicket(
            Subject: req.Subject!,
            Description: req.Description!,
            Category: category!,
            Priority: priority!,
            AttachmentBlobPaths: attachments);
    }

    public static UpdateTicket ValidateAndBuildUpdateTicket(UpdateTicketRequest req)
    {
        var errors = new List<ValidationError>();

        // Subject
        if (string.IsNullOrWhiteSpace(req.Subject))
        {
            errors.Add(new ValidationError("subject", "subject is required"));
        }
        else if (req.Subject.Length is < SubjectMinLength or > SubjectMaxLength)
        {
            errors.Add(new ValidationError(
                "subject",
                $"subject must be between {SubjectMinLength} and {SubjectMaxLength} characters"));
        }

        // Description
        if (string.IsNullOrWhiteSpace(req.Description))
        {
            errors.Add(new ValidationError("description", "description is required"));
        }
        else if (req.Description.Length > DescriptionMaxLength)
        {
            errors.Add(new ValidationError(
                "description",
                $"description must not exceed {DescriptionMaxLength} characters"));
        }

        // Priority (required em PUT — total replace)
        TicketPriority? priority = null;
        if (string.IsNullOrWhiteSpace(req.Priority))
        {
            errors.Add(new ValidationError("priority", "priority is required"));
        }
        else if (!TicketPriority.TryParse(req.Priority, out priority))
        {
            errors.Add(new ValidationError(
                "priority",
                $"priority must be one of: {string.Join(", ", TicketPriority.All.Select(p => p.Value))}"));
        }

        var attachments = ValidateAttachments(req.AttachmentBlobPaths, errors);

        ThrowIfErrors(errors);

        return new UpdateTicket(
            Subject: req.Subject!,
            Description: req.Description!,
            Priority: priority!,
            AttachmentBlobPaths: attachments);
    }

    public static (TicketStatus TargetStatus, string? Note) ValidateTransitionRequest(TransitionRequest req)
    {
        var errors = new List<ValidationError>();

        TicketStatus? targetStatus = null;
        if (string.IsNullOrWhiteSpace(req.TargetStatus))
        {
            errors.Add(new ValidationError("target_status", "target_status is required"));
        }
        else if (!TicketStatus.TryParse(req.TargetStatus, out targetStatus))
        {
            errors.Add(new ValidationError(
                "target_status",
                $"target_status must be one of: {string.Join(", ", TicketStatus.All.Select(s => s.Value))}"));
        }

        if (req.Note is not null && req.Note.Length > NoteMaxLength)
        {
            errors.Add(new ValidationError(
                "note",
                $"note must not exceed {NoteMaxLength} characters"));
        }

        ThrowIfErrors(errors);

        return (targetStatus!, string.IsNullOrWhiteSpace(req.Note) ? null : req.Note);
    }

    public static TicketFilter ValidateAndBuildFilter(
        string? status, string? category, string? q, int? page, int? pageSize)
    {
        var errors = new List<ValidationError>();

        TicketStatus? statusEnum = null;
        if (!string.IsNullOrWhiteSpace(status))
        {
            if (!TicketStatus.TryParse(status, out statusEnum))
            {
                errors.Add(new ValidationError(
                    "status",
                    $"status must be one of: {string.Join(", ", TicketStatus.All.Select(s => s.Value))}"));
            }
        }

        TicketCategory? categoryEnum = null;
        if (!string.IsNullOrWhiteSpace(category))
        {
            if (!TicketCategory.TryParse(category, out categoryEnum))
            {
                errors.Add(new ValidationError(
                    "category",
                    $"category must be one of: {string.Join(", ", TicketCategory.All.Select(c => c.Value))}"));
            }
        }

        var pageVal = page ?? 1;
        if (pageVal < 1)
        {
            errors.Add(new ValidationError("page", "page must be >= 1"));
        }

        var pageSizeVal = pageSize ?? TicketFilter.DefaultPageSize;
        if (pageSizeVal is < 1 or > TicketFilter.MaxPageSize)
        {
            errors.Add(new ValidationError(
                "page_size",
                $"page_size must be between 1 and {TicketFilter.MaxPageSize}"));
        }

        ThrowIfErrors(errors);

        return new TicketFilter(statusEnum, categoryEnum, q, pageVal, pageSizeVal);
    }

    private static IReadOnlyList<string> ValidateAttachments(
        IReadOnlyList<string>? attachments, List<ValidationError> errors)
    {
        if (attachments is null || attachments.Count == 0)
        {
            return Array.Empty<string>();
        }

        if (attachments.Count > MaxAttachments)
        {
            errors.Add(new ValidationError(
                "attachment_blob_paths",
                $"max {MaxAttachments} attachments allowed (got {attachments.Count})"));
        }

        for (var i = 0; i < attachments.Count; i++)
        {
            var path = attachments[i];
            if (string.IsNullOrWhiteSpace(path))
            {
                errors.Add(new ValidationError(
                    $"attachment_blob_paths[{i}]",
                    "attachment path cannot be empty"));
            }
            else if (path.Length > AttachmentPathMaxLength)
            {
                errors.Add(new ValidationError(
                    $"attachment_blob_paths[{i}]",
                    $"attachment path exceeds {AttachmentPathMaxLength} chars"));
            }
        }

        return attachments;
    }

    private static void ThrowIfErrors(List<ValidationError> errors)
    {
        if (errors.Count > 0)
        {
            throw new ValidationException(errors);
        }
    }
}
