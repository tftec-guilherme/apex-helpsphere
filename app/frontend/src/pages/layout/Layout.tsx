import { Outlet, Link, NavLink } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { Helmet } from "react-helmet-async";
import styles from "./Layout.module.css";

import { useLogin } from "../../authConfig";
import { LoginButton } from "../../components/LoginButton";
import { HelpSphereLogo } from "../../components/HelpSphereLogo";

const Layout = () => {
    const { t } = useTranslation();

    const navLinkClass = ({ isActive }: { isActive: boolean }) => (isActive ? `${styles.navLink} ${styles.navLinkActive}` : styles.navLink);

    return (
        <div className={styles.layout}>
            <Helmet>
                <title>{t("pageTitle")}</title>
            </Helmet>
            <header className={styles.header} role="banner">
                <div className={styles.headerContainer}>
                    <Link to="/" className={styles.headerTitleContainer} aria-label={t("helpsphere.appName")}>
                        <HelpSphereLogo size={32} className={styles.headerLogo} />
                        <div className={styles.headerBrandText}>
                            <h3 className={styles.headerTitle}>{t("helpsphere.appName")}</h3>
                            <span className={styles.headerTagline}>{t("helpsphere.tagline")}</span>
                        </div>
                    </Link>
                    <nav className={styles.headerNav} aria-label="Primary">
                        <NavLink to="/" end className={navLinkClass}>
                            {t("helpsphere.nav.home")}
                        </NavLink>
                        <NavLink to="/tickets" className={navLinkClass}>
                            {t("helpsphere.nav.tickets")}
                        </NavLink>
                    </nav>
                    <div className={styles.loginMenuContainer}>{useLogin && <LoginButton />}</div>
                </div>
            </header>

            <main className={styles.main} id="main-content">
                <Outlet />
            </main>
        </div>
    );
};

export default Layout;
