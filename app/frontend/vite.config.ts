import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// https://vitejs.dev/config/
export default defineConfig({
    plugins: [react()],
    resolve: {
        preserveSymlinks: true
    },
    build: {
        outDir: "../backend/static",
        emptyOutDir: true,
        sourcemap: true,
        rollupOptions: {
            output: {
                manualChunks: id => {
                    if (id.includes("@fluentui/react-icons")) {
                        return "fluentui-icons";
                    } else if (id.includes("@fluentui/react")) {
                        return "fluentui-react";
                    } else if (id.includes("node_modules")) {
                        return "vendor";
                    }
                }
            }
        },
        target: "esnext"
    },
    server: {
        proxy: {
            "/content/": "http://localhost:50505",
            "/auth_setup": "http://localhost:50505",
            "/.auth/me": "http://localhost:50505",
            "/chat": "http://localhost:50505",
            "/speech": "http://localhost:50505",
            "/config": "http://localhost:50505",
            "/upload": "http://localhost:50505",
            "/delete_uploaded": "http://localhost:50505",
            "/list_uploaded": "http://localhost:50505",
            "/chat_history": "http://localhost:50505",
            // Story 06.5c.6: backend Python continua servindo `/api/tenants/me` e
            // `/api/tickets/{id}/suggest` (stub 501). CRUD de tickets vai pro tickets-service .NET
            // via VITE_API_TICKETS_URL (vazio em dev = mesmo origin → vai para Python que retorna
            // 410 Gone, ideal para validar deprecation localmente). Para apontar pra um
            // tickets-service .NET local rodando em http://localhost:8080, defina
            // VITE_API_TICKETS_URL=http://localhost:8080 em `.env.development.local`.
            "/api/tenants": "http://localhost:50505",
            "/api/tickets": "http://localhost:50505"
        }
    }
});
