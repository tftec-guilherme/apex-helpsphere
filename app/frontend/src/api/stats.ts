/**
 * Cliente REST do endpoint `/api/tickets/stats` (Wave 3.E — backend agregador).
 *
 * Mantém o mesmo padrão production-grade de `tickets.ts`:
 * - Bearer token (MSAL) via `getHeaders`
 * - URL base via `ticketsApiBase` (runtime config — Decisão #19)
 * - Erros HTTP propagam status + statusText
 *
 * Consumido pela página Dashboard (`pages/dashboard/Dashboard.tsx`) para
 * renderizar KPIs, charts de categoria e volume de 7 dias.
 */
import { getHeaders } from "./api";
import { ticketsApiBase } from "../authConfig";

export interface TicketStats {
    totalOpen: number;
    slaBreachPct: number;
    criticalOpen: number;
    last24h: number;
    byStatus: Array<{ status: string; count: number }>;
    byCategory: Array<{ category: string; count: number }>;
    byPriority: Array<{ priority: string; count: number }>;
    dailyVolume7d: Array<{ date: string; count: number }>;
}

export async function getStatsApi(idToken: string | undefined): Promise<TicketStats> {
    const headers = await getHeaders(idToken);
    const response = await fetch(`${ticketsApiBase}/api/tickets/stats`, { headers });
    if (!response.ok) {
        throw new Error(`stats failed: ${response.status} ${response.statusText}`);
    }
    return (await response.json()) as TicketStats;
}
