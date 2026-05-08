/**
 * Cliente REST para o endpoint `/chat/rag` do backend Python.
 *
 * Story 06.10 — Lab Intermediário (Parte 8). Endpoint disponivel apenas quando
 * `RAG_ENABLED=true` no Container App backend; caso contrario retorna 503 +
 * payload didatico apontando para o guia.
 */
import { getHeaders } from "./api";

const BACKEND_URI = "";

export interface RagCitation {
    source: string;
    page?: number;
    [key: string]: unknown;
}

export interface RagSuggestResponse {
    suggested_response: string;
    confidence?: number;
    citations?: RagCitation[];
    [key: string]: unknown;
}

export interface RagSuggestErrorResponse {
    detail?: string;
    error?: string;
    implementation_status?: string;
    upstream_status?: number;
    upstream_body?: string;
}

export interface RagSuggestRequest {
    ticketId: number;
    description: string;
    attachmentUrls?: string[];
}

/**
 * POST /chat/rag — proxy para a Function App externa de RAG.
 *
 * Lanca Error com mensagem amigavel quando:
 * - 503 (RAG_ENABLED=false): mensagem do payload "detail" com hint para o guia
 * - 502 (upstream Function App falhou): mensagem com upstream_status + body
 * - outros erros HTTP: statusText
 */
export async function ragSuggestApi(
    req: RagSuggestRequest,
    idToken: string | undefined,
    signal?: AbortSignal
): Promise<RagSuggestResponse> {
    const headers = await getHeaders(idToken);
    const response = await fetch(`${BACKEND_URI}/chat/rag`, {
        method: "POST",
        headers: { ...headers, "Content-Type": "application/json" },
        body: JSON.stringify({
            ticket_id: req.ticketId,
            description: req.description,
            attachment_urls: req.attachmentUrls ?? []
        }),
        signal
    });

    if (!response.ok) {
        let errorMessage = `RAG request failed: ${response.status} ${response.statusText}`;
        try {
            const body = (await response.json()) as RagSuggestErrorResponse;
            if (body.detail) {
                errorMessage = body.detail;
            } else if (body.error && body.upstream_status) {
                errorMessage = `Upstream RAG Function retornou ${body.upstream_status}: ${body.upstream_body ?? body.error}`;
            } else if (body.error) {
                errorMessage = body.error;
            }
        } catch {
            // body nao-JSON, mantem mensagem default
        }
        throw new Error(errorMessage);
    }

    return (await response.json()) as RagSuggestResponse;
}

