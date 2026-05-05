/**
 * StatusPill — pill colorido com dot indicador para status de ticket.
 *
 * Wave 3.I (HelpSphere v2.1.0): versão completa que sobrescreve o stub do Wave 3.H.
 * Mapeia os 4 status do domínio HelpSphere (`Open`, `InProgress`, `Resolved`,
 * `Escalated`) para classes CSS usando design tokens (`var(--status-*)`,
 * `var(--color-*)`). Mantém suporte aos status genéricos (`Blocked`, `Closed`)
 * caso o backend evolua o vocabulário.
 *
 * Tamanhos: sm (default, listas), md (cards), lg (header de detalhe).
 */
import styles from "./StatusPill.module.css";

interface Props {
    status: string;
    size?: "sm" | "md" | "lg";
    className?: string;
}

const STATUS_LABELS: Record<string, string> = {
    Open: "Aberto",
    InProgress: "Em andamento",
    Resolved: "Resolvido",
    Escalated: "Escalonado",
    Blocked: "Bloqueado",
    Closed: "Fechado"
};

export const StatusPill = ({ status, size = "sm", className }: Props) => {
    const safeStatus = status || "Unknown";
    const key = safeStatus.toLowerCase();
    const label = STATUS_LABELS[safeStatus] || safeStatus;
    const variantClass = styles[`pill-${key}`] || styles["pill-default"];
    const sizeClass = styles[`size-${size}`];
    const cls = [styles.pill, variantClass, sizeClass, className].filter(Boolean).join(" ");
    return (
        <span className={cls} aria-label={`Status: ${label}`}>
            <span className={styles.dot} aria-hidden="true" />
            {label}
        </span>
    );
};

export default StatusPill;
