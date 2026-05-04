// Story 06.5c.2 T1.4 — TicketCategory smart enum
// Schema: VARCHAR(50) CHECK (category IN ('Comercial','TI','Operacional','RH','Financeiro'))

using System.Text.Json;
using System.Text.Json.Serialization;

namespace TicketsService.Domain.Tickets.Enums;

[JsonConverter(typeof(TicketCategoryJsonConverter))]
public sealed class TicketCategory : IEquatable<TicketCategory>
{
    public static readonly TicketCategory Comercial = new("Comercial");
    public static readonly TicketCategory TI = new("TI");
    public static readonly TicketCategory Operacional = new("Operacional");
    public static readonly TicketCategory RH = new("RH");
    public static readonly TicketCategory Financeiro = new("Financeiro");

    public static IReadOnlyList<TicketCategory> All { get; } = [Comercial, TI, Operacional, RH, Financeiro];

    public string Value { get; }

    private TicketCategory(string value) => Value = value;

    public static TicketCategory Parse(string value) => value switch
    {
        "Comercial" => Comercial,
        "TI" => TI,
        "Operacional" => Operacional,
        "RH" => RH,
        "Financeiro" => Financeiro,
        _ => throw new ArgumentException(
            $"Invalid TicketCategory: '{value}'. Valid: {string.Join(", ", All.Select(c => c.Value))}",
            nameof(value))
    };

    public static bool TryParse(string? value, out TicketCategory? category)
    {
        if (value is null)
        {
            category = null;
            return false;
        }
        try
        {
            category = Parse(value);
            return true;
        }
        catch (ArgumentException)
        {
            category = null;
            return false;
        }
    }

    public override string ToString() => Value;

    public bool Equals(TicketCategory? other) => other is not null && Value == other.Value;
    public override bool Equals(object? obj) => obj is TicketCategory other && Equals(other);
    public override int GetHashCode() => Value.GetHashCode(StringComparison.Ordinal);
    public static bool operator ==(TicketCategory? left, TicketCategory? right) => Equals(left, right);
    public static bool operator !=(TicketCategory? left, TicketCategory? right) => !Equals(left, right);
}

public sealed class TicketCategoryJsonConverter : JsonConverter<TicketCategory>
{
    public override TicketCategory? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var value = reader.GetString();
        return value is null ? null : TicketCategory.Parse(value);
    }

    public override void Write(Utf8JsonWriter writer, TicketCategory value, JsonSerializerOptions options)
        => writer.WriteStringValue(value.Value);
}
