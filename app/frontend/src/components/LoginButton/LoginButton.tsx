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

    const handleLoginRedirect = () => {
        // loginRedirect (vs popup): navega janela inteira para AAD, robusto contra popup blockers.
        // prompt:select_account força AAD a sempre mostrar seletor — UX claro quando user
        // quer alternar conta vs cached SSO.
        instance
            .loginRedirect({
                ...loginRequest,
                redirectUri: getRedirectUri(),
                prompt: "select_account"
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error("[MSAL loginRedirect] error:", error);
            });
    };

    const handleLogoutRedirect = () => {
        if (activeAccount) {
            // logoutRedirect + clear cache: garante que MSAL nao mantem refresh tokens
            // entre sessoes, evitando comportamento confuso ao trocar de conta.
            instance
                .logoutRedirect({
                    account: activeAccount,
                    postLogoutRedirectUri: "/"
                })
                .catch(error => {
                    // eslint-disable-next-line no-console
                    console.error("[MSAL logoutRedirect] error:", error);
                });
        } else {
            appServicesLogout();
        }
    };

    return (
        <Button className={styles.loginButton} onClick={loggedIn ? handleLogoutRedirect : handleLoginRedirect}>
            {loggedIn ? `${t("logout")}\n${username}` : `${t("login")}`}
        </Button>
    );
};
