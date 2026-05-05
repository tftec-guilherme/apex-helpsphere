import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from "recharts";

interface Props {
    data: Array<{ category: string; count: number }>;
}

export const CategoryBars = ({ data }: Props) => (
    <ResponsiveContainer width="100%" height={280}>
        <BarChart data={data} margin={{ top: 10, right: 10, bottom: 30, left: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="var(--color-border)" vertical={false} />
            <XAxis
                dataKey="category"
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
                cursor={{ fill: "var(--color-accent-soft)", opacity: 0.4 }}
                contentStyle={{
                    background: "var(--color-surface)",
                    border: "1px solid var(--color-border)",
                    borderRadius: "var(--radius-sm)",
                    fontFamily: "var(--font-body)",
                    fontSize: "var(--fs-sm)",
                    boxShadow: "var(--shadow-2)"
                }}
                labelStyle={{ color: "var(--color-text)", fontWeight: 600 }}
                itemStyle={{ color: "var(--color-text-muted)" }}
            />
            <Bar dataKey="count" fill="var(--color-accent)" radius={[4, 4, 0, 0]} />
        </BarChart>
    </ResponsiveContainer>
);
