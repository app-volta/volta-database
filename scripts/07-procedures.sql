-- ============================================================
-- VOLTA - PROCEDURES
-- ============================================================


-- ============================================================
-- 1. ATUALIZAR STATUS DE UMA COLETA
-- ============================================================
-- Atualiza o status atual da coleta e registra automaticamente
-- a alteração no histórico da tabela collection_status.
--
-- Exemplo:
--
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
        SELECT 1
        FROM collection
        WHERE id = p_collection_id
    ) THEN
        RAISE EXCEPTION
            'Collection with id % not found.',
            p_collection_id;
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
-- Define uma data para a coleta e altera seu status para
-- SCHEDULED.
--
-- A procedure também registra a alteração em collection_status,
-- mantendo o histórico sincronizado com current_status.
--
-- Exemplo:
--
-- CALL schedule_collection(
--     'UUID_DA_COLETA',
--     '2026-09-15 14:00:00'
-- );
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

    -- Obtém a data em que a coleta foi solicitada
    SELECT requested_at
    INTO v_requested_at
    FROM collection
    WHERE id = p_collection_id;

    -- Verifica se a coleta existe
    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Collection with id % not found.',
            p_collection_id;
    END IF;

    -- Garante coerência com a constraint do schema
    IF p_scheduled_at < v_requested_at THEN
        RAISE EXCEPTION
            'Scheduled date cannot be earlier than requested date.';
    END IF;

    -- Atualiza a coleta
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
        'Collection scheduled through procedure.'
    );

END;
$$;


-- ============================================================
-- 3. ENCERRAR UMA OCORRÊNCIA
-- ============================================================
-- Altera uma ocorrência para CLOSED e cria uma notificação
-- para o usuário responsável pelo registro.
--
-- Exemplo:
--
-- CALL close_incident(
--     'UUID_DA_OCORRENCIA'
-- );
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
    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Incident with id % not found.',
            p_incident_id;
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
        'A ocorrência foi encerrada com sucesso.',
        FALSE,
        CURRENT_TIMESTAMP
    );

END;
$$;


-- ============================================================
-- CONSULTAS DE VALIDAÇÃO
-- ============================================================


-- ============================================================
-- TESTE 1 - UPDATE COLLECTION STATUS
-- ============================================================

-- Exibe algumas coletas disponíveis
SELECT
    id,
    current_status
FROM collection
LIMIT 5;


-- Busca dinamicamente uma coleta existente.
-- Caso não existam coletas no banco, o teste é ignorado.
DO $$
DECLARE
    v_collection_id UUID;
BEGIN

    SELECT id
    INTO v_collection_id
    FROM collection
    ORDER BY requested_at
    LIMIT 1;

    IF v_collection_id IS NULL THEN

        RAISE NOTICE
            'Teste update_collection_status ignorado: nenhuma coleta disponível.';

    ELSE

        CALL update_collection_status(
            v_collection_id,
            'IN_PROGRESS',
            'Coleta iniciada para teste.'
        );

    END IF;

END;
$$;


-- Conferir coleta
SELECT
    id,
    current_status
FROM collection
LIMIT 5;


-- Conferir histórico
SELECT
    collection_id,
    status,
    changed_at,
    observation
FROM collection_status
ORDER BY changed_at DESC
LIMIT 10;


-- ============================================================
-- TESTE 2 - SCHEDULE COLLECTION
-- ============================================================

SELECT
    id,
    requested_at,
    scheduled_at,
    current_status
FROM collection
LIMIT 5;


-- Busca dinamicamente uma coleta existente.
-- A nova data é calculada a partir do requested_at,
-- evitando depender de datas fixas.
DO $$
DECLARE
    v_collection_id UUID;
    v_requested_at TIMESTAMP;
BEGIN

    SELECT
        id,
        requested_at
    INTO
        v_collection_id,
        v_requested_at
    FROM collection
    ORDER BY requested_at
    LIMIT 1;

    IF v_collection_id IS NULL THEN

        RAISE NOTICE
            'Teste schedule_collection ignorado: nenhuma coleta disponível.';

    ELSE

        CALL schedule_collection(
            v_collection_id,
            v_requested_at + INTERVAL '1 day'
        );

    END IF;

END;
$$;


-- Conferir resultado
SELECT
    id,
    requested_at,
    scheduled_at,
    current_status
FROM collection
LIMIT 5;


-- ============================================================
-- TESTE 3 - CLOSE INCIDENT
-- ============================================================

SELECT
    id,
    user_id,
    status
FROM incident
WHERE status <> 'CLOSED'
LIMIT 5;


-- Busca dinamicamente uma ocorrência ainda não encerrada.
-- Caso nenhuma exista, o teste é ignorado.
DO $$
DECLARE
    v_incident_id UUID;
BEGIN

    SELECT id
    INTO v_incident_id
    FROM incident
    WHERE status <> 'CLOSED'
    ORDER BY registered_at
    LIMIT 1;

    IF v_incident_id IS NULL THEN

        RAISE NOTICE
            'Teste close_incident ignorado: nenhuma ocorrência aberta disponível.';

    ELSE

        CALL close_incident(v_incident_id);

    END IF;

END;
$$;


-- Conferir ocorrência
SELECT
    id,
    status
FROM incident
WHERE status = 'CLOSED'
ORDER BY registered_at DESC
LIMIT 10;


-- Conferir notificação criada
SELECT
    user_id,
    type,
    title,
    message,
    created_at
FROM notification
ORDER BY created_at DESC
LIMIT 10;