-- ============================================================
-- VOLTA - Consultas com Window Functions
-- Atende ao requisito de Cálculos Analíticos (Running Total, Ranking, Deltas)
-- ============================================================

-- ------------------------------------------------------------
-- 1. Ranking de empresas por total reciclado (RANK)
-- Soma o material reciclado por empresa e usa RANK para atribuir a mesma
-- posição a empresas empatadas, pulando a posição subsequente.
-- ------------------------------------------------------------
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


-- ------------------------------------------------------------
-- 2. Evolução da reciclagem por empresa (LAG)
-- LAG consulta o valor do período anterior dentro de cada empresa. A diferença
-- demonstra a oscilação quantitativa entre os ciclos de medição ESG.
-- ------------------------------------------------------------
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
    re.total_recycled_kg - re.previous_period_recycled_kg AS recycled_difference_kg
FROM recycling_evolution re
JOIN company c
    ON c.id = re.company_id
ORDER BY company, re.period;


-- ------------------------------------------------------------
-- 3. Total reciclado acumulado por empresa (Running Total / SUM OVER)
-- SUM OVER calcula o volume acumulado cronológico desde o primeiro período
-- até a linha atual, preservando o nível de detalhe de cada período.
-- ------------------------------------------------------------
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


-- ------------------------------------------------------------
-- 4. Análise de desempenho das cooperativas (DENSE_RANK e AVG OVER)
-- Classifica as coletas por volume estimado dentro de cada cooperativa
-- e compara a quantidade de cada chamado com a média daquela entidade.
-- ------------------------------------------------------------
SELECT
    co.name AS cooperative_name,
    c.id AS collection_id,
    c.collection_type,
    i.estimated_quantity AS incident_volume_kg,
    ROUND(
        AVG(i.estimated_quantity) OVER (
            PARTITION BY c.cooperative_id
        ), 2
    ) AS cooperative_avg_volume_kg,
    DENSE_RANK() OVER (
        PARTITION BY c.cooperative_id
        ORDER BY i.estimated_quantity DESC NULLS LAST
    ) AS rank_volume_cooperative
FROM collection c
JOIN cooperative co
    ON co.id = c.cooperative_id
JOIN incident i
    ON i.id = c.incident_id
WHERE c.current_status = 'COMPLETED'
ORDER BY co.name, rank_volume_cooperative;