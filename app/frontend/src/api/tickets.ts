/**
 * Cliente REST dos endpoints HelpSphere `/api/tickets/*`.
 *
 * Padrão production-grade espelhando o backend (`blueprints/tickets.py`):
 * - Bearer token (MSAL) via `getHeaders` para todas as chamadas
 * - Erros HTTP 4xx/5xx propagam mensagem do backend quando disponível
 * - 501 do `/suggest` é tratado como sucesso para UX (resposta didática)
 */
import { getHeaders } from "./api";
import { ticketsApiBase } from "../authConfig";
import type {
    Ticket,
    TicketComment,
    TicketDetail,
    TicketPatchBody,
    Tenant,
    TicketsListFilters,
    TicketsListResponse,
    SuggestStubResponse,
    ApiErrorBody
} from "./ticketsModels";

// Story 06.5c.6 (Decisão #16) + Decisão #19 (runtime config):
// `TICKETS_API_BASE` vem do `/auth_setup` (campo `ticketsApiBase`, populado pelo backend
// a partir da env `TICKETS_BACKEND_URI`) — não está mais embarcado no bundle Vite, então o
// mesmo build serve qualquer environment (dev/staging/prod). `BACKEND_URI` (relative)
// continua apontando pro backend Python que serve `/api/tenants/me` (config) e
// `/api/tickets/{id}/suggest` (stub 501 para Lab Intermediário sobrescrever com RAG).
const TICKETS_API_BASE = ticketsApiBase;
const BACKEND_URI = "";
const TICKETS_BASE = `${TICKETS_API_BASE}/api/tickets`;

function buildQuery(filters: TicketsListFilters): string {
    const params = new URLSearchParams();
    if (filters.status) params.set("status", filters.status);
    if (filters.category) params.set("category", filters.category);
    if (typeof filters.limit === "number") params.set("limit", String(filters.limit));
    if (typeof filters.offset === "number") params.set("offset", String(filters.offset));
    const qs = params.toString();
    return qs ? `?${qs}` : "";
}

async function readErrorMessage(response: Response, fallback: string): Promise<string> {
    try {
        const body = (await response.json()) as ApiErrorBody;
        return body.error ?? body.detail ?? body.description ?? fallback;
    } catch {
        return fallback;
    }
}

export async function listTicketsApi(filters: TicketsListFilters, idToken: string | undefined): Promise<TicketsListResponse> {
    const headers = await getHeaders(idToken);
    const response = await fetch(`${TICKETS_BASE}${buildQuery(filters)}`, {
        method: "GET",
        headers
    });
    if (!response.ok) {
        throw new Error(await readErrorMessage(response, `Listing tickets failed: ${response.statusText}`));
    }
    return (await response.json()) as TicketsListResponse;
}

export async function getTicketApi(ticketId: number, idToken: string | undefined): Promise<TicketDetail> {
    const headers = await getHeaders(idToken);
    const response = await fetch(`${TICKETS_BASE}/${ticketId}`, {
        method: "GET",
        headers
    });
    if (!response.ok) {
        throw new Error(await readErrorMessage(response, `Loading ticket ${ticketId} failed: ${response.statusText}`));
    }
    return (await response.json()) as TicketDetail;
}

/**
 * Story 06.5c.6 — `POST /api/tickets/{id}/comments` ainda NÃO está implementado no
 * tickets-service .NET (futuro: Story 06.5c.10 ou Lab Intermediário). UI exibe o
 * input desabilitado com tooltip explicativo. Esta função existe para preservar o
 * contract da API mas retorna erro explícito até o endpoint ser implementado.
 */
export async function addCommentApi(_ticketId: number, _content: string, _idToken: string | undefined): Promise<TicketComment> {
    throw new Error(
        "Adicionar comentário ainda não está disponível: o endpoint POST /api/tickets/{id}/comments " +
            "será implementado no Lab Intermediário (junto com sugestão de resposta via RAG). " +
            "Por enquanto, a thread exibe os comentários do seed."
    );
}

export async function patchTicketApi(ticketId: number, body: TicketPatchBody, idToken: string | undefined): Promise<Ticket> {
    // .NET tickets-service expõe `PUT /api/tickets/{id}` (semântica de full update).
    // Mantemos o nome `patchTicketApi` por compat com call sites — método HTTP mudou para PUT.
    const headers = await getHeaders(idToken);
    const response = await fetch(`${TICKETS_BASE}/${ticketId}`, {
        method: "PUT",
        headers: { ...headers, "Content-Type": "application/json" },
        body: JSON.stringify(body)
    });
    if (!response.ok) {
        throw new Error(await readErrorMessage(response, `Updating ticket failed: ${response.statusText}`));
    }
    return (await response.json()) as Ticket;
}

/**
 * Stub explícito (HTTP 501) — resposta payload didática usada pela UI para
 * informar que a sugestão de IA será implementada no Lab Intermediário.
 *
 * Story 06.5c.6: `/suggest` PERMANECE no backend Python (rota `BACKEND_URI` relative)
 * porque é stub que será sobrescrito pelo Lab Intermediário com RAG/OpenAI — não migrou
 * para tickets-service .NET (que mantém apenas CRUD canônico).
 */
export async function suggestTicketApi(ticketId: number, idToken: string | undefined): Promise<SuggestStubResponse> {
    const headers = await getHeaders(idToken);
    const response = await fetch(`${BACKEND_URI}/api/tickets/${ticketId}/suggest`, {
        method: "POST",
        headers: { ...headers, "Content-Type": "application/json" }
    });
    // 501 é o contract esperado do stub — tratamos como sucesso "informativo"
    if (response.status !== 501 && !response.ok) {
        throw new Error(await readErrorMessage(response, `Suggest failed: ${response.statusText}`));
    }
    return (await response.json()) as SuggestStubResponse;
}

export async function getMyTenantApi(idToken: string | undefined): Promise<Tenant> {
    const headers = await getHeaders(idToken);
    const response = await fetch(`${BACKEND_URI}/api/tenants/me`, {
        method: "GET",
        headers
    });
    if (!response.ok) {
        throw new Error(await readErrorMessage(response, `Loading tenant failed: ${response.statusText}`));
    }
    return (await response.json()) as Tenant;
}
