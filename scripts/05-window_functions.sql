-- ============================================================
-- VOLTA - Consultas com Window Functions
-- ============================================================

-- 1. Ranking de empresas por total reciclado
-- Soma o material reciclado por empresa e usa RANK para atribuir a mesma
-- posicao a empresas empatadas, pulando a posicao seguinte quando necessario.
WITH company_recycling AS (
    SELECT
        company_id,
        SUM(total_recycled_kg) AS total_recycled_kg
    FROM esg_metric
    GROUP BY company_id
)
SELECT
    c.id AS company_id,
    c.name AS company,
    cr.total_recycled_kg,
    RANK() OVER (
        ORDER BY cr.total_recycled_kg DESC
    ) AS ranking_position
FROM company_recycling cr
JOIN company c
    ON c.id = cr.company_id
ORDER BY ranking_position, company;


-- 2. Evolucao da reciclagem por empresa
-- LAG consulta o valor do periodo anterior dentro de cada empresa. A diferenca
-- mostra quanto a quantidade reciclada aumentou ou diminuiu entre periodos.
WITH recycling_evolution AS (
    SELECT
        company_id,
        period,
        total_recycled_kg,
        LAG(total_recycled_kg) OVER (
            PARTITION BY company_id
            ORDER BY period
        ) AS previous_period_recycled_kg
    FROM esg_metric
)
SELECT
    c.id AS company_id,
    c.name AS company,
    re.period,
    re.total_recycled_kg,
    re.previous_period_recycled_kg,
    re.total_recycled_kg - re.previous_period_recycled_kg
        AS recycled_difference_kg
FROM recycling_evolution re
JOIN company c
    ON c.id = re.company_id
ORDER BY company, re.period;


-- 3. Total reciclado acumulado por empresa
-- SUM OVER calcula o acumulado cronologico desde o primeiro periodo da empresa
-- ate a linha atual, sem agrupar e perder os valores de cada periodo.
SELECT
    c.id AS company_id,
    c.name AS company,
    em.period,
    em.total_recycled_kg,
    SUM(em.total_recycled_kg) OVER (
        PARTITION BY em.company_id
        ORDER BY em.period
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS accumulated_recycled_kg
FROM esg_metric em
JOIN company c
    ON c.id = em.company_id
ORDER BY company, em.period;
