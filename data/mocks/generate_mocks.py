"""Gerador de PNGs mock para Vision OCR — Story 06.5a Sessão 3 [B4].

Produz 3 imagens sintéticas em `screenshots-mock/`:
  - pos-error-001.png   (1280x720)   — tela de erro POS terminal
  - nfce-receipt-001.png (480x1024)  — cupom fiscal NFC-e
  - sap-screen-001.png  (1366x768)   — tela SAP FI módulo financeiro

Cada imagem traz texto realista em pt-BR (cenários reais de retail brasileiro)
para que o Azure Vision OCR / Document Intelligence tenham material de
extração no Lab Intermediário (RAG).

Uso:
    cd helpsphere/data/mocks
    python generate_mocks.py

Dependência: Pillow >= 10.x.

Determinismo: cores e textos são hardcoded — output reproduzível bit-a-bit.
Tipo de fonte tenta Arial (Windows) / DejaVu Sans (Linux), com fallback
para a fonte default da Pillow se nenhuma estiver disponível.
"""

from __future__ import annotations

from collections.abc import Sequence
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = Path(__file__).parent / "screenshots-mock"


# ---------------------------------------------------------------------------
# Font resolution — graceful fallback chain
# ---------------------------------------------------------------------------

_FONT_CANDIDATES_REGULAR: tuple[str, ...] = (
    r"C:\Windows\Fonts\arial.ttf",
    r"C:\Windows\Fonts\segoeui.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/Library/Fonts/Arial.ttf",
)
_FONT_CANDIDATES_BOLD: tuple[str, ...] = (
    r"C:\Windows\Fonts\arialbd.ttf",
    r"C:\Windows\Fonts\segoeuib.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/Library/Fonts/Arial Bold.ttf",
)
_FONT_CANDIDATES_MONO: tuple[str, ...] = (
    r"C:\Windows\Fonts\consola.ttf",
    r"C:\Windows\Fonts\cour.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    "/Library/Fonts/Courier New.ttf",
)


def _load_font(candidates: Sequence[str], size: int) -> ImageFont.ImageFont:
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _font_regular(size: int) -> ImageFont.ImageFont:
    return _load_font(_FONT_CANDIDATES_REGULAR, size)


def _font_bold(size: int) -> ImageFont.ImageFont:
    return _load_font(_FONT_CANDIDATES_BOLD, size)


def _font_mono(size: int) -> ImageFont.ImageFont:
    return _load_font(_FONT_CANDIDATES_MONO, size)


# ---------------------------------------------------------------------------
# Image generators
# ---------------------------------------------------------------------------


def generate_pos_error(output_path: Path) -> None:
    """Tela de erro de POS terminal — fundo escuro, texto verde monospace."""
    width, height = 1280, 720
    bg = (10, 14, 28)
    fg = (134, 239, 172)
    accent = (251, 191, 36)
    error = (248, 113, 113)

    image = Image.new("RGB", (width, height), bg)
    draw = ImageDraw.Draw(image)

    title_font = _font_bold(34)
    header_font = _font_bold(22)
    body_font = _font_mono(20)
    small_font = _font_mono(16)

    # Header bar
    draw.rectangle([(0, 0), (width, 60)], fill=(15, 23, 42))
    draw.text((30, 16), "APEX MERCADO BRASIL — POS-12-04", font=title_font, fill=fg)
    draw.text((width - 240, 22), "TEF SITEF v4.21", font=small_font, fill=accent)

    # Loja info
    y = 90
    info_lines = [
        "LOJA #12  SP-CAPITAL / MOEMA",
        "OPERADOR: 04382  (CARLA M.)",
        "TURNO: T2  ABERTURA: 14:00",
    ]
    for line in info_lines:
        draw.text((40, y), line, font=body_font, fill=fg)
        y += 28

    # Error box
    box_top = 210
    box_bottom = 470
    draw.rectangle([(40, box_top), (width - 40, box_bottom)], outline=error, width=3)
    draw.text((60, box_top + 18), "ERRO DE COMUNICACAO", font=header_font, fill=error)
    draw.text((60, box_top + 56), "CODIGO 0xFF-SITEF-7841", font=body_font, fill=accent)

    error_lines = [
        "",
        "A comunicacao com o SITEF foi interrompida durante",
        "a autorizacao da transacao TEF na adquirente.",
        "",
        "Operacao: AUTHORIZATION_REQUEST",
        "Adquirente: REDE / ELO  |  Bandeira: VISA CREDITO",
        "Valor pendente: R$ 247,90  |  Parcelamento: 1x",
        "NSU local: 84291734  |  Status: PENDENTE_AUTORIZACAO",
    ]
    y = box_top + 92
    for line in error_lines:
        draw.text((60, y), line, font=body_font, fill=fg)
        y += 26

    # Footer actions
    draw.rectangle([(0, height - 90), (width, height)], fill=(15, 23, 42))
    actions = "[F1] Tentar novamente   [F2] Cancelar transacao   [F3] Modo offline   [F4] Chamar suporte"
    draw.text((40, height - 60), actions, font=body_font, fill=accent)
    draw.text((40, height - 28), "DATA: 14/03/2026 14:32:18  NSU: 84291734", font=small_font, fill=fg)

    image.save(output_path, "PNG", optimize=True)


def generate_nfce_receipt(output_path: Path) -> None:
    """Cupom fiscal NFC-e — formato estreito, fundo branco, monospace."""
    width, height = 480, 1024
    bg = (252, 252, 250)
    fg = (24, 24, 27)
    muted = (113, 113, 122)

    image = Image.new("RGB", (width, height), bg)
    draw = ImageDraw.Draw(image)

    title_font = _font_bold(18)
    body_font = _font_mono(13)
    small_font = _font_mono(11)
    big_font = _font_bold(16)

    margin = 20

    # Header
    y = margin
    for line in [
        "APEX MERCADO BRASIL LTDA",
        "CNPJ: 12.345.678/0012-34",
        "IE: 110.123.456.789",
        "Av. Paulista, 1500 - Sao Paulo/SP",
        "CEP: 01310-100",
    ]:
        draw.text((margin, y), line, font=body_font, fill=fg)
        y += 18

    y += 8
    draw.line([(margin, y), (width - margin, y)], fill=fg, width=1)
    y += 6
    draw.text((margin, y), "NF-e Consumidor Eletronica - NFC-e", font=title_font, fill=fg)
    y += 26
    draw.text((margin, y), "SERIE: 001    NUMERO: 000.123.456", font=body_font, fill=fg)
    y += 18
    draw.text((margin, y), "EMISSAO: 14/03/2026 14:35:42", font=body_font, fill=fg)
    y += 24

    # Items header
    draw.line([(margin, y), (width - margin, y)], fill=fg, width=1)
    y += 4
    draw.text((margin, y), "ITEM  CODIGO   DESCRICAO    QTD VLR  TOT", font=small_font, fill=muted)
    y += 18
    draw.line([(margin, y), (width - margin, y)], fill=fg, width=1)
    y += 4

    items = [
        ("001", "7890123", "Arroz Tipo 1 5kg", 1, 28.90),
        ("002", "7898765", "Feijao Carioca 1k", 2, 9.49),
        ("003", "7894561", "Oleo Soja 900ml", 3, 7.80),
        ("004", "7891234", "Cafe Trad 500g", 1, 18.50),
        ("005", "7895678", "Leite UHT Int 1L", 4, 5.49),
    ]
    subtotal = 0.0
    for n, code, desc, qty, price in items:
        total = qty * price
        subtotal += total
        line1 = f"{n}  {code}"
        line2 = f"   {desc[:22]:<22} {qty}x{price:6.2f} {total:7.2f}"
        draw.text((margin, y), line1, font=small_font, fill=fg)
        y += 14
        draw.text((margin, y), line2, font=small_font, fill=fg)
        y += 18

    y += 6
    draw.line([(margin, y), (width - margin, y)], fill=fg, width=1)
    y += 8

    draw.text((margin, y), f"TOTAL DE ITENS:    {len(items)}", font=body_font, fill=fg)
    y += 18
    draw.text((margin, y), f"VALOR TOTAL R$:    {subtotal:8.2f}", font=big_font, fill=fg)
    y += 24
    draw.text((margin, y), f"DESCONTO    R$:    {0.00:8.2f}", font=body_font, fill=fg)
    y += 18
    draw.text((margin, y), "FORMA DE PAGTO: PIX QR Code", font=body_font, fill=fg)
    y += 24

    # Chave de acesso
    draw.line([(margin, y), (width - margin, y)], fill=fg, width=1)
    y += 6
    draw.text((margin, y), "CHAVE DE ACESSO:", font=small_font, fill=muted)
    y += 16
    chave_lines = [
        "3526 0312 3456 7800 1234",
        "5500 1000 1234 5612 3456",
        "7891 0312",
    ]
    for line in chave_lines:
        draw.text((margin, y), line, font=body_font, fill=fg)
        y += 16

    y += 10
    # QR placeholder
    qr_size = 110
    qr_x = (width - qr_size) // 2
    draw.rectangle([(qr_x, y), (qr_x + qr_size, y + qr_size)], outline=fg, width=2)
    # diagonal pattern para sugerir QR
    for offset in range(0, qr_size, 8):
        draw.line([(qr_x + offset, y), (qr_x + qr_size, y + qr_size - offset)], fill=fg, width=1)
    y += qr_size + 10

    draw.text((margin, y), "PROTOCOLO: 35260312345678910", font=small_font, fill=muted)
    y += 14
    draw.text((margin, y), "Consulte: www.fazenda.sp.gov.br/nfce", font=small_font, fill=muted)
    y += 22
    draw.text((margin, y), "OBRIGADO PELA PREFERENCIA", font=body_font, fill=fg)
    y += 16
    draw.text((margin, y), "APEX MERCADO - REDE DO BAIRRO", font=small_font, fill=muted)

    image.save(output_path, "PNG", optimize=True)


def generate_sap_screen(output_path: Path) -> None:
    """Tela SAP FI — fundo cinza claro, top bar azul, layout transactional."""
    width, height = 1366, 768
    bg = (243, 244, 246)
    panel = (255, 255, 255)
    sap_blue = (0, 105, 177)
    text = (24, 24, 27)
    muted = (107, 114, 128)
    field_bg = (251, 251, 250)

    image = Image.new("RGB", (width, height), bg)
    draw = ImageDraw.Draw(image)

    title_font = _font_bold(16)
    label_font = _font_regular(13)
    label_bold = _font_bold(13)
    body_font = _font_mono(13)

    # Top bar (Logon Window header)
    draw.rectangle([(0, 0), (width, 32)], fill=sap_blue)
    draw.text((10, 7), "SAP", font=title_font, fill=(255, 255, 255))
    draw.text((50, 7), "Exibir documento: Visao geral - APX1 [PRD]", font=label_bold, fill=(255, 255, 255))

    # Toolbar
    draw.rectangle([(0, 32), (width, 70)], fill=(229, 231, 235))
    toolbar_items = ["Salvar", "Voltar", "Cancelar", "Sair", "|", "Imprimir", "Buscar", "|", "Mais"]
    x = 14
    for item in toolbar_items:
        draw.text((x, 44), item, font=label_font, fill=text if item != "|" else muted)
        x += draw.textlength(item, font=label_font) + 18

    # Transaction code
    draw.rectangle([(0, 70), (width, 100)], fill=(243, 244, 246))
    draw.text((14, 78), "Codigo de transacao:", font=label_font, fill=muted)
    draw.text((150, 78), "FB03", font=body_font, fill=text)
    draw.text((220, 78), "Exibir documento contabil", font=label_font, fill=text)

    # Main panel
    panel_x, panel_y = 16, 116
    draw.rectangle([(panel_x, panel_y), (width - 16, height - 60)], fill=panel, outline=(209, 213, 219), width=1)

    # Cabecalho do documento
    y = panel_y + 14
    draw.text((panel_x + 14, y), "Cabecalho do documento", font=title_font, fill=sap_blue)
    y += 28

    header_fields = [
        ("Empresa", "APX1   Apex Group Brasil Holding"),
        ("Numero documento", "2026-FI-094812"),
        ("Exercicio fiscal", "2026"),
        ("Tipo de documento", "KR  Fatura de fornecedor"),
        ("Data de lancamento", "12.03.2026"),
        ("Data de referencia", "08.03.2026"),
        ("Periodo contabil", "03 / 2026"),
        ("Documento referencia", "NF-e 78421 / Serie 1"),
        ("Moeda", "BRL"),
        ("Texto cabecalho", "Pagamento DISTRIB.APEX  fatura mar/26"),
    ]
    for label, value in header_fields:
        draw.text((panel_x + 14, y), label, font=label_font, fill=muted)
        draw.rectangle(
            [(panel_x + 230, y - 2), (panel_x + 720, y + 19)], fill=field_bg, outline=(209, 213, 219), width=1
        )
        draw.text((panel_x + 240, y), value, font=body_font, fill=text)
        y += 26

    # Posicoes section
    y += 10
    draw.text((panel_x + 14, y), "Posicoes (3 itens)", font=title_font, fill=sap_blue)
    y += 28

    # Table header
    cols_x = [panel_x + 14, panel_x + 70, panel_x + 240, panel_x + 460, panel_x + 590, panel_x + 760]
    headers = ["Item", "Conta razao", "Descricao", "Centro custo", "Valor", "DC"]
    for x, h in zip(cols_x, headers):
        draw.text((x, y), h, font=label_bold, fill=text)
    y += 22
    draw.line([(panel_x + 14, y - 2), (width - 30, y - 2)], fill=(209, 213, 219), width=1)

    rows = [
        ("001", "4112000001", "Despesa adm. - servicos", "APX-LOJ-12", "12.450,00", "D"),
        ("002", "1142000003", "PIS a recolher", "APX-CORP", "205,43", "C"),
        ("003", "2210000001", "Fornec. nac. (DISTRIB.APEX)", "APX-CORP", "12.244,57", "C"),
    ]
    for row in rows:
        for x, val in zip(cols_x, row):
            draw.text((x, y + 2), val, font=body_font, fill=text)
        y += 24
        draw.line([(panel_x + 14, y - 2), (width - 30, y - 2)], fill=(229, 231, 235), width=1)

    y += 12
    draw.text(
        (panel_x + 14, y),
        "Totais     Debito: R$ 12.450,00     Credito: R$ 12.450,00     Saldo: 0,00",
        font=label_bold,
        fill=text,
    )
    y += 28

    # Approval status box
    draw.rectangle([(panel_x + 14, y), (width - 30, y + 60)], fill=(254, 243, 199), outline=(217, 119, 6), width=1)
    draw.text((panel_x + 24, y + 8), "Status de aprovacao", font=label_bold, fill=(146, 64, 14))
    draw.text(
        (panel_x + 24, y + 30),
        "Em aprovacao  ·  2 alcadas pendentes  ·  Workflow WF-FI-7782",
        font=label_font,
        fill=(146, 64, 14),
    )

    # Status bar bottom
    draw.rectangle([(0, height - 32), (width, height)], fill=(229, 231, 235))
    draw.text(
        (14, height - 24),
        "Sistema: PRD  Cliente: 100  Usuario: BRUNO.S  Programa: SAPMF05L  ",
        font=label_font,
        fill=muted,
    )

    image.save(output_path, "PNG", optimize=True)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    generators = [
        ("pos-error-001.png", generate_pos_error),
        ("nfce-receipt-001.png", generate_nfce_receipt),
        ("sap-screen-001.png", generate_sap_screen),
    ]
    for filename, generator in generators:
        out = OUTPUT_DIR / filename
        generator(out)
        size_kb = out.stat().st_size / 1024
        print(f"  {filename:28s}  {size_kb:7.1f} KB")

    print(f"\nMocks gerados em: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
