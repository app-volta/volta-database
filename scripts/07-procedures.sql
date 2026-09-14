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

-- Busque primeiro uma coleta:
SELECT
    id,
    current_status
FROM collection
LIMIT 5;


-- Substitua pelo UUID encontrado:

CALL update_collection_status(
    'caf5f778-63d1-4662-b6e4-46b937465fba',
    'IN_PROGRESS',
    'Coleta iniciada para teste.'
);


-- Conferir coleta:
SELECT
    id,
    current_status
FROM collection
LIMIT 5;


-- Conferir histórico:
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

-- IMPORTANTE:
-- utilize uma data posterior ao requested_at da coleta.

SELECT
    id,
    requested_at,
    scheduled_at,
    current_status
FROM collection
LIMIT 5;


-- Exemplo:

CALL schedule_collection(
    '16e27436-e1fd-4d39-be71-8f1a53a85872',
	'2026-12-20 14:00:00'
);


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


-- Substitua pelo UUID encontrado:

CALL close_incident(
    '1e732f53-f410-40e5-9070-8dca0457dac4'
);


-- Conferir ocorrência:
SELECT
    id,
    status
FROM incident
WHERE status = 'CLOSED'
ORDER BY registered_at DESC
LIMIT 10;


-- Conferir notificação criada:
SELECT
    user_id,
    type,
    title,
    message,
    created_at
FROM notification
ORDER BY created_at DESC
LIMIT 10;