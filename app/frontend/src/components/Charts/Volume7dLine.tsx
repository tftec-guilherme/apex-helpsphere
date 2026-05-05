import { Line, Area, AreaChart, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from "recharts";

interface Props {
    data: Array<{ date: string; count: number }>;
}

const formatDate = (iso: string): string => {
    // Espera ISO date (YYYY-MM-DD); fallback gracioso para qualquer string.
    try {
        const d = new Date(iso);
        if (Number.isNaN(d.getTime())) return iso;
        return d.toLocaleDateString(undefined, { month: "short", day: "2-digit" });
    } catch {
        return iso;
    }
};

export const Volume7dLine = ({ data }: Props) => (
    <ResponsiveContainer width="100%" height={280}>
        <AreaChart data={data} margin={{ top: 10, right: 10, bottom: 30, left: 0 }}>
            <defs>
                <linearGradient id="volumeFill" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="var(--color-accent)" stopOpacity={0.25} />
                    <stop offset="100%" stopColor="var(--color-accent)" stopOpacity={0} />
                </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="var(--color-border)" vertical={false} />
            <XAxis
                dataKey="date"
                tickFormatter={formatDate}
                tick={{ fill: "var(--color-text-muted)", fontSize: 12, fontFamily: "var(--font-body)" }}
                tickLine={false}
                axisLine={{ stroke: "var(--color-border)" }}
            />
            <YAxis
                tick={{ fill: "var(--color-text-muted)", fontSize: 12, fontFamily: "var(--font-body)" }}
                tickLine={false}
                axisLine={false}
                allowDecimals={false}
            />
            <Tooltip
                cursor={{ stroke: "var(--color-accent)", strokeWidth: 1, strokeDasharray: "4 4" }}
                contentStyle={{
                    background: "var(--color-surface)",
                    border: "1px solid var(--color-border)",
                    borderRadius: "var(--radius-sm)",
                    fontFamily: "var(--font-body)",
                    fontSize: "var(--fs-sm)",
                    boxShadow: "var(--shadow-2)"
                }}
                labelFormatter={formatDate}
                labelStyle={{ color: "var(--color-text)", fontWeight: 600 }}
                itemStyle={{ color: "var(--color-text-muted)" }}
            />
            <Area type="monotone" dataKey="count" stroke="none" fill="url(#volumeFill)" />
            <Line
                type="monotone"
                dataKey="count"
                stroke="var(--color-accent)"
                strokeWidth={2}
                dot={false}
                activeDot={{ r: 5, fill: "var(--color-accent)", stroke: "var(--color-surface)", strokeWidth: 2 }}
            />
        </AreaChart>
    </ResponsiveContainer>
);
