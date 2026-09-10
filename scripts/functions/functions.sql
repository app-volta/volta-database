-- ============================================================
-- VOLTA - FUNCTIONS
-- ============================================================


-- ============================================================
-- 1. CALCULAR PERCENTUAL DE RECICLAGEM
-- ============================================================
-- Calcula o percentual reciclado a partir do total de resíduos
-- gerados e do total reciclado.
--
-- Exemplo:
-- SELECT calculate_recycling_percentage(1000, 750);
-- Resultado: 75.00
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_recycling_percentage(
    p_total_waste NUMERIC,
    p_total_recycled NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_total_waste IS NULL
       OR p_total_recycled IS NULL
       OR p_total_waste <= 0 THEN
        RETURN 0;
    END IF;

    RETURN ROUND(
        (p_total_recycled / p_total_waste) * 100,
        2
    );
END;
$$;


-- ============================================================
-- 2. CALCULAR TEMPO DE CONCLUSÃO DE UMA COLETA
-- ============================================================
-- Recebe o UUID de uma coleta e calcula quantas horas se
-- passaram entre REQUESTED e COMPLETED no histórico.
--
-- Caso a coleta ainda não tenha sido concluída ou não possua
-- os registros necessários, retorna NULL.
--
-- Exemplo:
-- SELECT calculate_collection_completion_hours(
--     'UUID_DA_COLETA'
-- );
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_collection_completion_hours(
    p_collection_id UUID
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_requested_at TIMESTAMP;
    v_completed_at TIMESTAMP;
BEGIN

    SELECT MIN(changed_at)
    INTO v_requested_at
    FROM collection_status
    WHERE collection_id = p_collection_id
      AND status = 'REQUESTED';

    SELECT MAX(changed_at)
    INTO v_completed_at
    FROM collection_status
    WHERE collection_id = p_collection_id
      AND status = 'COMPLETED';

    IF v_requested_at IS NULL
       OR v_completed_at IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN ROUND(
        (
            EXTRACT(
                EPOCH FROM (v_completed_at - v_requested_at)
            ) / 3600
        )::NUMERIC,
        2
    );

END;
$$;


-- ============================================================
-- 3. CALCULAR SCORE ESG DA EMPRESA
-- ============================================================
-- Calcula um score baseado no percentual de reciclagem mais
-- recente registrado para uma empresa.
--
-- Essa função também pode servir como base para integração
-- futura com o ranking de empresas armazenado no Redis.
--
-- Exemplo:
-- SELECT calculate_company_esg_score(
--     'UUID_DA_EMPRESA'
-- );
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_company_esg_score(
    p_company_id UUID
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_score NUMERIC;
BEGIN

    SELECT recycling_percentage
    INTO v_score
    FROM esg_metric
    WHERE company_id = p_company_id
    ORDER BY calculated_at DESC
    LIMIT 1;

    RETURN COALESCE(v_score, 0);

END;
$$;


-- ============================================================
-- EXEMPLOS PARA VALIDAÇÃO
-- ============================================================

-- Testar percentual de reciclagem
SELECT calculate_recycling_percentage(1000, 750)
    AS recycling_percentage;


-- Testar cálculo utilizando dados reais do dataload
SELECT
    c.id,
    c.current_status,
    calculate_collection_completion_hours(c.id)
        AS completion_hours
FROM collection c
WHERE c.current_status = 'COMPLETED'
LIMIT 10;


-- Testar score ESG das empresas
SELECT
    c.id,
    c.name,
    calculate_company_esg_score(c.id) AS esg_score
FROM company c
ORDER BY esg_score DESC;