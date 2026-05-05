import { useEffect, useRef, useState } from "react";
import { Outlet, NavLink, useLocation } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { Helmet } from "react-helmet-async";
import { FluentProvider, webLightTheme } from "@fluentui/react-components";
import { useMsal } from "@azure/msal-react";

import { LoginButton } from "./components/LoginButton/LoginButton";
import { BrandMark } from "./components/BrandMark/BrandMark";
import { LoginGate } from "./components/LoginGate/LoginGate";
import { LoginContext } from "./loginContext";
import { useLogin, enableChat, checkLoggedIn } from "./authConfig";
import styles from "./Shell.module.css";

interface NavItem {
    to: string;
    label: string;
    end?: boolean;
    description: string;
}

const buildNav = (chatEnabled: boolean): { section: string; items: NavItem[] }[] => {
    const sections = [
        {
            section: "Operação",
            items: [
                { to: "/", label: "Dashboard", end: true, description: "Visão executiva" },
                { to: "/tickets", label: "Tickets", description: "Fila operacional" }
            ] as NavItem[]
        }
    ];
    if (chatEnabled) {
        sections.push({
            section: "Inteligência",
            items: [{ to: "/chat", label: "Assistente IA", description: "Chat RAG sobre playbooks" }]
        });
    }
    return sections;
};

const PAGE_META: Record<string, { title: string; subtitle: string }> = {
    "/": { title: "Dashboard operacional", subtitle: "Visão consolidada da fila Apex" },
    "/tickets": { title: "Tickets", subtitle: "Fila operacional do tenant" },
    "/chat": { title: "Assistente IA", subtitle: "Chat RAG sobre base de conhecimento" }
};

const resolvePageMeta = (pathname: string) => {
    if (pathname.startsWith("/tickets/")) {
        return { title: "Detalhe do ticket", subtitle: "Investigação e resolução" };
    }
    return PAGE_META[pathname] || { title: "HelpSphere", subtitle: "Plataforma operacional Apex Group" };
};

const ShellLayout = () => {
    const { t } = useTranslation();
    const location = useLocation();
    const meta = resolvePageMeta(location.pathname);
    const navSections = buildNav(enableChat);

    const navLinkClass = ({ isActive }: { isActive: boolean }) => `${styles.navLink} ${isActive ? styles.navLinkActive : ""}`;

    return (
        <div className={styles.shell}>
            <Helmet>
                <title>{t("pageTitle")}</title>
            </Helmet>
            <aside className={styles.sidebar}>
                <div className={styles.brand}>
                    <BrandMark size={36} />
                    <div className={styles.brandText}>
                        <span className={styles.brandName}>HelpSphere</span>
                        <span className={styles.brandSubtitle}>Apex Group</span>
                    </div>
                </div>

                <nav className={styles.nav} aria-label="Primary">
                    {navSections.map(section => (
                        <div key={section.section} className={styles.navSection}>
                            <span className={styles.navSectionLabel}>{section.section}</span>
                            {section.items.map(item => (
                                <NavLink key={item.to} to={item.to} end={item.end} className={navLinkClass}>
                                    <span className={styles.navLinkLabel}>{item.label}</span>
                                    <span className={styles.navLinkDescription}>{item.description}</span>
                                </NavLink>
                            ))}
                        </div>
                    ))}
                </nav>

                <div className={styles.sidebarFooter}>
                    <span className={styles.brandTag}>D06 · Pós-graduação Azure</span>
                    <span className={styles.brandVersion}>v2.1.0</span>
                </div>
            </aside>

            <div className={styles.main}>
                <header className={styles.topbar}>
                    <div className={styles.topbarTitle}>
                        <span className={styles.topbarKicker}>{location.pathname.startsWith("/tickets") ? "Operação" : "Operação"}</span>
                        <h1>{meta.title}</h1>
                        <span className={styles.topbarSubtitle}>{meta.subtitle}</span>
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
                    <LoginGate isLoggedIn={loggedIn}>
                        <ShellLayout />
                    </LoginGate>
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
