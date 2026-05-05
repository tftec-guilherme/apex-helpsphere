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

    return (
        <div className={styles.page}>
            <header className={styles.header}>
                <h2>Dashboard operacional</h2>
                <p className={styles.subtitle}>Visão consolidada da fila de tickets do tenant</p>
            </header>

            <section className={styles.kpis} aria-label="Indicadores principais">
                <KpiCard label="Tickets abertos" value={stats.totalOpen} />
                <KpiCard
                    label="SLA breach"
                    value={`${stats.slaBreachPct.toFixed(1)}%`}
                    accent={stats.slaBreachPct > 10 ? "danger" : "default"}
                />
                <KpiCard
                    label="Críticos"
                    value={stats.criticalOpen}
                    accent={stats.criticalOpen > 0 ? "warn" : "default"}
                />
                <KpiCard label="Últimas 24h" value={stats.last24h} />
            </section>

            <section className={styles.charts} aria-label="Distribuição e tendência">
                <article className={styles.chartCard}>
                    <h3>Volume por categoria</h3>
                    <CategoryBars data={stats.byCategory} />
                </article>
                <article className={styles.chartCard}>
                    <h3>Volume últimos 7 dias</h3>
                    <Volume7dLine data={stats.dailyVolume7d} />
                </article>
            </section>
        </div>
    );
};

// Lazy route compatibility (react-router v6/v7 lazy)
export const Component = Dashboard;
export default Dashboard;
