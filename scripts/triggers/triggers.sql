-- ============================================================
-- VOLTA - TRIGGERS DE AUDITORIA
-- ============================================================


-- ============================================================
-- 1. TABELA DE AUDITORIA
-- ============================================================

CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(100) NOT NULL,
    record_id UUID,
    operation VARCHAR(10) NOT NULL,
    old_data JSONB,
    new_data JSONB,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    database_user VARCHAR(100) NOT NULL DEFAULT CURRENT_USER
);


-- ============================================================
-- 2. FUNCTION GENÉRICA DE AUDITORIA
-- ============================================================
-- Essa função será reutilizada por várias triggers.
--
-- Registra:
-- INSERT -> apenas new_data
-- UPDATE -> old_data e new_data
-- DELETE -> apenas old_data
-- ============================================================

CREATE OR REPLACE FUNCTION audit_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF TG_OP = 'INSERT' THEN

        INSERT INTO audit_log (
            table_name,
            record_id,
            operation,
            old_data,
            new_data
        )
        VALUES (
            TG_TABLE_NAME,
            NEW.id,
            TG_OP,
            NULL,
            to_jsonb(NEW)
        );

        RETURN NEW;


    ELSIF TG_OP = 'UPDATE' THEN

        INSERT INTO audit_log (
            table_name,
            record_id,
            operation,
            old_data,
            new_data
        )
        VALUES (
            TG_TABLE_NAME,
            NEW.id,
            TG_OP,
            to_jsonb(OLD),
            to_jsonb(NEW)
        );

        RETURN NEW;


    ELSIF TG_OP = 'DELETE' THEN

        INSERT INTO audit_log (
            table_name,
            record_id,
            operation,
            old_data,
            new_data
        )
        VALUES (
            TG_TABLE_NAME,
            OLD.id,
            TG_OP,
            to_jsonb(OLD),
            NULL
        );

        RETURN OLD;

    END IF;

    RETURN NULL;

END;
$$;


-- ============================================================
-- 3. TRIGGER - INCIDENT
-- ============================================================

DROP TRIGGER IF EXISTS trg_audit_incident ON incident;

CREATE TRIGGER trg_audit_incident
AFTER INSERT OR UPDATE OR DELETE
ON incident
FOR EACH ROW
EXECUTE FUNCTION audit_changes();


-- ============================================================
-- 4. TRIGGER - COLLECTION
-- ============================================================

DROP TRIGGER IF EXISTS trg_audit_collection ON collection;

CREATE TRIGGER trg_audit_collection
AFTER INSERT OR UPDATE OR DELETE
ON collection
FOR EACH ROW
EXECUTE FUNCTION audit_changes();


-- ============================================================
-- 5. TRIGGER - ESG_METRIC
-- ============================================================

DROP TRIGGER IF EXISTS trg_audit_esg_metric ON esg_metric;

CREATE TRIGGER trg_audit_esg_metric
AFTER INSERT OR UPDATE OR DELETE
ON esg_metric
FOR EACH ROW
EXECUTE FUNCTION audit_changes();


-- ============================================================
-- CONSULTAS DE VALIDAÇÃO
-- ============================================================


-- ============================================================
-- TESTE 1 - UPDATE EM INCIDENT
-- ============================================================

SELECT
    id,
    status,
    priority
FROM incident
LIMIT 5;


-- Substitua pelo UUID encontrado:
--
UPDATE incident
SET priority = 'HIGH'
WHERE id = '1e732f53-f410-40e5-9070-8dca0457dac4';


-- ============================================================
-- TESTE 2 - UPDATE EM COLLECTION
-- ============================================================

SELECT
    id,
    current_status
FROM collection
LIMIT 5;


-- Exemplo:
--
UPDATE collection
SET urgent = TRUE
WHERE id = 'f4971602-8354-432e-88f2-865d4fade1b1';


-- ============================================================
-- TESTE 3 - UPDATE EM ESG_METRIC
-- ============================================================

SELECT
    id,
    recycling_percentage
FROM esg_metric
LIMIT 5;


-- Exemplo:
--
UPDATE esg_metric
SET recycling_percentage = 80
WHERE id = '9392aa3f-db41-4ad1-84c2-9fe698c2ecd8';


-- ============================================================
-- CONSULTAR AUDITORIA
-- ============================================================

SELECT
    id,
    table_name,
    record_id,
    operation,
    old_data,
    new_data,
    changed_at,
    database_user
FROM audit_log
ORDER BY changed_at DESC;