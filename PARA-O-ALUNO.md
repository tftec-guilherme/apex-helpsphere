# PARA-O-ALUNO — Apex HelpSphere (Disciplina 06)

> Template HelpSphere **pré-pronto**. Você forka, roda `azd up`, ganha 9-14 minutos de setup, e foca o tempo de lab no que importa: **pipeline RAG, agentes, automação**.
>
> Setup zero-friction v2.1.0: **0 passos manuais no Portal Azure** (App Registrations, admin consent e extension properties são automatizados via `scripts/auth_init.py`).

---

## 🎯 Cenário (30 segundos)

A **Apex Group** — holding varejo brasileira fictícia — tem o HelpSphere em produção: 12 mil tickets/mês, R$ 102k/mês em tempo de tier 1. A CTO aprovou o **Programa Apex IA** e seu trabalho na disciplina é **acoplar IA dentro do HelpSphere existente** — não reconstruir.

Este repo é o HelpSphere base. Você forka, deploya, e o turbina nos 3 labs da disciplina.

---

## ✅ Pré-requisitos (1 minuto)

- [ ] Conta Azure **Pay-As-You-Go** (Free Trial $200 USD **não funciona** — Azure OpenAI exige PAYG)
- [ ] **Azure CLI 2.x**, **`azd`**, **Git**, **Docker Desktop** instalados
- [ ] Conta GitHub (para fork)

**Custo esperado:** R$ 8-15 por sessão de 4-6h **se** você rodar `azd down --purge` no fim. Esquecer ligado 1 mês = R$ 80-120. **Não esqueça.**

---

## 🚀 Quick Start (6 passos)

### 0. Pre-flight check (~30 segundos)

```bash
# Windows PowerShell:
pwsh ./scripts/preflight.ps1

# macOS/Linux/WSL:
./scripts/preflight.sh
```

Valida ambiente local (PowerShell 7+, Long Path Win, Docker, `az login`, ODBC Driver 18, Python 3.13.x). Sai com erro acionável se algo faltar.

### 1. Fork + clone

1. Forke `tftec-guilherme/apex-helpsphere` na UI do GitHub para `SEU_USUARIO/apex-helpsphere`
2. Clone seu fork:

```bash
git clone https://github.com/SEU_USUARIO/apex-helpsphere.git
cd apex-helpsphere
```

> **Por que fork?** Você vai customizar nos 3 labs e precisa fazer `git push` no seu progresso.

### 2. Login Azure

```bash
az login
azd auth login
```

### 3. Criar environment azd

```bash
azd env new helpsphere-demo-{seu-id}
```

Use identificador único — vira sufixo dos recursos no Azure.

### 4. `azd up`

```bash
azd up
```

⏳ **9-14 minutos.** Faz 3 coisas:

1. **Provision** — Bicep cria App Service + 2 Container Apps (backend Python + tickets-service .NET) + SQL + Storage + App Insights
2. **Build** — empacota frontend Vite + 2 imagens Docker
3. **Deploy** — sobe artefatos + roda migrations + seeda 50 tickets pt-BR em 5 tenants

### 5. Abrir no navegador

URL pública aparece no final do `azd up`. O fluxo correto é:

1. **Login bloqueante** → `<LoginGate>` componente redireciona pra Microsoft Entra (`prompt: select_account`)
2. **Apex Executivo Dashboard** (`/`) → 4 KPI cards + 2 gráficos Recharts em tempo real
3. **Lista de tickets** (`/tickets`) → 50 tickets pt-BR distribuídos em 5 tenants (Apex Mart, Apex Tech, Apex Logistics, Apex Finance, Apex Brasil)
4. **Detalhe do ticket** (`/tickets/{id}`) → descrição + comments seedados

Se vir os 4, **funcionou**.

> **Apex Executivo design:** Fraunces (display) + Inter Tight (UI) + JetBrains Mono (code) · paleta off-white `#fafaf7` / navy `#0c1834` / accent gold `#a87b3f`. Identidade visual SaaS executivo brasileiro — não é o template MS original.

---

## 🧹 Cleanup (TODA sessão)

```bash
azd down --purge
```

⚠️ **`--purge` é obrigatório.** Sem ele, Cognitive Services + Key Vault ficam soft-deleted por 90 dias e bloqueiam o próximo `azd up`.

---

## 🗺️ Os 3 labs da disciplina

| Lab | Você adiciona | Companion público (Portal-first) |
|-----|---------------|----------------------------------|
| **Lab Intermediário** (M02-M05) | Pipeline RAG: Document Intelligence + AI Search + chat com citations | [`apex-rag-lab`](https://github.com/tftec-guilherme/apex-rag-lab) — 10 capítulos passo-a-passo |
| **Lab Final** (M06) | Agentes Foundry + canal de voz Speech STT/TTS + n8n | (companion futuro Q3-2026) |
| **Lab Avançado** (D06 IA em produção) | CI/CD + APIM Developer + Content Safety + Azure Policy + circuit breaker — production-grade canônico | guia no [`azure-retail`](https://github.com/tftec-guilherme/azure-retail) |

> **Chat dormente:** rota `/chat` está oculta na nav lateral em v2.1.0. Você habilita no Lab Intermediário via Bicep param `enableChat=true` (que vira env var `ENABLE_CHAT=true`).

---

## 📚 Quer ir mais fundo?

- **[`DECISION-LOG.md`](./DECISION-LOG.md)** — 23 decisões arquiteturais com defesa para audiência sênior
- **[`APPENDIX-SURPRESAS.md`](./APPENDIX-SURPRESAS.md)** — 29 surpresas pedagógicas que o template MS não documenta (gotchas + lições)
- **[`APPENDIX-CI.md`](./APPENDIX-CI.md)** — setup federated SP + Microsoft Graph permissions para CI/CD
- **Estado canônico:** tag git [`helpsphere-v2.1.0`](https://github.com/tftec-guilherme/apex-helpsphere/releases/tag/helpsphere-v2.1.0) — `git checkout helpsphere-v2.1.0` para começar de um ponto exato

---

## 🆘 Suporte

- **Dúvidas gerais:** fórum AVA da disciplina
- **Bugs no template:** [issues no repo](https://github.com/tftec-guilherme/apex-helpsphere/issues)

**Prof. Guilherme Campos** · Pós-Graduação Avançada de Cloud com Azure

---

> **Lembrete final:** `azd down --purge` ao final de cada sessão. **Sempre.**
