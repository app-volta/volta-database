-- Tabelas SQL (Banco do primeiro ano)
-- Volta: criação do banco (postgresql 12 ou mais novo)
 
DROP TABLE IF EXISTS complaint CASCADE;
DROP TABLE IF EXISTS esg_metric CASCADE;
DROP TABLE IF EXISTS notification CASCADE;
DROP TABLE IF EXISTS message_attachment CASCADE;
DROP TABLE IF EXISTS message CASCADE;
DROP TABLE IF EXISTS conversation CASCADE;
DROP TABLE IF EXISTS review CASCADE;
DROP TABLE IF EXISTS collection_status CASCADE;
DROP TABLE IF EXISTS collection CASCADE;
DROP TABLE IF EXISTS attachment CASCADE;
DROP TABLE IF EXISTS ai_report CASCADE;
DROP TABLE IF EXISTS incident CASCADE;
DROP TABLE IF EXISTS cooperative_waste_type CASCADE;
DROP TABLE IF EXISTS waste_type CASCADE;
DROP TABLE IF EXISTS area CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS cooperative CASCADE;
DROP TABLE IF EXISTS company CASCADE;
DROP TABLE IF EXISTS role CASCADE;
 
-- perfis de acesso (administrador, gerente, funcionario)
CREATE TABLE role (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type VARCHAR(50) NOT NULL UNIQUE
);
 
CREATE TABLE company (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    cnpj VARCHAR(14) NOT NULL UNIQUE,
    cep VARCHAR(8),
    address VARCHAR(255) NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
 
    CONSTRAINT chk_cooperative_cep CHECK (cep ~ '^[0-9]{8}$'),
    CONSTRAINT chk_company_cnpj CHECK (cnpj ~ '^[0-9]{14}$')
);
 
-- as especialidades ficam em cooperative_waste_type
-- e a nota média na view vw_cooperative_rating
CREATE TABLE cooperative (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    cnpj VARCHAR(14) NOT NULL UNIQUE,
    cep VARCHAR(8),
    latitude DECIMAL(10,7) NOT NULL,
    longitude DECIMAL(10,7) NOT NULL,
    opening_time TIME,
    closing_time TIME,
    monthly_capacity DECIMAL(10,2),
 
    CONSTRAINT chk_cooperative_cnpj CHECK (cnpj ~ '^[0-9]{14}$'),
    CONSTRAINT chk_cooperative_cep CHECK (cep ~ '^[0-9]{8}$'),
    
    
    -- as coordenadas precisam estar dentro da cidade de são paulo
    CONSTRAINT chk_cooperative_latitude CHECK (latitude BETWEEN -24.10 AND -23.30),
    CONSTRAINT chk_cooperative_longitude CHECK (longitude BETWEEN -46.90 AND -46.30),
    CONSTRAINT chk_cooperative_hours CHECK (closing_time > opening_time),
    CONSTRAINT chk_cooperative_capacity CHECK (monthly_capacity >= 0)
);
 
-- cada usuário é de uma empresa ou de uma cooperativa, nunca dos dois
CREATE TABLE users (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id INTEGER,
    cooperative_id INTEGER,
    role_id INTEGER NOT NULL,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    position VARCHAR(100),
 
    CONSTRAINT fk_users_company FOREIGN KEY (company_id) REFERENCES company(id) ON DELETE RESTRICT,
    CONSTRAINT fk_users_cooperative FOREIGN KEY (cooperative_id) REFERENCES cooperative(id) ON DELETE RESTRICT,
    CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES role(id) ON DELETE RESTRICT,
    CONSTRAINT chk_users_owner CHECK (
        (company_id IS NOT NULL AND cooperative_id IS NULL)
        OR (company_id IS NULL AND cooperative_id IS NOT NULL)
    ),
    CONSTRAINT chk_users_email CHECK (email LIKE '%@%.%')
);
 
CREATE TABLE area (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id INTEGER NOT NULL,
    sector_name VARCHAR(150) NOT NULL,
    location_description VARCHAR(255),
 
    CONSTRAINT fk_area_company FOREIGN KEY (company_id) REFERENCES company(id) ON DELETE RESTRICT
);
 
CREATE TABLE waste_type (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    default_risk VARCHAR(50) NOT NULL,
 
    CONSTRAINT chk_waste_risk CHECK (default_risk IN ('BAIXO', 'MEDIO', 'ALTO'))
);
 
-- tabela de ligação: uma cooperativa aceita vários tipos de resíduo
-- e um tipo de resíduo pode ser aceito por várias cooperativas
CREATE TABLE cooperative_waste_type (
    cooperative_id INTEGER NOT NULL,
    waste_type_id INTEGER NOT NULL,
 
    PRIMARY KEY (cooperative_id, waste_type_id),
    CONSTRAINT fk_cooperative_waste_type_cooperative FOREIGN KEY (cooperative_id) REFERENCES cooperative(id) ON DELETE CASCADE,
    CONSTRAINT fk_cooperative_waste_type_waste_type FOREIGN KEY (waste_type_id) REFERENCES waste_type(id) ON DELETE RESTRICT
);
 
-- a empresa da ocorrência vem da área (area.company_id)
-- photo_url é a foto principal, outros arquivos ficam em attachment
CREATE TABLE incident (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL,
    area_id INTEGER NOT NULL,
    waste_type_id INTEGER NOT NULL,
    photo_url VARCHAR(500),
    employee_description TEXT NOT NULL,
    contamination_level VARCHAR(50),
    priority VARCHAR(50) NOT NULL DEFAULT 'MEDIA',
    status VARCHAR(50) NOT NULL DEFAULT 'PENDENTE',
    registered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estimated_weight DECIMAL(10,2),
 
    CONSTRAINT fk_incident_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_incident_area FOREIGN KEY (area_id) REFERENCES area(id) ON DELETE RESTRICT,
    CONSTRAINT fk_incident_waste_type FOREIGN KEY (waste_type_id) REFERENCES waste_type(id) ON DELETE RESTRICT,
    CONSTRAINT chk_incident_contamination CHECK (contamination_level IN ('BAIXO', 'MEDIO', 'ALTO')),
    CONSTRAINT chk_incident_weight CHECK (estimated_weight >= 0),
    CONSTRAINT chk_incident_priority CHECK (priority IN ('BAIXA', 'MEDIA', 'ALTA', 'URGENTE')),
    CONSTRAINT chk_incident_status CHECK (status IN ('PENDENTE', 'EM_ANALISE', 'RESOLVIDA', 'CANCELADA'))
);
 
-- um relatório de ia por ocorrência
CREATE TABLE ai_report (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    incident_id INTEGER NOT NULL UNIQUE,
    detected_waste VARCHAR(100),
    ai_contamination_level VARCHAR(50),
    recommendations TEXT,
    report_text TEXT,
    generated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 
    CONSTRAINT fk_ai_report_incident FOREIGN KEY (incident_id) REFERENCES incident(id) ON DELETE CASCADE,
    CONSTRAINT chk_ai_report_contamination CHECK (ai_contamination_level IN ('BAIXO', 'MEDIO', 'ALTO'))
);
 
CREATE TABLE attachment (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    incident_id INTEGER NOT NULL,
    file_url VARCHAR(500) NOT NULL,
    file_type VARCHAR(50) NOT NULL,
 
    CONSTRAINT fk_attachment_incident FOREIGN KEY (incident_id) REFERENCES incident(id) ON DELETE CASCADE,
    CONSTRAINT chk_attachment_file_type CHECK (file_type IN ('PDF', 'JPG', 'PNG'))
);
 
-- current_status guarda o último status da coleta, para consultar rápido.
-- toda vez que entrar uma linha em collection_status, a aplicação também
-- atualiza esta coluna (na mesma transação). a view vw_collection_status_check
-- mostra se algum valor ficou diferente do histórico.
CREATE TABLE collection (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    incident_id INTEGER NOT NULL,
    cooperative_id INTEGER NOT NULL,
    request_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    scheduled_date TIMESTAMP,
    current_status VARCHAR(50) NOT NULL DEFAULT 'SOLICITADA',
    collection_type VARCHAR(50),
    urgent BOOLEAN NOT NULL DEFAULT FALSE,
    estimated_time INTERVAL,
 
    CONSTRAINT fk_collection_incident FOREIGN KEY (incident_id) REFERENCES incident(id) ON DELETE RESTRICT,
    CONSTRAINT fk_collection_cooperative FOREIGN KEY (cooperative_id) REFERENCES cooperative(id) ON DELETE RESTRICT,
    CONSTRAINT chk_collection_current_status CHECK (current_status IN ('SOLICITADA', 'AGENDADA', 'ACEITA', 'EM_ANDAMENTO', 'CONCLUIDA', 'CANCELADA')),
    CONSTRAINT chk_collection_type CHECK (collection_type IN ('PADRAO', 'RECORRENTE')),
    CONSTRAINT chk_collection_scheduled_date CHECK (scheduled_date >= request_date)
);
 
-- histórico: cada mudança de status da coleta vira uma linha
CREATE TABLE collection_status (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    collection_id INTEGER NOT NULL,
    status VARCHAR(50) NOT NULL,
    change_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observation TEXT,
 
    CONSTRAINT fk_collection_status_collection FOREIGN KEY (collection_id) REFERENCES collection(id) ON DELETE CASCADE,
    CONSTRAINT chk_collection_status_status CHECK (status IN ('SOLICITADA', 'AGENDADA', 'ACEITA', 'EM_ANDAMENTO', 'CONCLUIDA', 'CANCELADA'))
);
 
-- a cooperativa avaliada vem da coleta (collection.cooperative_id)
CREATE TABLE review (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL,
    collection_id INTEGER NOT NULL,
    stars INTEGER NOT NULL,
    comment TEXT,
    review_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 
    CONSTRAINT fk_review_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_review_collection FOREIGN KEY (collection_id) REFERENCES collection(id) ON DELETE RESTRICT,
    CONSTRAINT chk_review_stars CHECK (stars BETWEEN 1 AND 5)
);
 
-- toda conversa pertence a uma coleta (a conversa começa depois do aceite)
CREATE TABLE conversation (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id INTEGER NOT NULL,
    cooperative_id INTEGER NOT NULL,
    collection_id INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 
    CONSTRAINT fk_conversation_company FOREIGN KEY (company_id) REFERENCES company(id) ON DELETE RESTRICT,
    CONSTRAINT fk_conversation_cooperative FOREIGN KEY (cooperative_id) REFERENCES cooperative(id) ON DELETE RESTRICT,
    CONSTRAINT fk_conversation_collection FOREIGN KEY (collection_id) REFERENCES collection(id) ON DELETE RESTRICT
);
 
CREATE TABLE message (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    conversation_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    text TEXT NOT NULL,
    reported BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 
    CONSTRAINT fk_message_conversation FOREIGN KEY (conversation_id) REFERENCES conversation(id) ON DELETE CASCADE,
    CONSTRAINT fk_message_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT chk_message_text CHECK (LENGTH(TRIM(text)) > 0)
);
 
CREATE TABLE message_attachment (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    message_id INTEGER NOT NULL,
    file_url VARCHAR(500) NOT NULL,
    file_type VARCHAR(50) NOT NULL,
 
    CONSTRAINT fk_message_attachment_message FOREIGN KEY (message_id) REFERENCES message(id) ON DELETE CASCADE,
    CONSTRAINT chk_message_attachment_file_type CHECK (file_type IN ('PDF', 'JPG', 'PNG'))
);
 
CREATE TABLE notification (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 
    CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_notification_type CHECK (type IN ('INCIDENTE', 'COLETA', 'SISTEMA'))
);
 
-- period é o mês no formato AAAA-MM
-- recycling_percentage o banco calcula sozinho, não entra no insert
CREATE TABLE esg_metric (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id INTEGER NOT NULL,
    period VARCHAR(20) NOT NULL,
    total_kg_waste DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_kg_recycled DECIMAL(12,2) NOT NULL DEFAULT 0,
    recycling_percentage DECIMAL(5,2) GENERATED ALWAYS AS (
        ROUND(total_kg_recycled * 100 / NULLIF(total_kg_waste, 0), 2)
    ) STORED,
    calculated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 
    CONSTRAINT fk_esg_metric_company FOREIGN KEY (company_id) REFERENCES company(id) ON DELETE RESTRICT,
    CONSTRAINT uq_esg_metric_company_period UNIQUE (company_id, period),
    CONSTRAINT chk_esg_metric_period CHECK (period ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
    CONSTRAINT chk_esg_total_waste CHECK (total_kg_waste >= 0),
    CONSTRAINT chk_esg_total_recycled CHECK (total_kg_recycled >= 0),
    CONSTRAINT chk_esg_recycled_not_above_waste CHECK (total_kg_recycled <= total_kg_waste)
);
 
-- a empresa da denúncia vem da ocorrência
CREATE TABLE complaint (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cooperative_id INTEGER NOT NULL,
    incident_id INTEGER NOT NULL,
    photo VARCHAR(500),
    description TEXT NOT NULL,
    complaint_date DATE NOT NULL DEFAULT CURRENT_DATE,
 
    CONSTRAINT fk_complaint_cooperative FOREIGN KEY (cooperative_id) REFERENCES cooperative(id) ON DELETE RESTRICT,
    CONSTRAINT fk_complaint_incident FOREIGN KEY (incident_id) REFERENCES incident(id) ON DELETE RESTRICT
);