// Story 06.5c.2 T1.5 — TicketPriority smart enum
// Schema: VARCHAR(10) CHECK (priority IN ('Low','Medium','High','Critical'))

using System.Text.Json;
using System.Text.Json.Serialization;

namespace TicketsService.Domain.Tickets.Enums;

[JsonConverter(typeof(TicketPriorityJsonConverter))]
public sealed class TicketPriority : IEquatable<TicketPriority>
{
    public static readonly TicketPriority Low = new("Low");
    public static readonly TicketPriority Medium = new("Medium");
    public static readonly TicketPriority High = new("High");
    public static readonly TicketPriority Critical = new("Critical");

    public static IReadOnlyList<TicketPriority> All { get; } = [Low, Medium, High, Critical];

    public string Value { get; }

    private TicketPriority(string value) => Value = value;

    public static TicketPriority Parse(string value) => value switch
    {
        "Low" => Low,
        "Medium" => Medium,
        "High" => High,
        "Critical" => Critical,
        _ => throw new ArgumentException(
            $"Invalid TicketPriority: '{value}'. Valid: {string.Join(", ", All.Select(p => p.Value))}",
            nameof(value))
    };

    public static bool TryParse(string? value, out TicketPriority? priority)
    {
        if (value is null)
        {
            priority = null;
            return false;
        }
        try
        {
            priority = Parse(value);
            return true;
        }
        catch (ArgumentException)
        {
            priority = null;
            return false;
        }
    }

    public override string ToString() => Value;

    public bool Equals(TicketPriority? other) => other is not null && Value == other.Value;
    public override bool Equals(object? obj) => obj is TicketPriority other && Equals(other);
    public override int GetHashCode() => Value.GetHashCode(StringComparison.Ordinal);
    public static bool operator ==(TicketPriority? left, TicketPriority? right) => Equals(left, right);
    public static bool operator !=(TicketPriority? left, TicketPriority? right) => !Equals(left, right);
}

public sealed class TicketPriorityJsonConverter : JsonConverter<TicketPriority>
{
    public override TicketPriority? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var value = reader.GetString();
        return value is null ? null : TicketPriority.Parse(value);
    }

    public override void Write(Utf8JsonWriter writer, TicketPriority value, JsonSerializerOptions options)
        => writer.WriteStringValue(value.Value);
}
