/**
 * EmptyState — placeholder centralizado quando uma lista/painel não tem dados.
 *
 * Composição genérica: ícone (SVG inline opcional) · título · descrição · ação.
 * Usa apenas tokens do design system — sem dependência de Fluent UI ou ícones
 * externos, mantendo bundle leve.
 */
import type { ReactNode } from "react";
import styles from "./EmptyState.module.css";

interface Props {
    title: string;
    description?: string;
    icon?: ReactNode;
    action?: ReactNode;
}

export const EmptyState = ({ title, description, icon, action }: Props) => (
    <div className={styles.empty} role="status">
        {icon && <div className={styles.icon}>{icon}</div>}
        <h3 className={styles.title}>{title}</h3>
        {description && <p className={styles.description}>{description}</p>}
        {action && <div className={styles.action}>{action}</div>}
    </div>
);

/** Ícone genérico de caixa de entrada vazia (Lucide-style stroke 1.5). */
export const InboxIcon = () => (
    <svg
        width="56"
        height="56"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
    >
        <path d="M22 12h-6l-2 3h-4l-2-3H2" />
        <path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z" />
    </svg>
);

export default EmptyState;
