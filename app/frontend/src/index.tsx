import React from "react";
import ReactDOM from "react-dom/client";
import { createHashRouter, RouterProvider } from "react-router-dom";
import { I18nextProvider } from "react-i18next";
import { HelmetProvider } from "react-helmet-async";
import { MsalProvider } from "@azure/msal-react";
import { AuthenticationResult, EventType, PublicClientApplication } from "@azure/msal-browser";

// Fontes editoriais (Apex Executivo) — carregadas globalmente via @fontsource.
// theme/tokens.css faz referência a 'Fraunces', 'Inter Tight' e 'JetBrains Mono'.
import "@fontsource/fraunces/400.css";
import "@fontsource/fraunces/600.css";
import "@fontsource-variable/inter-tight";
import "@fontsource/jetbrains-mono/400.css";

import "./index.css";

import Chat from "./pages/chat/Chat";
import { Shell } from "./Shell";
import i18next from "./i18n/config";
import { msalConfig, useLogin } from "./authConfig";

const router = createHashRouter([
    {
        path: "/",
        element: <Shell />,
        children: [
            {
                index: true,
                lazy: () => import("./pages/dashboard/Dashboard")
            },
            {
                path: "tickets",
                lazy: () => import("./pages/tickets/Tickets")
            },
            {
                path: "tickets/:ticketId",
                lazy: () => import("./pages/tickets/TicketDetail")
            },
            {
                // Chat usa default export — mantemos eager para preservar pattern atual.
                // Lab Intermediário ativa o link na sidebar via authSetup.enableChat.
                path: "chat",
                element: <Chat />
            },
            {
                path: "*",
                lazy: () => import("./pages/NoPage")
            }
        ]
    }
]);

const root = ReactDOM.createRoot(document.getElementById("root") as HTMLElement);

// Bootstrap the app once; conditionally wrap with MsalProvider when login is enabled
(async () => {
    let msalInstance: PublicClientApplication | undefined;

    if (useLogin) {
        msalInstance = new PublicClientApplication(msalConfig);
        try {
            await msalInstance.initialize();

            // CRITICAL: handleRedirectPromise must run on every page load before any
            // other MSAL call. Quando o user volta do AAD apos loginRedirect, este
            // metodo processa o hash da URL (#code=...) e completa o login fluxo.
            // Sem isso, loginRedirect quebra silenciosamente.
            try {
                const redirectResult = await msalInstance.handleRedirectPromise();
                if (redirectResult?.account) {
                    msalInstance.setActiveAccount(redirectResult.account);
                    // Apos consumir o hash MSAL, redireciona para root.
                    // pathname=/redirect (servido pelo backend) precisa virar / (hashRouter).
                    if (window.location.pathname === "/redirect") {
                        window.location.replace("/");
                    }
                }
            } catch (redirectErr) {
                // eslint-disable-next-line no-console
                console.error("MSAL handleRedirectPromise failed", redirectErr);
            }

            // Default active account to the first one if none is set
            if (!msalInstance.getActiveAccount() && msalInstance.getAllAccounts().length > 0) {
                msalInstance.setActiveAccount(msalInstance.getAllAccounts()[0]);
            }

            // Keep active account in sync on login success
            msalInstance.addEventCallback(event => {
                if (event.eventType === EventType.LOGIN_SUCCESS && event.payload) {
                    const result = event.payload as AuthenticationResult;
                    if (result.account) {
                        msalInstance!.setActiveAccount(result.account);
                    }
                }
            });
        } catch (e) {
            // Non-fatal: render the app even if MSAL initialization fails
            // eslint-disable-next-line no-console
            console.error("MSAL initialize failed", e);
            msalInstance = undefined;
        }
    }

    const appTree = (
        <React.StrictMode>
            <I18nextProvider i18n={i18next}>
                <HelmetProvider>
                    {useLogin && msalInstance ? (
                        <MsalProvider instance={msalInstance}>
                            <RouterProvider router={router} />
                        </MsalProvider>
                    ) : (
                        <RouterProvider router={router} />
                    )}
                </HelmetProvider>
            </I18nextProvider>
        </React.StrictMode>
    );

    root.render(appTree);
})();
