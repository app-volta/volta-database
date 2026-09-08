-- ============================================================
-- VOLTA - PostgreSQL - CREATES e  ALTERS/CONSTRAINTS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ============================================================
-- 1. COMPANY
-- ============================================================

CREATE TABLE IF NOT EXISTS company (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    cnpj VARCHAR(14) NOT NULL UNIQUE,
    address VARCHAR(255) NOT NULL
);


-- ============================================================
-- 2. ROLE
-- ============================================================

CREATE TABLE IF NOT EXISTS role (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(50) NOT NULL UNIQUE
);


-- ============================================================
-- 3. USERS
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    role_id UUID NOT NULL,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    position VARCHAR(100),

    CONSTRAINT fk_users_company
        FOREIGN KEY (company_id)
        REFERENCES company(id),

    CONSTRAINT fk_users_role
        FOREIGN KEY (role_id)
        REFERENCES role(id)
);


-- ============================================================
-- 4. AREA
-- ============================================================

CREATE TABLE IF NOT EXISTS area (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    sector_name VARCHAR(100) NOT NULL,
    location_description VARCHAR(255),

    CONSTRAINT fk_area_company
        FOREIGN KEY (company_id)
        REFERENCES company(id)
);


-- ============================================================
-- 5. WASTE TYPE
-- ============================================================

CREATE TABLE IF NOT EXISTS waste_type (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    default_risk_level VARCHAR(50) NOT NULL
);


-- ============================================================
-- 6. INCIDENT
-- ============================================================

CREATE TABLE IF NOT EXISTS incident (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    user_id UUID NOT NULL,
    area_id UUID NOT NULL,
    waste_type_id UUID,
    photo_url VARCHAR(500),
    employee_description TEXT NOT NULL,
    contamination_level VARCHAR(50),
    estimated_quantity DECIMAL(12,2),
    priority VARCHAR(30) NOT NULL,
    status VARCHAR(50) NOT NULL,
    registered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_incident_company
        FOREIGN KEY (company_id)
        REFERENCES company(id),

    CONSTRAINT fk_incident_user
        FOREIGN KEY (user_id)
        REFERENCES users(id),

    CONSTRAINT fk_incident_area
        FOREIGN KEY (area_id)
        REFERENCES area(id),

    CONSTRAINT fk_incident_waste_type
        FOREIGN KEY (waste_type_id)
        REFERENCES waste_type(id),

    CONSTRAINT chk_incident_quantity
        CHECK (
            estimated_quantity IS NULL
            OR estimated_quantity >= 0
        )
);


-- ============================================================
-- 7. AI REPORT
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_report (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID NOT NULL,
    detected_waste_type VARCHAR(100),
    ai_contamination_level VARCHAR(50),
    recommendations TEXT,
    report_text TEXT,
    generated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ai_report_incident
        FOREIGN KEY (incident_id)
        REFERENCES incident(id)
);


-- ============================================================
-- 8. ATTACHMENT
-- ============================================================

CREATE TABLE IF NOT EXISTS attachment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID NOT NULL,
    file_url VARCHAR(500) NOT NULL,
    file_type VARCHAR(100) NOT NULL,

    CONSTRAINT fk_attachment_incident
        FOREIGN KEY (incident_id)
        REFERENCES incident(id)
);


-- ============================================================
-- 9. COOPERATIVE
-- ============================================================

CREATE TABLE IF NOT EXISTS cooperative (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    cnpj VARCHAR(14) NOT NULL UNIQUE,
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    average_rating DECIMAL(3,2) DEFAULT 0,
    specialties VARCHAR(500),

    CONSTRAINT chk_cooperative_latitude
        CHECK (latitude BETWEEN -90 AND 90),

    CONSTRAINT chk_cooperative_longitude
        CHECK (longitude BETWEEN -180 AND 180),

    CONSTRAINT chk_cooperative_rating
        CHECK (average_rating BETWEEN 0 AND 5)
);


-- ============================================================
-- 10. COLLECTION
-- ============================================================

CREATE TABLE IF NOT EXISTS collection (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID NOT NULL,
    cooperative_id UUID NOT NULL,
    requested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    scheduled_at TIMESTAMP,
    current_status VARCHAR(50) NOT NULL,
    collection_type VARCHAR(50) NOT NULL,
    urgent BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT fk_collection_incident
        FOREIGN KEY (incident_id)
        REFERENCES incident(id),

    CONSTRAINT fk_collection_cooperative
        FOREIGN KEY (cooperative_id)
        REFERENCES cooperative(id),

    CONSTRAINT chk_collection_dates
        CHECK (
            scheduled_at IS NULL
            OR scheduled_at >= requested_at
        )
);


-- ============================================================
-- 11. COLLECTION STATUS
-- ============================================================

CREATE TABLE IF NOT EXISTS collection_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    collection_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observation TEXT,

    CONSTRAINT fk_collection_status_collection
        FOREIGN KEY (collection_id)
        REFERENCES collection(id)
);


-- ============================================================
-- 12. REVIEW
-- ============================================================

CREATE TABLE IF NOT EXISTS review (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cooperative_id UUID NOT NULL,
    user_id UUID NOT NULL,
    collection_id UUID NOT NULL,
    stars INTEGER NOT NULL,
    comment TEXT,
    reviewed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_review_cooperative
        FOREIGN KEY (cooperative_id)
        REFERENCES cooperative(id),

    CONSTRAINT fk_review_user
        FOREIGN KEY (user_id)
        REFERENCES users(id),

    CONSTRAINT fk_review_collection
        FOREIGN KEY (collection_id)
        REFERENCES collection(id),

    CONSTRAINT chk_review_stars
        CHECK (stars BETWEEN 1 AND 5)
);


-- ============================================================
-- 13. CONVERSATION
-- ============================================================

CREATE TABLE IF NOT EXISTS conversation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    cooperative_id UUID NOT NULL,
    collection_id UUID NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_conversation_company
        FOREIGN KEY (company_id)
        REFERENCES company(id),

    CONSTRAINT fk_conversation_cooperative
        FOREIGN KEY (cooperative_id)
        REFERENCES cooperative(id),

    CONSTRAINT fk_conversation_collection
        FOREIGN KEY (collection_id)
        REFERENCES collection(id)
);


-- ============================================================
-- 14. MESSAGE
-- ============================================================

CREATE TABLE IF NOT EXISTS message (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    user_id UUID NOT NULL,
    text TEXT NOT NULL,
    reported BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_message_conversation
        FOREIGN KEY (conversation_id)
        REFERENCES conversation(id),

    CONSTRAINT fk_message_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
);


-- ============================================================
-- 15. MESSAGE ATTACHMENT
-- ============================================================

CREATE TABLE IF NOT EXISTS message_attachment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL,
    file_url VARCHAR(500) NOT NULL,
    file_type VARCHAR(100) NOT NULL,

    CONSTRAINT fk_message_attachment_message
        FOREIGN KEY (message_id)
        REFERENCES message(id)
);


-- ============================================================
-- 16. NOTIFICATION
-- ============================================================

CREATE TABLE IF NOT EXISTS notification (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_notification_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
);


-- ============================================================
-- 17. ESG METRIC
-- ============================================================

CREATE TABLE IF NOT EXISTS esg_metric (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    period VARCHAR(20) NOT NULL,
    total_waste_kg DECIMAL(14,2) NOT NULL DEFAULT 0,
    total_recycled_kg DECIMAL(14,2) NOT NULL DEFAULT 0,
    recycling_percentage DECIMAL(5,2) NOT NULL DEFAULT 0,
    calculated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_esg_metric_company
        FOREIGN KEY (company_id)
        REFERENCES company(id),

    CONSTRAINT chk_esg_total_waste
        CHECK (total_waste_kg >= 0),

    CONSTRAINT chk_esg_total_recycled
        CHECK (total_recycled_kg >= 0),

    CONSTRAINT chk_esg_percentage
        CHECK (recycling_percentage BETWEEN 0 AND 100),

    CONSTRAINT chk_esg_recycled_not_greater
        CHECK (total_recycled_kg <= total_waste_kg)
);

ALTER TABLE company
ALTER COLUMN cnpj TYPE VARCHAR(18);

ALTER TABLE cooperative
ALTER COLUMN cnpj TYPE VARCHAR(18);
