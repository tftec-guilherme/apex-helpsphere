/**
 * ChatPanel — painel flutuante (canto inferior direito) que consome o endpoint
 * `/chat/rag` do backend Python.
 *
 * Story 06.10 — Lab Intermediário (Disciplina 06) Parte 8.
 *
 * Estado dormente (gating):
 *   1. Backend `RAG_ENABLED=true` (param Bicep `ragEnabled`) — expõe `/chat/rag`.
 *   2. Frontend monta o componente via `<Shell />` apenas quando:
 *      - `enableChat === true` (mesma flag da nav "Assistente IA")
 *      - URL contém `?chat=1` (Opção A do guia, Passo 8.4) OU `chat=1` no hash
 *      - `ragEnabled === true` no `/auth_setup`
 *
 * UX intencionalmente simples para suportar o checkpoint da Parte 8 sem
 * sobreengenhar (manutenção e leitura do código pelos alunos é primeira
 * prioridade). Itens fora de escopo: histórico de conversa, streaming,
 * markdown rendering, citation popovers. Tudo isso vive no `/chat` upstream
 * (página dedicada — o ChatPanel é um shortcut do Lab Inter).
 */
import { FormEvent, useCallback, useEffect, useRef, useState } from "react";
import { useMsal } from "@azure/msal-react";

import { ragSuggestApi, RagSuggestResponse } from "../../api/rag";
import { getToken, useLogin } from "../../authConfig";

import styles from "./ChatPanel.module.css";

interface Props {
    /** Permite fechar o painel via "?chat=1" toggle no Shell. */
    onClose?: () => void;
}

interface RagResultState {
    response: RagSuggestResponse | null;
    error: string | null;
    loading: boolean;
}

const INITIAL_RESULT: RagResultState = { response: null, error: null, loading: false };

export const ChatPanel = ({ onClose }: Props) => {
    const { instance } = useMsal();

    const [ticketId, setTicketId] = useState<string>("");
    const [description, setDescription] = useState<string>("");
    const [collapsed, setCollapsed] = useState<boolean>(false);
    const [result, setResult] = useState<RagResultState>(INITIAL_RESULT);
    const abortRef = useRef<AbortController | null>(null);

    useEffect(() => {
        return () => {
            if (abortRef.current) {
                abortRef.current.abort();
            }
        };
    }, []);

    const handleSubmit = useCallback(
        async (event: FormEvent<HTMLFormElement>) => {
            event.preventDefault();
            const ticketIdNum = Number(ticketId);
            if (!Number.isFinite(ticketIdNum) || ticketIdNum <= 0) {
                setResult({ response: null, error: "Informe um ticket_id numérico válido (> 0).", loading: false });
                return;
            }
            const trimmedDescription = description.trim();
            if (!trimmedDescription) {
                setResult({ response: null, error: "Descreva a dúvida ou o ticket para o assistente.", loading: false });
                return;
            }

            if (abortRef.current) {
                abortRef.current.abort();
            }
            const controller = new AbortController();
            abortRef.current = controller;

            setResult({ response: null, error: null, loading: true });
            try {
                const idToken = useLogin ? await getToken(instance) : undefined;
                const response = await ragSuggestApi(
                    {
                        ticketId: ticketIdNum,
                        description: trimmedDescription
                    },
                    idToken,
                    controller.signal
                );
                setResult({ response, error: null, loading: false });
            } catch (e) {
                if (controller.signal.aborted) {
                    return;
                }
                setResult({
                    response: null,
                    error: e instanceof Error ? e.message : String(e),
                    loading: false
                });
            }
        },
        [description, instance, ticketId]
    );

    if (collapsed) {
        return (
            <button
                type="button"
                className={styles.fab}
                aria-label="Abrir assistente RAG"
                onClick={() => setCollapsed(false)}
            >
                IA
            </button>
        );
    }

    return (
        <aside className={styles.panel} role="complementary" aria-label="Assistente RAG (Lab Intermediário)">
            <header className={styles.header}>
                <div className={styles.headerText}>
                    <span className={styles.kicker}>Lab Intermediário</span>
                    <h2 className={styles.title}>Assistente RAG</h2>
                </div>
                <div className={styles.headerActions}>
                    <button
                        type="button"
                        className={styles.iconButton}
                        aria-label="Minimizar painel"
                        onClick={() => setCollapsed(true)}
                    >
                        –
                    </button>
                    {onClose && (
                        <button
                            type="button"
                            className={styles.iconButton}
                            aria-label="Fechar painel"
                            onClick={onClose}
                        >
                            ×
                        </button>
                    )}
                </div>
            </header>

            <form className={styles.form} onSubmit={handleSubmit}>
                <label className={styles.label}>
                    <span>Ticket #</span>
                    <input
                        type="number"
                        min={1}
                        inputMode="numeric"
                        className={styles.input}
                        placeholder="4521"
                        value={ticketId}
                        onChange={e => setTicketId(e.target.value)}
                        disabled={result.loading}
                        required
                    />
                </label>
                <label className={styles.label}>
                    <span>Descrição / dúvida</span>
                    <textarea
                        className={styles.textarea}
                        placeholder="Como reembolsar lojista quando pedido não foi entregue?"
                        rows={3}
                        value={description}
                        onChange={e => setDescription(e.target.value)}
                        disabled={result.loading}
                        required
                    />
                </label>
                <button type="submit" className={styles.submit} disabled={result.loading}>
                    {result.loading ? "Consultando RAG…" : "Sugerir resposta"}
                </button>
            </form>

            {result.error && (
                <div className={styles.errorBox} role="alert">
                    {result.error}
                </div>
            )}
            {result.response && (
                <div className={styles.resultBox}>
                    <p className={styles.resultText}>{result.response.suggested_response}</p>
                    {typeof result.response.confidence === "number" && (
                        <p className={styles.confidence}>
                            Confiança: <strong>{(result.response.confidence * 100).toFixed(0)}%</strong>
                        </p>
                    )}
                    {result.response.citations && result.response.citations.length > 0 && (
                        <ul className={styles.citations} aria-label="Citações">
                            {result.response.citations.map((c, idx) => (
                                <li key={`${c.source}-${idx}`}>
                                    <span className={styles.citationSource}>{c.source}</span>
                                    {typeof c.page === "number" && (
                                        <span className={styles.citationPage}> · pág. {c.page}</span>
                                    )}
                                </li>
                            ))}
                        </ul>
                    )}
                </div>
            )}
        </aside>
    );
};

export default ChatPanel;
