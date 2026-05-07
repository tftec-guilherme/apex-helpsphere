-- =============================================================================
-- HelpSphere — seed/tickets.sql
-- 50 tickets bem modelados em pt-BR (retail brasileiro real)
--
-- Distribuição (story 06.5a AC):
--   Categorias: Comercial=10, TI=10, Operacional=10, RH=10, Financeiro=10
--   Status:     Open=20 (40%), InProgress=15 (30%), Resolved=10 (20%), Escalated=5 (10%)
--   Priority:   Low=15 (30%), Medium=25 (50%), High=8 (16%), Critical=2 (4%)
--
-- Curadoria editorial:
--   * Cada subject + description é redigido manualmente — sem AI-slop, sem lorem
--   * Cenários refletem realidade brasileira: NF-e, SPED, PIX, eSocial, ANTT,
--     CAT, Cielo, ERP, NFC-e — vocabulário que o aluno reconhece
--   * Ticket_id é IDENTITY auto-incremental — não especificado nos INSERT
--   * created_at é variado (5 a 60 dias atrás) para parecer dataset real,
--     não dump único do mesmo timestamp
--   * confidence_score = NULL em todos: a IA do Lab Final é quem preenche
--
-- Coerência cruzada com 06.7 (sample-kb): pelo menos 30 tickets têm pergunta
-- resolvível por algum dos 8 PDFs do sample-kb (planejamento dessas linhas
-- documentado em comentário "[KB]" inline)
-- =============================================================================

SET NOCOUNT ON;
GO

-- Limpa antes de re-seed (idempotente)
-- Patched (Surpresa #43): RESEED 0 numa tabela que NUNCA teve rows faz o
-- proximo INSERT comecar em 0 (nao 1). Comments.sql espera ticket_id 1..50,
-- e sem warm-up pega 0..49 -> FK violation.
-- Workaround: warm-up insert+delete pra marcar "tabela ja teve rows", entao
-- RESEED 0 final faz o proximo INSERT comecar em 1 corretamente.
DELETE FROM dbo.tbl_tickets;
SET IDENTITY_INSERT dbo.tbl_tickets ON;
INSERT INTO dbo.tbl_tickets (ticket_id, tenant_id, subject, description, category, status, priority, created_at)
VALUES (1, (SELECT TOP 1 tenant_id FROM dbo.tbl_tenants), N'__warmup__', N'__warmup__', 'TI', 'Open', 'Low', SYSUTCDATETIME());
SET IDENTITY_INSERT dbo.tbl_tickets OFF;
DELETE FROM dbo.tbl_tickets;
DBCC CHECKIDENT ('dbo.tbl_tickets', RESEED, 0);
GO

-- -----------------------------------------------------------------------------
-- COMERCIAL (10) — vendas, devoluções, NF-e, condições comerciais
-- -----------------------------------------------------------------------------
INSERT INTO dbo.tbl_tickets
    (tenant_id, subject, description, category, status, priority, created_at)
VALUES
-- TKT-1 — Apex Tech
('22222222-2222-2222-2222-222222222222',
 N'Devolução de geladeira fora do prazo de 7 dias do CDC',
 N'Cliente comprou geladeira Brastemp BRM69 em 12/03 e abriu chamado em 25/03 pedindo devolução por desistência. Já passou do prazo CDC de 7 dias para arrependimento. Vendedor pede orientação se aplicamos política comercial interna mais flexível ou negamos. [KB] sample-kb politica-devolucoes.pdf',
 'Comercial', 'InProgress', 'Medium', DATEADD(day, -8, SYSUTCDATETIME())),

-- TKT-2 — Apex Moda
('33333333-3333-3333-3333-333333333333',
 N'Cliente alega tamanho M na etiqueta mas vestiu como P',
 N'Pedido #ML-7821 (Mercado Livre): cliente comprou camisa polo masc tamanho M, recebeu peça com etiqueta M mas modelagem reduzida. Vendedor terceiro suspeita de erro no fornecedor da coleção verão 2026. Cliente solicita troca por outro tamanho ou estorno.',
 'Comercial', 'Open', 'Low', DATEADD(day, -2, SYSUTCDATETIME())),

-- TKT-3 — Apex Mercado
('11111111-1111-1111-1111-111111111111',
 N'NFe de pedido B2B rejeitada — Rejeição 539 (CFOP incompatível)',
 N'Restaurante cliente PJ (CNPJ 12.345.678/0001-90) fez pedido B2B de R$ 18.430 em hortifruti + bebidas. NFe emitida mas SEFAZ-SP retornou rejeição 539. Pedido travado na expedição há 4h. Cliente cobra entrega para almoço de amanhã. [KB] sample-kb nfe-rejeicoes-comuns.pdf',
 'Comercial', 'InProgress', 'High', DATEADD(day, -1, SYSUTCDATETIME())),

-- TKT-4 — Apex Casa
('44444444-4444-4444-4444-444444444444',
 N'Solicitação de extensão de garantia em sofá retrátil',
 N'Cliente comprou sofá retrátil em 09/2025 (garantia de fábrica 1 ano). Solicita contratação de extensão de garantia adicional de 2 anos. Quer saber valor, cobertura (mecanismo retrátil incluído?) e prazo de carência. [KB] sample-kb garantias-estendidas.pdf',
 'Comercial', 'Open', 'Low', DATEADD(day, -5, SYSUTCDATETIME())),

-- TKT-5 — Apex Logística
('55555555-5555-5555-5555-555555555555',
 N'Cobrança duplicada de frete em fatura B2B intra-grupo',
 N'Apex Mercado contestou fatura de fevereiro: 2 entradas de frete CD-Cajamar→Loja-Pinheiros, mesmo valor R$ 1.247, mesma data 14/02, mesmo veículo. Suspeita de duplicidade de lançamento. Resolvido: estorno emitido após auditoria, processo de validação ajustado.',
 'Comercial', 'Resolved', 'Medium', DATEADD(day, -22, SYSUTCDATETIME())),

-- TKT-6 — Apex Tech
('22222222-2222-2222-2222-222222222222',
 N'Notebook anunciado por R$ 199 no site (preço correto: R$ 1.999)',
 N'Erro de cadastro CMS: notebook Lenovo IdeaPad anunciado por R$ 199 às 14h, identificado às 15h30 (90 minutos no ar). 47 pedidos efetivados nesse intervalo. Jurídico precisa avaliar honorar ou cancelar com base em CDC art. 30. Urgente — clientes já compartilhando print nas redes.',
 'Comercial', 'Open', 'High', DATEADD(day, 0, SYSUTCDATETIME())),

-- TKT-7 — Apex Moda
('33333333-3333-3333-3333-333333333333',
 N'Coleção inverno chegou com peças trocadas no PDV Iguatemi',
 N'Loja Iguatemi recebeu caixa C-1247 (coleção inverno fem) com 30% das peças não correspondendo ao romaneio. Vieram blusas tam P quando pedido era M e G. Provável troca na separação do CD. Gerente da loja precisa de orientação para devolução + reposição expressa. Próxima campanha começa em 5 dias.',
 'Comercial', 'InProgress', 'Medium', DATEADD(day, -3, SYSUTCDATETIME())),

-- TKT-8 — Apex Mercado
('11111111-1111-1111-1111-111111111111',
 N'Cliente alega cobrança de chocolate Lindt que não levou (R$ 89)',
 N'Cliente do programa de fidelidade reclamou no SAC: cupom fiscal mostra 1x chocolate Lindt R$ 89 que ele não retirou da prateleira. Análise CFTV confirmou — produto foi bipado por engano (estava no carrinho da frente). Resolvido: estorno + 100 pontos extras de fidelidade como cortesia.',
 'Comercial', 'Resolved', 'Low', DATEADD(day, -18, SYSUTCDATETIME())),

-- TKT-9 — Apex Casa
('44444444-4444-4444-4444-444444444444',
 N'Pedido de orçamento corporativo: mobiliar 5 escritórios em SP',
 N'Empresa de tecnologia abrindo 5 unidades em SP (Berrini, Faria Lima, Vila Olímpia, Pinheiros, Itaim) pediu orçamento single-source: mesas, cadeiras ergonômicas, salas de reunião + decoração. Total estimado R$ 2.4M. Comercial B2B + arquiteto interno precisam montar proposta em 7 dias úteis.',
 'Comercial', 'Open', 'Medium', DATEADD(day, -4, SYSUTCDATETIME())),

-- TKT-10 — Apex Tech
('22222222-2222-2222-2222-222222222222',
 N'Cancelamento de venda parcelada após 28h (fora prazo de 24h)',
 N'Cliente comprou Smart TV 65" parcelada em 12x via cartão Itaú no app. Pediu cancelamento após 28h alegando que não viu boleto/parcelamento. CDC garante 7 dias para arrependimento em compras online. Política interna prevê cancelamento simples até 24h — após disso requer escalonamento. [KB] sample-kb politica-devolucoes.pdf',
 'Comercial', 'InProgress', 'Medium', DATEADD(day, -6, SYSUTCDATETIME())),

-- -----------------------------------------------------------------------------
-- TI (10) — sistemas, integrações, POS, ERP, infra
-- -----------------------------------------------------------------------------

-- TKT-11 — Apex Mercado
('11111111-1111-1111-1111-111111111111',
 N'POS da loja Pinheiros travando ao emitir NFC-e (3 ocorrências/dia)',
 N'Caixa 03 da loja Pinheiros: ao emitir NFC-e em vendas com mais de 8 itens, o aplicativo do PDV congela por 30-45s e às vezes precisa reiniciar. Aconteceu 3x ontem em horário de pico. Suspeita: timeout na chamada SEFAZ-SP. Loja perde transações. [KB] sample-kb troubleshooting-pdv.pdf',
 'TI', 'InProgress', 'Medium', DATEADD(day, -2, SYSUTCDATETIME())),

-- TKT-12 — Apex Tech (CRITICAL)
('22222222-2222-2222-2222-222222222222',
 N'CRÍTICO: Integração ERP↔Magento falhando em 18% dos pedidos',
 N'Desde 03h da madrugada de ontem, 18% dos pedidos do e-commerce não estão sendo gravados no ERP TOTVS. Pedidos ficam "pending sync" e estoque não é baixado. Risco: overselling em produtos com baixo estoque. Time de TI já identificou que message broker (RabbitMQ) está rejeitando mensagens com payload acima de 256KB. Engenharia trabalhando em fix. [KB] sample-kb arquitetura-integracao.pdf',
 'TI', 'InProgress', 'Critical', DATEADD(day, -1, SYSUTCDATETIME())),

-- TKT-13 — Apex Moda
('33333333-3333-3333-3333-333333333333',
 N'App mobile não atualiza estoque em tempo real',
 N'Clientes reclamam que produto aparece como "disponível" no app mas no checkout dá "fora de estoque". Cache do CDN demorando 8-12 minutos para invalidar após sync de estoque. Marketing pede correção antes da campanha de Outubro Rosa.',
 'TI', 'Open', 'Low', DATEADD(day, -7, SYSUTCDATETIME())),

-- TKT-14 — Apex Casa
('44444444-4444-4444-4444-444444444444',
 N'Erro ao gerar SPED Fiscal de mês fechado (referência 09/2026)',
 N'Contabilidade tentou gerar SPED Fiscal de setembro/2026 (mês já encerrado em ERP) e o sistema retorna "Erro: registro D100 com inconsistência de CFOP". Validação PVA-SPED da Receita rejeita o arquivo. Prazo legal de transmissão: dia 25/10. Restam 4 dias úteis. [KB] sample-kb sped-fiscal-troubleshooting.pdf',
 'TI', 'InProgress', 'Medium', DATEADD(day, -3, SYSUTCDATETIME())),

-- TKT-15 — Apex Logística
('55555555-5555-5555-5555-555555555555',
 N'Roteirizador (Frota.io) parou de receber pedidos do TMS',
 N'Desde ontem 17h o Frota.io não está mais recebendo pedidos novos para roteirização. Webhook do TMS retorna 200 OK mas pedidos não aparecem na fila do Frota. Suspeita: token de API expirou na renovação automática. CD precisa reiniciar processo manual de roteirização para entregas de amanhã.',
 'TI', 'Open', 'Medium', DATEADD(day, -1, SYSUTCDATETIME())),

-- TKT-16 — Apex Mercado
('11111111-1111-1111-1111-111111111111',
 N'Câmera CFTV da loja Vila Mariana offline há 3 dias',
 N'4 câmeras do setor de hortifruti da loja Vila Mariana estão offline desde o início da semana. Outras câmeras da mesma loja funcionam. Suspeita: switch PoE local falhando ou cabo rompido em manutenção recente do gesso. Sem urgência operacional, mas regulação interna exige cobertura mínima. Visita técnica agendada para amanhã.',
 'TI', 'Open', 'Low', DATEADD(day, -3, SYSUTCDATETIME())),

-- TKT-17 — Apex Tech
('22222222-2222-2222-2222-222222222222',
 N'12 funcionários de matriz sem reset de senha SSO (Entra ID)',
 N'Após policy mensal de password rotation do Entra ID, 12 colaboradores não receberam o e-mail de reset. Investigação identificou: conta de service principal do script de notificação caiu em hard rate-limit por roll de credencial. Resolvido: senha aplicada manualmente + script ajustado para usar Managed Identity.',
 'TI', 'Resolved', 'Medium', DATEADD(day, -14, SYSUTCDATETIME())),

-- TKT-18 — Apex Moda (CRITICAL)
('33333333-3333-3333-3333-333333333333',
 N'CRÍTICO RESOLVIDO: Site institucional fora do ar 47min na Black Friday',
 N'Site apexmoda.com.br ficou fora do ar de 23h13 a 00h00 da Black Friday 2025 (47min). Causa: pico de tráfego excedeu auto-scaling do App Service (B3) configurado para max 10 instâncias quando o pico atingiu carga equivalente a ~17 instâncias. Marketing estima R$ 1.8M de GMV perdido. Postmortem documentado, scaling reconfigurado para max 30 + warm pool. [KB] sample-kb postmortem-blackfriday-2025.pdf',
 'TI', 'Resolved', 'Critical', DATEADD(day, -55, SYSUTCDATETIME())),

-- TKT-19 — Apex Casa
('44444444-4444-4444-4444-444444444444',
 N'Impressora térmica de etiquetas Zebra ZD230 desalinhada',
 N'Impressora ZD230 do CD imprimindo etiquetas com offset de 3mm para a direita. Testou ajuste manual do sensor de gap, sem efeito. Provável calibração necessária ou rolete de tração desgastado. Etiquetas desalinhadas estão sendo descartadas, custo médio de R$ 0,08 por etiqueta — desprezível mas atrapalha o fluxo.',
 'TI', 'Open', 'Low', DATEADD(day, -4, SYSUTCDATETIME())),

-- TKT-20 — Apex Logística
('55555555-5555-5555-5555-555555555555',
 N'VPN para parceiro last-mile (Loggi) sem conectar após renewal de cert',
 N'Site-to-site VPN entre Apex Logística e parceiro Loggi caiu após renovação do certificado X.509 em 28/04. IPsec phase-2 falha com "no proposal chosen". Loggi confirma que renovou o cert do lado deles. Suspeita: divergência de algoritmo de hash (SHA1 vs SHA256). Já escalado para fornecedor do firewall (Fortinet), aguardando contato.',
 'TI', 'Escalated', 'High', DATEADD(day, -4, SYSUTCDATETIME())),

-- -----------------------------------------------------------------------------
-- OPERACIONAL (10) — logística, estoque, separação, doca, montagem
-- -----------------------------------------------------------------------------

-- TKT-21 — Apex Mercado
('11111111-1111-1111-1111-111111111111',
 N'ESCALADO: Carga de hortifruti chegou a 14°C (limite 8°C)',
 N'Caminhão refrigerado #PLK-2D47 chegou ao CD Cajamar com produtos hortifruti registrando 14°C no datalogger. Limite ANVISA para verduras folhosas é 8°C. Carga de R$ 47.300 em risco. Decisão imediata: receber e descartar (perda total) ou recusar e responsabilizar transportadora. Vigilância sanitária notificada.',
 'Operacional', 'Escalated', 'High', DATEADD(day, 0, SYSUTCDATETIME())),

-- TKT-22 — Apex Tech
('22222222-2222-2222-2222-222222222222',
 N'3 Smart TVs Samsung 75" com tampa de palete danificada no recebimento',
 N'Lote de 24 TVs Samsung QLED 75" — paletização correta mas 3 unidades com a tampa de proteção de canto amassada. Aparente avaria de transporte. Embalagem secundária ainda íntegra, mas não dá para garantir integridade da tela sem teste. Comercial pediu que TI rastreie histórico de manuseio do palete via tag RFID.',
 'Operacional', 'InProgress', 'Medium', DATEADD(day, -2, SYSUTCDATETIME())),

-- TKT-23 — Apex Moda
('33333333-3333-3333-3333-333333333333',
 N'8 pedidos com SKU trocado na separação (Outubro Rosa)',
 N'Auditoria de pedido pré-expedição identificou 8 pedidos da campanha Outubro Rosa onde a blusa rosa premium foi substituída por blusa rosa básica (variação de R$ 240 entre os SKUs). Causa: SKUs com código de barras parecidos (terminam em 4747 vs 4774). Treinamento da turma da tarde agendado.',
 'Operacional', 'InProgress', 'Medium', DATEADD(day, -1, SYSUTCDATETIME())),

-- TKT-24 — Apex Casa
('44444444-4444-4444-4444-444444444444',
 N'Caminhão de móveis com 4h de atraso na doca CD-Cajamar',
 N'Caminhão de fornecedor (Tok&Stok) agendado para 08h chegou às 12h. Doca já estava ocupada com outras descargas. Operação atrasada em cascata. Custo estimado de hora-parada: R$ 380. Política contratual prevê cobrança de demurrage após 2h. [KB] sample-kb politica-doca-recebimento.pdf',
 'Operacional', 'Open', 'Medium', DATEADD(day, -1, SYSUTCDATETIME())),

-- TKT-25 — Apex Logística
('55555555-5555-5555-5555-555555555555',
 N'Motorista terceirizado sem CNH válida no embarque (categoria E)',
 N'Embarque agendado 14h para São Paulo→Curitiba (carga R$ 280k em eletrônicos). Motorista chegou e check-in detectou CNH categoria E vencida há 11 dias. Bloqueio imediato. Carga reagendada com risco de perder janela de descarga em Curitiba. Investigar processo de pré-validação de CNH na empresa terceirizada.',
 'Operacional', 'Escalated', 'High', DATEADD(day, 0, SYSUTCDATETIME())),

-- TKT-26 — Apex Mercado
('11111111-1111-1111-1111-111111111111',
 N'Inventário do estoque seco com divergência de 2,3% (R$ 18.700)',
 N'Inventário rotativo do estoque seco do CD apontou divergência de 2,3% (limite tolerável: 1%). R$ 18.700 a menor. Análise por SKU mostra concentração em itens de mercearia premium (azeite, vinhos, queijos). Suspeita de quebra de embalagem + furto interno + erro de baixa em sistema. Auditoria detalhada agendada.',
 'Operacional', 'Open', 'Medium', DATEADD(day, -3, SYSUTCDATETIME())),

-- TKT-27 — Apex Tech
('22222222-2222-2222-2222-222222222222',
 N'ESCALADO: Lote de 60 smartphones sem lacre original (suspeita violação)',
 N'Lote LX-789 de 60 unidades iPhone 15 Pro chegou no CD com caixas externas íntegras MAS lacres internos de fábrica violados em todas as 60 unidades. Distribuidor autorizado nega responsabilidade. Risco de receptação ou troca por unidades adulteradas. Auditoria + Polícia Federal acionada (lote vale R$ 480k).',
 'Operacional', 'Escalated', 'High', DATEADD(day, -1, SYSUTCDATETIME())),

-- TKT-28 — Apex Moda
('33333333-3333-3333-3333-333333333333',
 N'Loja Iguatemi pediu reposição urgente de coleção masculina',
 N'Loja Iguatemi vendeu 67% da coleção masculina inverno em 4 dias (esperado em 3 semanas). Gerente solicita reposição expressa via cross-docking. Estoque do CD tem cobertura para mais 2 semanas de venda no ritmo atual. Comercial e logística precisam alinhar prioridade vs outras lojas da rede.',
 'Operacional', 'Open', 'Low', DATEADD(day, -2, SYSUTCDATETIME())),

-- TKT-29 — Apex Casa
('44444444-4444-4444-4444-444444444444',
 N'Equipe de montagem indisponível no sábado — agenda de 14 clientes',
 N'Coordenador da equipe de montagem informou que sábado terá equipe reduzida (3 de 8 montadores) por motivos de saúde + folga programada. Agenda do dia tem 14 clientes confirmados. Capacidade real: ~6 montagens. Necessário decidir reagendamento ou contratação de equipe externa de emergência.',
 'Operacional', 'Open', 'Medium', DATEADD(day, -2, SYSUTCDATETIME())),

-- TKT-30 — Apex Logística
('55555555-5555-5555-5555-555555555555',
 N'Conferência de doca CD-Cajamar atrasou 2 turnos (causa: WMS lento)',
 N'Operação de conferência de docas do CD-Cajamar atrasou 2 turnos consecutivos esta semana. Causa-raiz identificada: lentidão no WMS da Manhattan Associates após upgrade de versão. Patch de hotfix aplicado na madrugada de quarta. Operação normalizada. Postmortem documentado.',
 'Operacional', 'Resolved', 'Medium', DATEADD(day, -10, SYSUTCDATETIME())),

-- -----------------------------------------------------------------------------
-- RH (10) — escalas, banco de horas, eSocial, ponto, reembolso
-- -----------------------------------------------------------------------------

-- TKT-31 — Apex Mercado
('11111111-1111-1111-1111-111111111111',
 N'Funcionária pede troca de turno por motivo médico (gravidez de risco)',
 N'Operadora de caixa do turno noturno apresentou atestado de gravidez de risco recomendando turno diurno. Loja precisa rebalancear escala — turno noturno com 1 vaga a cobrir. Política interna prevê transferência prioritária nesses casos. Encaminhar para coordenação de loja + RH-Folha. [KB] sample-kb politicas-rh-gestacao.pdf',
 'RH', 'Open', 'Low', DATEADD(day, -2, SYSUTCDATETIME())),

-- TKT-32 — Apex Tech
('22222222-2222-2222-2222-222222222222',
 N'Reembolso de treinamento AWS Solution Architect (R$ 2.400) há 45 dias',
 N'Engenheiro de dados solicitou reembolso de prova AWS SA (R$ 2.400) em 18/03. Aprovação técnica e gerencial OK desde 22/03. Travado em "aguardando processamento" desde então (45 dias). Funcionário começou a cobrar. Investigar atraso no fluxo financeiro/RH.',
 'RH', 'InProgress', 'Medium', DATEADD(day, -8, SYSUTCDATETIME())),

-- TKT-33 — Apex Moda
('33333333-3333-3333-3333-333333333333',
 N'Banco de horas de operadora de caixa com 80h excedidas (limite 60h)',
 N'Operadora da loja Vila Olímpia atingiu 142h de banco de horas positivo. CCT do varejo SP limita a 60h de saldo. Excedente precisa ser pago como hora extra (50%) ou compensado em até 60 dias. Coordenadora da loja precisa de orientação para escala de compensação ou aprovação de pagamento.',
 'RH', 'Open', 'Medium', DATEADD(day, -5, SYSUTCDATETIME())),

-- TKT-34 — Apex Casa
('44444444-4444-4444-4444-444444444444',
 N'Pedido de licença-paternidade — orientação de prazo (Empresa Cidadã?)',
 N'Designer de interiores pediu orientação sobre licença-paternidade. Filho previsto para 15/05. Apex Casa não é optante do programa Empresa Cidadã (licença estendida de 20 dias). Resolvido: comunicado oficial de 5 dias úteis CLT, com possibilidade de uso de 5 dias adicionais via banco de horas. RH atualizou cartilha interna.',
 'RH', 'Resolved', 'Low', DATEADD(day, -25, SYSUTCDATETIME())),

-- TKT-35 — Apex Logística
('55555555-5555-5555-5555-555555555555',
 N'Acidente de trabalho leve com motorista (corte na mão) — registro CAT',
 N'Motorista da equipe própria sofreu corte superficial na mão durante operação de descarga (lâmina de stretch). Atendido na UPA, 2 pontos, liberado. Evento configura acidente de trabalho — necessário emitir CAT no eSocial em até 24h úteis. RH-Folha tomando providência. Investigação de causa-raiz solicitada (uso de EPI?).',
 'RH', 'InProgress', 'Medium', DATEADD(day, 0, SYSUTCDATETIME())),

-- TKT-36 — Apex Mercado
('11111111-1111-1111-1111-111111111111',
 N'Solicitação de adiantamento salarial (40% do líquido) — prazo aprovação',
 N'Repositor de loja solicita adiantamento de 40% do salário líquido para emergência familiar (cirurgia da mãe). Política interna prevê até 30% sem análise especial; acima disso requer aprovação do gerente regional + RH. Funcionário sem histórico de adiantamento. Cobertura do benefício saúde já encaminhada paralelamente.',
 'RH', 'Open', 'Low', DATEADD(day, -1, SYSUTCDATETIME())),

-- TKT-37 — Apex Tech
('22222222-2222-2222-2222-222222222222',
 N'Convocação para entrevista de desligamento (turnover voluntário)',
 N'Vendedor da loja Morumbi pediu desligamento voluntário após 3,2 anos de empresa. Indo para concorrente. Resolvido: exit interview realizada na semana passada — feedback consolidado no relatório trimestral de turnover. Principais motivos: oferta salarial 32% maior + flexibilidade de horário no concorrente.',
 'RH', 'Resolved', 'Low', DATEADD(day, -15, SYSUTCDATETIME())),

-- TKT-38 — Apex Moda
('33333333-3333-3333-3333-333333333333',
 N'Atualização cadastral com erro no eSocial (vínculo S-2206)',
 N'Promoção interna de "Vendedor Pleno" para "Coordenador" cadastrada em 02/04, mas evento S-2206 do eSocial rejeitou: "ocorrência de período já transmitido". Aparentemente houve duplicidade de envio. Provedor do eSocial (Senior) abriu chamado. Bloqueia próximas alterações cadastrais do colaborador.',
 'RH', 'InProgress', 'Medium', DATEADD(day, -6, SYSUTCDATETIME())),

-- TKT-39 — Apex Casa
('44444444-4444-4444-4444-444444444444',
 N'ESCALADO: Reclamação anônima por canal de ética sobre supervisor',
 N'Canal de ética recebeu denúncia anônima sobre supervisor da loja Berrini (assédio moral, segundo relato). Política interna: investigação confidencial pelo Comitê de Ética em até 30 dias. Coordenação interna entre RH + Compliance + Jurídico em curso. Prazos legais e LGPD sendo respeitados.',
 'RH', 'Escalated', 'High', DATEADD(day, -7, SYSUTCDATETIME())),

-- TKT-40 — Apex Logística
('55555555-5555-5555-5555-555555555555',
 N'Renovação de exames periódicos de motoristas vencendo em 30 dias',
 N'12 motoristas da equipe própria com exames periódicos vencendo nos próximos 30 dias (toxicológico + audiometria + clínico). Médico do trabalho terceirizado tem capacidade para 4 exames/dia. Necessário agendar com antecedência para evitar bloqueio operacional. Lista enviada ao parceiro de medicina ocupacional.',
 'RH', 'Open', 'Medium', DATEADD(day, -2, SYSUTCDATETIME())),

-- -----------------------------------------------------------------------------
-- FINANCEIRO (10) — conciliação, fornecedores, tributos, auditoria
-- -----------------------------------------------------------------------------

-- TKT-41 — Apex Mercado
('11111111-1111-1111-1111-111111111111',
 N'Conciliação Cielo com diferença de R$ 2.847 não justificada (abr/26)',
 N'Conciliação automática Cielo do mês de abril identificou diferença de R$ 2.847,30 entre o relatório da adquirente e o ERP. 14 transações divergentes — todas de cartão de crédito parcelado. Suspeita: cobrança de MDR diferente do contrato (1,89% vs 2,12%). Necessário extrair detalhamento da Cielo + comparar contrato.',
 'Financeiro', 'InProgress', 'High', DATEADD(day, -4, SYSUTCDATETIME())),

-- TKT-42 — Apex Tech
('22222222-2222-2222-2222-222222222222',
 N'Fornecedor cobra 2x mesma NF-e (cabos HDMI) — solicita revisão',
 N'Fornecedor Multilaser apresentou 2 cobranças da NF-e #45821 (cabos HDMI premium, R$ 18.420). Conciliação financeira mostra que NF foi paga em 12/04 via PIX. Provável erro de gestão financeira do fornecedor. Solicitar comprovante PIX + escalar com Vendor Manager para evitar danos à relação.',
 'Financeiro', 'Open', 'Medium', DATEADD(day, -3, SYSUTCDATETIME())),

-- TKT-43 — Apex Moda
('33333333-3333-3333-3333-333333333333',
 N'DARF de IRRF gerada com base de cálculo errada (folha 10/2026)',
 N'Sistema de folha gerou DARF de IRRF outubro com base errada — usou folha bruta sem deduzir contribuição previdenciária. Diferença R$ 38.470 a maior. Vencimento 20/11 (5 dias úteis). Necessário gerar DARF retificadora antes da transmissão. Fornecedor de folha (Senior) já notificado para corrigir parametrização.',
 'Financeiro', 'InProgress', 'High', DATEADD(day, -1, SYSUTCDATETIME())),

-- TKT-44 — Apex Casa
('44444444-4444-4444-4444-444444444444',
 N'Boleto de cliente PJ vencido sem retorno do banco (Banco do Brasil)',
 N'Boleto #99841 de cliente PJ no valor R$ 47.300 com vencimento 20/04 não retornou liquidação até 30/04. Cliente afirma ter pago via PIX no dia. Banco do Brasil em processo de conciliação interna. Crédito do cliente travado. Necessário levantar status com BB-Cobrança para liberar próximos pedidos.',
 'Financeiro', 'Open', 'Low', DATEADD(day, -10, SYSUTCDATETIME())),

-- TKT-45 — Apex Logística
('55555555-5555-5555-5555-555555555555',
 N'Ressarcimento de combustível sem comprovante anexado (motorista)',
 N'Motorista solicitou ressarcimento de R$ 287 em combustível (viagem SP-Rio) sem anexar nota fiscal de abastecimento. Política financeira exige NF para reembolso acima de R$ 100. Resolvido: ressarcimento aprovado em caráter excepcional + comunicado lembrete para todas as equipes.',
 'Financeiro', 'Resolved', 'Low', DATEADD(day, -16, SYSUTCDATETIME())),

-- TKT-46 — Apex Mercado
('11111111-1111-1111-1111-111111111111',
 N'Dúvida sobre retenção de IRRF + INSS sobre serviço de TI (PJ)',
 N'Contratação de consultoria de TI (CNPJ MEI) para integração de sistemas — valor R$ 12.500. Fiscal pediu orientação sobre retenções aplicáveis. MEI tem regras específicas de retenção de IRRF (1,5%) e INSS (11% se serviço de natureza específica). Necessário confirmar enquadramento exato antes do pagamento. [KB] sample-kb retencoes-tributarias-pj.pdf',
 'Financeiro', 'Open', 'Low', DATEADD(day, -4, SYSUTCDATETIME())),

-- TKT-47 — Apex Tech
('22222222-2222-2222-2222-222222222222',
 N'PIX recebido R$ 8.470 sem identificação do cliente (rastreio necessário)',
 N'Recebimento via PIX de R$ 8.470,00 em 28/04 sem identificação no campo "remetente" ou descrição. Tesouraria precisa rastrear via API do Bacen ou planilha de pedidos abertos. Possível pagamento de pedido B2B aguardando faturamento. Crédito não pode ser apropriado sem identificação.',
 'Financeiro', 'InProgress', 'Medium', DATEADD(day, -3, SYSUTCDATETIME())),

-- TKT-48 — Apex Moda
('33333333-3333-3333-3333-333333333333',
 N'SPED Contribuições — registro M210 inconsistente (PIS/COFINS)',
 N'PVA-SPED Contribuições rejeitou arquivo de março/2026 com erro no registro M210 (apuração PIS não cumulativo). Diferença identificada: R$ 12.300 a maior na base de cálculo de créditos. Resolvido: ajuste retroativo + transmissão dentro do prazo (25/04). Causa: parametrização de CFOP de devolução. [KB] sample-kb sped-contribuicoes-erros.pdf',
 'Financeiro', 'Resolved', 'Medium', DATEADD(day, -12, SYSUTCDATETIME())),

-- TKT-49 — Apex Casa
('44444444-4444-4444-4444-444444444444',
 N'Auditoria interna pediu evidência de contrato de leasing (frota)',
 N'Auditoria interna em andamento pediu cópia digitalizada + assinatura eletrônica do contrato de leasing financeiro da frota de utilitários (12 veículos VW Saveiro, contrato Bradesco Leasing). Tesouraria precisa localizar nos arquivos digitais e enviar até 05/05.',
 'Financeiro', 'Resolved', 'Low', DATEADD(day, -7, SYSUTCDATETIME())),

-- TKT-50 — Apex Logística
('55555555-5555-5555-5555-555555555555',
 N'Cobrança de multa ANTT em duplicidade (R$ 1.870)',
 N'ANTT enviou 2 cobranças da mesma multa por excesso de peso (auto AIT-2026-014782) no valor de R$ 1.870 cada. Veículo, data, local e valor idênticos. Provável falha do sistema da ANTT. Necessário abrir processo de defesa administrativa solicitando cancelamento de uma das cobranças. Prazo de defesa: 30 dias.',
 'Financeiro', 'Open', 'Medium', DATEADD(day, -5, SYSUTCDATETIME()));
GO

-- -----------------------------------------------------------------------------
-- Validação rápida pós-seed (smoke check)
-- -----------------------------------------------------------------------------
DECLARE @total INT = (SELECT COUNT(*) FROM dbo.tbl_tickets);
DECLARE @open INT = (SELECT COUNT(*) FROM dbo.tbl_tickets WHERE status='Open');
DECLARE @inprogress INT = (SELECT COUNT(*) FROM dbo.tbl_tickets WHERE status='InProgress');
DECLARE @resolved INT = (SELECT COUNT(*) FROM dbo.tbl_tickets WHERE status='Resolved');
DECLARE @escalated INT = (SELECT COUNT(*) FROM dbo.tbl_tickets WHERE status='Escalated');

PRINT CONCAT('HelpSphere: ', @total, ' tickets carregados.');
PRINT CONCAT('  Status: Open=', @open, ', InProgress=', @inprogress, ', Resolved=', @resolved, ', Escalated=', @escalated);
GO
