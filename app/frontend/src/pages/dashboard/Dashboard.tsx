import { useEffect, useState } from "react";
import { useMsal } from "@azure/msal-react";

import { getStatsApi, TicketStats } from "../../api/stats";
import { getToken } from "../../authConfig";
import { KpiCard } from "../../components/KpiCard/KpiCard";
import { CategoryBars } from "../../components/Charts/CategoryBars";
import { Volume7dLine } from "../../components/Charts/Volume7dLine";
import styles from "./Dashboard.module.css";

const Dashboard = () => {
    const { instance } = useMsal();
    const [stats, setStats] = useState<TicketStats | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        let cancelled = false;
        const load = async () => {
            try {
                const token = await getToken(instance);
                const data = await getStatsApi(token);
                if (!cancelled) {
                    setStats(data);
                }
            } catch (e) {
                if (!cancelled) {
                    setError(e instanceof Error ? e.message : String(e));
                }
            } finally {
                if (!cancelled) {
                    setLoading(false);
                }
            }
        };
        load();
        return () => {
            cancelled = true;
        };
    }, [instance]);

    if (loading) return <div className={styles.loading}>Carregando dashboard…</div>;
    if (error) return <div className={styles.error}>Erro: {error}</div>;
    if (!stats) return <div className={styles.empty}>Sem dados.</div>;

    // Defensive defaults — backend pode retornar null em valores quando o tenant
    // nao tem nenhum ticket ainda (NULLIF protege div/0 mas retorna null no JSON).
    const slaBreachPct = stats.sla_breach_pct ?? 0;
    const totalOpen = stats.total_open ?? 0;
    const criticalOpen = stats.critical_open ?? 0;
    const last24h = stats.last24h ?? 0;
    const byCategory = stats.by_category ?? [];
    const dailyVolume = stats.daily_volume7d ?? [];

    return (
        <div className={styles.page}>
            <section className={styles.kpis} aria-label="Indicadores principais">
                <KpiCard label="Tickets abertos" value={totalOpen} />
                <KpiCard label="SLA breach" value={`${slaBreachPct.toFixed(1)}%`} accent={slaBreachPct > 10 ? "danger" : "default"} />
                <KpiCard label="Críticos" value={criticalOpen} accent={criticalOpen > 0 ? "warn" : "default"} />
                <KpiCard label="Últimas 24h" value={last24h} />
            </section>

            <section className={styles.charts} aria-label="Distribuição e tendência">
                <article className={styles.chartCard}>
                    <header className={styles.chartCardHeader}>
                        <h3>Volume por categoria</h3>
                        <span className={styles.chartCardKicker}>Total acumulado</span>
                    </header>
                    <CategoryBars data={byCategory} />
                </article>
                <article className={styles.chartCard}>
                    <header className={styles.chartCardHeader}>
                        <h3>Volume últimos 7 dias</h3>
                        <span className={styles.chartCardKicker}>Tendência</span>
                    </header>
                    <Volume7dLine data={dailyVolume} />
                </article>
            </section>
        </div>
    );
};

// Lazy route compatibility (react-router v6/v7 lazy)
export const Component = Dashboard;
export default Dashboard;
