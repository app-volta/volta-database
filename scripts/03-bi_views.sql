-- Camada analítica (Data Mart) do projeto VOLTA.
-- Execute este script após criar o schema público e popular o banco.

CREATE SCHEMA IF NOT EXISTS bi;

CREATE OR REPLACE VIEW bi.dim_company AS
SELECT
    c.id AS company_id,
    c.name AS company_name,
    c.cnpj,
    c.address,
    c.is_available
FROM public.company c;

CREATE OR REPLACE VIEW bi.dim_area AS
SELECT
    a.id AS area_id,
    a.company_id,
    a.sector_name,
    a.location_description
FROM public.area a;

CREATE OR REPLACE VIEW bi.dim_waste_type AS
SELECT
    wt.id AS waste_type_id,
    wt.category AS waste_category,
    wt.description AS waste_description,
    wt.default_risk_level
FROM public.waste_type wt;

CREATE OR REPLACE VIEW bi.dim_cooperative AS
SELECT
    co.id AS cooperative_id,
    co.name AS cooperative_name,
    co.cnpj,
    co.latitude,
    co.longitude,
    co.average_rating,
    co.specialties
FROM public.cooperative co;

CREATE OR REPLACE VIEW bi.dim_date AS
WITH date_bounds AS (
    SELECT
        MIN(source_date)::date AS first_date,
        MAX(source_date)::date AS last_date
    FROM (
        SELECT registered_at AS source_date FROM public.incident
        UNION ALL
        SELECT requested_at FROM public.collection
        UNION ALL
        SELECT scheduled_at FROM public.collection WHERE scheduled_at IS NOT NULL
        UNION ALL
        SELECT calculated_at FROM public.esg_metric
        UNION ALL
        SELECT reviewed_at FROM public.review
    ) dates
),
calendar AS (
    SELECT generate_series(
        COALESCE(first_date, CURRENT_DATE),
        COALESCE(last_date, CURRENT_DATE),
        INTERVAL '1 day'
    )::date AS date_key
    FROM date_bounds
)
SELECT
    date_key,
    EXTRACT(YEAR FROM date_key)::int AS year,
    EXTRACT(MONTH FROM date_key)::int AS month,
    EXTRACT(DAY FROM date_key)::int AS day,
    EXTRACT(QUARTER FROM date_key)::int AS quarter,
    EXTRACT(DOW FROM date_key)::int AS day_of_week,
    TO_CHAR(date_key, 'YYYY-MM') AS year_month
FROM calendar;

CREATE OR REPLACE VIEW bi.fact_incident AS
SELECT
    i.id AS incident_id,
    i.company_id,
    i.user_id,
    i.area_id,
    i.waste_type_id,
    i.registered_at::date AS date_key,
    EXTRACT(HOUR FROM i.registered_at)::int AS registered_hour,
    i.registered_at,
    i.contamination_level,
    i.estimated_quantity AS estimated_quantity_kg,
    i.priority,
    i.status,
    EXISTS (
        SELECT 1
        FROM public.attachment a
        WHERE a.incident_id = i.id
    ) AS has_attachment,
    ar.id IS NOT NULL AS has_ai_report,
    ar.detected_waste_type,
    ar.ai_contamination_level,
    ar.generated_at AS ai_report_generated_at
FROM public.incident i
LEFT JOIN LATERAL (
    SELECT
        ar.id,
        ar.detected_waste_type,
        ar.ai_contamination_level,
        ar.generated_at
    FROM public.ai_report ar
    WHERE ar.incident_id = i.id
    ORDER BY ar.generated_at DESC, ar.id DESC
    LIMIT 1
) ar ON TRUE;

CREATE OR REPLACE VIEW bi.fact_collection AS
WITH status_rollup AS (
    SELECT
        cs.collection_id,
        MAX(cs.changed_at) AS last_status_at,
        MAX(cs.changed_at) FILTER (
            WHERE UPPER(cs.status) IN (
                'CONCLUIDA',
                'FINALIZADA',
                'COLETADA',
                'COMPLETED',
                'DONE'
            )
        ) AS completed_at
    FROM public.collection_status cs
    GROUP BY cs.collection_id
)
SELECT
    c.id AS collection_id,
    c.incident_id,
    i.company_id,
    i.area_id,
    i.waste_type_id,
    c.cooperative_id,
    c.requested_at::date AS requested_date_key,
    c.scheduled_at::date AS scheduled_date_key,
    c.requested_at,
    c.scheduled_at,
    sr.completed_at,
    sr.last_status_at,
    c.current_status,
    c.collection_type,
    c.urgent,
    CASE
        WHEN c.scheduled_at IS NULL THEN NULL
        ELSE EXTRACT(EPOCH FROM (c.scheduled_at - c.requested_at)) / 3600
    END AS scheduling_time_hours,
    CASE
        WHEN sr.completed_at IS NULL THEN NULL
        ELSE EXTRACT(EPOCH FROM (sr.completed_at - c.requested_at)) / 3600
    END AS resolution_time_hours
FROM public.collection c
JOIN public.incident i
    ON i.id = c.incident_id
LEFT JOIN status_rollup sr
    ON sr.collection_id = c.id;

CREATE OR REPLACE VIEW bi.fact_esg_metric AS
SELECT
    em.id AS esg_metric_id,
    em.company_id,
    em.period,
    em.total_waste_kg,
    em.total_recycled_kg,
    em.recycling_percentage,
    em.calculated_at,
    em.calculated_at::date AS calculated_date_key,
    CASE
        WHEN em.period ~ '^[0-9]{4}-[0-9]{2}$'
        THEN to_date(em.period || '-01', 'YYYY-MM-DD')
        ELSE NULL
    END AS period_date
FROM public.esg_metric em;

CREATE OR REPLACE VIEW bi.fact_cooperative_review AS
SELECT
    r.id AS review_id,
    r.cooperative_id,
    r.user_id,
    r.collection_id,
    c.incident_id,
    i.company_id,
    r.stars,
    r.comment,
    r.reviewed_at,
    r.reviewed_at::date AS reviewed_date_key
FROM public.review r
JOIN public.collection c
    ON c.id = r.collection_id
JOIN public.incident i
    ON i.id = c.incident_id;

CREATE OR REPLACE VIEW bi.mart_occurrences_dashboard AS
SELECT
    fi.incident_id,
    fi.company_id,
    dc.company_name,
    dc.is_available AS company_is_available,
    fi.area_id,
    da.sector_name,
    da.location_description,
    fi.waste_type_id,
    dwt.waste_category,
    dwt.default_risk_level,
    fi.date_key,
    dd.year,
    dd.month,
    dd.year_month,
    fi.registered_hour,
    fi.registered_at,
    fi.priority,
    fi.status,
    fi.contamination_level,
    fi.estimated_quantity_kg,
    fi.has_attachment,
    fi.has_ai_report
FROM bi.fact_incident fi
JOIN bi.dim_company dc
    ON dc.company_id = fi.company_id
LEFT JOIN bi.dim_area da
    ON da.area_id = fi.area_id
LEFT JOIN bi.dim_waste_type dwt
    ON dwt.waste_type_id = fi.waste_type_id
LEFT JOIN bi.dim_date dd
    ON dd.date_key = fi.date_key;

CREATE OR REPLACE VIEW bi.mart_collection_performance AS
SELECT
    fc.collection_id,
    fc.incident_id,
    fc.company_id,
    dc.company_name,
    dc.is_available AS company_is_available,
    fc.area_id,
    da.sector_name,
    fc.waste_type_id,
    dwt.waste_category,
    fc.cooperative_id,
    dco.cooperative_name,
    dco.latitude,
    dco.longitude,
    dco.average_rating,
    fc.requested_date_key,
    dd.year,
    dd.month,
    dd.year_month,
    fc.requested_at,
    fc.scheduled_at,
    fc.completed_at,
    fc.last_status_at,
    fc.scheduling_time_hours,
    fc.resolution_time_hours,
    fc.current_status,
    fc.collection_type,
    fc.urgent
FROM bi.fact_collection fc
JOIN bi.dim_company dc
    ON dc.company_id = fc.company_id
LEFT JOIN bi.dim_area da
    ON da.area_id = fc.area_id
LEFT JOIN bi.dim_waste_type dwt
    ON dwt.waste_type_id = fc.waste_type_id
JOIN bi.dim_cooperative dco
    ON dco.cooperative_id = fc.cooperative_id
LEFT JOIN bi.dim_date dd
    ON dd.date_key = fc.requested_date_key;

CREATE OR REPLACE VIEW bi.mart_esg_monthly AS
SELECT
    fem.esg_metric_id,
    fem.company_id,
    dc.company_name,
    dc.is_available AS company_is_available,
    fem.period,
    fem.total_waste_kg,
    fem.total_recycled_kg,
    fem.recycling_percentage,
    fem.calculated_at,
    fem.recycling_percentage
        - LAG(fem.recycling_percentage) OVER (
            PARTITION BY fem.company_id
            ORDER BY fem.period_date NULLS LAST, fem.calculated_at
        ) AS recycling_percentage_delta
FROM bi.fact_esg_metric fem
JOIN bi.dim_company dc
    ON dc.company_id = fem.company_id;+