# APPENDIX — Setup CI/CD (GitHub Actions)

> Setup avançado pra quem quer rodar `azd provision` automaticamente em GitHub Actions. **Não é necessário em primeira execução do template** — você pode pular este apêndice e voltar quando precisar de pipeline automatizado.

---

## Permissão Microsoft Graph para `auth_init.py` em CI

O workflow `.github/workflows/setup-aad.yml` (e o `azure-dev.yml` que chama `azd provision` → preprovision hook → `auth_init.py`) cria App Registrations no AAD via Microsoft Graph API. Pra isso funcionar em CI, o **federated SP** que GitHub Actions usa precisa de:

- **API permission Microsoft Graph `Application.ReadWrite.All`** (Application type, **NÃO** Delegated)
- **Admin consent** dessa permission

---

## Configuração (1 vez, depois de `azd pipeline config`)

```bash
# Pegue o SP_APP_ID do federated SP (printado por azd pipeline config)
SP_APP_ID="<from-azd-pipeline-config>"

# Adiciona permission
az ad app permission add --id $SP_APP_ID \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9=Role

# Admin consent
az ad app permission admin-consent --id $SP_APP_ID
```

---

## Sintomas de configuração ausente

Sem essa permission, CI falha com:

```
ERROR: Insufficient privileges to complete the operation
```

durante a etapa de `auth_init.py` no preprovision hook do `azd provision`.

---

## Workflows disponíveis no template

| Workflow | Trigger | Função |
|---|---|---|
| `1-validate-bicep.yml` | PR + push em main | Lint + build de todos os Bicep modules |
| `2-lint-frontend.yml` | PR + push (frontend/) | ESLint + Prettier check |
| `3-test-backend.yml` | PR + push (app/backend/) | Pytest + ruff + ty + black + Playwright E2E |
| `4-test-tickets.yml` | PR + push (tickets-service/) | xUnit + dotnet build + dotnet format |
| `5-deploy.yml` | push em main | `azd provision` + `azd deploy` |

Numeração 1-5 foi cravada na Sessão 9.6 (cleanup final) pra forçar ordem visível na aba Actions do GitHub.

---

## Federated SP e OIDC

`azd pipeline config` configura federated identity (sem secret estático). O SP recebe trust em:

- `repo:tftec-guilherme/apex-helpsphere:ref:refs/heads/main`
- `repo:tftec-guilherme/apex-helpsphere:pull_request`
- `repo:tftec-guilherme/apex-helpsphere:environment:helpsphere-actions`

Trust subjects podem ser ajustados em **Azure Portal** → App Registration do SP → **Certificates & secrets** → **Federated credentials**.

---

## Roles necessárias no SP

Para o pipeline rodar `azd provision` end-to-end:

| Role | Scope | Por quê |
|---|---|---|
| `Owner` | Subscription OU Resource Group | Criar resources + role assignments |
| `Application.ReadWrite.All` | Microsoft Graph (tenant) | `auth_init.py` cria App Registrations |

> Em prod com tenant restritivo, considere split: SP de provisionamento com `Contributor` no RG + SP separado pra Microsoft Graph (rotina cross-tenant).

---

## Debugging CI com `act` localmente

Para reproduzir o pipeline antes de pushar:

```bash
# Instalar act (Docker required)
# macOS: brew install act
# Linux: curl https://raw.githubusercontent.com/nektos/act/master/install.sh | bash

# Rodar workflow localmente (simula GitHub Actions runner)
act -W .github/workflows/3-test-backend.yml -j test
```

> `act` não suporta federated OIDC — para testar `5-deploy.yml`, use branch de teste no remoto.

---

## Referências

- [Federated identity para GitHub Actions](https://learn.microsoft.com/azure/active-directory/develop/workload-identity-federation)
- [`azd pipeline config`](https://learn.microsoft.com/azure/developer/azure-developer-cli/reference#azd-pipeline-config)
- [Microsoft Graph permissions](https://learn.microsoft.com/graph/permissions-reference)
