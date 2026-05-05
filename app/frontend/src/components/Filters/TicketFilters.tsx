/**
 * TicketFilters — barra de filtros sticky para a lista de tickets.
 *
 * Pills toggle para Status (clique repetido limpa) + dropdowns nativos para
 * Prioridade e Categoria + search input livre. Componente "controlled" — o
 * estado vive em `Tickets.tsx` (espelha URL via `useSearchParams` para
 * deep-linking).
 */
import { useTranslation } from "react-i18next";
import { TICKET_STATUSES, TICKET_PRIORITIES, type TicketStatus, type TicketPriority, type TicketCategory } from "../../api/ticketsModels";
import styles from "./TicketFilters.module.css";

export interface TicketFiltersValue {
    status?: TicketStatus;
    priority?: TicketPriority;
    category?: TicketCategory;
    search?: string;
}

interface Props extends TicketFiltersValue {
    categoryOptions: readonly TicketCategory[] | string[];
    onChange: (next: TicketFiltersValue) => void;
}

export const TicketFilters = ({ status, priority, category, search, onChange, categoryOptions }: Props) => {
    const { t } = useTranslation();

    const update = (patch: Partial<TicketFiltersValue>) => {
        onChange({ status, priority, category, search, ...patch });
    };

    return (
        <div className={styles.filters} role="region" aria-label={t("helpsphere.tickets.filters.status", { defaultValue: "Filtros" })}>
            <div className={styles.statusGroup} role="group" aria-label={t("helpsphere.tickets.filters.status")}>
                {TICKET_STATUSES.map(s => {
                    const active = status === s;
                    return (
                        <button
                            type="button"
                            key={s}
                            aria-pressed={active}
                            className={`${styles.pill} ${active ? styles.pillActive : ""}`}
                            onClick={() => update({ status: active ? undefined : s })}
                        >
                            {t(`helpsphere.tickets.status.${s}`, { defaultValue: s })}
                        </button>
                    );
                })}
            </div>

            <div className={styles.controls}>
                <select
                    className={styles.select}
                    value={priority ?? ""}
                    onChange={e => update({ priority: (e.target.value as TicketPriority) || undefined })}
                    aria-label={t("helpsphere.tickets.filters.priority")}
                >
                    <option value="">{t("helpsphere.tickets.filters.priority")}</option>
                    {TICKET_PRIORITIES.map(p => (
                        <option key={p} value={p}>
                            {t(`helpsphere.tickets.priority.${p}`, { defaultValue: p })}
                        </option>
                    ))}
                </select>

                <select
                    className={styles.select}
                    value={category ?? ""}
                    onChange={e => update({ category: (e.target.value as TicketCategory) || undefined })}
                    aria-label={t("helpsphere.tickets.filters.category")}
                >
                    <option value="">{t("helpsphere.tickets.filters.category")}</option>
                    {categoryOptions.map(c => (
                        <option key={c} value={c}>
                            {t(`helpsphere.tickets.category.${c}`, { defaultValue: c })}
                        </option>
                    ))}
                </select>

                <input
                    type="search"
                    placeholder={t("helpsphere.tickets.search")}
                    value={search ?? ""}
                    onChange={e => update({ search: e.target.value || undefined })}
                    className={styles.search}
                    aria-label={t("helpsphere.tickets.search")}
                />
            </div>
        </div>
    );
};

export default TicketFilters;
