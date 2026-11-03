-- ============================================================
-- VOLTA - TRIGGERS DE AUDITORIA E REGRAS DE DOMÍNIO
-- Atende ao requisito: Triggers de Auditoria com logs completos
-- (NEW, OLD, TG_OP, CURRENT_USER) em 2+ tabelas
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

-- Índices para otimização de consultas nos relatórios de auditoria
CREATE INDEX IF NOT EXISTS idx_audit_log_table ON audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_log_changed_at ON audit_log(changed_at DESC);


-- ============================================================
-- 2. FUNCTION GENÉRICA DE AUDITORIA
-- ============================================================
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
-- 3. TRIGGERS DE AUDITORIA NAS TABELAS PRINCIPAIS
-- ============================================================

-- Tabela 1: INCIDENT
DROP TRIGGER IF EXISTS trg_audit_incident ON incident;
CREATE TRIGGER trg_audit_incident
AFTER INSERT OR UPDATE OR DELETE
ON incident
FOR EACH ROW
EXECUTE FUNCTION audit_changes();

-- Tabela 2: COLLECTION
DROP TRIGGER IF EXISTS trg_audit_collection ON collection;
CREATE TRIGGER trg_audit_collection
AFTER INSERT OR UPDATE OR DELETE
ON collection
FOR EACH ROW
EXECUTE FUNCTION audit_changes();

-- Tabela 3: ESG_METRIC
DROP TRIGGER IF EXISTS trg_audit_esg_metric ON esg_metric;
CREATE TRIGGER trg_audit_esg_metric
AFTER INSERT OR UPDATE OR DELETE
ON esg_metric
FOR EACH ROW
EXECUTE FUNCTION audit_changes();


-- ============================================================
-- 4. TRIGGER DE DOMÍNIO - EXPIRAÇÃO DE METAS ESG
-- ============================================================

CREATE OR REPLACE FUNCTION fn_reset_esg_targets()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.weekly_date IS NOT NULL
       AND CURRENT_DATE > NEW.weekly_date + INTERVAL '7 days' THEN
        NEW.weekly_target := 0;
        NEW.weekly_date   := NULL;
    END IF;

    IF NEW.monthly_date IS NOT NULL
       AND CURRENT_DATE > (NEW.monthly_date + INTERVAL '1 month')::date THEN
        NEW.monthly_target := 0;
        NEW.monthly_date   := NULL;
    END IF;

    IF NEW.quarterly_date IS NOT NULL
       AND CURRENT_DATE > (NEW.quarterly_date + INTERVAL '3 months')::date THEN
        NEW.quarterly_target := 0;
        NEW.quarterly_date   := NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_reset_esg_targets ON esg_metric;
CREATE TRIGGER trg_reset_esg_targets
BEFORE INSERT OR UPDATE ON esg_metric
FOR EACH ROW
EXECUTE FUNCTION fn_reset_esg_targets();


-- ============================================================
-- CONSULTAS DE VALIDAÇÃO AUTOMATIZADAS (SEM HARDCODED UUID)
-- ============================================================

-- Simulação de UPDATE em INCIDENT
DO $$
DECLARE
    v_id UUID;
BEGIN
    SELECT id INTO v_id FROM incident LIMIT 1;
    IF v_id IS NOT NULL THEN
        UPDATE incident
        SET priority = CASE WHEN priority = 'URGENT' THEN 'HIGH' ELSE 'URGENT' END
        WHERE id = v_id;
    END IF;
END;
$$;

-- Simulação de UPDATE em COLLECTION
DO $$
DECLARE
    v_id UUID;
BEGIN
    SELECT id INTO v_id FROM collection LIMIT 1;
    IF v_id IS NOT NULL THEN
        UPDATE collection
        SET urgent = NOT urgent
        WHERE id = v_id;
    END IF;
END;
$$;

-- Simulação de UPDATE em ESG_METRIC
DO $$
DECLARE
    v_id UUID;
BEGIN
    SELECT id INTO v_id FROM esg_metric LIMIT 1;
    IF v_id IS NOT NULL THEN
        UPDATE esg_metric
        SET recycling_percentage = LEAST(recycling_percentage + 1, 100)
        WHERE id = v_id;
    END IF;
END;
$$;

-- Conferência imediata dos registros gravados pela auditoria
SELECT
    id,
    table_name,
    record_id,
    operation,
    changed_at,
    database_user,
    old_data,
    new_data
FROM audit_log
ORDER BY changed_at DESC
LIMIT 10;