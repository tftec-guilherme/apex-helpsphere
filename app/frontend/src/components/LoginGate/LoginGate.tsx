import { ReactNode } from "react";
import { useMsal } from "@azure/msal-react";
import { loginRequest, getRedirectUri, useLogin } from "../../authConfig";
import { BrandMark } from "../BrandMark/BrandMark";
import styles from "./LoginGate.module.css";

interface Props {
    isLoggedIn: boolean;
    children: ReactNode;
}

/**
 * Gate bloqueante de autenticacao. Se `useLogin=true` e user nao logou ainda,
 * renderiza landing com call-to-action explicito em vez do Shell.
 *
 * Resolve UX issue: botao Login no topbar pode falhar silenciosamente quando
 * popup e bloqueado pelo browser. Landing centralizada com mensagem clara
 * elimina ambiguidade.
 */
export const LoginGate = ({ isLoggedIn, children }: Props) => {
    const { instance } = useMsal();

    if (!useLogin || isLoggedIn) {
        return <>{children}</>;
    }

    const handleLogin = () => {
        // loginRedirect: navega a janela inteira para login.microsoftonline.com
        // (vs popup que pode ser bloqueado em incognito). Volta para /redirect
        // com hash #code=..., processado por handleRedirectPromise() no boot
        // (index.tsx). Mais robusto + fluxo padrao recomendado pela MS.
        //
        // prompt: "select_account" — forca AAD a mostrar o seletor de contas
        // sempre, mesmo se user ja tem sessao SSO ativa. Resolve UX confuso
        // quando user quer logar com conta diferente da cached.
        instance
            .loginRedirect({
                ...loginRequest,
                redirectUri: getRedirectUri(),
                prompt: "select_account"
            })
            .catch(error => {
                const code = error?.errorCode || error?.name || "unknown";
                const msg = error?.errorMessage || error?.message || String(error);
                const banner = document.createElement("div");
                banner.className = styles.errorBanner;
                banner.textContent = `[${code}] ${msg}`;
                const existing = document.getElementById("login-error-banner");
                if (existing) existing.remove();
                banner.id = "login-error-banner";
                document.querySelector(`.${styles.card}`)?.appendChild(banner);
            });
    };

    return (
        <div className={styles.gate}>
            <header className={styles.top}>
                <div className={styles.topBrand}>
                    <BrandMark size={28} />
                    <span className={styles.wordmark}>HelpSphere</span>
                </div>
                <span className={styles.topMeta}>Apex Group · Disciplina 06</span>
            </header>

            <main className={styles.main}>
                <div className={styles.card}>
                    <div className={styles.markWrap}>
                        <BrandMark size={48} />
                    </div>
                    <h1 className={styles.title}>HelpSphere</h1>
                    <p className={styles.lede}>
                        Plataforma operacional de tickets do <strong>Apex Group</strong>
                    </p>
                    <p className={styles.body}>Acesso restrito a colaboradores. Use sua conta corporativa para entrar.</p>
                    <button type="button" className={styles.cta} onClick={handleLogin}>
                        <svg width="18" height="18" viewBox="0 0 23 23" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                            <rect x="1" y="1" width="10" height="10" fill="#f25022" />
                            <rect x="12" y="1" width="10" height="10" fill="#7fba00" />
                            <rect x="1" y="12" width="10" height="10" fill="#00a4ef" />
                            <rect x="12" y="12" width="10" height="10" fill="#ffb900" />
                        </svg>
                        Entrar com Microsoft
                    </button>
                    <p className={styles.footnote}>
                        Sua sessão é mantida via Microsoft Entra ID. Bloqueio de popup pode interromper o login — confira que pop-ups estão liberados para{" "}
                        <code>localhost:50505</code>.
                    </p>
                </div>
            </main>

            <footer className={styles.bottom}>
                <span>v2.1.0 · two-app pattern · runtime config</span>
                <span>© Apex Group · template pedagógico TFTEC</span>
            </footer>
        </div>
    );
};
