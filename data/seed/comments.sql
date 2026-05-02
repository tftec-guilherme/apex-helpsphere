-- =============================================================================
-- HelpSphere — seed/comments.sql
-- ~80 comments distribuídos pelos 50 tickets, coerentes com narrativa
--
-- Distribuição planejada:
--   Open (20)        → 0-1 comments cada (~10 comments total)
--   InProgress (15)  → 1-2 comments cada (~28 comments total)
--   Resolved (10)    → 2-3 comments cada (~25 comments total)
--   Escalated (5)    → 3 comments cada     (~15 comments total)
--   TOTAL ~78 comments
--
-- Authors fictícios da operação Apex (consistentes ao longo do dataset):
--   Diego Almeida   = atendente N1 do canal de atendimento
--   Marina Souza    = especialista N2 técnico/comercial
--   Carla Ribeiro   = gerente comercial (Apex Tech + Apex Moda)
--   Bruno Tavares   = gerente operacional (CDs + lojas)
--   Letícia Fonseca = analista RH-Folha
--   Roberto Vieira  = analista financeiro/tributário
--   agent-ai        = agente IA (apenas tickets onde Lab Final processou)
--
-- Pré-requisito: tickets já carregados (ticket_id sequencial 1..50)
-- =============================================================================

SET NOCOUNT ON;
GO

-- Limpa antes de re-seed
DELETE FROM dbo.tbl_comments;
DBCC CHECKIDENT ('dbo.tbl_comments', RESEED, 0);
GO

INSERT INTO dbo.tbl_comments (ticket_id, author, content, created_at) VALUES

-- TKT-1 (Comercial / InProgress) — Devolução geladeira fora prazo
(1, N'Diego Almeida',
 N'Cliente atendido. Confirmei que a compra foi 12/03 e abertura do chamado 25/03 (13 dias depois). Política CDC art. 49 prevê 7 dias para arrependimento em compra à distância, mas a venda foi presencial — política CDC não se aplica aqui. Encaminhando para a Carla avaliar política comercial interna.',
 DATEADD(day, -7, SYSUTCDATETIME())),
(1, N'Carla Ribeiro',
 N'Olhei o caso. Nossa política comercial interna prevê troca em até 30 dias por produto avariado ou diferente do comprado, NÃO por desistência. Como o cliente é primeira compra na loja, vou autorizar excepcionalmente um voucher de R$ 200 para próxima compra como retenção, sem devolução do produto. Diego, comunique ao cliente.',
 DATEADD(day, -3, SYSUTCDATETIME())),

-- TKT-3 (Comercial / InProgress / High) — NFe rejeição 539
(3, N'Marina Souza',
 N'Rejeição 539 = "CFOP de devolução em operação que não é devolução". Olhei no ERP: o pedido foi cadastrado com CFOP 1.202 (devolução de venda) por engano. Deveria ser 5.102 (venda dentro do estado) ou 6.102 (interestadual). Corrigindo agora e re-emitindo a NF-e.',
 DATEADD(hour, -3, SYSUTCDATETIME())),
(3, N'Marina Souza',
 N'NF-e re-emitida com CFOP 5.102, autorizada pela SEFAZ-SP às 14h22. Liberando expedição. Cliente avisado que a entrega está mantida para amanhã 10h. Bug do template do ERP que cadastra CFOP errado em pedido B2B será reportado para fornecedor (TOTVS).',
 DATEADD(hour, -1, SYSUTCDATETIME())),

-- TKT-5 (Comercial / Resolved) — Cobrança duplicada frete
(5, N'Roberto Vieira',
 N'Confirmado: ambas as entradas correspondem ao mesmo conhecimento de transporte (CTe 098745). Lançamento duplicado pelo financeiro intra-grupo. Estorno de R$ 1.247 emitido em 18/02.',
 DATEADD(day, -25, SYSUTCDATETIME())),
(5, N'Bruno Tavares',
 N'Para evitar reincidência, ajustamos o processo: matching automático CTe↔fatura no fechamento mensal, com flag de duplicidade quando mesma chave CTe aparece 2+ vezes em janela de 30 dias. Implementado em 22/02.',
 DATEADD(day, -23, SYSUTCDATETIME())),

-- TKT-6 (Comercial / Open / High) — Notebook R$ 199
(6, N'Carla Ribeiro',
 N'Dimensão do problema: 47 pedidos × R$ 1.800 prejuízo médio = R$ 84.600 se honrarmos todos. Já há prints circulando. Acionei o Jurídico e o Marketing para resposta unificada nas próximas 2h. Cancelamento + cupom de 10% off como retenção é a posição preliminar.',
 DATEADD(hour, -1, SYSUTCDATETIME())),

-- TKT-7 (Comercial / InProgress) — Coleção peças trocadas
(7, N'Bruno Tavares',
 N'Verifiquei o romaneio C-1247 vs separação. Confirmação: 47 peças trocadas (P quando deveria ser M/G). Causa-raiz: nova operadora da turma da tarde sem treinamento prévio em SKUs de coleção sazonal. Iniciando reposição expressa: cross-dock direto fornecedor→Iguatemi previsto p/ chegar em 36h.',
 DATEADD(day, -2, SYSUTCDATETIME())),
(7, N'Carla Ribeiro',
 N'Conversei com a gerente da Iguatemi: aceitam manter PDV abrindo com a coleção parcial até a reposição chegar. Combinamos comunicado interno de "novas peças chegam dia 04" para gerar expectativa positiva.',
 DATEADD(day, -1, SYSUTCDATETIME())),

-- TKT-8 (Comercial / Resolved) — Cobrança chocolate Lindt
(8, N'Diego Almeida',
 N'Análise do CFTV mostrou que o produto foi bipado por engano pelo operador (estava em outro carrinho na frente). Estorno de R$ 89 + 100 pontos extras de fidelidade aplicados em 05/04. Cliente aceitou e elogiou rapidez do retorno.',
 DATEADD(day, -17, SYSUTCDATETIME())),
(8, N'Bruno Tavares',
 N'Lembrete reforçado para a turma: aguardar finalizar UM cliente antes de iniciar leitura do próximo. Processo já era padrão, mas estávamos relaxados em horário de baixo movimento.',
 DATEADD(day, -16, SYSUTCDATETIME())),

-- TKT-10 (Comercial / InProgress) — Cancelamento parcelado 28h
(10, N'Diego Almeida',
 N'Conversei com o cliente. Ele confirma que recebeu o e-mail de confirmação do parcelamento mas não abriu o anexo. Está com superendividamento e precisa cancelar. Por estar dentro dos 7 dias do CDC (compra online), tecnicamente temos obrigação. Encaminhando para Carla aprovar.',
 DATEADD(day, -5, SYSUTCDATETIME())),
(10, N'Carla Ribeiro',
 N'Aprovado. CDC prevalece sobre política interna nesse caso. Estorno do parcelamento sendo processado pelo Itaú. Comunicado ao cliente. Vamos rever a política interna para alinhar prazo de cancelamento simples ao prazo CDC.',
 DATEADD(day, -2, SYSUTCDATETIME())),

-- TKT-11 (TI / InProgress / Medium) — POS travando NFC-e
(11, N'Marina Souza',
 N'Capturei o trace do PDV no horário do travamento: chamada SOAP para SEFAZ-SP demorou 47s antes de timeout. Conferi com outras lojas: somente Pinheiros tem essa lentidão. Suspeita: link de internet local da loja Pinheiros está com perda de pacotes intermitente (ping da operadora confirmou 3% loss).',
 DATEADD(day, -1, SYSUTCDATETIME())),
(11, N'Marina Souza',
 N'Operadora abrirá chamado de manutenção do link na loja amanhã pela manhã. Como mitigação imediata: alteramos o timeout do client SOAP de 30s para 60s — assim a venda completa antes do usuário re-tentar. Não é fix definitivo mas estabiliza até a operadora resolver.',
 DATEADD(hour, -6, SYSUTCDATETIME())),

-- TKT-12 (TI / InProgress / CRITICAL) — Integração ERP↔Magento
(12, N'Marina Souza',
 N'Identificado: 18% dos pedidos têm payload de extras/personalização que ultrapassa 256KB (limite atual do RabbitMQ). Solução curta: aumentar para 1MB no broker (mudança de config, sem deploy). Solução longa: refatorar payload para usar referências em vez de payload inline.',
 DATEADD(hour, -22, SYSUTCDATETIME())),
(12, N'Marina Souza',
 N'Config aplicada às 04h da manhã. Mensagens reprocessadas — 100% dos pedidos pendentes sincronizados em ~40min. Estoque agora consistente. Refactor do payload entrando no backlog Q3 com prioridade alta.',
 DATEADD(hour, -2, SYSUTCDATETIME())),

-- TKT-14 (TI / InProgress / Medium) — SPED Fiscal CFOP
(14, N'Roberto Vieira',
 N'Identifiquei 17 NF-e de devolução em set/2026 com CFOP 5.202 mas a operação é 1.202 (devolução de compra). Erro de cadastro recorrente. Corrigindo agora via script SQL no ERP. SPED será regerado e re-enviado até dia 23/10 (2 dias antes do prazo).',
 DATEADD(day, -2, SYSUTCDATETIME())),

-- TKT-15 (TI / Open) — Frota.io webhook
(15, N'Marina Souza',
 N'Confirmei que o token expirou em 30/04 23:59. Auto-renew falhou (script com permissão antiga). Renovei manualmente e webhooks voltaram a fluir. Backlog de pedidos (~80) sendo processado. Vou agendar o fix do auto-renew para amanhã pela manhã.',
 DATEADD(hour, -4, SYSUTCDATETIME())),

-- TKT-17 (TI / Resolved) — Reset SSO 12 funcionários
(17, N'Marina Souza',
 N'Investigação: o service principal do script de notificação atingiu rate limit do MS Graph (10k requests/dia) durante roll mensal porque deduplicação de e-mails estava OFF, causando re-tentativa em loop. 12 e-mails pararam na fila.',
 DATEADD(day, -15, SYSUTCDATETIME())),
(17, N'Marina Souza',
 N'Corrigido: (a) senhas aplicadas manualmente para os 12 colaboradores afetados; (b) deduplicação ON; (c) script migrado para Managed Identity (escopo limitado, sem rate limit por usuário). Postmortem documentado em Confluence.',
 DATEADD(day, -14, SYSUTCDATETIME())),

-- TKT-18 (TI / Resolved / CRITICAL) — Black Friday 47min
(18, N'Marina Souza',
 N'Postmortem completo: pico 23h13 atingiu carga de ~5.200 RPS quando capacidade efetiva era ~3.400 RPS (10 instâncias B3 saturadas). Auto-scaling demorou 4min para escalar para 15 (máx config), insuficiente. Site voltou após 47min quando config emergencial subiu max para 25.',
 DATEADD(day, -56, SYSUTCDATETIME())),
(18, N'Carla Ribeiro',
 N'Marketing estimou GMV perdido em R$ 1.8M (média histórica de R$ 38k/min em pico de Black Friday). Vamos reapresentar a proposta de Premium tier do App Service para este ano com esses números.',
 DATEADD(day, -55, SYSUTCDATETIME())),
(18, N'Marina Souza',
 N'Configurações atualizadas para Black Friday 2026: max instances = 30 (B3), warm pool de 5 instâncias pré-aquecidas, plano de mudança temporária para P1V3 nos 7 dias do evento. Runbook de incident response também atualizado.',
 DATEADD(day, -50, SYSUTCDATETIME())),

-- TKT-20 (TI / Escalated / Medium) — VPN Loggi
(20, N'Marina Souza',
 N'Confirmado divergência: nosso lado está com SHA1, Loggi com SHA256 após renovação. Padrão correto = SHA256. Vamos atualizar nosso side para SHA256 — janela de manutenção sábado 23h.',
 DATEADD(day, -3, SYSUTCDATETIME())),
(20, N'Marina Souza',
 N'Janela de sábado adiada — Fortinet pediu validação adicional do nosso firmware (3.6.x não é mais suportado para SHA256 no DH group 14). Precisa upgrade firmware antes. Escalado para 2nd-level Fortinet via parceiro.',
 DATEADD(day, -2, SYSUTCDATETIME())),
(20, N'Bruno Tavares',
 N'Workaround: configurei rota alternativa via tunnel reverso da Loggi para os pedidos críticos do dia. Não é escalável mas mantém operação. Aguardando upgrade definitivo.',
 DATEADD(day, -1, SYSUTCDATETIME())),

-- TKT-21 (Operacional / Escalated / High) — Hortifruti 14°C
(21, N'Bruno Tavares',
 N'Decisão: receber e descartar a carga (perda total R$ 47.300). Vigilância sanitária notificada e validou descarte. Transportadora será responsabilizada via apólice de carga. Documentação fotográfica feita.',
 DATEADD(hour, -3, SYSUTCDATETIME())),
(21, N'Bruno Tavares',
 N'Escalei para diretoria operacional: este é o 3º caso da mesma transportadora em 2 meses (CARGOMAIS Transportes). Avaliar recissão contratual.',
 DATEADD(hour, -2, SYSUTCDATETIME())),
(21, N'Roberto Vieira',
 N'Apólice da Tokio Marine cobre 100% do valor. Sinistro aberto às 16h, expectativa de ressarcimento em 30 dias úteis. Documentação enviada.',
 DATEADD(hour, -1, SYSUTCDATETIME())),

-- TKT-22 (Operacional / InProgress) — TVs Samsung tampa danificada
(22, N'Bruno Tavares',
 N'Rastreamento RFID: o palete passou por 3 manuseios — fornecedor (origem), terminal de transbordo Curitiba, doca CD-Cajamar. Avaria provavelmente no transbordo (registro de impacto >2g no acelerômetro do palete às 03h17 de quinta).',
 DATEADD(day, -1, SYSUTCDATETIME())),
(22, N'Marina Souza',
 N'Teste das 3 unidades: ligadas, todas funcionam normalmente. Tela íntegra. Decisão: aceitar e vender com desconto de 15% (cosmético-only) na liquidação fim de mês. Custo da avaria ressarcido pela seguradora do transbordo.',
 DATEADD(hour, -8, SYSUTCDATETIME())),

-- TKT-23 (Operacional / InProgress) — SKUs trocados Outubro Rosa
(23, N'Bruno Tavares',
 N'Retroalimentando os 8 pedidos: 6 já enviados, 2 ainda na expedição. Para os 6 enviados, vou contatar clientes proativamente oferecendo: (a) troca expressa sem custo + manter SKU básico como brinde, (b) estorno parcial da diferença.',
 DATEADD(hour, -10, SYSUTCDATETIME())),
(23, N'Diego Almeida',
 N'5 dos 6 clientes contactados aceitaram opção (a). 1 preferiu (b). 2 pedidos da expedição corrigidos antes do envio. Treinamento adicional sobre SKUs sazonais agendado para terça.',
 DATEADD(hour, -4, SYSUTCDATETIME())),

-- TKT-25 (Operacional / Escalated / High) — Motorista CNH vencida
(25, N'Bruno Tavares',
 N'Motorista bloqueado e dispensado do embarque. Empresa terceirizada (Trans-Oeste) acionada para enviar substituto em 2h. Carga reagendada para 18h. Ainda devemos chegar Curitiba dentro da janela.',
 DATEADD(hour, -2, SYSUTCDATETIME())),
(25, N'Letícia Fonseca',
 N'Apex Logística não tem responsabilidade trabalhista (motorista é da Trans-Oeste). Mas: notificamos formalmente a Trans-Oeste que processo de pré-validação CNH deles falhou. Cláusula contratual prevê multa de 5% sobre faturamento mensal por caso. Jurídico avaliando aplicação.',
 DATEADD(hour, -1, SYSUTCDATETIME())),
(25, N'Bruno Tavares',
 N'Substituto chegou no horário, embarcou, partiu 18h12. Carga em rota normal. Vamos exigir auditoria completa do processo de pré-validação CNH da Trans-Oeste antes de novos embarques.',
 DATEADD(minute, -30, SYSUTCDATETIME())),

-- TKT-27 (Operacional / Escalated / High) — Smartphones violados
(27, N'Bruno Tavares',
 N'Lote isolado em área restrita do CD. Foto de cada caixa enviada para auditoria interna + Apple (distribuidor oficial). Nenhuma unidade liberada para venda. Risco financeiro: R$ 480k em estoque congelado.',
 DATEADD(hour, -16, SYSUTCDATETIME())),
(27, N'Marina Souza',
 N'IMEIs verificados via API Apple Authorized: 100% dos aparelhos são genuínos (verificação remota). Mas lacre violado significa que o aparelho pode ter sido aberto e devolvido. Apple confirmou: lote será coletado para perícia e substituído integralmente.',
 DATEADD(hour, -8, SYSUTCDATETIME())),
(27, N'Roberto Vieira',
 N'Polícia Federal informada (procedimento padrão para suspeita de fraude em lote >R$ 100k). Sem necessidade de B.O. presencial agora — procedimento documental. Apple coordenará com PF a investigação no distribuidor de origem.',
 DATEADD(hour, -2, SYSUTCDATETIME())),

-- TKT-30 (Operacional / Resolved) — WMS Manhattan lentidão
(30, N'Marina Souza',
 N'Causa-raiz: upgrade do WMS para v2026.4 introduziu regressão no índice da tabela de movimentação. Query de conferência de doca subiu de ~80ms para ~4.2s. Hotfix do fornecedor (Manhattan) aplicado quarta 02h.',
 DATEADD(day, -10, SYSUTCDATETIME())),
(30, N'Bruno Tavares',
 N'Operação normalizada nas conferências de quinta e sexta. Nenhum atraso adicional. Fornecedor solicitou abertura de RCA formal; documentação enviada.',
 DATEADD(day, -8, SYSUTCDATETIME())),
(30, N'Marina Souza',
 N'Postmortem completo: vamos exigir do Manhattan smoke test em ambiente de staging (que tem dataset realista) antes de promover qualquer hotfix para produção. Cláusula sendo adicionada à renovação contratual.',
 DATEADD(day, -7, SYSUTCDATETIME())),

-- TKT-31 (RH / Open) — Funcionária troca turno gravidez
(31, N'Letícia Fonseca',
 N'Caso protocolado. Encaminhei para a coordenação de loja avaliar a escala. Política da empresa garante prioridade nesses casos. Posicionamento esperado em até 5 dias úteis.',
 DATEADD(day, -1, SYSUTCDATETIME())),

-- TKT-32 (RH / InProgress / Medium) — Reembolso AWS R$ 2.400
(32, N'Letícia Fonseca',
 N'Investigando: reembolso aprovado em 22/03 deveria ter entrado na folha de abril. Conferência financeira sem registro do lançamento. Provável que a aprovação não chegou ao financeiro pelo bug da integração com fluxo legado. Forçando lançamento manual na folha de maio.',
 DATEADD(day, -7, SYSUTCDATETIME())),
(32, N'Roberto Vieira',
 N'Confirmado lançamento manual de R$ 2.400 na folha de maio (referência 04/2026), pago em 30/04 via mesma conta-folha. Fix do fluxo de aprovação→financeiro entrou no backlog de TI.',
 DATEADD(day, -2, SYSUTCDATETIME())),

-- TKT-33 (RH / Open) — Banco horas excedido
(33, N'Letícia Fonseca',
 N'Olhei o caso: 142h é uma das maiores na rede neste trimestre. Sugiro plano combinado: (a) folga compensatória de 5 dias úteis em maio, (b) pagamento de 30h excedentes ao limite de 60h. Aguardando aprovação da coordenadora regional antes de comunicar a colaboradora.',
 DATEADD(day, -2, SYSUTCDATETIME())),

-- TKT-34 (RH / Resolved) — Licença-paternidade
(34, N'Letícia Fonseca',
 N'Confirmado: Apex Casa não é optante de Empresa Cidadã. CLT garante 5 dias corridos de licença. Comunicado oficial enviado em 12/04. Colaborador aceitou + utilizará 5 dias adicionais via banco de horas para compor 2 semanas próximas ao parto.',
 DATEADD(day, -25, SYSUTCDATETIME())),
(34, N'Letícia Fonseca',
 N'Cartilha interna do RH atualizada para esclarecer essa diferença prospectivamente. Sugestão de avaliação custo-benefício de aderir ao Empresa Cidadã enviada para diretoria de RH (5 a 8 colaboradores ano se beneficiariam).',
 DATEADD(day, -23, SYSUTCDATETIME())),

-- TKT-35 (RH / InProgress / Medium) — Acidente trabalho motorista
(35, N'Letícia Fonseca',
 N'CAT emitida no eSocial às 11h22 (dentro do prazo de 24h úteis). Motorista liberado pela UPA, retorna ao trabalho amanhã com restrição de carga manual por 5 dias. EPI (luva resistente a corte) será fornecido para toda equipe — auditoria identificou que apenas 60% usavam.',
 DATEADD(hour, -3, SYSUTCDATETIME())),

-- TKT-37 (RH / Resolved) — Exit interview
(37, N'Letícia Fonseca',
 N'Exit interview realizada em 18/04. Principais motivos: oferta salarial 32% maior + flexibilidade home-office no concorrente. Cliente do feedback estruturado: avaliação geral 8/10, recomendaria a empresa.',
 DATEADD(day, -14, SYSUTCDATETIME())),
(37, N'Carla Ribeiro',
 N'Esse é o 3º vendedor sênior que sai por motivo de remuneração no trimestre. Vou propor revisão da grade salarial para vendedores sênior em maio. Tendência confirmada nos relatórios trimestrais.',
 DATEADD(day, -10, SYSUTCDATETIME())),

-- TKT-38 (RH / InProgress / Medium) — eSocial duplicidade
(38, N'Letícia Fonseca',
 N'Senior já abriu chamado #98742 com prazo de retorno de 5 dias úteis. Enquanto isso, novas alterações cadastrais para esse colaborador estão suspensas (sistema bloqueia para evitar agravamento da inconsistência).',
 DATEADD(day, -5, SYSUTCDATETIME())),
(38, N'Letícia Fonseca',
 N'Resposta da Senior: bug confirmado na rotina de retransmissão automática que enviou o evento 2x. Patch agendado para release de maio. Mitigação manual: rotina interna de pré-validação de duplicidade já implementada.',
 DATEADD(day, -1, SYSUTCDATETIME())),

-- TKT-39 (RH / Escalated / High) — Denúncia ética
(39, N'Letícia Fonseca',
 N'Denúncia recebida e protocolada pelo Comitê de Ética. Sigilo total mantido. Investigação em curso (testemunhas colaterais sendo entrevistadas). Prazo legal: até 30 dias para conclusão preliminar.',
 DATEADD(day, -7, SYSUTCDATETIME())),
(39, N'Roberto Vieira',
 N'Compliance e Jurídico envolvidos. Procedimento seguindo política aprovada pelo Conselho. Atualizações apenas para a equipe restrita (não constam em sistemas operacionais).',
 DATEADD(day, -5, SYSUTCDATETIME())),

-- TKT-40 (RH / Open) — Exames periódicos
(40, N'Letícia Fonseca',
 N'Lista enviada para a Asas Saúde Ocupacional. Agendamento sugerido: 3 motoristas/dia em 4 dias (semana de 13/05). Coordenação operacional precisa liberar os motoristas em janelas de 2h para o exame.',
 DATEADD(day, -1, SYSUTCDATETIME())),

-- TKT-41 (Financeiro / InProgress / High) — Conciliação Cielo
(41, N'Roberto Vieira',
 N'Extração detalhada da Cielo (API v3) identificou: 14 transações com MDR de 2,12% em vez de 1,89% (tabela contratada). Causa: cards usando bandeira Hipercard (não inclusa no contrato negociado). Total cobrado a maior: R$ 2.847,30.',
 DATEADD(day, -3, SYSUTCDATETIME())),
(41, N'Roberto Vieira',
 N'Cielo confirmou erro de classificação de bandeira (Hipercard estava no escopo do contrato mas faturamento estava em tabela default). Estorno de R$ 2.847,30 sendo processado para crédito na próxima fatura.',
 DATEADD(day, -1, SYSUTCDATETIME())),

-- TKT-42 (Financeiro / Open) — Fornecedor cobra 2x
(42, N'Roberto Vieira',
 N'Localizei o comprovante PIX (chave do fornecedor: contato@multilaser.com.br) no extrato de 12/04 às 16h47, valor R$ 18.420. E-mail formal enviado ao Multilaser anexando comprovante e solicitando cancelamento da segunda cobrança em até 5 dias úteis.',
 DATEADD(day, -2, SYSUTCDATETIME())),

-- TKT-43 (Financeiro / InProgress / Medium) — DARF IRRF errada
(43, N'Roberto Vieira',
 N'Bug confirmado: parametrização do Senior Folha está somando contribuição previdenciária à base IRRF em vez de subtrair. Impacto: 38.470 a maior. Senior reportará patch em 5 dias úteis (antes do vencimento 20/11).',
 DATEADD(day, 0, SYSUTCDATETIME())),

-- TKT-44 (Financeiro / Open) — Boleto sem retorno BB
(44, N'Roberto Vieira',
 N'Cliente enviou comprovante de PIX de R$ 47.300 (não boleto). Investigando se o PIX caiu em conta diferente. Se confirmado, vamos baixar manualmente e desbloquear próximos pedidos. Prazo: 48h.',
 DATEADD(day, -8, SYSUTCDATETIME())),

-- TKT-45 (Financeiro / Resolved) — Ressarcimento sem NF
(45, N'Roberto Vieira',
 N'Aprovado em caráter excepcional (motorista é colaborador antigo, primeira ocorrência). Ressarcimento de R$ 287 efetuado via folha de abril.',
 DATEADD(day, -16, SYSUTCDATETIME())),
(45, N'Letícia Fonseca',
 N'Comunicado lembrete enviado para todas as equipes operacionais: NF obrigatória para reembolso acima de R$ 100. Treinamento integrado nas reuniões mensais de equipe.',
 DATEADD(day, -15, SYSUTCDATETIME())),

-- TKT-47 (Financeiro / InProgress / Medium) — PIX sem ID
(47, N'Roberto Vieira',
 N'Rastreamento via end-to-end ID do PIX identificou: pagamento corresponde ao pedido B2B #PB-3471 (Apex Tech vendendo lote de 50 monitores para empresa parceira). Cliente esqueceu de identificar. Crédito apropriado, NF emitida.',
 DATEADD(day, -1, SYSUTCDATETIME())),

-- TKT-48 (Financeiro / Resolved) — SPED Contribuições M210
(48, N'Roberto Vieira',
 N'Causa: NF-e de devolução com CFOP 1.202 (entrada) estava sendo lida pelo SPED como crédito de PIS/COFINS quando deveria ser estorno do crédito original. Correção retroativa aplicada no SPED.',
 DATEADD(day, -13, SYSUTCDATETIME())),
(48, N'Roberto Vieira',
 N'SPED retransmitido em 24/04 (1 dia antes do vencimento). Aceito pela Receita sem alertas. Parametrização do ERP corrigida para evitar reincidência.',
 DATEADD(day, -12, SYSUTCDATETIME())),

-- TKT-49 (Financeiro / Resolved) — Auditoria leasing
(49, N'Roberto Vieira',
 N'Contrato Bradesco Leasing #BL-2024-08741 localizado no DocuSign (assinatura eletrônica). PDF + certificado de assinatura enviados para auditoria em 04/05.',
 DATEADD(day, -7, SYSUTCDATETIME())),
(49, N'Roberto Vieira',
 N'Auditoria validou. Recomendação aceita: documentos de leasing devem ser indexados também no SharePoint da Tesouraria com tags de busca específicas (contraparte, vigência, valor). Implementado.',
 DATEADD(day, -5, SYSUTCDATETIME())),

-- TKT-50 (Financeiro / Open) — Multa ANTT duplicidade
(50, N'Roberto Vieira',
 N'Defesa administrativa sendo redigida. Anexos: print das 2 cobranças idênticas + extrato comprovando que a multa original já foi paga em 02/04. Protocolo da defesa: até 25/05 (30 dias do recebimento da segunda cobrança).',
 DATEADD(day, -4, SYSUTCDATETIME()));
GO

DECLARE @c INT = (SELECT COUNT(*) FROM dbo.tbl_comments);
PRINT CONCAT('HelpSphere: ', @c, ' comments carregados.');
GO
