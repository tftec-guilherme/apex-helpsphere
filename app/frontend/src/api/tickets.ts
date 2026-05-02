/**
 * Cliente REST dos endpoints HelpSphere `/api/tickets/*`.
 *
 * Padrão production-grade espelhando o backend (`blueprints/tickets.py`):
 * - Bearer token (MSAL) via `getHeaders` para todas as chamadas
 * - Erros HTTP 4xx/5xx propagam mensagem do backend quando disponível
 * - 501 do `/suggest` é tratado como sucesso para UX (resposta didática)
 */
import { getHeaders } from "./api";
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

const BACKEND_URI = "";
const TICKETS_BASE = `${BACKEND_URI}/api/tickets`;

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

export async function addCommentApi(ticketId: number, content: string, idToken: string | undefined): Promise<TicketComment> {
    const headers = await getHeaders(idToken);
    const response = await fetch(`${TICKETS_BASE}/${ticketId}/comments`, {
        method: "POST",
        headers: { ...headers, "Content-Type": "application/json" },
        body: JSON.stringify({ content })
    });
    if (!response.ok) {
        throw new Error(await readErrorMessage(response, `Adding comment failed: ${response.statusText}`));
    }
    return (await response.json()) as TicketComment;
}

export async function patchTicketApi(ticketId: number, body: TicketPatchBody, idToken: string | undefined): Promise<Ticket> {
    const headers = await getHeaders(idToken);
    const response = await fetch(`${TICKETS_BASE}/${ticketId}`, {
        method: "PATCH",
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
 */
export async function suggestTicketApi(ticketId: number, idToken: string | undefined): Promise<SuggestStubResponse> {
    const headers = await getHeaders(idToken);
    const response = await fetch(`${TICKETS_BASE}/${ticketId}/suggest`, {
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
