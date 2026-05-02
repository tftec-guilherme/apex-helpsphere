import { useTranslation } from "react-i18next";
import styles from "./StatusBadge.module.css";
import type { TicketStatus } from "../../api/ticketsModels";

interface StatusBadgeProps {
    status: TicketStatus;
    className?: string;
}

const STATUS_CLASS: Record<TicketStatus, string> = {
    Open: styles.open,
    InProgress: styles.inProgress,
    Resolved: styles.resolved,
    Escalated: styles.escalated
};

export const StatusBadge = ({ status, className }: StatusBadgeProps) => {
    const { t } = useTranslation();
    const label = t(`helpsphere.tickets.status.${status}`, { defaultValue: status });
    const dotClass = STATUS_CLASS[status] ?? styles.open;
    return (
        <span className={`${styles.badge} ${className ?? ""}`} aria-label={`Status: ${label}`}>
            <span className={`${styles.dot} ${dotClass}`} aria-hidden="true" />
            <span className={styles.label}>{label}</span>
        </span>
    );
};
