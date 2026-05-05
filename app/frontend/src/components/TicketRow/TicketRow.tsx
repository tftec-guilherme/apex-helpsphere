/**
 * TicketRow — linha individual da lista de tickets ("Apex Executivo" v2.1.0).
 *
 * Layout em grid (7 colunas): priority dot · #id · subject · tags · status · time.
 * Hover sutil com elevação (shadow-1) e troca de superfície para indicar afordância.
 * A linha inteira é um Link (`react-router-dom`) — clicar OU teclar Enter abre o detail.
 */
import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import type { Ticket } from "../../api/ticketsModels";
import { StatusPill } from "../StatusPill/StatusPill";
import styles from "./TicketRow.module.css";

interface Props {
    ticket: Ticket;
    locale?: string;
}

/**
 * Formato relativo curto (ex.: "agora", "2h", "3d"). Mantido client-side para evitar
 * dependência adicional (date-fns, dayjs). Em datas > 30 dias delega ao Intl para
 * data absoluta — mais informativo que "92d".
 */
function formatRelative(iso: string, locale: string): string {
    try {
        const diffMs = Date.now() - new Date(iso).getTime();
        const minutes = Math.floor(diffMs / 60000);
        if (minutes < 1) return "agora";
        if (minutes < 60) return `${minutes}m`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return `${hours}h`;
        const days = Math.floor(hours / 24);
        if (days < 30) return `${days}d`;
        return new Date(iso).toLocaleDateString(locale, { day: "2-digit", month: "short" });
    } catch {
        return iso;
    }
}

const priorityClass = (p: string) => `priority${p.charAt(0).toUpperCase() + p.slice(1).toLowerCase()}`;

export const TicketRow = ({ ticket, locale = "pt-BR" }: Props) => {
    const { t } = useTranslation();
    const categoryLabel = t(`helpsphere.tickets.category.${ticket.category}`, { defaultValue: ticket.category });
    const priorityLabel = t(`helpsphere.tickets.priority.${ticket.priority}`, { defaultValue: ticket.priority });

    return (
        <Link to={`/tickets/${ticket.ticket_id}`} className={styles.row} aria-label={`Ticket #${ticket.ticket_id}: ${ticket.subject}`}>
            <span
                className={`${styles.priorityDot} ${styles[priorityClass(ticket.priority)]}`}
                aria-label={`Prioridade ${priorityLabel}`}
                title={priorityLabel}
            />
            <span className={styles.id}>#{ticket.ticket_id}</span>
            <span className={styles.subject}>{ticket.subject}</span>
            <span className={styles.tags}>
                <span className={styles.category}>{categoryLabel}</span>
            </span>
            <StatusPill status={ticket.status} />
            <span className={styles.time} title={new Date(ticket.updated_at).toLocaleString(locale)}>
                {formatRelative(ticket.updated_at, locale)}
            </span>
        </Link>
    );
};

export default TicketRow;
