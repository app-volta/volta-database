-- ============================================================
-- VOLTA - RECURSIVE CTE - Hierarquia de áreas/setores
-- ============================================================


-- ============================================================
-- 1. ADICIONAR RELAÇÃO HIERÁRQUICA
-- ============================================================

ALTER TABLE area
ADD COLUMN IF NOT EXISTS parent_area_id UUID;


ALTER TABLE area
DROP CONSTRAINT IF EXISTS fk_area_parent;


ALTER TABLE area
ADD CONSTRAINT fk_area_parent
FOREIGN KEY (parent_area_id)
REFERENCES area(id)
ON DELETE SET NULL;


-- ============================================================
-- 2. CONSULTAR HIERARQUIA
-- ============================================================

WITH RECURSIVE area_hierarchy AS (

    -- Nível raiz
    SELECT
        a.id,
        a.company_id,
        a.parent_area_id,
        a.sector_name,
        1 AS level,
        a.sector_name::TEXT AS hierarchy_path
    FROM area a
    WHERE a.parent_area_id IS NULL
	UNION ALL

    -- Filhos
    SELECT
        child.id,
        child.company_id,
        child.parent_area_id,
        child.sector_name,
        parent.level + 1,
        (
            parent.hierarchy_path
            || ' > '
            || child.sector_name
        )::TEXT
    FROM area child
    INNER JOIN area_hierarchy parent
        ON child.parent_area_id = parent.id
)

SELECT
    id,
    company_id,
    parent_area_id,
    sector_name,
    level,
    hierarchy_path
FROM area_hierarchy
ORDER BY
    company_id,
    hierarchy_path;