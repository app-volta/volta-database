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
    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE id = p_user_id
    ) THEN
        RAISE EXCEPTION
            'User with id % not found.',
            p_user_id;
    END IF;

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

-- Obter usuário:
SELECT id, name, email
FROM users
LIMIT 5;


-- Executar mais de uma vez:
--
CALL register_user_access('e7d2d020-a687-4d1b-8da2-9f4e7c5fe8e3');
--
CALL register_user_access('11bc16a5-3294-4893-bc20-7e23deed5155');
--
CALL register_user_access('6d109ff5-0ce1-4b16-836e-6817cb587f4b');


-- Conferir:
SELECT *
FROM user_daily_access
ORDER BY access_date DESC;