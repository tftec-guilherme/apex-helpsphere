import { useEffect, useRef, useState } from "react";
import { Outlet, NavLink } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { Helmet } from "react-helmet-async";
import { FluentProvider, webLightTheme } from "@fluentui/react-components";
import { useMsal } from "@azure/msal-react";

import { LoginButton } from "./components/LoginButton/LoginButton";
import { LoginContext } from "./loginContext";
import { useLogin, enableChat, checkLoggedIn } from "./authConfig";
import styles from "./Shell.module.css";

const ShellLayout = () => {
    const { t } = useTranslation();

    const navLinkClass = ({ isActive }: { isActive: boolean }) => `${styles.navLink} ${isActive ? styles.navLinkActive : ""}`;

    return (
        <div className={styles.shell}>
            <Helmet>
                <title>{t("pageTitle")}</title>
            </Helmet>
            <aside className={styles.sidebar}>
                <div className={styles.brand}>
                    <span className={styles.brandMark} aria-hidden="true">
                        ◇
                    </span>
                    <span className={styles.brandName}>HelpSphere</span>
                </div>
                <nav className={styles.nav} aria-label="Primary">
                    <NavLink to="/" end className={navLinkClass}>
                        Dashboard
                    </NavLink>
                    <NavLink to="/tickets" className={navLinkClass}>
                        Tickets
                    </NavLink>
                    {enableChat && (
                        <NavLink to="/chat" className={navLinkClass}>
                            Assistente IA
                        </NavLink>
                    )}
                </nav>
                <div className={styles.sidebarFooter}>
                    <span className={styles.brandTag}>Apex Group · D06</span>
                </div>
            </aside>
            <div className={styles.main}>
                <header className={styles.topbar}>
                    <div className={styles.topbarTitle}>
                        <h1>HelpSphere</h1>
                        <span className={styles.topbarSubtitle}>Plataforma operacional de tickets</span>
                    </div>
                    <div className={styles.topbarActions}>{useLogin && <LoginButton />}</div>
                </header>
                <main className={styles.content} id="main-content">
                    <Outlet />
                </main>
            </div>
        </div>
    );
};

export const Shell = () => {
    const [loggedIn, setLoggedIn] = useState(false);

    if (useLogin) {
        const { instance } = useMsal();
        const mounted = useRef<boolean>(true);

        useEffect(() => {
            mounted.current = true;
            checkLoggedIn(instance)
                .then(isLoggedIn => {
                    if (mounted.current) setLoggedIn(isLoggedIn);
                })
                .catch(e => {
                    console.error("checkLoggedIn failed", e);
                });
            return () => {
                mounted.current = false;
            };
        }, [instance]);

        return (
            <LoginContext.Provider value={{ loggedIn, setLoggedIn }}>
                <FluentProvider theme={webLightTheme} style={{ minHeight: "100vh", backgroundColor: "transparent" }}>
                    <ShellLayout />
                </FluentProvider>
            </LoginContext.Provider>
        );
    }

    return (
        <LoginContext.Provider value={{ loggedIn, setLoggedIn }}>
            <FluentProvider theme={webLightTheme} style={{ minHeight: "100vh", backgroundColor: "transparent" }}>
                <ShellLayout />
            </FluentProvider>
        </LoginContext.Provider>
    );
};

export default Shell;
