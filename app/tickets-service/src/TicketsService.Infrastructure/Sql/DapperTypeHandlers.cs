// Story 06.5c.2 — Dapper TypeHandlers para smart enums
// Defesa: Dapper precisa saber serializar TicketStatus etc ↔ string em queries.
// Sem TypeHandler, Dapper materializa Ticket (com TicketStatus prop) e falha.
// Registrar 1x no Program.cs via SqlMapper.AddTypeHandler(...)

using System.Data;
using Dapper;
using TicketsService.Domain.Tickets.Enums;

namespace TicketsService.Infrastructure.Sql;

public sealed class TicketStatusTypeHandler : SqlMapper.TypeHandler<TicketStatus>
{
    public override TicketStatus Parse(object value) => TicketStatus.Parse((string)value);
    public override void SetValue(IDbDataParameter parameter, TicketStatus? value)
    {
        parameter.Value = value?.Value ?? (object)DBNull.Value;
        parameter.DbType = DbType.AnsiString;
    }
}

public sealed class TicketCategoryTypeHandler : SqlMapper.TypeHandler<TicketCategory>
{
    public override TicketCategory Parse(object value) => TicketCategory.Parse((string)value);
    public override void SetValue(IDbDataParameter parameter, TicketCategory? value)
    {
        parameter.Value = value?.Value ?? (object)DBNull.Value;
        parameter.DbType = DbType.AnsiString;
    }
}

public sealed class TicketPriorityTypeHandler : SqlMapper.TypeHandler<TicketPriority>
{
    public override TicketPriority Parse(object value) => TicketPriority.Parse((string)value);
    public override void SetValue(IDbDataParameter parameter, TicketPriority? value)
    {
        parameter.Value = value?.Value ?? (object)DBNull.Value;
        parameter.DbType = DbType.AnsiString;
    }
}

public static class DapperTypeHandlerRegistration
{
    /// <summary>
    /// Registra todos os TypeHandlers HelpSphere. Chamar 1x no Program.cs antes de qualquer query.
    /// Idempotente: Dapper sobrescreve handlers do mesmo tipo silenciosamente.
    /// </summary>
    public static void RegisterAll()
    {
        SqlMapper.AddTypeHandler(new TicketStatusTypeHandler());
        SqlMapper.AddTypeHandler(new TicketCategoryTypeHandler());
        SqlMapper.AddTypeHandler(new TicketPriorityTypeHandler());
    }
}
