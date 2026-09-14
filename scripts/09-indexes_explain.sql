-- ============================================================
-- VOLTA - INDEXES + EXPLAIN ANALYZE
-- ============================================================

-- ============================================================
-- 1. CONSULTAS BASE PARA ANALISE
-- ============================================================
-- A ideia é executar os EXPLAIN ANALYZE primeiro,
-- observar o plano de execução e depois criar os índices.

-- ------------------------------------------------------------
-- Consulta 1:
-- Busca ocorrências por empresa e status.
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    id,
    company_id,
    status,
    priority,
    registered_at
FROM incident
WHERE company_id = (
    SELECT id
    FROM company
    LIMIT 1
)
AND status = 'OPEN';


-- ------------------------------------------------------------
-- Consulta 2:
-- Busca coletas por cooperativa e status.
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    id,
    cooperative_id,
    current_status,
    requested_at,
    scheduled_at
FROM collection
WHERE cooperative_id = (
    SELECT id
    FROM cooperative
    LIMIT 1
)
AND current_status = 'COMPLETED';


-- ------------------------------------------------------------
-- Consulta 3:
-- Consulta histórico de status de uma coleta ordenado por data.
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    collection_id,
    status,
    changed_at,
    observation
FROM collection_status
WHERE collection_id = (
    SELECT id
    FROM collection
    LIMIT 1
)
ORDER BY changed_at DESC;


-- ------------------------------------------------------------
-- Consulta 4:
-- Consulta métricas ESG por empresa ordenadas por período.
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    company_id,
    period,
    total_waste_kg,
    total_recycled_kg,
    recycling_percentage
FROM esg_metric
WHERE company_id = (
    SELECT id
    FROM company
    LIMIT 1
)
ORDER BY period;


-- ============================================================
-- 2. CRIACAO DOS INDICES
-- ============================================================

-- ------------------------------------------------------------
-- INDEX 1
-- Acelera buscas de ocorrências por empresa e status.
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_incident_company_status
ON incident (company_id, status);


-- ------------------------------------------------------------
-- INDEX 2
-- Acelera buscas de coletas por cooperativa e status.
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_collection_cooperative_status
ON collection (cooperative_id, current_status);


-- ------------------------------------------------------------
-- INDEX 3
-- Acelera consulta do histórico de uma coleta e sua ordenação.
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_collection_status_collection_changed_at
ON collection_status (collection_id, changed_at DESC);


-- ------------------------------------------------------------
-- INDEX 4
-- Acelera consultas de métricas ESG por empresa e período.
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_esg_metric_company_period
ON esg_metric (company_id, period);


-- ============================================================
-- 3. ATUALIZAR ESTATISTICAS
-- ============================================================
-- Atualiza as estatísticas utilizadas pelo otimizador
-- do PostgreSQL para escolher o melhor plano de execução.

ANALYZE incident;
ANALYZE collection;
ANALYZE collection_status;
ANALYZE esg_metric;


-- ============================================================
-- 4. EXPLAIN ANALYZE APOS OS INDICES
-- ============================================================

-- ------------------------------------------------------------
-- Consulta 1 - após índice
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    id,
    company_id,
    status,
    priority,
    registered_at
FROM incident
WHERE company_id = (
    SELECT id
    FROM company
    LIMIT 1
)
AND status = 'OPEN';


-- ------------------------------------------------------------
-- Consulta 2 - após índice
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    id,
    cooperative_id,
    current_status,
    requested_at,
    scheduled_at
FROM collection
WHERE cooperative_id = (
    SELECT id
    FROM cooperative
    LIMIT 1
)
AND current_status = 'COMPLETED';


-- ------------------------------------------------------------
-- Consulta 3 - após índice
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    collection_id,
    status,
    changed_at,
    observation
FROM collection_status
WHERE collection_id = (
    SELECT id
    FROM collection
    LIMIT 1
)
ORDER BY changed_at DESC;


-- ------------------------------------------------------------
-- Consulta 4 - após índice
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    company_id,
    period,
    total_waste_kg,
    total_recycled_kg,
    recycling_percentage
FROM esg_metric
WHERE company_id = (
    SELECT id
    FROM company
    LIMIT 1
)
ORDER BY period;


-- ============================================================
-- 5. CONSULTAR INDICES CRIADOS
-- ============================================================

SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename IN (
    'incident',
    'collection',
    'collection_status',
    'esg_metric'
)
ORDER BY tablename, indexname;