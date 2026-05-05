/**
 * CommentTimeline — thread vertical de comentários do ticket.
 *
 * Wave 3.I (HelpSphere v2.1.0). Lista ordenada visual com marker dot + linha
 * vertical conectando os items via pseudo-elementos do CSS module. Cada item
 * exibe header (autor + timestamp formatado pt-BR) e body do comentário.
 *
 * Os campos do `TicketComment` são snake_case (`comment_id`, `created_at`)
 * para casar 1:1 com o JSON do backend Python.
 */
import type { TicketComment } from "../../api/ticketsModels";
import styles from "./CommentTimeline.module.css";

interface Props {
    comments: TicketComment[];
    locale?: string;
    emptyMessage?: string;
}

const formatDateTime = (iso: string, locale = "pt-BR"): string => {
    try {
        return new Date(iso).toLocaleString(locale, {
            day: "2-digit",
            month: "short",
            year: "numeric",
            hour: "2-digit",
            minute: "2-digit"
        });
    } catch {
        return iso;
    }
};

export const CommentTimeline = ({ comments, locale = "pt-BR", emptyMessage = "Sem comentários ainda." }: Props) => {
    if (!comments || comments.length === 0) {
        return <div className={styles.empty}>{emptyMessage}</div>;
    }
    return (
        <ol className={styles.timeline}>
            {comments.map((c, i) => (
                <li key={c.comment_id ?? i} className={styles.item}>
                    <span className={styles.marker} aria-hidden="true" />
                    <div className={styles.content}>
                        <header className={styles.head}>
                            <span className={styles.author}>{c.author || "Anônimo"}</span>
                            <span className={styles.time}>{formatDateTime(c.created_at, locale)}</span>
                        </header>
                        <p className={styles.body}>{c.content}</p>
                    </div>
                </li>
            ))}
        </ol>
    );
};

export default CommentTimeline;
