/**
 * Tipos do domínio HelpSphere espelhando o contract dos endpoints
 * `app/backend/blueprints/tickets.py`. snake_case preservado para
 * casar 1:1 com o JSON do backend (sem mapeamento extra no client).
 */

export const TICKET_STATUSES = ["Open", "InProgress", "Resolved", "Escalated"] as const;
export type TicketStatus = (typeof TICKET_STATUSES)[number];

export const TICKET_PRIORITIES = ["Low", "Medium", "High", "Critical"] as const;
export type TicketPriority = (typeof TICKET_PRIORITIES)[number];

export const TICKET_CATEGORIES = ["Comercial", "TI", "Operacional", "RH", "Financeiro"] as const;
export type TicketCategory = (typeof TICKET_CATEGORIES)[number];

export interface Ticket {
    ticket_id: number;
    tenant_id: string;
    subject: string;
    description: string;
    category: TicketCategory;
    language: string;
    status: TicketStatus;
    priority: TicketPriority;
    confidence_score: number | null;
    /** JSON array string de paths blob — caller faz parse com try/catch */
    attachment_blob_paths: string | null;
    created_at: string;
    updated_at: string;
}

export interface TicketComment {
    comment_id: number;
    ticket_id?: number;
    author: string;
    content: string;
    created_at: string;
}

export interface TicketDetail extends Ticket {
    comments: TicketComment[];
}

export interface TicketsPagination {
    limit: number;
    offset: number;
    total: number;
}

export interface TicketsListResponse {
    items: Ticket[];
    pagination: TicketsPagination;
}

export interface Tenant {
    tenant_id: string;
    brand_name: string;
    created_at: string;
}

export interface TicketsListFilters {
    status?: TicketStatus;
    category?: TicketCategory;
    limit?: number;
    offset?: number;
}

export interface TicketPatchBody {
    status?: TicketStatus;
    priority?: TicketPriority;
}

export interface SuggestStubResponse {
    detail: string;
    ticket_id: number;
    implementation_status: string;
    see_also: string;
}

export interface ApiErrorBody {
    error?: string;
    detail?: string;
    description?: string;
    details?: unknown;
}
