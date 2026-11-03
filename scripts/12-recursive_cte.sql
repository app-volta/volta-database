-- ============================================================
-- VOLTA - RECURSIVE CTE - Hierarquia de Áreas e Setores Fabris
-- Atende ao requisito de Estruturas Avançadas (CTE Recursiva)
-- ============================================================


-- ============================================================
-- 1. ADICIONAR RELAÇÃO HIERÁRQUICA (AUTORREFERENCIAL)
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

CREATE INDEX IF NOT EXISTS idx_area_parent_id
ON area(parent_area_id);


-- ============================================================
-- 2. POPULAR MASSA DE DADOS HIERÁRQUICA (EXEMPLO PRÁTICO)
-- Cria uma estrutura em árvore de 3 níveis em uma das empresas
-- para demonstrar a recursão de forma imediata na avaliação.
-- ============================================================

DO $$
DECLARE
    v_comp_id UUID;
    v_root_id UUID;
    v_sub_id UUID;
BEGIN
    SELECT id INTO v_comp_id FROM company LIMIT 1;

    IF v_comp_id IS NOT NULL THEN
        -- Nível 1: Planta Industrial Principal (Raiz)
        INSERT INTO area (company_id, sector_name, location_description, parent_area_id)
        VALUES (v_comp_id, 'Complexo Industrial Matriz', 'Instalação industrial consolidada', NULL)
        RETURNING id INTO v_root_id;

        -- Nível 2: Galpões / Setores (Filhos da Matriz)
        INSERT INTO area (company_id, sector_name, location_description, parent_area_id)
        VALUES (v_comp_id, 'Galpão de Usinagem e Montagem', 'Pátio interno de produção', v_root_id)
        RETURNING id INTO v_sub_id;

        INSERT INTO area (company_id, sector_name, location_description, parent_area_id)
        VALUES (v_comp_id, 'Centro Logístico e Doca Sul', 'Expedição e carregamento de frotas', v_root_id);

        -- Nível 3: Células Operacionais (Folhas / Sub-setores)
        INSERT INTO area (company_id, sector_name, location_description, parent_area_id)
        VALUES (v_comp_id, 'Linha Automatizada 01', 'Bancada robótica e esteira de estamparia', v_sub_id);

        INSERT INTO area (company_id, sector_name, location_description, parent_area_id)
        VALUES (v_comp_id, 'Ponto de Descarte de Sucata Metálica', 'Caçamba identificada de cavaco', v_sub_id);
    END IF;
END;
$$;


-- ============================================================
-- 3. CTE RECURSIVA: NAVEGAÇÃO DA ÁRVORE HIERÁRQUICA
-- Mapeia a profundidade (level), o caminho completo (path)
-- e o número de ocorrências associadas a cada nó.
-- ============================================================

WITH RECURSIVE area_hierarchy AS (
    -- Termo Âncora: Áreas raiz da empresa (sem superior)
    SELECT
        a.id,
        a.company_id,
        a.parent_area_id,
        a.sector_name,
        1 AS hierarchy_level,
        a.sector_name::TEXT AS hierarchy_path
    FROM area a
    WHERE a.parent_area_id IS NULL

    UNION ALL

    -- Termo Recursivo: Subsetores vinculados aos seus respectivos pais
    SELECT
        child.id,
        child.company_id,
        child.parent_area_id,
        child.sector_name,
        parent.hierarchy_level + 1,
        (parent.hierarchy_path || ' > ' || child.sector_name)::TEXT
    FROM area child
    INNER JOIN area_hierarchy parent
        ON child.parent_area_id = parent.id
)
SELECT
    ah.id AS area_id,
    c.name AS company_name,
    ah.hierarchy_level,
    ah.hierarchy_path,
    ah.sector_name,
    COUNT(i.id) AS total_incidents_recorded
FROM area_hierarchy ah
JOIN company c
    ON c.id = ah.company_id
LEFT JOIN incident i
    ON i.area_id = ah.id
GROUP BY
    ah.id,
    c.name,
    ah.hierarchy_level,
    ah.hierarchy_path,
    ah.sector_name
ORDER BY
    c.name,
    ah.hierarchy_path;