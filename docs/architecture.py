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

GRAPH_ATTR = {
    "fontname": "Segoe UI",
    "fontsize": "22",
    "bgcolor": "white",
    "pad": "0.8",
    "splines": "spline",
    "rankdir": "LR",
    "compound": "true",
    "nodesep": "0.6",
    "ranksep": "1.4",
    "labelloc": "t",
}

NODE_ATTR = {
    "fontname": "Segoe UI",
    "fontsize": "13",
}

EDGE_ATTR = {
    "fontname": "Segoe UI",
    "fontsize": "11",
}


def render(outformat: str = "png") -> None:
    """Render the architecture diagram to docs/architecture.<outformat>."""
    with Diagram(
        "HelpSphere · Apex Group · Hybrid Microservices on Azure",
        filename="docs/architecture",
        outformat=outformat,
        show=False,
        direction="LR",
        graph_attr=GRAPH_ATTR,
        node_attr=NODE_ATTR,
        edge_attr=EDGE_ATTR,
    ):
        # ===============================================================
        # Edge — Internet entry
        # ===============================================================
        users = Usericon("Atendentes Apex\n5 marcas multi-tenant")

        # ===============================================================
        # Frontend layer
        # ===============================================================
        spa = AppServices("SPA React + Vite\nApp Service B1\n(Always-On)")

        # ===============================================================
        # Compute — 2 microservices em ACA env compartilhado
        # ===============================================================
        with Cluster(
            "Container Apps Environment · westus3",
            graph_attr={
                "style": "rounded",
                "bgcolor": "#EDF7ED",
                "color": "#107C10",
                "fontsize": "16",
                "labelloc": "t",
            },
        ):
            backend = ContainerApps("Backend Python\nQuart + gunicorn\n/chat /ask /upload\n/api/tickets/* → 410 Gone")
            tickets = ContainerApps("Tickets-service .NET 10\nMinimal API + Dapper\n5 endpoints REST + JWT auth")

        # ===============================================================
        # Identity perimeter (Zero Trust)
        # ===============================================================
        with Cluster(
            "Identity & Governance · least privilege REAL",
            graph_attr={
                "style": "rounded",
                "bgcolor": "#FFF8E1",
                "color": "#F2B600",
                "fontsize": "16",
                "labelloc": "t",
            },
        ):
            mi_backend = ManagedIdentities("User-Assigned MI\nbackend (Python)")
            mi_tickets = ManagedIdentities("User-Assigned MI\ntickets-service (.NET)")

        # ===============================================================
        # Persistence
        # ===============================================================
        with Cluster(
            "Persistence",
            graph_attr={
                "style": "rounded",
                "bgcolor": "#FFEBEE",
                "color": "#D83B01",
                "fontsize": "16",
                "labelloc": "t",
            },
        ):
            sql = SQLDatabases(
                "Azure SQL DB Serverless\nGP_S_Gen5_2\nautoPauseDelay = -1\n5 tenants · 50 tickets · 70 comments"
            )
            blob = BlobStorage("Blob Storage\n62 PDFs Apex KB\n+ mocks Vision OCR")

        # ===============================================================
        # AI Platform (consumido pelo backend Python)
        # ===============================================================
        with Cluster(
            "AI Platform",
            graph_attr={
                "style": "rounded",
                "bgcolor": "#F3E5F5",
                "color": "#5C2D91",
                "fontsize": "16",
                "labelloc": "t",
            },
        ):
            openai = CognitiveServices("Azure OpenAI\ngpt-4.1-mini\n+ emb-3-large")
            search = Search("AI Search\nsemantic ranker")
            vision = CognitiveServices("Doc Intelligence\n+ AI Vision\n(OCR · layout)")

        # ===============================================================
        # Observability + DevOps
        # ===============================================================
        with Cluster(
            "Observability & DevOps",
            graph_attr={
                "style": "rounded",
                "bgcolor": "#FFF3E0",
                "color": "#FF8C00",
                "fontsize": "16",
                "labelloc": "t",
            },
        ):
            ai = CognitiveServices("Application Insights\nworkspace-based")
            acr = ContainerRegistries("ACR\n2 imagens Docker")
            ci = Devops("GitHub Actions\nazd CI/CD · OIDC")

        # ===============================================================
        # Edges — request flow
        # ===============================================================
        users >> Edge(label="HTTPS · Entra ID JWT", color="#0078D4", style="bold") >> spa
        (
            spa
            >> Edge(
                label="/chat /ask /upload\nVITE_API_BACKEND_URL",
                color="#0078D4",
            )
            >> backend
        )
        (
            spa
            >> Edge(
                label="/api/tickets/*\nVITE_API_TICKETS_URL",
                color="#0078D4",
            )
            >> tickets
        )

        # Deprecation flow (Decisão #16) — Python redireciona pro .NET via Link header
        (
            backend
            >> Edge(
                label="410 Gone + Link\nrel=successor-version (RFC 8288)",
                color="#D83B01",
                style="dashed",
            )
            >> tickets
        )

        # ===============================================================
        # Edges — MI auth (least privilege real verificável)
        # ===============================================================
        backend >> Edge(label="MI", color="#605E5C", style="dotted") >> mi_backend
        tickets >> Edge(label="MI", color="#605E5C", style="dotted") >> mi_tickets

        (
            mi_backend
            >> Edge(
                label="SELECT em tbl_tenants\nAPENAS (Decisão #17)",
                color="#107C10",
                fontcolor="#107C10",
            )
            >> sql
        )
        (
            mi_tickets
            >> Edge(
                label="9 grants scoped\nobject-level\n(sys.database_permissions)",
                color="#107C10",
                fontcolor="#107C10",
            )
            >> sql
        )

        # ===============================================================
        # Edges — AI consumption (apenas backend Python)
        # ===============================================================
        backend >> Edge(label="RAG", color="#5C2D91", style="dashed") >> openai
        backend >> Edge(label="index", color="#5C2D91", style="dashed") >> search
        backend >> Edge(label="OCR", color="#5C2D91", style="dashed") >> vision
        backend >> Edge(label="docs", color="#5C2D91", style="dashed") >> blob

        # ===============================================================
        # Edges — Observability + DevOps
        # ===============================================================
        backend >> Edge(label="OpenTelemetry", color="#605E5C", style="dotted") >> ai
        tickets >> Edge(label="OpenTelemetry", color="#605E5C", style="dotted") >> ai
        ci >> Edge(label="azd up", color="#605E5C", style="dotted") >> acr
        acr >> Edge(label="image pull", color="#605E5C", style="dotted") >> backend
        acr >> Edge(label="image pull", color="#605E5C", style="dotted") >> tickets


if __name__ == "__main__":
    render(outformat="png")
    render(outformat="svg")
    print("[OK] Generated docs/architecture.png + docs/architecture.svg")
