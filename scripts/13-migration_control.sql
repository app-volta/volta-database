-- VOLTA | Controle da migração legado → novo banco
-- Executar SOMENTE no banco de DESTINO DE TESTE.

CREATE TABLE IF NOT EXISTS migration_run (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'RUNNING',
    source_records INTEGER NOT NULL DEFAULT 0,
    migrated_records INTEGER NOT NULL DEFAULT 0,
    failed_records INTEGER NOT NULL DEFAULT 0,
    error_message TEXT,

    CONSTRAINT chk_migration_run_status
        CHECK (status IN ('RUNNING', 'SUCCESS', 'PARTIAL', 'FAILED'))
);

CREATE TABLE IF NOT EXISTS migration_id_map (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_table VARCHAR(100) NOT NULL,
    source_id INTEGER NOT NULL,
    target_table VARCHAR(100) NOT NULL,
    target_id UUID NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_migration_source
        UNIQUE (source_table, source_id),

    CONSTRAINT uq_migration_target
        UNIQUE (target_table, target_id)
);

CREATE TABLE IF NOT EXISTS migration_error (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    migration_run_id UUID NOT NULL
        REFERENCES migration_run(id),
    source_table VARCHAR(100) NOT NULL,
    source_id INTEGER,
    error_message TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Rastreia relacionamentos importados do legado.
-- Preserva relacionamentos criados diretamente no destino.

CREATE TABLE IF NOT EXISTS migration_relation_map (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    source_table VARCHAR(100) NOT NULL,
    source_id_1 INTEGER NOT NULL,
    source_id_2 INTEGER NOT NULL,

    target_table VARCHAR(100) NOT NULL,
    target_id_1 UUID NOT NULL,
    target_id_2 UUID NOT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_migration_relation_source
        UNIQUE (source_table, source_id_1, source_id_2),

    CONSTRAINT uq_migration_relation_target
        UNIQUE (target_table, target_id_1, target_id_2)
);