-- ============================================================
-- VOLTA - Consultas com Common Table Expressions (CTEs)
-- ============================================================

-- 1. Resumo de ocorrencias por empresa
-- Agrupa as ocorrencias para mostrar, inclusive para empresas sem registros,
-- a quantidade de ocorrencias e o total estimado de residuos.
WITH incident_summary AS (
    SELECT
        company_id,
        COUNT(*) AS total_incidents,
        SUM(estimated_quantity) AS total_estimated_quantity
    FROM incident
    GROUP BY company_id
)
SELECT
    c.id AS company_id,
    c.name AS company,
    COALESCE(i.total_incidents, 0) AS total_incidents,
    COALESCE(i.total_estimated_quantity, 0) AS total_estimated_quantity
FROM company c
LEFT JOIN incident_summary i
    ON i.company_id = c.id
ORDER BY total_incidents DESC, company;


-- 2. Resumo de reciclagem por empresa
-- Soma os indicadores ESG e calcula o percentual reciclado.
-- NULLIF impede divisao por zero quando o total de residuos e igual a zero.
WITH recycling_summary AS (
    SELECT
        company_id,
        SUM(total_waste_kg) AS total_waste_kg,
        SUM(total_recycled_kg) AS total_recycled_kg
    FROM esg_metric
    GROUP BY company_id
)
SELECT
    c.id AS company_id,
    c.name AS company,
    r.total_waste_kg,
    r.total_recycled_kg,
    ROUND(
        (r.total_recycled_kg / NULLIF(r.total_waste_kg, 0)) * 100,
        2
    ) AS recycling_percentage
FROM recycling_summary r
JOIN company c
    ON c.id = r.company_id
ORDER BY recycling_percentage DESC NULLS LAST, company;


-- 3. Tempo medio de conclusao das coletas por cooperativa
-- Localiza o primeiro status REQUESTED e o ultimo status COMPLETED de cada
-- coleta concluida, calcula a duracao entre eles e apresenta a media em horas.
WITH completed_collections AS (
    SELECT
        c.id AS collection_id,
        c.cooperative_id,
        MIN(cs.changed_at) FILTER (
            WHERE cs.status = 'REQUESTED'
        ) AS requested_at,
        MAX(cs.changed_at) FILTER (
            WHERE cs.status = 'COMPLETED'
        ) AS completed_at
    FROM collection c
    JOIN collection_status cs
        ON cs.collection_id = c.id
    WHERE c.current_status = 'COMPLETED'
    GROUP BY c.id, c.cooperative_id
)
SELECT
    co.id AS cooperative_id,
    co.name AS cooperative,
    COUNT(*) AS completed_collections,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (cc.completed_at - cc.requested_at)) / 3600)::numeric,
        2
    ) AS average_completion_hours
FROM completed_collections cc
JOIN cooperative co
    ON co.id = cc.cooperative_id
WHERE cc.requested_at IS NOT NULL
  AND cc.completed_at IS NOT NULL
GROUP BY co.id, co.name
ORDER BY average_completion_hours, cooperative;
