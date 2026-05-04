/**
 * Página `/tickets/:ticketId` — detalhe completo de ticket.
 *
 * Production-pattern visível (audiência sênior — Disciplina 06):
 * - Carga unica via GET /api/tickets/{id} (LEFT JOIN no backend evita N+1)
 * - PATCH otimistico-no-refresh (estado local atualizado a partir da resposta)
 * - POST comment com auto-append na thread + reset do input
 * - POST suggest exibe payload didatico do stub (501 esperado)
 * - Skeleton, error MessageBar com retry, fallback para 404
 */
import { useCallback, useEffect, useMemo, useState, type JSX } from "react";
import { Link, useParams } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import { useTranslation } from "react-i18next";
import { useMsal } from "@azure/msal-react";
import { Button, Dropdown, MessageBar, MessageBarBody, MessageBarTitle, Option, Skeleton, SkeletonItem, Spinner, Textarea } from "@fluentui/react-components";
import { ArrowClockwise24Regular, ArrowLeft24Regular, Send24Regular, Sparkle24Regular } from "@fluentui/react-icons";

import styles from "./TicketDetail.module.css";
import { addCommentApi, getTicketApi, patchTicketApi, suggestTicketApi, type TicketDetail as TicketDetailType } from "../../api";
import { TICKET_STATUSES, type TicketStatus } from "../../api/ticketsModels";
import { StatusBadge } from "../../components/StatusBadge";
import { PriorityBadge } from "../../components/PriorityBadge";
import { useLogin, getToken } from "../../authConfig";

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

    const [commentDraft, setCommentDraft] = useState("");
    const [submittingComment, setSubmittingComment] = useState(false);
    const [commentError, setCommentError] = useState<string | null>(null);

    const [patchingStatus, setPatchingStatus] = useState(false);

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

    const submitComment = async () => {
        if (!ticket) return;
        const trimmed = commentDraft.trim();
        if (!trimmed) return;
        setSubmittingComment(true);
        setCommentError(null);
        try {
            const idToken = await getIdToken();
            const newComment = await addCommentApi(ticket.ticket_id, trimmed, idToken);
            setTicket(prev => (prev ? { ...prev, comments: [...prev.comments, newComment] } : prev));
            setCommentDraft("");
        } catch (e) {
            setCommentError(e instanceof Error ? e.message : String(e));
        } finally {
            setSubmittingComment(false);
        }
    };

    const patchStatus = async (next: TicketStatus) => {
        if (!ticket || next === ticket.status) return;
        setPatchingStatus(true);
        setError(null);
        try {
            const idToken = await getIdToken();
            const updated = await patchTicketApi(ticket.ticket_id, { status: next }, idToken);
            setTicket(prev => (prev ? { ...updated, comments: prev.comments } : prev));
        } catch (e) {
            setError(e instanceof Error ? e.message : String(e));
        } finally {
            setPatchingStatus(false);
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
                <>
                    <header className={styles.header}>
                        <div className={styles.headerTop}>
                            <span className={styles.ticketId}>#{ticket.ticket_id}</span>
                            <PriorityBadge priority={ticket.priority} />
                            <StatusBadge status={ticket.status} />
                        </div>
                        <h1 className={styles.subject}>{ticket.subject}</h1>
                    </header>

                    <div className={styles.layoutGrid}>
                        <div className={styles.mainColumn}>
                            <section className={styles.card}>
                                <h2 className={styles.cardTitle}>{t("helpsphere.tickets.detail.description")}</h2>
                                <p className={styles.descriptionText}>{ticket.description}</p>
                            </section>

                            <section className={styles.card} aria-label={t("helpsphere.tickets.detail.comments", { count: ticket.comments.length })}>
                                <h2 className={styles.cardTitle}>{t("helpsphere.tickets.detail.comments", { count: ticket.comments.length })}</h2>

                                {ticket.comments.length === 0 ? (
                                    <p className={styles.muted}>—</p>
                                ) : (
                                    <ul className={styles.commentsList}>
                                        {ticket.comments.map(c => (
                                            <li key={c.comment_id} className={styles.comment}>
                                                <div className={styles.commentMeta}>
                                                    <span className={styles.commentAuthor}>{c.author}</span>
                                                    <span className={styles.commentDate}>{formatDateTime(c.created_at)}</span>
                                                </div>
                                                <p className={styles.commentContent}>{c.content}</p>
                                            </li>
                                        ))}
                                    </ul>
                                )}

                                {/*
                                  Story 06.5c.6 — Adicionar comentário desabilitado temporariamente.
                                  POST /api/tickets/{id}/comments será implementado no Lab Intermediário
                                  (junto com sugestão de resposta via RAG). A thread acima continua
                                  populada pelos comments do seed. Ver DECISION-LOG.md #16.
                                 */}
                                <MessageBar intent="info" className={styles.commentForm}>
                                    <MessageBarBody>
                                        <MessageBarTitle>Adicionar comentário — Lab Intermediário</MessageBarTitle>
                                        Esta funcionalidade será habilitada quando você acoplar o pipeline RAG no Lab Intermediário (junto com sugestão de
                                        resposta automática via IA). A thread acima exibe os comentários do seed.
                                    </MessageBarBody>
                                </MessageBar>
                                <form
                                    className={styles.commentForm}
                                    onSubmit={e => {
                                        e.preventDefault();
                                        void submitComment();
                                    }}
                                    style={{ display: "none" }}
                                >
                                    <Textarea
                                        placeholder={t("helpsphere.tickets.detail.commentPlaceholder")}
                                        value={commentDraft}
                                        onChange={(_, d) => setCommentDraft(d.value)}
                                        rows={3}
                                        disabled={submittingComment}
                                        className={styles.commentInput}
                                    />
                                    {commentError && (
                                        <span className={styles.inlineError} role="alert">
                                            {commentError}
                                        </span>
                                    )}
                                    <div className={styles.commentSubmitRow}>
                                        <Button
                                            appearance="primary"
                                            type="submit"
                                            icon={<Send24Regular />}
                                            disabled={!commentDraft.trim() || submittingComment}
                                        >
                                            {submittingComment ? t("helpsphere.tickets.detail.submitting") : t("helpsphere.tickets.detail.submit")}
                                        </Button>
                                    </div>
                                </form>
                            </section>
                        </div>

                        <aside className={styles.sideColumn}>
                            <section className={styles.card}>
                                <h2 className={styles.cardTitle}>{t("helpsphere.tickets.columns.subject")}</h2>
                                <dl className={styles.metaList}>
                                    <dt>{t("helpsphere.tickets.columns.tenant")}</dt>
                                    <dd className={styles.tenantValue} title={ticket.tenant_id}>
                                        {ticket.tenant_id.slice(0, 8)}…
                                    </dd>

                                    <dt>{t("helpsphere.tickets.columns.category")}</dt>
                                    <dd>{t(`helpsphere.tickets.category.${ticket.category}`)}</dd>

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
                            </section>

                            <section className={styles.card}>
                                <h2 className={styles.cardTitle}>{t("helpsphere.tickets.detail.patchStatus")}</h2>
                                <Dropdown
                                    value={t(`helpsphere.tickets.status.${ticket.status}`)}
                                    selectedOptions={[ticket.status]}
                                    onOptionSelect={(_, d) => {
                                        if (d.optionValue) void patchStatus(d.optionValue as TicketStatus);
                                    }}
                                    disabled={patchingStatus}
                                    className={styles.statusDropdown}
                                >
                                    {TICKET_STATUSES.map(s => (
                                        <Option key={s} value={s}>
                                            {t(`helpsphere.tickets.status.${s}`)}
                                        </Option>
                                    ))}
                                </Dropdown>

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
                            </section>
                        </aside>
                    </div>
                </>
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
