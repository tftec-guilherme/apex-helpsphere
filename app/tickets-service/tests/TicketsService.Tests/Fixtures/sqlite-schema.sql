-- HelpSphere tickets-service — SQLite schema adapter (Story 06.5c.2 AC-11)
--
-- Equivalente funcional do `helpsphere/data/migrations/001_initial_schema.sql` para
-- tests in-memory rápidos. Documentação dos gaps em SQLITE-VS-SQLEDGE.md (mesma pasta).

CREATE TABLE IF NOT EXISTS tbl_tenants (
    tenant_id TEXT PRIMARY KEY,
    brand_name TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE IF NOT EXISTS tbl_tickets (
    ticket_id INTEGER PRIMARY KEY AUTOINCREMENT,
    tenant_id TEXT NOT NULL REFERENCES tbl_tenants(tenant_id),
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL,
    language TEXT NOT NULL DEFAULT 'pt-BR',
    status TEXT NOT NULL DEFAULT 'Open',
    priority TEXT NOT NULL DEFAULT 'Medium',
    confidence_score REAL,
    attachment_blob_paths TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_tickets_status_created ON tbl_tickets(status, created_at);
CREATE INDEX IF NOT EXISTS idx_tickets_tenant_category ON tbl_tickets(tenant_id, category);

CREATE TABLE IF NOT EXISTS tbl_comments (
    comment_id INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_id INTEGER NOT NULL REFERENCES tbl_tickets(ticket_id),
    author TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
