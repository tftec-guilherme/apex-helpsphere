# `data/mocks/` — Imagens sintéticas para Vision OCR

> **Propósito pedagógico:** dar ao Azure Vision OCR / Document Intelligence material de extração realista em pt-BR para o **Lab Intermediário (RAG)** da Disciplina 06.
>
> **Story:** [06.5a — HelpSphere Template (REUSE fork Microsoft)](../../../../../docs/stories/06.5a.helpsphere-template.md) · Sessão 3 · Bloco B4
>
> **version-anchor:** Q2-2026

---

## ⚠️ Estes mocks NÃO são screenshots reais

São imagens **sintéticas geradas via Pillow** com texto coerente em pt-BR. Existem para que:

1. O fluxo Vision OCR / Doc Intelligence do Lab Intermediário tenha entrada antes da Story 06.6 capturar screenshots reais;
2. O Bicep do template HelpSphere possa apontar para um Blob Storage com conteúdo válido em ambiente limpo (`azd up` + flag `AZURE_LOAD_SEED_DATA=true`);
3. Auditor sênior reconheça imediatamente o que é mock vs real (declarado, não escondido).

**Substituição planejada:** Story 06.6 captura screenshots reais do portal HelpSphere após 06.5a + 06.5b + 06.7 estarem `Done`.

---

## Imagens disponíveis (`screenshots-mock/`)

| Arquivo | Dimensão | Tamanho | Conteúdo |
|---|---|---|---|
| `pos-error-001.png` | 1280×720 | ~62 KB | Tela de POS terminal com erro de comunicação SITEF (código `0xFF-SITEF-7841`). Loja, operador, valor da transação, NSU, ações F1-F4. Cenário canônico de TEF brasileiro. |
| `nfce-receipt-001.png` | 480×1024 | ~41 KB | Cupom fiscal eletrônico NFC-e: CNPJ, IE, série/número, 5 itens com código de barras, totais, chave de acesso 44 dígitos formatada, protocolo SEFAZ-SP, QR placeholder. |
| `sap-screen-001.png` | 1366×768 | ~68 KB | SAP GUI clássico — transação FB03 (exibir documento contábil): cabeçalho com empresa APX1, tipo KR, datas, 3 posições com conta razão/centro custo/valor/D-C, status de workflow de aprovação. |

**Total:** ~170 KB.

---

## Conteúdo extratível pelo Vision OCR

| Tipo de campo | Onde aparece |
|---|---|
| CNPJ formatado | nfce-receipt |
| Inscrição Estadual | nfce-receipt |
| Chave de acesso NF-e (44 dígitos) | nfce-receipt |
| Valores em R$ com centavos | todos |
| Códigos de produto / EAN | nfce-receipt |
| Datas (formatos brasileiros e europeus) | todos |
| IDs de transação (NSU, número documento) | pos-error, sap-screen |
| Códigos de erro técnico | pos-error |
| Transaction codes SAP | sap-screen |
| Centros de custo / contas razão | sap-screen |
| Workflow / status de aprovação | sap-screen |

---

## Regenerar / customizar

```bash
cd Disciplina_06_*/03_Aplicações/helpsphere/data/mocks
python generate_mocks.py
```

**Dependência:** `pillow >= 10`.

O script é **determinístico** — mesmas cores, fontes (Arial/Segoe UI/DejaVu como fallback) e textos hardcoded produzem PNGs idênticos byte-a-byte. Sem aleatoriedade.

Para adicionar um quarto/quinto mock (até 5 conforme Story AC), criar nova função `generate_*` em `generate_mocks.py` e adicionar à tupla `generators` em `main()`.

---

## Anti-padrões (declarados explicitamente)

- ❌ **Não use AI generativo** para criar essas imagens — viola Article IV (No Invention) e introduz não-determinismo no repo.
- ❌ **Não substitua por imagens reais de produção** sem anonimização; CNPJ/IE/chave NF-e usados aqui são fictícios e segmentados a Apex Group.
- ❌ **Não confie nestas imagens para teste de fidelidade visual da UI** — Story 06.6 é responsável por screenshots reais.
