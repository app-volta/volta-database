-- ============================================================
-- VOLTA - DAILY ACTIVE USER (DAU) - Monitoramento de acessos
-- ============================================================


-- ============================================================
-- 1. TABELA DE ACESSOS DIÁRIOS
-- ============================================================

CREATE TABLE IF NOT EXISTS user_daily_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    access_date DATE NOT NULL DEFAULT CURRENT_DATE,
    first_access_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_access_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    access_count INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT fk_user_daily_access_user
        FOREIGN KEY (user_id)
        REFERENCES users(id),

    CONSTRAINT uq_user_daily_access
        UNIQUE (user_id, access_date),

    CONSTRAINT chk_access_count
        CHECK (access_count > 0)
);


-- ============================================================
-- 2. PROCEDURE DE REGISTRO DE ACESSO
-- ============================================================
-- Deve ser chamada após uma autenticação válida.
--
-- Primeiro acesso do dia:
-- cria o registro.
--
-- Próximos acessos:
-- atualiza last_access_at e incrementa access_count.
-- ============================================================

CREATE OR REPLACE PROCEDURE register_user_access(
    p_user_id UUID
)
LANGUAGE plpgsql
AS $$
BEGIN

    -- Verifica se o usuário existe
    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE id = p_user_id
    ) THEN
        RAISE EXCEPTION
            'User with id % not found.',
            p_user_id;
    END IF;

    -- Registra o acesso do usuário
    INSERT INTO user_daily_access (
        user_id,
        access_date,
        first_access_at,
        last_access_at,
        access_count
    )
    VALUES (
        p_user_id,
        CURRENT_DATE,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        1
    )

    -- Caso o usuário já tenha acessado no mesmo dia,
    -- atualiza o último acesso e incrementa o contador.
    ON CONFLICT (user_id, access_date)
    DO UPDATE SET
        last_access_at = CURRENT_TIMESTAMP,
        access_count = user_daily_access.access_count + 1;

END;
$$;


-- ============================================================
-- 3. CONSULTA DAU
-- ============================================================
-- Cada usuário aparece no máximo uma vez por dia.
-- Portanto COUNT(*) representa usuários ativos únicos.
-- ============================================================

SELECT
    access_date,
    COUNT(*) AS daily_active_users
FROM user_daily_access
GROUP BY access_date
ORDER BY access_date DESC;


-- ============================================================
-- 4. DETALHAMENTO DOS ACESSOS
-- ============================================================

SELECT
    uda.access_date,
    u.id AS user_id,
    u.name,
    uda.first_access_at,
    uda.last_access_at,
    uda.access_count
FROM user_daily_access uda
JOIN users u
    ON u.id = uda.user_id
ORDER BY
    uda.access_date DESC,
    uda.last_access_at DESC;


-- ============================================================
-- EXEMPLO DE TESTE
-- ============================================================

-- Exibe alguns usuários disponíveis
SELECT
    id,
    name,
    email
FROM users
LIMIT 5;


-- ============================================================
-- TESTE - REGISTER USER ACCESS
-- ============================================================
-- Busca dinamicamente até 3 usuários existentes no banco.
--
-- Para cada usuário encontrado:
-- 1ª chamada -> cria o registro de acesso;
-- 2ª chamada -> testa o ON CONFLICT e incrementa access_count.
--
-- Caso não existam usuários, o teste é ignorado sem
-- interromper a execução do CI.
-- ============================================================

DO $$
DECLARE
    v_user RECORD;
    v_users_found INTEGER := 0;
BEGIN

    FOR v_user IN
        SELECT id
        FROM users
        ORDER BY id
        LIMIT 3
    LOOP

        v_users_found := v_users_found + 1;

        -- Primeiro acesso
        CALL register_user_access(v_user.id);

        -- Segundo acesso no mesmo dia
        -- Deve incrementar access_count através do ON CONFLICT
        CALL register_user_access(v_user.id);

    END LOOP;

    IF v_users_found = 0 THEN
        RAISE NOTICE
            'Teste register_user_access ignorado: nenhum usuário disponível.';
    END IF;

END;
$$;


-- ============================================================
-- CONFERIR RESULTADO
-- ============================================================

SELECT
    id,
    user_id,
    access_date,
    first_access_at,
    last_access_at,
    access_count
FROM user_daily_access
ORDER BY
    access_date DESC,
    last_access_at DESC;


-- ============================================================
-- CONFERIR DAU APÓS O TESTE
-- ============================================================

SELECT
    access_date,
    COUNT(*) AS daily_active_users
FROM user_daily_access
GROUP BY access_date
ORDER BY access_date DESC;