"""Setup Azure AI Search index — idempotente, pre-prepdocs.

HelpSphere — Story 06.5c.9 (Sessao 9.5, Decisao #21):
Garante que o backend Python suba mesmo se prepdocs.py nao rodou ainda.

Quando AZURE_USE_AUTHENTICATION=true, app/backend/app.py:566 faz
`await search_index_client.get_index(AZURE_SEARCH_INDEX)` no startup
pra validar que `oids` e `groups` existem no schema (ACL filtering).
Sem o indice, lifespan crash em LifespanFailureError → backend
crashloop → aluno fica preso.

Este script e idempotente:
- Indice existe → log "skipping" + exit 0
- Indice nao existe → cria com schema MINIMO (5 fields) + exit 0
- Erro inesperado → log + exit 1

Schema minimo satisfaz `AuthenticationHelper.has_auth_fields` check
(precisa de `oids` e `groups` Collection(Edm.String)). prepdocs.py
depois sobrescreve com schema completo (vector embeddings, semantic
search, sourcefile, category, etc) quando aluno popular ./data/.

Hook order em azure.yaml postprovision:
    auth_update → setup_search_index → prepdocs → sql_init
                  ^^^^^^^^^^^^^^^^^^
                  garante indice antes do backend tentar deploy.
"""

import asyncio
import logging
import os
import sys

from azure.core.exceptions import ResourceNotFoundError
from azure.identity.aio import AzureDeveloperCliCredential
from azure.search.documents.indexes.aio import SearchIndexClient
from azure.search.documents.indexes.models import (
    SearchField,
    SearchFieldDataType,
    SearchIndex,
)

from load_azd_env import load_azd_env

logger = logging.getLogger("scripts.setup_search_index")


def build_minimal_index(index_name: str) -> SearchIndex:
    """Schema minimo (5 fields) que satisfaz startup do backend.

    `oids` e `groups` sao OBRIGATORIOS — `AuthenticationHelper.has_auth_fields`
    valida ambos antes de habilitar ACL filtering. prepdocs.py depois faz
    PUT com schema completo (vetor, semantic, sourcefile etc).
    """
    return SearchIndex(
        name=index_name,
        fields=[
            SearchField(
                name="id",
                type=SearchFieldDataType.String,
                key=True,
                searchable=False,
                filterable=True,
                retrievable=True,
            ),
            SearchField(
                name="content",
                type=SearchFieldDataType.String,
                searchable=True,
                retrievable=True,
            ),
            SearchField(
                name="sourcepage",
                type=SearchFieldDataType.String,
                searchable=False,
                filterable=True,
                retrievable=True,
            ),
            SearchField(
                name="oids",
                type=SearchFieldDataType.Collection(SearchFieldDataType.String),
                filterable=True,
                retrievable=True,
            ),
            SearchField(
                name="groups",
                type=SearchFieldDataType.Collection(SearchFieldDataType.String),
                filterable=True,
                retrievable=True,
            ),
        ],
    )


async def ensure_index() -> int:
    """Cria indice se nao existe. Retorna exit code (0 ok, 1 erro)."""
    load_azd_env()

    search_service = os.environ.get("AZURE_SEARCH_SERVICE")
    if not search_service:
        logger.error(
            "AZURE_SEARCH_SERVICE nao definido no azd env. " "Rode `azd provision` antes (Bicep cria o Search Service)."
        )
        return 1

    index_name = os.environ.get("AZURE_SEARCH_INDEX", "gptkbindex")
    tenant_id = os.environ.get("AZURE_TENANT_ID")

    endpoint = f"https://{search_service}.search.windows.net"
    logger.info(f"Search endpoint: {endpoint}")
    logger.info(f"Index name: {index_name}")

    credential = AzureDeveloperCliCredential(tenant_id=tenant_id) if tenant_id else AzureDeveloperCliCredential()

    try:
        async with credential, SearchIndexClient(endpoint=endpoint, credential=credential) as client:
            try:
                existing = await client.get_index(index_name)
                logger.info(f"Index '{existing.name}' already exists ({len(existing.fields)} fields). Skipping.")
                return 0
            except ResourceNotFoundError:
                logger.info(f"Index '{index_name}' nao existe — criando schema minimo (5 fields)...")
                index = build_minimal_index(index_name)
                created = await client.create_index(index)
                logger.info(
                    f"Index '{created.name}' created with {len(created.fields)} fields. "
                    "prepdocs.py vai sobrescrever com schema completo quando rodar."
                )
                return 0
    except Exception as exc:
        logger.exception(f"Falha ao garantir indice '{index_name}': {exc}")
        return 1


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    exit_code = asyncio.run(ensure_index())
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
