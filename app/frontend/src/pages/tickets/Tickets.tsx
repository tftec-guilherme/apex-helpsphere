/**
 * Página `/tickets` — lista paginada de tickets do tenant logado.
 *
 * Production-pattern visível (audiência sênior — Disciplina 06):
 * - URL state via `useSearchParams` para deep-linking de filtros e paginação
 * - Loading skeleton em vez de spinner-on-empty (UX percebida)
 * - Error boundary local com retry
 * - Empty state com mensagem i18n
 * - Search client-side sobre o subject (filtros server-side já reduziram
 *   o dataset; busca textual fica no client para feedback imediato)
 * - Bearer token do MSAL respeitando o flow do template upstream
 */
import { useEffect, useMemo, useState, type JSX } from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import { useTranslation } from "react-i18next";
import { useMsal } from "@azure/msal-react";
import { Button, Dropdown, Input, MessageBar, MessageBarBody, MessageBarTitle, Option, Skeleton, SkeletonItem } from "@fluentui/react-components";
import { ArrowClockwise24Regular, DismissCircle24Regular, Search24Regular } from "@fluentui/react-icons";

import styles from "./Tickets.module.css";
import { listTicketsApi, type Ticket, type TicketsListResponse } from "../../api";
import { TICKET_CATEGORIES, TICKET_STATUSES, type TicketCategory, type TicketStatus } from "../../api/ticketsModels";
import { StatusBadge } from "../../components/StatusBadge";
import { PriorityBadge } from "../../components/PriorityBadge";
import { useLogin, getToken } from "../../authConfig";

const PAGE_SIZE = 20;

function formatDate(iso: string, locale: string): string {
    try {
        return new Date(iso).toLocaleDateString(locale, {
            day: "2-digit",
            month: "2-digit",
            year: "numeric"
        });
    } catch {
        return iso;
    }
}

export function Component(): JSX.Element {
    const { t, i18n } = useTranslation();
    const navigate = useNavigate();
    const [searchParams, setSearchParams] = useSearchParams();
    const { instance } = useMsal();

    const statusParam = (searchParams.get("status") as TicketStatus | null) ?? undefined;
    const categoryParam = (searchParams.get("category") as TicketCategory | null) ?? undefined;
    const queryParam = searchParams.get("q") ?? "";
    const pageParam = Math.max(1, Number(searchParams.get("page")) || 1);

    const [data, setData] = useState<TicketsListResponse | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [reloadKey, setReloadKey] = useState(0);

    useEffect(() => {
        let cancelled = false;
        async function load() {
            setLoading(true);
            setError(null);
            try {
                const idToken = useLogin && instance ? await getToken(instance) : undefined;
                const response = await listTicketsApi(
                    {
                        status: statusParam,
                        category: categoryParam,
                        limit: PAGE_SIZE,
                        offset: (pageParam - 1) * PAGE_SIZE
                    },
                    idToken
                );
                if (!cancelled) setData(response);
            } catch (e) {
                if (!cancelled) setError(e instanceof Error ? e.message : String(e));
            } finally {
                if (!cancelled) setLoading(false);
            }
        }
        void load();
        return () => {
            cancelled = true;
        };
    }, [statusParam, categoryParam, pageParam, instance, reloadKey]);

    const visibleItems = useMemo(() => {
        if (!data?.items) return [];
        if (!queryParam.trim()) return data.items;
        const needle = queryParam.trim().toLowerCase();
        return data.items.filter(ticket => ticket.subject.toLowerCase().includes(needle) || String(ticket.ticket_id).includes(needle));
    }, [data, queryParam]);

    const total = data?.pagination?.total ?? 0;
    const totalPages = total === 0 ? 1 : Math.ceil(total / PAGE_SIZE);
    const fromIndex = total === 0 ? 0 : (pageParam - 1) * PAGE_SIZE + 1;
    const toIndex = Math.min(pageParam * PAGE_SIZE, total);

    const updateParam = (key: string, value: string | undefined) => {
        const next = new URLSearchParams(searchParams);
        if (value === undefined || value === "") {
            next.delete(key);
        } else {
            next.set(key, value);
        }
        // Filtros server-side resetam a paginação para 1 (UX padrão)
        if (key !== "q" && key !== "page") {
            next.delete("page");
        }
        setSearchParams(next, { replace: true });
    };

    const clearFilters = () => {
        setSearchParams(new URLSearchParams(), { replace: true });
    };

    const goToPage = (page: number) => {
        if (page < 1 || page > totalPages) return;
        const next = new URLSearchParams(searchParams);
        if (page === 1) next.delete("page");
        else next.set("page", String(page));
        setSearchParams(next, { replace: true });
    };

    const hasFilters = Boolean(statusParam || categoryParam || queryParam);
    const localeTag = i18n.resolvedLanguage === "ptBR" ? "pt-BR" : i18n.resolvedLanguage || "en";

    return (
        <div className={styles.page}>
            <Helmet>
                <title>{`${t("helpsphere.tickets.pageTitle")} — ${t("helpsphere.appName")}`}</title>
            </Helmet>

            <header className={styles.header}>
                <h1 className={styles.title}>{t("helpsphere.tickets.pageTitle")}</h1>
                <p className={styles.subtitle}>{t("helpsphere.tagline")}</p>
            </header>

            <section className={styles.toolbar} aria-label="Filtros">
                <div className={styles.searchWrapper}>
                    <Input
                        appearance="outline"
                        placeholder={t("helpsphere.tickets.search")}
                        value={queryParam}
                        contentBefore={<Search24Regular aria-hidden="true" />}
                        onChange={(_, d) => updateParam("q", d.value)}
                        className={styles.searchInput}
                    />
                </div>

                <div className={styles.filtersGroup}>
                    <label className={styles.filterLabel}>
                        <span className={styles.filterLabelText}>{t("helpsphere.tickets.filters.status")}</span>
                        <Dropdown
                            value={statusParam ? t(`helpsphere.tickets.status.${statusParam}`) : t("helpsphere.tickets.filters.all")}
                            selectedOptions={statusParam ? [statusParam] : []}
                            onOptionSelect={(_, d) => updateParam("status", d.optionValue || undefined)}
                            placeholder={t("helpsphere.tickets.filters.all")}
                            className={styles.dropdown}
                        >
                            <Option value="">{t("helpsphere.tickets.filters.all")}</Option>
                            {TICKET_STATUSES.map(s => (
                                <Option key={s} value={s}>
                                    {t(`helpsphere.tickets.status.${s}`)}
                                </Option>
                            ))}
                        </Dropdown>
                    </label>

                    <label className={styles.filterLabel}>
                        <span className={styles.filterLabelText}>{t("helpsphere.tickets.filters.category")}</span>
                        <Dropdown
                            value={categoryParam ? t(`helpsphere.tickets.category.${categoryParam}`) : t("helpsphere.tickets.filters.all")}
                            selectedOptions={categoryParam ? [categoryParam] : []}
                            onOptionSelect={(_, d) => updateParam("category", d.optionValue || undefined)}
                            placeholder={t("helpsphere.tickets.filters.all")}
                            className={styles.dropdown}
                        >
                            <Option value="">{t("helpsphere.tickets.filters.all")}</Option>
                            {TICKET_CATEGORIES.map(c => (
                                <Option key={c} value={c}>
                                    {t(`helpsphere.tickets.category.${c}`)}
                                </Option>
                            ))}
                        </Dropdown>
                    </label>

                    {hasFilters && (
                        <Button appearance="subtle" icon={<DismissCircle24Regular />} onClick={clearFilters} className={styles.clearButton}>
                            {t("helpsphere.tickets.filters.clear")}
                        </Button>
                    )}
                </div>
            </section>

            {error && (
                <MessageBar intent="error" className={styles.errorBar}>
                    <MessageBarBody>
                        <MessageBarTitle>{t("helpsphere.tickets.errorLoading")}</MessageBarTitle>
                        {error}
                    </MessageBarBody>
                    <Button appearance="subtle" icon={<ArrowClockwise24Regular />} onClick={() => setReloadKey(k => k + 1)}>
                        {t("helpsphere.tickets.retry")}
                    </Button>
                </MessageBar>
            )}

            {loading && !data && <TicketsSkeleton />}

            {!loading && !error && visibleItems.length === 0 && (
                <div className={styles.emptyState} role="status">
                    <p>{t("helpsphere.tickets.empty")}</p>
                    {hasFilters && (
                        <Button appearance="primary" onClick={clearFilters}>
                            {t("helpsphere.tickets.filters.clear")}
                        </Button>
                    )}
                </div>
            )}

            {!error && data && visibleItems.length > 0 && (
                <div className={styles.tableWrapper}>
                    <table className={styles.table} aria-label={t("helpsphere.tickets.pageTitle")}>
                        <thead>
                            <tr>
                                <th className={styles.colId} scope="col">
                                    {t("helpsphere.tickets.columns.id")}
                                </th>
                                <th scope="col">{t("helpsphere.tickets.columns.subject")}</th>
                                <th scope="col">{t("helpsphere.tickets.columns.category")}</th>
                                <th scope="col">{t("helpsphere.tickets.columns.status")}</th>
                                <th scope="col">{t("helpsphere.tickets.columns.priority")}</th>
                                <th className={styles.colDate} scope="col">
                                    {t("helpsphere.tickets.columns.updatedAt")}
                                </th>
                            </tr>
                        </thead>
                        <tbody>
                            {visibleItems.map(ticket => (
                                <TicketRow key={ticket.ticket_id} ticket={ticket} locale={localeTag} navigate={navigate} t={t} />
                            ))}
                        </tbody>
                    </table>
                </div>
            )}

            {!error && data && (
                <footer className={styles.pagination} aria-label="Paginação">
                    <span className={styles.paginationInfo}>{t("helpsphere.tickets.pagination.showing", { from: fromIndex, to: toIndex, total })}</span>
                    <div className={styles.paginationControls}>
                        <Button appearance="secondary" disabled={pageParam <= 1} onClick={() => goToPage(pageParam - 1)}>
                            {t("helpsphere.tickets.pagination.previous")}
                        </Button>
                        <span className={styles.pageIndicator}>{t("helpsphere.tickets.pagination.page", { page: pageParam, total: totalPages })}</span>
                        <Button appearance="secondary" disabled={pageParam >= totalPages || total === 0} onClick={() => goToPage(pageParam + 1)}>
                            {t("helpsphere.tickets.pagination.next")}
                        </Button>
                    </div>
                </footer>
            )}
        </div>
    );
}

Component.displayName = "Tickets";

interface TicketRowProps {
    ticket: Ticket;
    locale: string;
    navigate: ReturnType<typeof useNavigate>;
    t: ReturnType<typeof useTranslation>["t"];
}

function TicketRow({ ticket, locale, navigate, t }: TicketRowProps) {
    const open = () => navigate(`/tickets/${ticket.ticket_id}`);
    const onKey: React.KeyboardEventHandler<HTMLTableRowElement> = e => {
        if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            open();
        }
    };
    return (
        <tr className={styles.row} tabIndex={0} role="link" onClick={open} onKeyDown={onKey}>
            <td className={styles.colId}>#{ticket.ticket_id}</td>
            <td className={styles.subject}>
                <span className={styles.subjectText}>{ticket.subject}</span>
            </td>
            <td>{t(`helpsphere.tickets.category.${ticket.category}`)}</td>
            <td>
                <StatusBadge status={ticket.status} />
            </td>
            <td>
                <PriorityBadge priority={ticket.priority} />
            </td>
            <td className={styles.colDate}>{formatDate(ticket.updated_at, locale)}</td>
        </tr>
    );
}

function TicketsSkeleton() {
    return (
        <div className={styles.tableWrapper} aria-busy="true" aria-live="polite">
            <Skeleton>
                <div className={styles.skeletonRow}>
                    <SkeletonItem shape="rectangle" size={16} style={{ width: "3rem" }} />
                    <SkeletonItem shape="rectangle" size={16} style={{ flex: 1 }} />
                    <SkeletonItem shape="rectangle" size={16} style={{ width: "6rem" }} />
                    <SkeletonItem shape="rectangle" size={16} style={{ width: "5rem" }} />
                </div>
                {Array.from({ length: 6 }).map((_, idx) => (
                    <div className={styles.skeletonRow} key={idx}>
                        <SkeletonItem shape="rectangle" size={16} style={{ width: "3rem" }} />
                        <SkeletonItem shape="rectangle" size={16} style={{ flex: 1 }} />
                        <SkeletonItem shape="rectangle" size={16} style={{ width: "6rem" }} />
                        <SkeletonItem shape="rectangle" size={16} style={{ width: "5rem" }} />
                    </div>
                ))}
            </Skeleton>
        </div>
    );
}
