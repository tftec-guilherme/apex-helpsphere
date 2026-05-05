import styles from "./KpiCard.module.css";

interface Props {
    label: string;
    value: string | number;
    delta?: { value: number; positive?: boolean };
    accent?: "default" | "success" | "warn" | "danger";
}

export const KpiCard = ({ label, value, delta, accent = "default" }: Props) => (
    <div className={`${styles.card} ${styles[`accent-${accent}`]}`}>
        <span className={styles.label}>{label}</span>
        <span className={styles.value}>{value}</span>
        {delta && (
            <span className={`${styles.delta} ${delta.positive ? styles.up : styles.down}`}>
                {delta.positive ? "↑" : "↓"} {Math.abs(delta.value)}%
            </span>
        )}
    </div>
);
