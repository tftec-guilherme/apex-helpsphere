import i18next from "i18next";
import LanguageDetector from "i18next-browser-languagedetector";
import HttpApi from "i18next-http-backend";
import { initReactI18next } from "react-i18next";

import enTranslation from "../locales/en/translation.json";
import ptBRTranslation from "../locales/ptBR/translation.json";

// HelpSphere Apex — Story 06.5c.9 (Sessão 9.2 · TD-3 cleanup):
// Locales reduzidos de 10 (template MS upstream: da, en, es, fr, it, ja, nl, pl, ptBR, tr)
// para 2 (en, ptBR). Justificativa: Apex Group é holding brasileira fictícia, audiência
// primária pt-BR + secundária en (auditoria internacional). Os 8 locales removidos
// estavam 58 chaves desatualizados desde a Sessão 3 (HelpSphere-specific keys de
// tickets/comments/status adicionadas em en+ptBR sem propagar). Lingual i18n-check
// quebrava o `Python check` workflow em todas as 24 jobs do matrix.
export const supportedLngs: { [key: string]: { name: string; locale: string } } = {
    en: {
        name: "English",
        locale: "en-US"
    },
    ptBR: {
        name: "Português Brasileiro",
        locale: "pt-BR"
    }
};

i18next
    .use(HttpApi)
    .use(LanguageDetector)
    .use(initReactI18next)
    // init i18next
    // for all options read: https://www.i18next.com/overview/configuration-options
    .init({
        resources: {
            en: { translation: enTranslation },
            ptBR: { translation: ptBRTranslation }
        },
        fallbackLng: "en",
        supportedLngs: Object.keys(supportedLngs),
        debug: import.meta.env.DEV,
        interpolation: {
            escapeValue: false // not needed for react as it escapes by default
        }
    });

export default i18next;
