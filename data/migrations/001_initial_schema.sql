-- =============================================================================
-- HelpSphere — 001_initial_schema.sql
-- Migration inicial: 3 tabelas (tenants, tickets, comments)
-- Target: Azure SQL Database (Serverless tier para custo)
-- T-SQL syntax | idempotent (IF OBJECT_ID guards)
--
-- Story: 06.5a (HelpSphere Template)
-- Sessão: 2.2 — Schema SQL + Seeds
-- Audiência: arquiteto sênior (production-pattern visível, sem bloat)
-- =============================================================================

SET NOCOUNT ON;
GO

-- -----------------------------------------------------------------------------
-- tbl_tenants — multi-tenancy via UNIQUEIDENTIFIER
--
-- Design:
--   * GUID como PK em vez de IDENTITY INT — preparação para sharding futuro
--     e evita disclosure de "quantos tenants temos"
--   * brand_name UNIQUE — cada marca Apex aparece uma única vez
--   * created_at default UTC — UTC sempre, conversão para local fica no app
-- -----------------------------------------------------------------------------
IF OBJECT_ID('dbo.tbl_tenants', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.tbl_tenants (
        tenant_id  UNIQUEIDENTIFIER  NOT NULL  CONSTRAINT pk_tenants PRIMARY KEY DEFAULT NEWID(),
        brand_name NVARCHAR(100)     NOT NULL  CONSTRAINT uq_tenants_brand UNIQUE,
        created_at DATETIME2(3)      NOT NULL  CONSTRAINT df_tenants_created DEFAULT SYSUTCDATETIME()
    );
END
GO

-- -----------------------------------------------------------------------------
-- tbl_tickets — núcleo do domínio HelpSphere
--
-- Design:
--   * IDENTITY INT como PK — chave humanamente legível (TKT-12345)
--   * tenant_id FK NOT NULL — todo ticket pertence a um tenant (multi-tenancy)
--   * category/status/priority com CHECK constraints — sem enum no app, regra
--     no banco (DBA-friendly, source of truth)
--   * confidence_score DECIMAL(3,2) — preenchido pelo agente IA no Lab Final
--     (range 0.00-1.00, NULL = ainda não processado por IA)
--   * attachment_blob_paths NVARCHAR(MAX) — JSON array com paths do Blob
--     Storage; NULL = sem anexos. Não é tabela separada porque é payload
--     denormalizado de leitura (típico em ticketing)
--   * 2 índices não-clustered:
--       - idx_status_created (status, created_at DESC) — query mais comum
--         "tickets abertos mais recentes"
--       - idx_tenant_category (tenant_id, category) — filtro do dashboard
-- -----------------------------------------------------------------------------
IF OBJECT_ID('dbo.tbl_tickets', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.tbl_tickets (
        ticket_id              INT             NOT NULL IDENTITY(1,1)  CONSTRAINT pk_tickets PRIMARY KEY,
        tenant_id              UNIQUEIDENTIFIER NOT NULL                CONSTRAINT fk_tickets_tenant
                                                                        FOREIGN KEY REFERENCES dbo.tbl_tenants(tenant_id),
        subject                NVARCHAR(200)   NOT NULL,
        description            NVARCHAR(MAX)   NOT NULL,
        category               VARCHAR(50)     NOT NULL                CONSTRAINT ck_tickets_category
                                                                        CHECK (category IN ('Comercial','TI','Operacional','RH','Financeiro')),
        language               VARCHAR(5)      NOT NULL                CONSTRAINT df_tickets_language DEFAULT 'pt-BR',
        status                 VARCHAR(20)     NOT NULL                CONSTRAINT df_tickets_status   DEFAULT 'Open'
                                                                        CONSTRAINT ck_tickets_status
                                                                        CHECK (status IN ('Open','InProgress','Resolved','Escalated')),
        priority               VARCHAR(10)     NOT NULL                CONSTRAINT df_tickets_priority DEFAULT 'Medium'
                                                                        CONSTRAINT ck_tickets_priority
                                                                        CHECK (priority IN ('Low','Medium','High','Critical')),
        confidence_score       DECIMAL(3,2)    NULL                    CONSTRAINT ck_tickets_confidence
                                                                        CHECK (confidence_score IS NULL
                                                                            OR (confidence_score >= 0.00 AND confidence_score <= 1.00)),
        attachment_blob_paths  NVARCHAR(MAX)   NULL,
        created_at             DATETIME2(3)    NOT NULL                CONSTRAINT df_tickets_created  DEFAULT SYSUTCDATETIME(),
        updated_at             DATETIME2(3)    NOT NULL                CONSTRAINT df_tickets_updated  DEFAULT SYSUTCDATETIME()
    );

    CREATE NONCLUSTERED INDEX idx_status_created
        ON dbo.tbl_tickets (status, created_at DESC)
        INCLUDE (tenant_id, subject, priority);

    CREATE NONCLUSTERED INDEX idx_tenant_category
        ON dbo.tbl_tickets (tenant_id, category)
        INCLUDE (status, priority, created_at);
END
GO

-- -----------------------------------------------------------------------------
-- tbl_comments — thread de comentários por ticket
--
-- Design:
--   * IDENTITY INT como PK — sequência simples
--   * ticket_id FK ON DELETE CASCADE — apagar ticket apaga comentários
--     (relação composição, não associação)
--   * author NVARCHAR — nome livre do humano OU 'agent-ai' quando IA
--     adiciona resposta sugerida (Lab Final)
--   * Sem índice extra — query padrão é "all comments by ticket_id"
--     que já é eficiente via FK index implícito
-- -----------------------------------------------------------------------------
IF OBJECT_ID('dbo.tbl_comments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.tbl_comments (
        comment_id  INT           NOT NULL IDENTITY(1,1)  CONSTRAINT pk_comments PRIMARY KEY,
        ticket_id   INT           NOT NULL                CONSTRAINT fk_comments_ticket
                                                          FOREIGN KEY REFERENCES dbo.tbl_tickets(ticket_id)
                                                          ON DELETE CASCADE,
        author      NVARCHAR(100) NOT NULL,
        content     NVARCHAR(MAX) NOT NULL,
        created_at  DATETIME2(3)  NOT NULL                CONSTRAINT df_comments_created DEFAULT SYSUTCDATETIME()
    );
END
GO

-- -----------------------------------------------------------------------------
-- Trigger: manter updated_at coerente em tbl_tickets
--
-- Por que trigger e não app-side?
--   * Garantia mesmo se alguém UPDATE direto via T-SQL ad-hoc no portal
--   * Source of truth no banco (consistente com CHECK constraints acima)
--   * Custo desprezível (3 tabelas, baixo throughput)
-- -----------------------------------------------------------------------------
IF OBJECT_ID('dbo.trg_tickets_set_updated_at', 'TR') IS NULL
EXEC('
CREATE TRIGGER dbo.trg_tickets_set_updated_at
ON dbo.tbl_tickets
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE t
       SET updated_at = SYSUTCDATETIME()
      FROM dbo.tbl_tickets AS t
     INNER JOIN inserted AS i ON t.ticket_id = i.ticket_id;
END
');
GO

PRINT 'HelpSphere: schema 001 aplicado com sucesso (3 tabelas + 2 índices + 1 trigger).';
GO
