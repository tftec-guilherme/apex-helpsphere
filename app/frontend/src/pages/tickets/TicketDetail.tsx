/**
 * Página `/tickets/:ticketId` — detalhe completo de ticket no layout Apex Executivo.
 *
 * Wave 3.I (HelpSphere v2.1.0): redesign 2-colunas (main + sidebar sticky) usando
 * design tokens (`var(--color-*)`, `var(--space-*)`, `var(--font-*)`) e os
 * components da Wave 3.I (StatusPill big, SlaCountdown live, CommentTimeline).
 *
 * Production-pattern visível (audiência sênior — Disciplina 06):
 * - Carga única via GET /api/tickets/{id} (LEFT JOIN no backend evita N+1)
 * - PUT otimistico-no-refresh (estado local atualizado a partir da resposta)
 * - POST suggest exibe payload didático do stub (501 esperado)
 * - Skeleton, error MessageBar com retry, fallback para 404
 * - Comments thread populada pelo seed; POST comment continua stub (Lab Intermediário)
 */
import { useCallback, useEffect, useMemo, useState, type JSX } from "react";
import { Link, useParams } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import { useTranslation } from "react-i18next";
import { useMsal } from "@azure/msal-react";
import { Button, MessageBar, MessageBarBody, MessageBarTitle, Skeleton, SkeletonItem, Spinner } from "@fluentui/react-components";
import { ArrowClockwise24Regular, ArrowLeft24Regular, Sparkle24Regular } from "@fluentui/react-icons";

import styles from "./TicketDetail.module.css";
import { getTicketApi, patchTicketApi, suggestTicketApi } from "../../api";
import type { TicketDetail as TicketDetailType } from "../../api";
import { TICKET_STATUSES, type TicketStatus } from "../../api/ticketsModels";
import { StatusPill } from "../../components/StatusPill/StatusPill";
import { SlaCountdown } from "../../components/SlaCountdown/SlaCountdown";
import { CommentTimeline } from "../../components/Timeline/CommentTimeline";
import { useLogin, getToken } from "../../authConfig";

const PRIORITY_LABELS: Record<string, string> = {
    Critical: "Crítica",
    High: "Alta",
    Medium: "Média",
    Low: "Baixa"
};

export function Component(): JSX.Element {
    const { ticketId } = useParams<{ ticketId: string }>();
    const ticketIdNum = Number(ticketId);
    const ticketIdValid = Number.isFinite(ticketIdNum) && ticketIdNum > 0;

    const { t, i18n } = useTranslation();
    const { instance } = useMsal();

    const [ticket, setTicket] = useState<TicketDetailType | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [reloadKey, setReloadKey] = useState(0);

    const [patchingStatus, setPatchingStatus] = useState<TicketStatus | null>(null);

    const [suggesting, setSuggesting] = useState(false);
    const [suggestResult, setSuggestResult] = useState<string | null>(null);

    const getIdToken = useCallback(async (): Promise<string | undefined> => {
        if (!useLogin || !instance) return undefined;
        return await getToken(instance);
    }, [instance]);

    useEffect(() => {
        if (!ticketIdValid) {
            setError(`Ticket id inválido: "${ticketId ?? ""}"`);
            setLoading(false);
            return;
        }
        let cancelled = false;
        async function load() {
            setLoading(true);
            setError(null);
            try {
                const idToken = await getIdToken();
                const detail = await getTicketApi(ticketIdNum, idToken);
                if (!cancelled) setTicket(detail);
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
    }, [ticketIdNum, ticketIdValid, ticketId, reloadKey, getIdToken]);

    const patchStatus = async (next: TicketStatus) => {
        if (!ticket || next === ticket.status) return;
        setPatchingStatus(next);
        setError(null);
        try {
            const idToken = await getIdToken();
            const updated = await patchTicketApi(ticket.ticket_id, { status: next }, idToken);
            setTicket(prev => (prev ? { ...updated, comments: prev.comments } : prev));
        } catch (e) {
            setError(e instanceof Error ? e.message : String(e));
        } finally {
            setPatchingStatus(null);
        }
    };

    const callSuggest = async () => {
        if (!ticket) return;
        setSuggesting(true);
        setSuggestResult(null);
        try {
            const idToken = await getIdToken();
            const result = await suggestTicketApi(ticket.ticket_id, idToken);
            setSuggestResult(result.detail);
        } catch (e) {
            setSuggestResult(e instanceof Error ? e.message : String(e));
        } finally {
            setSuggesting(false);
        }
    };

    const attachments = useMemo(() => {
        if (!ticket?.attachment_blob_paths) return [] as string[];
        try {
            const parsed = JSON.parse(ticket.attachment_blob_paths);
            return Array.isArray(parsed) ? parsed.map((x: unknown) => String(x)) : [];
        } catch {
            return [] as string[];
        }
    }, [ticket?.attachment_blob_paths]);

    const localeTag = i18n.resolvedLanguage === "ptBR" ? "pt-BR" : i18n.resolvedLanguage || "en";

    const formatDateTime = (iso: string): string => {
        try {
            return new Date(iso).toLocaleString(localeTag, {
                day: "2-digit",
                month: "2-digit",
                year: "numeric",
                hour: "2-digit",
                minute: "2-digit"
            });
        } catch {
            return iso;
        }
    };

    const headTitle = ticket
        ? `#${ticket.ticket_id} ${ticket.subject} — ${t("helpsphere.appName")}`
        : `${t("helpsphere.tickets.pageTitle")} — ${t("helpsphere.appName")}`;

    const safePriority = ticket?.priority || "";
    const priorityLabel = ticket ? PRIORITY_LABELS[safePriority] || safePriority || "—" : "";
    const priorityClass = ticket && safePriority ? styles[`pri-${safePriority.toLowerCase()}`] : "";

    return (
        <div className={styles.page}>
            <Helmet>
                <title>{headTitle}</title>
            </Helmet>

            <Link to="/tickets" className={styles.backLink}>
                <ArrowLeft24Regular aria-hidden="true" />
                <span>{t("helpsphere.tickets.detail.back")}</span>
            </Link>

            {error && (
                <MessageBar intent="error" className={styles.errorBar}>
                    <MessageBarBody>
                        <MessageBarTitle>{t("helpsphere.tickets.detail.errorLoading")}</MessageBarTitle>
                        {error}
                    </MessageBarBody>
                    {ticketIdValid && (
                        <Button appearance="subtle" icon={<ArrowClockwise24Regular />} onClick={() => setReloadKey(k => k + 1)}>
                            {t("helpsphere.tickets.retry")}
                        </Button>
                    )}
                </MessageBar>
            )}

            {loading && !ticket && <DetailSkeleton />}

            {ticket && (
                <div className={styles.layout}>
                    <article className={styles.main}>
                        <header className={styles.header}>
                            <div className={styles.headerMeta}>
                                <span className={styles.id}>#{ticket.ticket_id}</span>
                                <span className={`${styles.priority} ${priorityClass}`}>{priorityLabel}</span>
                                <StatusPill status={ticket.status} size="lg" />
                            </div>
                        </header>

                        <h2 className={styles.subject}>{ticket.subject}</h2>
                        <p className={styles.description}>{ticket.description}</p>

                        <section className={styles.statusActions} aria-label={t("helpsphere.tickets.detail.patchStatus")}>
                            <h3 className={styles.sectionTitle}>{t("helpsphere.tickets.detail.patchStatus")}</h3>
                            <div className={styles.statusButtons}>
                                {TICKET_STATUSES.map(s => {
                                    const isActive = ticket.status === s;
                                    const isPending = patchingStatus === s;
                                    return (
                                        <button
                                            key={s}
                                            type="button"
                                            className={`${styles.statusBtn} ${isActive ? styles.statusBtnActive : ""}`}
                                            onClick={() => void patchStatus(s)}
                                            disabled={isActive || patchingStatus !== null}
                                            aria-pressed={isActive}
                                        >
                                            {isPending && <Spinner size="tiny" className={styles.btnSpinner} />}
                                            <span>{t(`helpsphere.tickets.status.${s}`, { defaultValue: s })}</span>
                                        </button>
                                    );
                                })}
                            </div>
                        </section>

                        <section className={styles.commentsSection}>
                            <h3 className={styles.sectionTitle}>{t("helpsphere.tickets.detail.comments", { count: ticket.comments.length })}</h3>
                            <CommentTimeline comments={ticket.comments} locale={localeTag} />
                            {/*
                              Story 06.5c.6 — Adicionar comentário desabilitado temporariamente.
                              POST /api/tickets/{id}/comments será implementado no Lab Intermediário
                              (junto com sugestão de resposta via RAG). Ver DECISION-LOG.md #16.
                            */}
                            <MessageBar intent="info" className={styles.commentNotice}>
                                <MessageBarBody>
                                    <MessageBarTitle>Adicionar comentário — Lab Intermediário</MessageBarTitle>
                                    Esta funcionalidade será habilitada quando você acoplar o pipeline RAG no Lab Intermediário (junto com sugestão de resposta
                                    automática via IA). A thread acima exibe os comentários do seed.
                                </MessageBarBody>
                            </MessageBar>
                        </section>
                    </article>

                    <aside className={styles.sidebar}>
                        <div className={styles.card}>
                            <h4 className={styles.cardTitle}>{t("helpsphere.tickets.detail.description")}</h4>
                            <dl className={styles.dl}>
                                <dt>{t("helpsphere.tickets.columns.tenant")}</dt>
                                <dd className={styles.tenantValue} title={ticket.tenant_id}>
                                    {ticket.tenant_id.slice(0, 8)}…
                                </dd>

                                <dt>{t("helpsphere.tickets.columns.category")}</dt>
                                <dd>{t(`helpsphere.tickets.category.${ticket.category}`, { defaultValue: ticket.category })}</dd>

                                <dt>{t("helpsphere.tickets.detail.language")}</dt>
                                <dd>{ticket.language}</dd>

                                <dt>{t("helpsphere.tickets.detail.createdAt")}</dt>
                                <dd>{formatDateTime(ticket.created_at)}</dd>

                                <dt>{t("helpsphere.tickets.detail.updatedAt")}</dt>
                                <dd>{formatDateTime(ticket.updated_at)}</dd>

                                <dt>{t("helpsphere.tickets.detail.confidence")}</dt>
                                <dd>
                                    {ticket.confidence_score === null ? (
                                        <span className={styles.muted}>{t("helpsphere.tickets.detail.noConfidence")}</span>
                                    ) : (
                                        <ConfidenceBar value={ticket.confidence_score} />
                                    )}
                                </dd>

                                <dt>{t("helpsphere.tickets.detail.attachments")}</dt>
                                <dd>
                                    {attachments.length === 0 ? (
                                        <span className={styles.muted}>{t("helpsphere.tickets.detail.noAttachments")}</span>
                                    ) : (
                                        <ul className={styles.attachmentsList}>
                                            {attachments.map(path => (
                                                <li key={path} className={styles.attachment}>
                                                    {path.split("/").pop() || path}
                                                </li>
                                            ))}
                                        </ul>
                                    )}
                                </dd>
                            </dl>
                        </div>

                        <div className={styles.card}>
                            <h4 className={styles.cardTitle}>SLA</h4>
                            <SlaCountdown createdAt={ticket.created_at} priority={ticket.priority} status={ticket.status} />
                        </div>

                        <div className={styles.card}>
                            <h4 className={styles.cardTitle}>{t("helpsphere.tickets.detail.suggest")}</h4>
                            <Button
                                appearance="primary"
                                icon={suggesting ? <Spinner size="tiny" /> : <Sparkle24Regular />}
                                onClick={() => void callSuggest()}
                                disabled={suggesting}
                                className={styles.suggestButton}
                            >
                                {t("helpsphere.tickets.detail.suggest")}
                            </Button>
                            {suggestResult && (
                                <MessageBar intent="info" className={styles.suggestResult}>
                                    <MessageBarBody>{suggestResult}</MessageBarBody>
                                </MessageBar>
                            )}
                        </div>
                    </aside>
                </div>
            )}
        </div>
    );
}

Component.displayName = "TicketDetail";

interface ConfidenceBarProps {
    value: number;
}

function ConfidenceBar({ value }: ConfidenceBarProps) {
    const pct = Math.round(Math.max(0, Math.min(1, value)) * 100);
    return (
        <div className={styles.confidence} role="meter" aria-valuemin={0} aria-valuemax={100} aria-valuenow={pct}>
            <div className={styles.confidenceTrack}>
                <div className={styles.confidenceFill} style={{ width: `${pct}%` }} aria-hidden="true" />
            </div>
            <span className={styles.confidenceValue}>{pct}%</span>
        </div>
    );
}

function DetailSkeleton() {
    return (
        <div className={styles.skeletonWrapper} aria-busy="true" aria-live="polite">
            <Skeleton>
                <div className={styles.skeletonHeader}>
                    <SkeletonItem shape="rectangle" size={32} style={{ width: "10rem", marginBottom: "0.5rem" }} />
                    <SkeletonItem shape="rectangle" size={24} style={{ width: "70%" }} />
                </div>
                <div className={styles.skeletonContent}>
                    <SkeletonItem shape="rectangle" size={16} style={{ width: "100%" }} />
                    <SkeletonItem shape="rectangle" size={16} style={{ width: "92%" }} />
                    <SkeletonItem shape="rectangle" size={16} style={{ width: "85%" }} />
                </div>
            </Skeleton>
        </div>
    );
}
