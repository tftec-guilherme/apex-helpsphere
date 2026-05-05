/**
 * SlaCountdown — exibe SLA restante (ou estourado) com barra de progresso live.
 *
 * Wave 3.I (HelpSphere v2.1.0). Atualiza a cada 60s enquanto o ticket NÃO
 * estiver fechado (`Resolved` no domínio HelpSphere). Usa design tokens
 * (`var(--color-accent)`, `var(--color-danger)`) para diferenciar normal vs
 * SLA estourado. Tabela `SLA_HOURS` usa o vocabulário de prioridade real do
 * HelpSphere (`Critical | High | Medium | Low`) — fallback 168h (Low) para
 * valores desconhecidos.
 *
 * NB: status "fechado" = `Resolved`. `Escalated` continua contando porque
 * representa SLA potencialmente em risco.
 */
import { useEffect, useMemo, useState } from "react";
import styles from "./SlaCountdown.module.css";

const SLA_HOURS: Record<string, number> = { Critical: 4, High: 24, Medium: 72, Low: 168 };
const TERMINAL_STATUSES = new Set(["Resolved", "Closed"]);

interface Props {
    createdAt: string;
    priority: string;
    status: string;
    className?: string;
}

const formatHours = (h: number): string => {
    if (h >= 24) {
        const days = Math.floor(h / 24);
        const rem = Math.round(h - days * 24);
        return rem === 0 ? `${days}d` : `${days}d ${rem}h`;
    }
    return `${h.toFixed(1)}h`;
};

export const SlaCountdown = ({ createdAt, priority, status, className }: Props) => {
    const [now, setNow] = useState(() => Date.now());
    const isTerminal = TERMINAL_STATUSES.has(status);

    useEffect(() => {
        if (isTerminal) return;
        const t = setInterval(() => setNow(Date.now()), 60000);
        return () => clearInterval(t);
    }, [isTerminal]);

    const { remaining, breached, pct } = useMemo(() => {
        const slaHours = SLA_HOURS[priority] ?? 168;
        const createdMs = new Date(createdAt).getTime();
        const elapsedHours = Number.isFinite(createdMs) ? (now - createdMs) / 3600000 : 0;
        const remainingHours = slaHours - elapsedHours;
        const breachedFlag = remainingHours < 0;
        const pctVal = Math.max(0, Math.min(100, (elapsedHours / slaHours) * 100));
        return { remaining: remainingHours, breached: breachedFlag, pct: pctVal };
    }, [createdAt, priority, now]);

    if (isTerminal) {
        return (
            <div className={[styles.countdown, styles.closed, className].filter(Boolean).join(" ")} role="status">
                <div className={styles.label}>SLA concluído</div>
                <div className={styles.bar}>
                    <div className={`${styles.fill} ${styles.fillClosed}`} style={{ width: "100%" }} />
                </div>
            </div>
        );
    }

    return (
        <div className={[styles.countdown, breached ? styles.breached : "", className].filter(Boolean).join(" ")} role="status" aria-live="polite">
            <div className={styles.label}>{breached ? `SLA estourou há ${formatHours(Math.abs(remaining))}` : `SLA em ${formatHours(remaining)}`}</div>
            <div className={styles.bar} aria-hidden="true">
                <div className={styles.fill} style={{ width: `${pct}%` }} />
            </div>
        </div>
    );
};

export default SlaCountdown;
