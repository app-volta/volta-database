-- =========================
-- VOLTA — Schema legado
-- =========================


CREATE TABLE role (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE company (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    cnpj VARCHAR(14) NOT NULL UNIQUE,
    address VARCHAR(255) NOT NULL,

    CONSTRAINT chk_company_cnpj
    CHECK (cnpj ~ '^[0-9]{14}$')
);

CREATE TABLE users (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id INTEGER NOT NULL,
    role_id INTEGER NOT NULL,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    position VARCHAR(100),

    CONSTRAINT fk_users_company
    FOREIGN KEY (company_id)
    REFERENCES company(id),

    CONSTRAINT fk_users_role
    FOREIGN KEY (role_id)
    REFERENCES role(id)
);

CREATE TABLE area (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id INTEGER NOT NULL,
    sector_name VARCHAR(150) NOT NULL,
    location_description VARCHAR(255),

    CONSTRAINT fk_area_company
    FOREIGN KEY (company_id)
    REFERENCES company(id)
);

CREATE TABLE waste_type (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    default_risk VARCHAR(50) NOT NULL,

    CONSTRAINT chk_waste_risk
    CHECK (default_risk IN ('BAIXO', 'MEDIO', 'ALTO'))
);

CREATE TABLE incident (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    area_id INTEGER NOT NULL,
    waste_type_id INTEGER NOT NULL,
    photo_url VARCHAR(500),
    employee_description TEXT,
    contamination_level VARCHAR(50),
    estimated_quantity DECIMAL(10,2),
    priority VARCHAR(50) NOT NULL DEFAULT 'MEDIA',
    status VARCHAR(50) NOT NULL DEFAULT 'PENDENTE',
    registered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estimated_weight DECIMAL(10,2),

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
    CHECK (estimated_quantity >= 0),

    CONSTRAINT chk_incident_weight
    CHECK (estimated_weight >= 0),

    CONSTRAINT chk_incident_priority
    CHECK (priority IN ('BAIXA', 'MEDIA', 'ALTA', 'URGENTE')),

    CONSTRAINT chk_incident_status
    CHECK (status IN ('PENDENTE', 'EM_ANALISE', 'RESOLVIDA', 'CANCELADA'))
);

CREATE TABLE ai_report (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    incident_id INTEGER NOT NULL UNIQUE,
    detected_waste VARCHAR(100),
    ai_contamination_level VARCHAR(50),
    recommendations TEXT,
    report_text TEXT,
    generated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ai_report_incident
    FOREIGN KEY (incident_id)
    REFERENCES incident(id)
);

CREATE TABLE attachment (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    incident_id INTEGER NOT NULL,
    file_url VARCHAR(500) NOT NULL,
    file_type VARCHAR(50) NOT NULL,

    CONSTRAINT fk_attachment_incident
    FOREIGN KEY (incident_id)
    REFERENCES incident(id)
);

CREATE TABLE cooperative (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    cnpj VARCHAR(14) NOT NULL UNIQUE,
    latitude DECIMAL(10,7),
    longitude DECIMAL(10,7),
    average_rating DECIMAL(3,2) DEFAULT 0,
    specialties VARCHAR(500),
    opening_time TIME,
    monthly_capacity DECIMAL(10,2),

    CONSTRAINT chk_cooperative_cnpj
    CHECK (cnpj ~ '^[0-9]{14}$'),

    CONSTRAINT chk_cooperative_rating
    CHECK (average_rating BETWEEN 0 AND 5),

    CONSTRAINT chk_cooperative_capacity
    CHECK (monthly_capacity >= 0)
);

CREATE TABLE collection (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    incident_id INTEGER NOT NULL,
    cooperative_id INTEGER NOT NULL,
    request_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    scheduled_date TIMESTAMP,
    current_status VARCHAR(50) NOT NULL DEFAULT 'SOLICITADA',
    collection_type VARCHAR(50),
    urgent BOOLEAN NOT NULL DEFAULT FALSE,
    estimated_time TIME,

    CONSTRAINT fk_collection_incident
    FOREIGN KEY (incident_id)
    REFERENCES incident(id),

    CONSTRAINT fk_collection_cooperative
    FOREIGN KEY (cooperative_id)
    REFERENCES cooperative(id),

    CONSTRAINT chk_collection_status
    CHECK (
        current_status IN (
            'SOLICITADA',
            'AGENDADA',
            'ACEITA',
            'EM_ANDAMENTO',
            'CONCLUIDA',
            'CANCELADA'
        )
    )
);

CREATE TABLE collection_status (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    collection_id INTEGER NOT NULL,
    status VARCHAR(50) NOT NULL,
    change_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observation TEXT,

    CONSTRAINT fk_collection_status_collection
    FOREIGN KEY (collection_id)
    REFERENCES collection(id)
);

CREATE TABLE review (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cooperative_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    collection_id INTEGER NOT NULL,
    stars INTEGER NOT NULL,
    comment TEXT,
    review_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

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

CREATE TABLE conversation (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id INTEGER NOT NULL,
    cooperative_id INTEGER NOT NULL,
    collection_id INTEGER,
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

CREATE TABLE message (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    conversation_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    text TEXT NOT NULL,
    reported BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_message_conversation
    FOREIGN KEY (conversation_id)
    REFERENCES conversation(id),

    CONSTRAINT fk_message_user
    FOREIGN KEY (user_id)
    REFERENCES users(id),

    CONSTRAINT chk_message_text
    CHECK (LENGTH(TRIM(text)) > 0)
);

CREATE TABLE message_attachment (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    message_id INTEGER NOT NULL,
    file_url VARCHAR(500) NOT NULL,
    file_type VARCHAR(50) NOT NULL,

    CONSTRAINT fk_message_attachment_message
    FOREIGN KEY (message_id)
    REFERENCES message(id)
);

CREATE TABLE notification (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_notification_user
    FOREIGN KEY (user_id)
    REFERENCES users(id)
);

CREATE TABLE esg_metric (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id INTEGER NOT NULL,
    period VARCHAR(20) NOT NULL,
    total_kg_waste DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_kg_recycled DECIMAL(12,2) NOT NULL DEFAULT 0,
    recycling_percentage DECIMAL(5,2) NOT NULL DEFAULT 0,
    calculated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_esg_metric_company
    FOREIGN KEY (company_id)
    REFERENCES company(id),

    CONSTRAINT chk_esg_total_waste
    CHECK (total_kg_waste >= 0),

    CONSTRAINT chk_esg_total_recycled
    CHECK (total_kg_recycled >= 0),

    CONSTRAINT chk_esg_percentage
    CHECK (recycling_percentage BETWEEN 0 AND 100)
);