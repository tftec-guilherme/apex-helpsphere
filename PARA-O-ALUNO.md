# PARA-O-ALUNO — Disciplina 06 / Apex HelpSphere

> Bem-vindo. Este é o **entrypoint** do template HelpSphere que você vai turbinar com IA ao longo dos 3 Labs da Disciplina 06. Leia este arquivo na primeira passada — **não precisa ler tudo do README ou do DECISION-LOG agora.**

---

## 🎯 Cenário em 3 linhas

A **Apex Group** (holding varejo brasileira fictícia) já tem um sistema de tickets em produção: o **HelpSphere**. 12 mil tickets/mês, R$ 102 mil/mês em tempo de tier 1. A Carla (CTO) aprovou o **Programa Apex IA** e seu trabalho na disciplina é: **acoplar IA dentro do HelpSphere existente**, não reconstruir nada.

Esse repo é o **HelpSphere pré-pronto** — você roda `azd up`, ganha 9-14 minutos, e foca o tempo de lab no que importa: pipeline RAG, agentes, automação.

---

## ✅ Pré-requisitos (checklist 1 minuto)

- [ ] Conta Azure **Pay-As-You-Go** (Free Trial USD 200 NÃO funciona — Azure OpenAI exige PAYG)
- [ ] Quota Azure OpenAI já aprovada via `aka.ms/oai/access` (1-3 dias úteis — só necessário a partir do Lab Intermediário)
- [ ] Cartão de crédito internacional vinculado à subscription
- [ ] **Azure CLI 2.x**, **Azure Developer CLI (`azd`)**, **Git**, **Docker Desktop** instalados
- [ ] Conta GitHub (para forkar este repo)

Custo esperado por sessão: **R$ 8-15** se você usar 4-6h e rodar `azd down --purge` no final.
Custo se esquecer ligado 1 mês: **R$ 80-120**. Não esqueça.

---

## 🚀 Quick Start (5 passos)

### 1. Fork + clone do **seu** fork

Forque este repositório na UI do GitHub: `tftec-guilherme/apex-helpsphere` → `SEU_USUARIO/apex-helpsphere`.

> **Por que fork primeiro?** Você vai customizar ao longo dos 3 labs (RAG, agentes, automação). Sem fork, você não tem permissão de `git push` no seu progresso.

```bash
git clone https://github.com/SEU_USUARIO/apex-helpsphere.git
cd apex-helpsphere
```

### 2. Login Azure

```bash
az login
azd auth login
```

### 3. Criar environment azd

```bash
azd env new helpsphere-demo-{seu-id}
```

Use um identificador único (ex: `helpsphere-demo-joao2026`). Esse nome vira sufixo dos recursos no Azure.

### 4. `azd up`

```bash
azd up
```

Espera ~9-14 minutos. O comando faz 3 coisas:

1. **Provision** — Bicep cria App Service + 2 Container Apps (Python backend + .NET tickets-service) + SQL + Storage + App Insights
2. **Build** — empacota frontend Vite + 2 imagens Docker
3. **Deploy** — sobe artefatos + roda migrations + seed (50 tickets pt-BR populados)

No final, o `azd up` imprime a URL pública. Acesse, faça login com sua conta Entra, e veja a fila de tickets.

### 5. Verificar que funcionou

```bash
# Pegue o tickets-service URL
TICKETS_URL=$(azd env get-value TICKETS_BACKEND_URI)

# Liste os tickets (vai pedir token Entra — copie do DevTools do browser depois de logar no frontend)
curl -H "Authorization: Bearer $TOKEN" "$TICKETS_URL/api/tickets"
```

Você deve ver JSON com 50 tickets pt-BR. Se vir, **tudo funciona**.

---

## 🧹 Cleanup (toda sessão)

```bash
azd down --purge
```

`--purge` é importante — sem ele, recursos soft-deleted (Cognitive Services, Key Vault) ficam ocupando o nome por 90 dias e bloqueiam o próximo `azd up`.

---

## 🗺️ Próximos passos na disciplina

| Lab | O que você adiciona | Repo destino |
|-----|---------------------|--------------|
| **Lab Intermediário** (M02-M05) | Pipeline RAG: AI Search + embeddings + chat com citation rendering sobre os 62 PDFs Apex | seu fork (branch `lab-intermediario`) |
| **Lab Final** (M06) | Agentes Foundry com tools + canal de voz (Speech STT/TTS) + integração com tickets | seu fork (branch `lab-final`) |
| **Lab Avançado** (D04 sinergia) | Tickets-service publica `TicketStatusChanged` no Service Bus, Logic App reage | repo separado: `lab-avancado-dashboard` |

---

## 💡 Surpresas pedagógicas que você vai encontrar (e que o template MS NÃO documenta)

Se algo der errado, antes de perguntar no fórum, dê uma olhada nestas lições aprendidas (todas com defesa arquitetural completa em [`DECISION-LOG.md`](./DECISION-LOG.md)):

| # | Surpresa | Lição |
|---|----------|-------|
| **#1** | Free Trial USD 200 não roda Azure OpenAI | PAYG é mandatório. Não tente Free Trial — vai bloquear na quota. |
| **#2** | `eastus2` sem capacidade SQL/Search em Q2-2026 | Use **`westus3`** ou **`brazilsouth`** para HelpSphere. East US 2 só pra Foundry Hub depois. |
| **#3** | `pyodbc` 5.1.0 não compila em CPython 3.13 | Stack Python+ODBC+SQL+MI é frágil. **A Decisão #16 deste repo migrou tickets para .NET** justamente por isso. |
| **#4** | `azd hooks` (preprovision/postprovision) **NÃO leem env vars do shell** | Eles leem só do `.azure/<env>/.env`. Use `azd env set` antes de provision para garantir hooks veem o que precisam. |
| **#5** | Smoke test 30s pega container em state `Activating` | Cold start de gunicorn + token MI pode levar 1-3min. Use retry loop, não single-shot. |
| **#6** | "Backend MI tem acesso ao banco" ≠ least privilege real | Least privilege real é **9 grants object-level scoped a tabelas específicas**, verificável via `sys.database_permissions`. Decisão #16. |
| **#7** | Endpoints deprecated devem retornar **HTTP 410 Gone** + `Link: rel="successor-version"` (RFC 8288) | É o padrão profissional. Não use 404 (silencioso) nem 301 (mantém keep-alive). |
| **#8** | `git ls-files` ignora arquivos do `.gitignore` raiz mesmo em monorepos | Auditar `git ls-files --others --ignored --exclude-standard` antes de extração de monorepo. |
| **#9** | Cognitive Services soft-deleted bloqueiam re-provisão por 90 dias | Use `RESTORE_COGNITIVE_SERVICES=true` no workflow OU sempre `azd down --purge`. |
| **#10** | Bicep AVM modules têm breaking changes não documentados | `bicep build` antes de PR (CodeRabbit não roda). Decisão #9. |

---

## 🆘 Suporte

- **Dúvidas gerais:** fórum da disciplina no AVA Anhanguera
- **Bugs no template:** abra issue no `tftec-guilherme/apex-helpsphere`
- **Defesa arquitetural** (audiência sênior): leia `DECISION-LOG.md` — 16 decisões cravadas com contexto, alternativas avaliadas e anti-padrões rejeitados

**Prof. Guilherme Campos** — guilherme.campos@tftec.com.br
TFTEC Treinamentos · Pós-Graduação em Arquitetura Cloud Azure

---

> **Lembrete final:** `azd down --purge` ao final de cada sessão. Sempre.
