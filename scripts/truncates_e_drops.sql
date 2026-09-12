-- ============================================================
-- VOLTA - PostgreSQL - TRUNCATES e DROPS
-- ============================================================

TRUNCATE TABLE
    message_attachment,
    message,
    conversation,
    review,
    collection_status,
    collection,
    attachment,
    ai_report,
    incident,
    notification,
    esg_metric,
    area,
    users,
    cooperative,
    waste_type,
    company,
    role
RESTART IDENTITY CASCADE;

DROP TABLE IF EXISTS
    message_attachment,
    message,
    conversation,
    review,
    collection_status,
    collection,
    attachment,
    ai_report,
    incident,
    notification,
    esg_metric,
    area,
    users,
    cooperative,
    waste_type,
    company,
    role
CASCADE;