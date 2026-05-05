"""HelpSphere — Geração do diagrama Draw.io profissional via Azure-DrawIO-MCP lib.

Usa `lilepeeps/Azure-DrawIO-MCP` (https://github.com/lilepeeps/Azure-DrawIO-MCP)
diretamente como Python lib (não como MCP server), gerando um .drawio editável
com ícones oficiais Azure2 da biblioteca draw.io.

Vantagens vs `mingrammer/diagrams`:
- Output editável (.drawio XML versionável + abre no draw.io GUI)
- Ícones Azure2 SVG (3D MS oficiais, não flat)
- Auto-layout configurável + override de posição manual
- Export PNG/SVG/PDF via draw.io desktop ou drawio CLI

Geração:
    # Pré-requisitos (já instalados):
    pip install --user uv
    python -m uv tool install --from git+https://github.com/lilepeeps/Azure-DrawIO-MCP.git azure-drawio-mcp

    # Execução:
    cd <repo-root>
    python docs/architecture-drawio.py
    # → produz docs/architecture.drawio

    # Refinamento visual (opcional):
    # Abrir docs/architecture.drawio no draw.io desktop ou web (drawio.com)
    # Ajustar posições, alinhamentos, cores manualmente.

    # Export PNG (manual via draw.io File → Export As → PNG)
    # Ou via drawio CLI: drawio --export --format png --output architecture.png architecture.drawio

Decisões refletidas (vide DECISION-LOG.md):
- #5  Container Apps + JWT tenant + auth obrigatório
- #16 Hybrid Microservices Python (RAG) + .NET (Tickets CRUD)
- #17 Token AAD explícito (workaround ODBC Driver 18 + UMI Linux)
- #18 SQL Serverless autoPauseDelay = -1 (confiabilidade > FinOps)
"""

import asyncio
import sys
from pathlib import Path

# Tornar o pacote azure_drawio_mcp_server importável sem MCP server rodando
_REPO = Path("C:/Users/GuilhermePruxCampos/AppData/Local/Temp/azure-drawio-mcp")
if _REPO.exists():
    sys.path.insert(0, str(_REPO))

# Imports DEPOIS do sys.path.insert acima — E402 esperado neste padrao de
# loading dynamic install path do uv tool.
from azure_drawio_mcp_server.drawio_generator import (  # noqa: E402
    generate_drawio_diagram,
)
from azure_drawio_mcp_server.models import (  # noqa: E402
    AzureResource,
    Connection,
    DiagramRequest,
    ResourceGroup,
)

# ---------------------------------------------------------------------------
# Recursos HelpSphere (com posições explícitas para alinhamento profissional)
# ---------------------------------------------------------------------------
# Layout grid:
#   ZONA 1 (top):    Atendentes Apex
#   ZONA 2:          SPA App Service
#   ZONA 3 (3 cols): Backend Python | Tickets .NET (Container Apps Env)
#                    UMI backend     | UMI tickets    (Identity)
#   ZONA 4:          Azure SQL DB    | Blob Storage   (Persistence)
#   ZONA 5 (lateral): AI Platform (OpenAI, Search, DocIntel)
#   ZONA 6 (footer):  App Insights | ACR | GitHub Actions

RESOURCES = [
    # Zona 1 — Edge
    AzureResource(
        id="users",
        resource_type="User",
        name="Atendentes Apex (5 marcas)",
        group="edge",
        rationale="~3.500 operadores multi-tenant — entrada via Entra ID JWT",
    ),
    # Zona 2 — Apresentação
    AzureResource(
        id="spa",
        resource_type="AppService",
        name="SPA React + Vite",
        group="presentation",
        rationale="App Service B1 Always-On · Fluent UI v9 · TS",
    ),
    # Zona 3 — Compute (2 microservices em ACA env)
    AzureResource(
        id="backend",
        resource_type="WorkerContainerApp",
        name="Backend Python (RAG)",
        group="compute",
        rationale="Quart + gunicorn 8w · /chat /ask /upload · /api/tickets/* → 410 Gone",
    ),
    AzureResource(
        id="tickets",
        resource_type="WorkerContainerApp",
        name="Tickets-service .NET 10",
        group="compute",
        rationale="Minimal API + Dapper + Microsoft.Data.SqlClient · 5 endpoints REST · JWT auth",
    ),
    # Zona 3b — Identity
    AzureResource(
        id="mi_backend",
        resource_type="ManagedIdentity",
        name="UMI backend",
        group="identity",
        rationale="CONNECT + SELECT em tbl_tenants APENAS (least privilege real · Decisão #17)",
    ),
    AzureResource(
        id="mi_tickets",
        resource_type="ManagedIdentity",
        name="UMI tickets-service",
        group="identity",
        rationale="9 grants object-level scoped (tbl_tickets, tbl_comments) — sys.database_permissions",
    ),
    # Zona 4 — Persistence
    AzureResource(
        id="sql",
        resource_type="AzureSQL",
        name="Azure SQL Serverless",
        group="data",
        rationale="GP_S_Gen5_2 · autoPauseDelay = -1 (Decisão #18) · 5 tenants/50 tickets/70 comments",
    ),
    AzureResource(
        id="blob",
        resource_type="StorageAccount",
        name="Blob Storage",
        group="data",
        rationale="62 PDFs Apex KB + 3 mocks Vision OCR · MI auth",
    ),
    # Zona 5 — AI Platform (consumido apenas pelo backend Python)
    AzureResource(
        id="openai",
        resource_type="AzureOpenAI",
        name="Azure OpenAI",
        group="ai",
        rationale="gpt-4.1-mini + text-embedding-3-large",
    ),
    AzureResource(
        id="search",
        resource_type="SearchService",
        name="AI Search",
        group="ai",
        rationale="Standard S0 · semantic ranker free tier (RAG index)",
    ),
    AzureResource(
        id="docint",
        resource_type="FormRecognizer",
        name="Document Intelligence",
        group="ai",
        rationale="Layout/OCR de documentos Apex (Lab Intermediário)",
    ),
    AzureResource(
        id="vision",
        resource_type="ComputerVision",
        name="AI Vision",
        group="ai",
        rationale="OCR + image embeddings (Lab Intermediário)",
    ),
    # Zona 6 — Observability + DevOps
    AzureResource(
        id="appinsights",
        resource_type="ApplicationInsight",
        name="Application Insights",
        group="ops",
        rationale="Workspace-based · OpenTelemetry middleware (Quart + ASP.NET Core)",
    ),
    AzureResource(
        id="acr",
        resource_type="ContainerRegistry",
        name="Azure Container Registry",
        group="ops",
        rationale="2 imagens Docker (backend Python + tickets-service .NET)",
    ),
    AzureResource(
        id="ci",
        resource_type="AzureDevOps",
        name="GitHub Actions (azd CI/CD)",
        group="ops",
        rationale="OIDC federated credentials · azd up · 3 workflows (Deploy + Python check + .NET test)",
    ),
]

# ---------------------------------------------------------------------------
# Resource Groups (clusters visuais)
# ---------------------------------------------------------------------------
GROUPS = [
    ResourceGroup(id="edge", name="Edge · Internet", color="#F0F6FF"),
    ResourceGroup(id="presentation", name="Apresentação", color="#E6F2FB"),
    ResourceGroup(id="compute", name="Container Apps Environment · westus3", color="#EAF6EA"),
    ResourceGroup(id="identity", name="Identity · least privilege REAL", color="#FFF7DB"),
    ResourceGroup(id="data", name="Persistence", color="#FDEAE7"),
    ResourceGroup(id="ai", name="AI Platform · consumido por backend Python (RAG)", color="#F5EBF8"),
    ResourceGroup(id="ops", name="Observability & DevOps", color="#FFF1DB"),
]

# ---------------------------------------------------------------------------
# Conexões (com labels semânticos e estilos de linha apropriados)
# ---------------------------------------------------------------------------
CONNECTIONS = [
    # Request flow (azul · sólido)
    Connection(source="users", target="spa", label="HTTPS · Entra ID JWT", style="solid"),
    Connection(source="spa", target="backend", label="VITE_API_BACKEND_URL", style="solid"),
    Connection(source="spa", target="tickets", label="VITE_API_TICKETS_URL", style="solid"),
    # Deprecação RFC 8288 (vermelho · tracejado)
    Connection(
        source="backend",
        target="tickets",
        label="410 Gone + Link rel=successor-version (RFC 8288)",
        style="dashed",
    ),
    # MI auth (cinza · pontilhado)
    Connection(source="backend", target="mi_backend", label="MI auth", style="dotted"),
    Connection(source="tickets", target="mi_tickets", label="MI auth", style="dotted"),
    # Grants verificáveis (verde · sólido)
    Connection(
        source="mi_backend",
        target="sql",
        label="SELECT em tbl_tenants APENAS",
        style="solid",
    ),
    Connection(
        source="mi_tickets",
        target="sql",
        label="9 grants object-level scoped",
        style="solid",
    ),
    # AI consumption (apenas backend · tracejado)
    Connection(source="backend", target="openai", label="RAG (chat/ask)", style="dashed"),
    Connection(source="backend", target="search", label="index query", style="dashed"),
    Connection(source="backend", target="docint", label="OCR/layout", style="dashed"),
    Connection(source="backend", target="vision", label="vision OCR", style="dashed"),
    Connection(source="backend", target="blob", label="docs upload", style="dashed"),
    # Observability + DevOps (pontilhado)
    Connection(source="backend", target="appinsights", label="OpenTelemetry", style="dotted"),
    Connection(source="tickets", target="appinsights", label="OpenTelemetry", style="dotted"),
    Connection(source="ci", target="acr", label="azd up · push images", style="dotted"),
    Connection(source="acr", target="backend", label="image pull", style="dotted"),
    Connection(source="acr", target="tickets", label="image pull", style="dotted"),
]


async def main() -> int:
    """Generate the .drawio file."""
    request = DiagramRequest(
        title="HelpSphere · Apex Group · Hybrid Microservices on Azure",
        resources=RESOURCES,
        connections=CONNECTIONS,
        groups=GROUPS,
        workspace_dir=str(Path(__file__).parent.resolve()),
        filename="architecture",
        open_in_vscode=False,
        show_legend=True,
        show_instructions=False,
        show_resource_numbers=False,
        use_nested_groups=False,
        use_infinite_canvas=True,
    )

    response = await generate_drawio_diagram(request)
    # Sessao 9.2 cont: stdout do Windows e cp1252 - sanitiza para ASCII puro
    msg = response.message.encode("ascii", errors="replace").decode("ascii")
    print(f"[{response.status.upper()}] {msg}")
    if response.path:
        print(f"  Output: {response.path}")
    return 0 if response.status == "success" else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
