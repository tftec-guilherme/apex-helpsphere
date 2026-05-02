import { useTranslation } from "react-i18next";
import styles from "./PriorityBadge.module.css";
import type { TicketPriority } from "../../api/ticketsModels";

interface PriorityBadgeProps {
    priority: TicketPriority;
    className?: string;
}

const PRIORITY_CLASS: Record<TicketPriority, string> = {
    Low: styles.low,
    Medium: styles.medium,
    High: styles.high,
    Critical: styles.critical
};

export const PriorityBadge = ({ priority, className }: PriorityBadgeProps) => {
    const { t } = useTranslation();
    const label = t(`helpsphere.tickets.priority.${priority}`, { defaultValue: priority });
    const variantClass = PRIORITY_CLASS[priority] ?? styles.medium;
    return (
        <span className={`${styles.badge} ${variantClass} ${className ?? ""}`} aria-label={`Priority: ${label}`}>
            {label}
        </span>
    );
};
