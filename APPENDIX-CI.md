# APPENDIX — Detalhes do CI/CD (federated SP + Microsoft Graph)

> Este apêndice complementa o **Caminho A** do [`PARA-O-ALUNO.md`](./PARA-O-ALUNO.md) com detalhes técnicos do federated Service Principal e das permissões Microsoft Graph. Você só precisa ler isto se algo no passo 3 do Quick Start falhou OU se quer entender o "porquê" das decisões.

---

## Por que federated OIDC e não secret estático?

Federated OIDC = sem `client_secret` armazenado no GitHub. O token Azure é trocado em runtime quando o workflow roda, usando o JWT do GitHub Actions como prova de identidade. Vantagens:

- ✅ Sem secret pra rotacionar (ou vazar em logs)
- ✅ Trust escopado por repo + branch (não tenant-wide)
- ✅ Auditoria limpa: cada `azd up` tem trace OIDC no AAD logs

---

## As 5 GitHub Variables explicadas

| Variable | O que é | Onde pegar |
|----------|---------|-----------|
| `AZURE_CLIENT_ID` | App ID do federated SP | `az ad app list --display-name sp-apex-helpsphere-{user}` |
| `AZURE_TENANT_ID` | Tenant Azure | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | Subscription onde recursos vão | `az account show --query id -o tsv` |
| `AZURE_ENV_NAME` | Nome do `azd env` (vira sufixo dos recursos) | escolha você (ex: `helpsphere-actions`) |
| `AZURE_LOCATION` | Região Azure | `westus3` (validado no template) |

> **Por que `vars` e não `secrets`?** Estes 5 valores são **identificadores**, não senhas. Federated OIDC dispensa segredo estático — o token AAD é trocado em runtime. GitHub Variables aparecem em logs (não em mascaramento) e isso está OK porque não há informação sensível.

---

## Federated credential — o que o `--parameters @/tmp/fed.json` faz

```json
{
  "name": "github-{user}-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:{user}/apex-helpsphere:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}
```

Cria um **trust** no Azure AD:

- **Issuer:** `token.actions.githubusercontent.com` — só aceita tokens emitidos pelo GitHub Actions OIDC service
- **Subject:** `repo:{user}/apex-helpsphere:ref:refs/heads/main` — só aceita workflows rodando NO seu fork, NA branch main
- **Audience:** `api://AzureADTokenExchange` — público fixo do Azure AD para token exchange

Resultado: GitHub Actions consegue obter um token Azure, mas só rodando no SEU fork na branch main. Tentativa de PR-fork malicioso ou outro repo é rejeitada pelo AAD.

### Adicionar trust pra outros branches

Se você quer o CI rodar em PRs também:

```bash
APP_OBJECT_ID=$(az ad app show --id $AZURE_CLIENT_ID --query id -o tsv)

cat > /tmp/fed-pr.json <<EOF
{
  "name": "github-${GITHUB_USER}-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_USER}/apex-helpsphere:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF

az ad app federated-credential create --id "$APP_OBJECT_ID" --parameters @/tmp/fed-pr.json
```

---

## Microsoft Graph `Application.ReadWrite.All`

O preprovision hook do `azd provision` chama `scripts/auth_init.py` que **cria 2 App Registrations** no AAD (Server App + Client App). Pra isso, o federated SP precisa de:

- **API permission Microsoft Graph `Application.ReadWrite.All`** (Application type, NÃO Delegated)
- **Admin consent** dessa permission

A permission ID `1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9` é o GUID dessa role. O passo 3 do Quick Start já roda esses 2 comandos:

```bash
az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9=Role
az ad app permission admin-consent --id "$APP_ID"
```

---

## Workflows disponíveis

| Workflow | Trigger | Função |
|----------|---------|--------|
| **5. Deploy (Azure Container Apps)** | push em main + workflow_dispatch | Provision + Build + Deploy |
| **Setup Azure AD (manual)** | workflow_dispatch | Recria App Registrations sem reprovisionar (caso tenha deletado) |
| **1. Validate Bicep** | PR + push (infra/) | Bicep build + lint |
| **2. Lint Frontend** | PR + push (app/frontend/) | ESLint + Prettier check |
| **3. Test Backend** | PR + push (app/backend/) | Pytest + ruff + ty + black + Playwright |
| **4. Test Tickets** | PR + push (tickets-service/) | xUnit + dotnet build + dotnet format |

> Numeração **1-5** foi cravada na Sessão 9.6 (cleanup final) pra forçar ordem visível na aba Actions do GitHub.

---

## Troubleshooting CI

### `AADSTS70021: No matching federated identity record found`

Sintoma: workflow falha no passo `azure/login@v2`.

Causa: o `subject` da federated credential não bate com o que o GitHub está mandando.

Fix: confira que o `subject` no JSON é exatamente `repo:{user}/apex-helpsphere:ref:refs/heads/main`. Se você renomeou seu fork ou está em outra branch, atualize.

### `Insufficient privileges to complete the operation`

Sintoma: `auth_init.py` no preprovision aborta com 403.

Causa: faltou rodar o `permission admin-consent`.

Fix:
```bash
az ad app permission admin-consent --id "$AZURE_CLIENT_ID"
```

### `The subscription 'XXX' could not be found`

Sintoma: `azd provision` falha logo no início.

Causa: `AZURE_SUBSCRIPTION_ID` não está visível pro federated SP.

Fix: confirme que você atribuiu role `Owner` na subscription:
```bash
az role assignment create --assignee "$AZURE_CLIENT_ID" --role "Owner" --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID"
```

### Workflow `5. Deploy` não aparece na lista

Causa: Actions ainda não habilitado no fork.

Fix: aba **Actions** → botão **"I understand my workflows, go ahead and enable them"**.

---

## Por que NÃO usar `azd pipeline config`

`azd pipeline config` é um comando que automatiza tudo isto — mas tem 2 problemas para uso pedagógico:

1. **Cria SP genérico** sem nome customizado por aluno (todos viram `azd-pipeline-...`)
2. **Faz commit automático** no seu repo, adicionando workflow files que duplicam os do template

O passo 3 do Quick Start é **explícito e didático** — você vê cada permissão sendo concedida. Em produção, `azd pipeline config` é OK; pra disciplina, queremos transparência.

---

## Referências

- [Federated identity para GitHub Actions](https://learn.microsoft.com/azure/active-directory/develop/workload-identity-federation)
- [Microsoft Graph permissions reference](https://learn.microsoft.com/graph/permissions-reference)
- [GitHub OIDC tokens](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
