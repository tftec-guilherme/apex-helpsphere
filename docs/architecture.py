"""HelpSphere — Diagrama de arquitetura (Apex Group · Disciplina 06)

Diagram-as-code usando mingrammer/diagrams (https://diagrams.mingrammer.com/)
com icon set oficial Microsoft Azure (Azure2 SVG library).

Geração:
    pip install --user diagrams
    # Pré-requisito sistema: Graphviz no PATH
    #   Windows: winget install Graphviz.Graphviz
    #   macOS:   brew install graphviz
    #   Linux:   apt install graphviz
    cd <repo-root>
    python docs/architecture.py
    # → produz docs/architecture.png e docs/architecture.svg

Versionar PNG no repo (referenciado pelo README) E o .py (regenerável).
SVG é bonus para visualização zoomada offline.

Layout decisão (Sessão 9.2 cont · iteração 3):
- Top-bottom (TB) com 4 zonas horizontais: Edge → Compute → Data → AI/Ops
- Identity como cluster lateral compacto (UMIs + grants verificáveis)
- Edges curtos com labels concisos (sem CSS-art em ASCII)
- Splines curvas (não ortho) para fluidez visual

Decisões refletidas (vide DECISION-LOG.md):
- #5  Container Apps + JWT tenant + auth obrigatório
- #16 Hybrid Microservices Python (RAG) + .NET (Tickets CRUD)
- #17 Token AAD explícito (workaround ODBC Driver 18 + UMI Linux)
- #18 SQL Serverless autoPauseDelay = -1 (confiabilidade > FinOps)
"""

from diagrams import Cluster, Diagram, Edge
from diagrams.azure.compute import ContainerApps, ContainerRegistries
from diagrams.azure.database import SQLDatabases
from diagrams.azure.devops import Devops
from diagrams.azure.general import Usericon
from diagrams.azure.identity import ManagedIdentities
from diagrams.azure.ml import CognitiveServices
from diagrams.azure.storage import BlobStorage
from diagrams.azure.web import AppServices, Search

# ---------------------------------------------------------------------------
# Theme tokens — alinhados com paleta Azure oficial
# ---------------------------------------------------------------------------
AZURE_BLUE = "#0078D4"
AZURE_GREEN = "#107C10"
AZURE_RED = "#D83B01"
AZURE_PURPLE = "#5C2D91"
AZURE_AMBER = "#F2B600"
AZURE_GRAY = "#605E5C"
INK = "#252423"

GRAPH_ATTR = {
    "fontname": "Segoe UI Semibold",
    "fontsize": "26",
    "fontcolor": INK,
    "bgcolor": "white",
    "pad": "1.0",
    "splines": "spline",
    "rankdir": "TB",
    "compound": "true",
    "nodesep": "0.7",
    "ranksep": "1.0",
    "labelloc": "t",
    "labeljust": "c",
}

NODE_ATTR = {
    "fontname": "Segoe UI",
    "fontsize": "13",
    "fontcolor": INK,
}

EDGE_ATTR = {
    "fontname": "Segoe UI",
    "fontsize": "11",
    "fontcolor": AZURE_GRAY,
}


def _cluster_attr(bgcolor: str, border: str) -> dict:
    """Atributos consistentes para todos os clusters."""
    return {
        "style": "rounded",
        "bgcolor": bgcolor,
        "color": border,
        "pencolor": border,
        "penwidth": "2",
        "fontname": "Segoe UI Semibold",
        "fontsize": "15",
        "fontcolor": INK,
        "labelloc": "t",
        "margin": "20",
    }


def render(outformat: str = "png") -> None:
    """Render the architecture diagram to docs/architecture.<outformat>."""
    with Diagram(
        "HelpSphere · Apex Group · Hybrid Microservices on Azure",
        filename="docs/architecture",
        outformat=outformat,
        show=False,
        direction="TB",
        graph_attr=GRAPH_ATTR,
        node_attr=NODE_ATTR,
        edge_attr=EDGE_ATTR,
    ):
        # ===============================================================
        # ZONA 1 — EDGE (entrada de usuários)
        # ===============================================================
        with Cluster("Edge · Internet", graph_attr=_cluster_attr("#F0F6FF", AZURE_BLUE)):
            users = Usericon("Atendentes Apex\n5 marcas multi-tenant\n~3.500 operadores")

        # ===============================================================
        # ZONA 2 — APRESENTAÇÃO
        # ===============================================================
        with Cluster("Apresentação", graph_attr=_cluster_attr("#E6F2FB", AZURE_BLUE)):
            spa = AppServices("SPA React + Vite + TS\nFluent UI v9\nApp Service B1 (Always-On)")

        # ===============================================================
        # ZONA 3 — COMPUTE (2 microservices) + IDENTITY (lateral)
        # ===============================================================
        with Cluster(
            "Container Apps Environment · westus3",
            graph_attr=_cluster_attr("#EAF6EA", AZURE_GREEN),
        ):
            backend = ContainerApps(
                "Backend Python\nQuart · gunicorn 8w\n/chat /ask /upload\n/api/tickets/* → 410 Gone"
            )
            tickets = ContainerApps(
                "Tickets-service .NET 10\nMinimal API · Dapper\n5 endpoints REST\nJWT auth obrigatório"
            )

        with Cluster(
            "Identity · least privilege REAL",
            graph_attr=_cluster_attr("#FFF7DB", AZURE_AMBER),
        ):
            mi_backend = ManagedIdentities("UMI backend\nSELECT em tbl_tenants\nAPENAS")
            mi_tickets = ManagedIdentities("UMI tickets-service\n9 grants object-level\nscoped")

        # ===============================================================
        # ZONA 4 — DATA + AI PLATFORM (lado a lado)
        # ===============================================================
        with Cluster("Persistence", graph_attr=_cluster_attr("#FDEAE7", AZURE_RED)):
            sql = SQLDatabases(
                "Azure SQL Serverless\nGP_S_Gen5_2 · autoPause OFF\n5 tenants · 50 tickets · 70 comments"
            )
            blob = BlobStorage("Blob Storage\n62 PDFs Apex KB\n+ mocks Vision OCR")

        with Cluster("AI Platform · consumido por backend Python", graph_attr=_cluster_attr("#F5EBF8", AZURE_PURPLE)):
            openai = CognitiveServices("Azure OpenAI\ngpt-4.1-mini\n+ emb-3-large")
            search = Search("AI Search\nsemantic ranker")
            vision = CognitiveServices("Doc Intelligence\n+ AI Vision (OCR)")

        # ===============================================================
        # ZONA 5 — OBSERVABILITY + DEVOPS (rodapé)
        # ===============================================================
        with Cluster("Observability & DevOps", graph_attr=_cluster_attr("#FFF1DB", "#FF8C00")):
            ai_insights = CognitiveServices("Application Insights\nworkspace-based\nOpenTelemetry")
            acr = ContainerRegistries("Azure Container\nRegistry · 2 imagens")
            ci = Devops("GitHub Actions\nazd CI/CD · OIDC")

        # ===============================================================
        # FLUXOS — request path (azul, sólido)
        # ===============================================================
        users >> Edge(label="HTTPS · Entra ID JWT", color=AZURE_BLUE, penwidth="2") >> spa
        spa >> Edge(label="VITE_API_BACKEND_URL", color=AZURE_BLUE) >> backend
        spa >> Edge(label="VITE_API_TICKETS_URL", color=AZURE_BLUE) >> tickets

        # Deprecação (Decisão #16) — vermelho tracejado, RFC 8288
        (
            backend
            >> Edge(
                label="410 Gone + Link\nrel=successor-version",
                color=AZURE_RED,
                style="dashed",
                fontcolor=AZURE_RED,
            )
            >> tickets
        )

        # ===============================================================
        # FLUXOS — MI auth (verde, com grants verificáveis nos labels)
        # ===============================================================
        backend >> Edge(label="MI", color=AZURE_GRAY, style="dotted") >> mi_backend
        tickets >> Edge(label="MI", color=AZURE_GRAY, style="dotted") >> mi_tickets

        (
            mi_backend
            >> Edge(
                label="SELECT tbl_tenants\n(token via SQL_COPT_SS_ACCESS_TOKEN)",
                color=AZURE_GREEN,
                fontcolor=AZURE_GREEN,
                penwidth="2",
            )
            >> sql
        )

        (
            mi_tickets
            >> Edge(
                label="SELECT/INSERT/UPDATE/DELETE\ntbl_tickets + tbl_comments",
                color=AZURE_GREEN,
                fontcolor=AZURE_GREEN,
                penwidth="2",
            )
            >> sql
        )

        # ===============================================================
        # FLUXOS — AI consumption (roxo tracejado, apenas backend)
        # ===============================================================
        backend >> Edge(label="RAG", color=AZURE_PURPLE, style="dashed") >> openai
        backend >> Edge(label="index", color=AZURE_PURPLE, style="dashed") >> search
        backend >> Edge(label="OCR", color=AZURE_PURPLE, style="dashed") >> vision
        backend >> Edge(label="docs", color=AZURE_PURPLE, style="dashed") >> blob

        # ===============================================================
        # FLUXOS — Observability + DevOps (cinza pontilhado, baixa hierarquia)
        # ===============================================================
        backend >> Edge(label="OTel", color=AZURE_GRAY, style="dotted") >> ai_insights
        tickets >> Edge(label="OTel", color=AZURE_GRAY, style="dotted") >> ai_insights
        ci >> Edge(label="azd up", color=AZURE_GRAY, style="dotted") >> acr
        acr >> Edge(label="image pull", color=AZURE_GRAY, style="dotted") >> backend
        acr >> Edge(label="image pull", color=AZURE_GRAY, style="dotted") >> tickets


if __name__ == "__main__":
    render(outformat="png")
    render(outformat="svg")
    print("[OK] Generated docs/architecture.png + docs/architecture.svg")
