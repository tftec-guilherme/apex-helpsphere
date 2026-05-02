-- =============================================================================
-- HelpSphere — seed/tenants.sql
-- 5 marcas tenants do grupo Apex (subset das 12 mencionadas na story 06.5a)
--
-- GUIDs determinísticos (padrão 1111.../2222.../...) são PEDAGÓGICOS:
-- aluno olha o seed e entende imediatamente o mapping tenant→marca.
-- Em produção real, GUIDs são gerados via NEWID() (default da coluna).
--
-- Cobertura vertical (5 personas de retail brasileiro):
--   Apex Mercado     = supermercado (alta rotatividade, perecíveis)
--   Apex Tech        = eletrônicos + linha branca (NF-e, garantia, instalação)
--   Apex Moda        = fashion (sazonalidade, devoluções, tamanhos)
--   Apex Casa        = móveis e decor (logística pesada, montagem)
--   Apex Logística   = operação B2B intra-grupo (SLA, doca, motoristas)
-- =============================================================================

SET NOCOUNT ON;
GO

-- Idempotente: só insere se não existir
MERGE dbo.tbl_tenants AS target
USING (VALUES
    ('11111111-1111-1111-1111-111111111111', 'Apex Mercado'),
    ('22222222-2222-2222-2222-222222222222', 'Apex Tech'),
    ('33333333-3333-3333-3333-333333333333', 'Apex Moda'),
    ('44444444-4444-4444-4444-444444444444', 'Apex Casa'),
    ('55555555-5555-5555-5555-555555555555', 'Apex Logística')
) AS source (tenant_id, brand_name)
ON target.tenant_id = source.tenant_id
WHEN NOT MATCHED THEN
    INSERT (tenant_id, brand_name)
    VALUES (source.tenant_id, source.brand_name);
GO

PRINT 'HelpSphere: 5 tenants Apex carregados.';
GO
