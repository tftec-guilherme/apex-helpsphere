import { Button } from "@fluentui/react-components";
import { useMsal } from "@azure/msal-react";
import { useTranslation } from "react-i18next";

import styles from "./LoginButton.module.css";
import { getRedirectUri, loginRequest, appServicesLogout, getUsername, checkLoggedIn } from "../../authConfig";
import { useState, useEffect, useContext } from "react";
import { LoginContext } from "../../loginContext";

export const LoginButton = () => {
    const { instance } = useMsal();
    const { loggedIn, setLoggedIn } = useContext(LoginContext);
    const activeAccount = instance.getActiveAccount();
    const [username, setUsername] = useState("");
    const { t } = useTranslation();

    useEffect(() => {
        const fetchUsername = async () => {
            setUsername((await getUsername(instance)) ?? "");
        };

        fetchUsername();
    }, []);

    const handleLoginPopup = () => {
        /**
         * When using popup and silent APIs, we recommend setting the redirectUri to a blank page or a page
         * that does not implement MSAL. Keep in mind that all redirect routes must be registered with the application
         * For more information, please follow this link: https://github.com/AzureAD/microsoft-authentication-library-for-js/blob/dev/lib/msal-browser/docs/login-user.md#redirecturi-considerations
         */
        instance
            .loginPopup({
                ...loginRequest,
                redirectUri: getRedirectUri()
            })
            .catch(error => {
                // Diagnóstico: banner DOM selecionável (alert nativo não permite copy).
                // eslint-disable-next-line no-console
                console.error("[MSAL loginPopup] error:", error);
                const code = error?.errorCode || error?.name || "unknown";
                const msg = error?.errorMessage || error?.message || String(error);
                const stack = error?.stack || "";
                const fullText = `[${code}]\n${msg}\n\n${stack}`;

                // Remove banner anterior se existir
                const existing = document.getElementById("msal-error-banner");
                if (existing) existing.remove();

                const banner = document.createElement("div");
                banner.id = "msal-error-banner";
                banner.style.cssText =
                    "position:fixed;top:0;left:0;right:0;background:#fee2e2;border-bottom:3px solid #dc2626;padding:16px 24px;z-index:99999;font-family:Consolas,monospace;font-size:13px;color:#7f1d1d;max-height:60vh;overflow:auto;box-shadow:0 4px 12px rgba(0,0,0,0.15);user-select:text;";
                const closeBtn =
                    '<button onclick="document.getElementById(\'msal-error-banner\').remove()" style="float:right;cursor:pointer;background:#dc2626;color:white;border:none;padding:4px 12px;border-radius:4px;">Fechar</button>';
                const pre = document.createElement("pre");
                pre.style.cssText = "white-space:pre-wrap;margin:8px 0 0 0;user-select:text;";
                pre.textContent = fullText;
                banner.innerHTML = `<strong>LOGIN ERROR — selecione o texto abaixo e copie (Ctrl+C):</strong> ${closeBtn}`;
                banner.appendChild(pre);
                document.body.appendChild(banner);
            })
            .then(async () => {
                setLoggedIn(await checkLoggedIn(instance));
                setUsername((await getUsername(instance)) ?? "");
            });
    };
    const handleLogoutPopup = () => {
        if (activeAccount) {
            instance
                .logoutPopup({
                    mainWindowRedirectUri: "/", // redirects the top level app after logout
                    account: instance.getActiveAccount()
                })
                .catch(error => console.log(error))
                .then(async () => {
                    setLoggedIn(await checkLoggedIn(instance));
                    setUsername((await getUsername(instance)) ?? "");
                });
        } else {
            appServicesLogout();
        }
    };
    return (
        <Button className={styles.loginButton} onClick={loggedIn ? handleLogoutPopup : handleLoginPopup}>
            {loggedIn ? `${t("logout")}\n${username}` : `${t("login")}`}
        </Button>
    );
};
