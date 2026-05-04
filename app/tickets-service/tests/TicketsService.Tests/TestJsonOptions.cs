// Story 06.5c.2 — JsonSerializerOptions compartilhadas para tests
// Espelha config global do Program.cs (snake_case naming policy + smart enum converters).

using System.Text.Json;
using TicketsService.Domain.Tickets.Enums;

namespace TicketsService.Tests;

internal static class TestJsonOptions
{
    public static JsonSerializerOptions SnakeCase { get; } = Build();

    private static JsonSerializerOptions Build()
    {
        var options = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
            DictionaryKeyPolicy = JsonNamingPolicy.SnakeCaseLower
        };
        options.Converters.Add(new TicketStatusJsonConverter());
        options.Converters.Add(new TicketCategoryJsonConverter());
        options.Converters.Add(new TicketPriorityJsonConverter());
        return options;
    }
}
