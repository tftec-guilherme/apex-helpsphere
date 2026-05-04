// Story 06.5c.2 T1.3 — TicketStatus smart enum
// Defesa: type safety completo (compilador previne typo Open vs open)
// + Parse defensivo central (lança ArgumentException em valor inválido)
// + Dapper-friendly via .Value property (matches T-SQL CHECK constraint)
// + JSON serializa para string ("Open") via TicketStatusJsonConverter

using System.Text.Json;
using System.Text.Json.Serialization;

namespace TicketsService.Domain.Tickets.Enums;

[JsonConverter(typeof(TicketStatusJsonConverter))]
public sealed class TicketStatus : IEquatable<TicketStatus>
{
    public static readonly TicketStatus Open = new("Open");
    public static readonly TicketStatus InProgress = new("InProgress");
    public static readonly TicketStatus Resolved = new("Resolved");
    public static readonly TicketStatus Escalated = new("Escalated");

    public static IReadOnlyList<TicketStatus> All { get; } = [Open, InProgress, Resolved, Escalated];

    public string Value { get; }

    private TicketStatus(string value) => Value = value;

    public static TicketStatus Parse(string value) => value switch
    {
        "Open" => Open,
        "InProgress" => InProgress,
        "Resolved" => Resolved,
        "Escalated" => Escalated,
        _ => throw new ArgumentException(
            $"Invalid TicketStatus: '{value}'. Valid: {string.Join(", ", All.Select(s => s.Value))}",
            nameof(value))
    };

    public static bool TryParse(string? value, out TicketStatus? status)
    {
        if (value is null)
        {
            status = null;
            return false;
        }
        try
        {
            status = Parse(value);
            return true;
        }
        catch (ArgumentException)
        {
            status = null;
            return false;
        }
    }

    public override string ToString() => Value;

    public bool Equals(TicketStatus? other) => other is not null && Value == other.Value;
    public override bool Equals(object? obj) => obj is TicketStatus other && Equals(other);
    public override int GetHashCode() => Value.GetHashCode(StringComparison.Ordinal);
    public static bool operator ==(TicketStatus? left, TicketStatus? right) => Equals(left, right);
    public static bool operator !=(TicketStatus? left, TicketStatus? right) => !Equals(left, right);
}

public sealed class TicketStatusJsonConverter : JsonConverter<TicketStatus>
{
    public override TicketStatus? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var value = reader.GetString();
        return value is null ? null : TicketStatus.Parse(value);
    }

    public override void Write(Utf8JsonWriter writer, TicketStatus value, JsonSerializerOptions options)
        => writer.WriteStringValue(value.Value);
}
