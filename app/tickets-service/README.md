# tickets-service — HelpSphere v2 Hybrid Microservice (.NET 10)

> Story 06.5c.1 — skeleton .NET para Epic [06.5c HelpSphere v2 Hybrid Microservices](../../../azure-retail/docs/stories/epics/epic-06.5c-helpsphere-hybrid-microservices/epic.md).

## Stack

| Camada | Tecnologia | Versão |
|---|---|---|
| Runtime | **.NET LTS** | 10.0 |
| API | **ASP.NET Core Minimal API** | 10.0 |
| ORM | **Dapper** | 2.x (micro-ORM SQL-first) |
| SQL client | **Microsoft.Data.SqlClient** | 6.x (`Authentication=ActiveDirectoryManagedIdentity` nativo) |
| Auth | **Microsoft.Identity.Web** | 3.x (JWT validation enterprise) |
| Tests | **xUnit** + **WebApplicationFactory** | 2.9 / 10.x |
| Container | **Docker multi-stage** com `aspnet:10.0-alpine` | image alvo < 250MB |

## Defesa arquitetural (resumo)

Este microserviço resolve as **8 camadas de fragilidade pyodbc/aioodbc/MI** que travaram a Sessão 5 do HelpSphere v1 monolito Python (18 runs do `azure-dev.yml` sem fechar). `Microsoft.Data.SqlClient` é nativo MS, in-process, com token cache/refresh transparente — elimina compile de driver, instalação de ODBC no runner, e timeouts HYT00.

**Decisão #16 do `apex-helpsphere/DECISION-LOG.md`** documenta a defesa completa.

## Pré-requisitos local

| Item | Como instalar |
|---|---|
| .NET 10 SDK | https://dotnet.microsoft.com/download — verifica com `dotnet --version` |
| Docker Desktop (opcional, só pra build de container) | https://www.docker.com/products/docker-desktop |
| Azure CLI logado (`az login`) | Necessário para `Authentication=ActiveDirectoryDefault` em DEV |

## Como rodar local

```bash
cd app/tickets-service
az login                                              # Autentica como user (DEV usa ActiveDirectoryDefault)
export AZURE_SQL_SERVER="sql-yyowe3poxq7oc.database.windows.net"
export AZURE_SQL_DATABASE="helpsphere"
dotnet run --project src/TicketsService.Api
```

Acesse:
- `GET http://localhost:5000/health` → `{"status":"healthy","version":"1.0.0"}` (sem auth)
- `GET http://localhost:5000/internal/sql-ping` → 401 sem token JWT

## Como rodar testes

```bash
cd app/tickets-service
dotnet test --configuration Release
```

10 testes esperados (todos passing).

## Como buildar Docker

```bash
cd app/tickets-service
docker build -t tickets-service:dev .
docker run -p 8080:8080 -e ASPNETCORE_ENVIRONMENT=Development tickets-service:dev
curl http://localhost:8080/health
```

> **Story 06.5c.1:** AC-6 (build Docker local) deferida para validação no CI da Story 06.5c.5 (Dockerfile criado mas não buildado por ausência de Docker Desktop no workstation atual).

## Variáveis de ambiente esperadas

| Variável | Obrigatório | Origem |
|---|---|---|
| `AZURE_SQL_SERVER` | sim | Bicep output (Story 06.5c.3) |
| `AZURE_SQL_DATABASE` | sim | Bicep output (default `helpsphere`) |
| `AZURE_CLIENT_ID` | só prod | UMI tickets-identity clientId (Story 06.5c.3) |
| `AzureAd__TenantId` | sim | Entra ID tenant |
| `AzureAd__ClientId` | sim | App Registration client ID (audience JWT) |
| `AzureAd__Audience` | sim | `api://{ClientId}` matching frontend MSAL scope |
| `ASPNETCORE_ENVIRONMENT` | sim | `Production` em ACA, `Development` local |

## Troubleshooting

### 1. SQL HYT00 timeout
Não acontece com `Microsoft.Data.SqlClient` — esse era problema do v1 com pyodbc/aioodbc. Se acontecer, verifique firewall do SQL Server (`AllowAllAzureServices` rule) e se o backend MI é SQL user com grants (Story 06.5c.4).

### 2. SQL `Login failed for user '<token-identified principal>'` (18456)
UMI não é SQL user — verifique se `sql_init.sh` (Story 06.5c.4) executou e criou `CREATE USER FROM EXTERNAL PROVIDER` para o tickets MI.

### 3. JWT `401 Unauthorized` em endpoints autenticados
Audience mismatch entre frontend MSAL scope e `AzureAd:Audience` no appsettings. Verifique se o `aud` claim do JWT bate exatamente.

### 4. `dotnet build` falha com CA1848 ou similar
`TreatWarningsAsErrors=true` em `Directory.Build.props` torna analyzer warnings em erros (production-grade). Refactor o código (ex: usar `[LoggerMessage]` para CA1848) — não suprima a regra em source code.

### 5. Docker port conflict (8080 já em uso)
Use `-p 8081:8080` em vez de `-p 8080:8080` ou pare o container conflitante (`docker ps` + `docker stop <id>`).

## Referência cruzada

- **Decisão #16** completa: `apex-helpsphere/DECISION-LOG.md`
- **Epic parent:** `azure-retail/docs/stories/epics/epic-06.5c-helpsphere-hybrid-microservices/epic.md`
- **Story file:** `azure-retail/docs/stories/06.5c.1.dotnet-tickets-service-skeleton.md`
- **Próximas stories:** 06.5c.2 (5 endpoints), 06.5c.3 (Bicep + ACA), 06.5c.4 (sql_init), 06.5c.5 (workflow CI), 06.5c.6 (frontend), 06.5c.7 (deprecate Python tickets), 06.5c.8 (E2E smoke), 06.5c.9 (DECISION-LOG final + README v2)
