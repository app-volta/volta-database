-- ============================================================
-- VOLTA - PROCEDURES (Objetos Lógicos de Negócio)
-- Atende ao requisito de SQL Avançado (Mínimo de 2 Procedures)
-- ============================================================


-- ============================================================
-- 1. ATUALIZAR STATUS DE UMA COLETA
-- ============================================================
-- Atualiza o status atual da coleta e registra automaticamente
-- a alteração no histórico da tabela collection_status.
--
-- Exemplo:
-- CALL update_collection_status(
--     'UUID_DA_COLETA',
--     'IN_PROGRESS',
--     'Cooperativa iniciou o deslocamento.'
-- );
-- ============================================================

CREATE OR REPLACE PROCEDURE update_collection_status(
    p_collection_id UUID,
    p_new_status VARCHAR(50),
    p_observation TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Verifica se a coleta existe
    IF NOT EXISTS (
        SELECT 1 FROM collection WHERE id = p_collection_id
    ) THEN
        RAISE EXCEPTION 'Collection with id % not found.', p_collection_id;
    END IF;

    -- Atualiza o status atual
    UPDATE collection
    SET current_status = p_new_status
    WHERE id = p_collection_id;

    -- Registra a alteração no histórico
    INSERT INTO collection_status (
        collection_id,
        status,
        changed_at,
        observation
    )
    VALUES (
        p_collection_id,
        p_new_status,
        CURRENT_TIMESTAMP,
        p_observation
    );
END;
$$;


-- ============================================================
-- 2. AGENDAR UMA COLETA
-- ============================================================
-- Define uma data para a coleta e altera seu status para SCHEDULED.
-- Mantém o histórico sincronizado e respeita chk_collection_dates.
--
-- Exemplo:
-- CALL schedule_collection('UUID_DA_COLETA', '2026-11-10 14:00:00');
-- ============================================================

CREATE OR REPLACE PROCEDURE schedule_collection(
    p_collection_id UUID,
    p_scheduled_at TIMESTAMP
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_requested_at TIMESTAMP;
BEGIN
    -- Obtém a data de solicitação da coleta
    SELECT requested_at
    INTO v_requested_at
    FROM collection
    WHERE id = p_collection_id;

    -- Verifica se a coleta existe
    IF v_requested_at IS NULL THEN
        RAISE EXCEPTION 'Collection with id % not found.', p_collection_id;
    END IF;

    -- Garante coerência com a constraint chk_collection_dates
    IF p_scheduled_at < v_requested_at THEN
        RAISE EXCEPTION 'Scheduled date (%) cannot be earlier than requested date (%).',
            p_scheduled_at, v_requested_at;
    END IF;

    -- Atualiza o agendamento e o status da coleta
    UPDATE collection
    SET
        scheduled_at = p_scheduled_at,
        current_status = 'SCHEDULED'
    WHERE id = p_collection_id;

    -- Registra o histórico
    INSERT INTO collection_status (
        collection_id,
        status,
        changed_at,
        observation
    )
    VALUES (
        p_collection_id,
        'SCHEDULED',
        CURRENT_TIMESTAMP,
        'Agendamento efetuado via procedure schedule_collection.'
    );
END;
$$;


-- ============================================================
-- 3. ENCERRAR UMA OCORRÊNCIA
-- ============================================================
-- Altera uma ocorrência para CLOSED e cria uma notificação
-- automática para o usuário responsável pelo registro.
--
-- Exemplo:
-- CALL close_incident('UUID_DA_OCORRENCIA');
-- ============================================================

CREATE OR REPLACE PROCEDURE close_incident(
    p_incident_id UUID
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Localiza o usuário responsável pela ocorrência
    SELECT user_id
    INTO v_user_id
    FROM incident
    WHERE id = p_incident_id;

    -- Verifica se a ocorrência existe
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Incident with id % not found.', p_incident_id;
    END IF;

    -- Atualiza o status
    UPDATE incident
    SET status = 'CLOSED'
    WHERE id = p_incident_id;

    -- Notifica o usuário responsável
    INSERT INTO notification (
        user_id,
        type,
        title,
        message,
        read,
        created_at
    )
    VALUES (
        v_user_id,
        'INCIDENT',
        'Ocorrência encerrada',
        'A ocorrência foi encerrada com sucesso após triagem/coleta.',
        FALSE,
        CURRENT_TIMESTAMP
    );
END;
$$;


-- ============================================================
-- CONSULTAS DE VALIDAÇÃO
-- ============================================================

-- TESTE 1: update_collection_status
DO $$
DECLARE
    v_collection_id UUID;
BEGIN
    SELECT id INTO v_collection_id FROM collection ORDER BY requested_at LIMIT 1;
    IF v_collection_id IS NOT NULL THEN
        CALL update_collection_status(
            v_collection_id,
            'IN_PROGRESS',
            'Coleta em andamento (teste de procedure).'
        );
    END IF;
END;
$$;

-- TESTE 2: schedule_collection
DO $$
DECLARE
    v_collection_id UUID;
    v_requested_at TIMESTAMP;
BEGIN
    SELECT id, requested_at INTO v_collection_id, v_requested_at FROM collection ORDER BY requested_at LIMIT 1;
    IF v_collection_id IS NOT NULL THEN
        CALL schedule_collection(v_collection_id, v_requested_at + INTERVAL '1 day');
    END IF;
END;
$$;

-- TESTE 3: close_incident
DO $$
DECLARE
    v_incident_id UUID;
BEGIN
    SELECT id INTO v_incident_id FROM incident WHERE status <> 'CLOSED' ORDER BY registered_at LIMIT 1;
    IF v_incident_id IS NOT NULL THEN
        CALL close_incident(v_incident_id);
    END IF;
END;
$$;