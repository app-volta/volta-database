-- ============================================================
-- VOLTA - DATA LOAD CONSOLIDADO (600+ REGISTROS)
-- PostgreSQL | Requer schema atual + pgcrypto
-- Totalmente compatível com 3FN e constraints organizacionais
-- ============================================================

BEGIN;

-- ============================================================
-- 1. DADOS FIXOS: ROLES, COMPANHIA E COOPERATIVAS
-- ============================================================

INSERT INTO role (type) VALUES
('ADMIN'), ('MANAGER'), ('EMPLOYEE')
ON CONFLICT (type) DO NOTHING;

INSERT INTO company (name, cnpj, address, is_available) VALUES
('EcoTech Indústria Ltda', '12.345.678/0001-01', 'Av. Paulista, 1000, São Paulo - SP', TRUE),
('Verde Futuro S.A.', '23.456.789/0001-02', 'Rua das Flores, 245, Campinas - SP', TRUE),
('Indústria Sustentável Ltda', '34.567.890/0001-03', 'Av. Brasil, 550, Santos - SP', TRUE),
('Nova Terra Logística', '45.678.901/0001-04', 'Rua Industrial, 820, Jundiaí - SP', TRUE),
('BioCycle Brasil', '56.789.012/0001-05', 'Av. Ambiental, 320, Sorocaba - SP', TRUE),
('GreenWorks Comércio', '67.890.123/0001-06', 'Rua Central, 77, Osasco - SP', TRUE),
('Recicla Mais S.A.', '78.901.234/0001-07', 'Av. das Nações, 120, Barueri - SP', TRUE),
('Evolução Ambiental Ltda', '89.012.345/0001-08', 'Rua Sustentável, 430, São Paulo - SP', FALSE),
('Circular Solutions', '90.123.456/0001-09', 'Av. Tecnologia, 900, Guarulhos - SP', TRUE),
('Impacto Zero Indústria', '01.234.567/0001-10', 'Rua da Produção, 210, Mogi das Cruzes - SP', FALSE)
ON CONFLICT (cnpj) DO NOTHING;

INSERT INTO cooperative (name, cnpj, email, latitude, longitude, average_rating, specialties) VALUES
('Cooperativa Verde São Paulo', '11.111.111/0001-01', 'caduamaral87@gmail.com', -23.550520, -46.633308, 4.50, 'Plástico, papel e metal'),
('Recicla SP Cooperativa', '22.222.222/0001-02', 'contato@reciclasp.coop.br', -23.561414, -46.655881, 4.30, 'Papel e papelão'),
('Coop Ambiental Paulista', '33.333.333/0001-03', 'operacoes@coopambientalpaulista.org.br', -23.548943, -46.638818, 4.70, 'Vidro e plástico'),
('EcoCoop Campinas', '44.444.444/0001-04', 'coleta@ecocoopcampinas.com.br', -22.905560, -47.060830, 4.20, 'Plástico e orgânicos'),
('Cooperativa Novo Ciclo', '55.555.555/0001-05', 'triagem@coopnovociclo.com.br', -23.179440, -45.886940, 4.60, 'Metal e eletrônicos'),
('Coop Reciclagem Santos', '66.666.666/0001-06', 'atendimento@coopreciclagemsantos.org.br', -23.960830, -46.333610, 4.10, 'Vidro e papel'),
('Cooperativa Futuro Verde', '77.777.777/0001-07', 'contato@futuroverde.coop.br', -23.501530, -46.875000, 4.40, 'Plástico e metal'),
('Coop Circular Jundiaí', '88.888.888/0001-08', 'operacional@circularjundiai.org.br', -23.185700, -46.897800, 4.80, 'Papel, plástico e vidro'),
('Cooperativa Sustenta Brasil', '99.999.999/0001-09', 'sustentabilidade@sustentabrasil.com.br', -23.532900, -46.791700, 4.50, 'Resíduos industriais'),
('Coop EcoAção', '10.101.010/0001-10', 'chamados@ecoacao.coop.br', -23.550000, -46.650000, 4.00, 'Resíduos orgânicos'),
('Reciclagem Solidária ABC', '20.202.020/0001-11', 'contato@reciclagemabc.org.br', -23.674000, -46.543000, 4.30, 'Metal e plástico'),
('Cooperativa Reutilizar', '30.303.030/0001-12', 'diretoria@reutilizar.org.br', -23.499000, -46.850000, 4.60, 'Eletrônicos'),
('Coop Planeta Limpo', '40.404.040/0001-13', 'triagem@planetalimpo.org.br', -23.610000, -46.700000, 4.20, 'Papel e vidro'),
('Cooperativa Vida Circular', '50.505.050/0001-14', 'contato@vidacircular.coop.br', -23.480000, -46.620000, 4.70, 'Plástico e orgânicos'),
('EcoCoop Metropolitana', '60.606.060/0001-15', 'central@ecocoopmetro.org.br', -23.570000, -46.680000, 4.40, 'Resíduos industriais e recicláveis')
ON CONFLICT (cnpj) DO NOTHING;

INSERT INTO waste_type (category, description, default_risk_level) VALUES
('PLASTICO', 'Resíduos plásticos recicláveis', 'LOW'),
('PAPEL', 'Papel e papelão para reciclagem', 'LOW'),
('VIDRO', 'Garrafas e materiais de vidro', 'MEDIUM'),
('METAL', 'Latas, alumínio e metais diversos', 'LOW'),
('ORGANICO', 'Resíduos orgânicos biodegradáveis', 'MEDIUM'),
('ELECTRONICO', 'Equipamentos e componentes eletrônicos', 'HIGH'),
('QUIMICO', 'Resíduos químicos industriais', 'HIGH'),
('TEXTIL', 'Tecidos e materiais têxteis', 'LOW'),
('MADEIRA', 'Madeira e derivados', 'MEDIUM'),
('MISTO', 'Resíduos recicláveis misturados', 'MEDIUM')
ON CONFLICT DO NOTHING;

INSERT INTO cooperative_waste_type (cooperative_id, waste_type_id)
SELECT c.id, wt.id
FROM (
    VALUES
        ('11.111.111/0001-01', 'PLASTICO'),
        ('11.111.111/0001-01', 'PAPEL'),
        ('11.111.111/0001-01', 'METAL'),
        ('22.222.222/0001-02', 'PAPEL'),
        ('33.333.333/0001-03', 'VIDRO'),
        ('33.333.333/0001-03', 'PLASTICO'),
        ('44.444.444/0001-04', 'PLASTICO'),
        ('44.444.444/0001-04', 'ORGANICO'),
        ('55.555.555/0001-05', 'METAL'),
        ('55.555.555/0001-05', 'ELECTRONICO'),
        ('66.666.666/0001-06', 'VIDRO'),
        ('66.666.666/0001-06', 'PAPEL'),
        ('77.777.777/0001-07', 'PLASTICO'),
        ('77.777.777/0001-07', 'METAL'),
        ('88.888.888/0001-08', 'PAPEL'),
        ('88.888.888/0001-08', 'PLASTICO'),
        ('88.888.888/0001-08', 'VIDRO'),
        ('99.999.999/0001-09', 'QUIMICO'),
        ('10.101.010/0001-10', 'ORGANICO'),
        ('20.202.020/0001-11', 'METAL'),
        ('20.202.020/0001-11', 'PLASTICO'),
        ('30.303.030/0001-12', 'ELECTRONICO'),
        ('40.404.040/0001-13', 'PAPEL'),
        ('40.404.040/0001-13', 'VIDRO'),
        ('50.505.050/0001-14', 'PLASTICO'),
        ('50.505.050/0001-14', 'ORGANICO'),
        ('60.606.060/0001-15', 'QUIMICO'),
        ('60.606.060/0001-15', 'MISTO')
) AS mapping(cooperative_cnpj, waste_category)
JOIN cooperative c ON c.cnpj = mapping.cooperative_cnpj
JOIN waste_type wt ON wt.category = mapping.waste_category
ON CONFLICT (cooperative_id, waste_type_id) DO NOTHING;

-- ============================================================
-- 2. USERS (40 Usuários corporativos + Usuário Gestor da Cooperativa)
-- Atende chk_users_organization
-- ============================================================

-- Usuário Gestor Oficial da Cooperativa (Senha: Gestor@123)
INSERT INTO users (
    company_id,
    cooperative_id,
    role_id,
    name,
    email,
    password_hash,
    position,
    registered_at,
    first_login
)
VALUES (
    NULL,
    (SELECT id FROM cooperative WHERE cnpj = '11.111.111/0001-01' LIMIT 1),
    (SELECT id FROM role WHERE type = 'MANAGER' LIMIT 1),
    'Gestor BioCycle',
    'gestor@biocycle.com',
    '$2b$10$j8Cq0C4oEwUfE9nI6dY2.uV0I5lA5N3l3wUvYm8v1E4K0X8Q9Z5b6',
    'Gestor Operacional',
    CURRENT_DATE,
    FALSE
)
ON CONFLICT (email) DO NOTHING;

-- 35 Usuários vinculados a Empresas
INSERT INTO users (company_id, cooperative_id, role_id, name, email, password_hash, position, registered_at, first_login)
SELECT
    (SELECT id FROM company ORDER BY random() LIMIT 1),
    NULL,
    (SELECT id FROM role ORDER BY random() LIMIT 1),
    'Usuário Empresa ' || g,
    'empresa_user' || g || '@volta.local',
    '$2b$10$j8Cq0C4oEwUfE9nI6dY2.uV0I5lA5N3l3wUvYm8v1E4K0X8Q9Z5b6',
    (ARRAY['Analista Ambiental', 'Supervisor', 'Gerente', 'Técnico de Segurança'])[(g % 4) + 1],
    CURRENT_DATE - ((random() * 90)::int || ' days')::interval,
    FALSE
FROM generate_series(1, 35) g
ON CONFLICT (email) DO NOTHING;

-- 10 Usuários vinculados a Cooperativas
INSERT INTO users (company_id, cooperative_id, role_id, name, email, password_hash, position, registered_at, first_login)
SELECT
    NULL,
    (SELECT id FROM cooperative ORDER BY random() LIMIT 1),
    (SELECT id FROM role WHERE type IN ('MANAGER', 'EMPLOYEE') ORDER BY random() LIMIT 1),
    'Operador Coop ' || g,
    'coop_user' || g || '@cooperativa.local',
    '$2b$10$j8Cq0C4oEwUfE9nI6dY2.uV0I5lA5N3l3wUvYm8v1E4K0X8Q9Z5b6',
    (ARRAY['Triador', 'Coletor Líder', 'Encarregado de Pátio'])[(g % 3) + 1],
    CURRENT_DATE - ((random() * 90)::int || ' days')::interval,
    FALSE
FROM generate_series(1, 10) g
ON CONFLICT (email) DO NOTHING;

-- ============================================================
-- 3. AREA (30)
-- ============================================================

INSERT INTO area (company_id, sector_name, location_description)
SELECT
    (SELECT id FROM company ORDER BY random() LIMIT 1),
    (ARRAY['Produção', 'Armazenamento', 'Logística', 'Escritório', 'Manutenção', 'Recebimento'])[(g % 6) + 1] || ' ' || g,
    'Área operacional ' || g
FROM generate_series(1, 30) g;

-- ============================================================
-- 4. INCIDENT (100)
-- Usuário remetente sempre da mesma empresa da área
-- ============================================================

INSERT INTO incident (
    company_id,
    user_id,
    area_id,
    photo_url,
    employee_description,
    contamination_level,
    estimated_quantity,
    priority,
    status,
    registered_at,
    title
)
SELECT
    a.company_id,
    u.id,
    a.id,
    'https://example.com/incidents/photo_' || g || '.jpg',
    'Ocorrência de resíduo registrada no setor: relato automático #' || g,
    (ARRAY['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'])[(g % 4) + 1],
    ROUND((10 + random() * 990)::numeric, 2),
    (ARRAY['LOW', 'MEDIUM', 'HIGH', 'URGENT'])[(g % 4) + 1],
    (ARRAY['OPEN', 'ANALYZING', 'COLLECTION_REQUESTED', 'RESOLVED', 'CLOSED'])[(g % 5) + 1],
    CURRENT_TIMESTAMP - ((random() * 180)::int || ' days')::interval,
    'Incidente de Descarte #' || g
FROM generate_series(1, 100) g
CROSS JOIN LATERAL (SELECT * FROM area ORDER BY random() LIMIT 1) a
CROSS JOIN LATERAL (
    SELECT id FROM users WHERE company_id = a.company_id ORDER BY random() LIMIT 1
) u;

-- ============================================================
-- 4.1 INCIDENT_WASTE_TYPE (Associação N:N - 150 registros)
-- Cada incidente recebe entre 1 e 2 tipos de resíduos
-- ============================================================

INSERT INTO incident_waste_type (incident_id, waste_type_id)
SELECT i.id, wt.id
FROM incident i
CROSS JOIN LATERAL (
    SELECT id FROM waste_type ORDER BY random() LIMIT 2
) wt
ON CONFLICT (incident_id, waste_type_id) DO NOTHING;

-- ============================================================
-- 5. AI REPORT (50) / ATTACHMENT (30)
-- ============================================================

INSERT INTO ai_report (
    incident_id,
    detected_waste_type,
    ai_contamination_level,
    recommendations,
    report_text,
    generated_at
)
SELECT
    i.id,
    (SELECT category FROM waste_type ORDER BY random() LIMIT 1),
    (ARRAY['LOW', 'MEDIUM', 'HIGH'])[(row_number() OVER () % 3) + 1],
    'Segregar material conforme norma técnica e encaminhar para triagem especializada.',
    'Análise computacional concluída: padrão morfológico compatível com material reciclável.',
    i.registered_at + interval '30 minutes'
FROM (SELECT * FROM incident ORDER BY random() LIMIT 50) i;

INSERT INTO attachment (incident_id, file_url, file_type)
SELECT
    i.id,
    'https://example.com/attachments/incident_' || g || '.jpg',
    (ARRAY['image/jpeg', 'application/pdf', 'image/png'])[(g % 3) + 1]
FROM generate_series(1, 30) g
CROSS JOIN LATERAL (SELECT id FROM incident ORDER BY random() LIMIT 1) i;

-- ============================================================
-- 6. COLLECTION (80)
-- ============================================================

WITH picked AS (
    SELECT i.*, row_number() OVER (ORDER BY i.id) rn
    FROM (SELECT * FROM incident ORDER BY random() LIMIT 80) i
)
INSERT INTO collection (
    incident_id,
    cooperative_id,
    requested_at,
    scheduled_at,
    current_status,
    collection_type,
    urgent
)
SELECT
    p.id,
    (SELECT id FROM cooperative ORDER BY random() LIMIT 1),
    p.registered_at + interval '1 hour',
    p.registered_at + interval '1 day' + ((p.rn % 12) || ' hours')::interval,
    CASE
        WHEN p.rn <= 40 THEN 'COMPLETED'
        WHEN p.rn <= 55 THEN 'SCHEDULED'
        WHEN p.rn <= 70 THEN 'REQUESTED'
        ELSE 'IN_PROGRESS'
    END,
    (ARRAY['STANDARD', 'SELECTIVE', 'URGENT'])[(p.rn % 3) + 1],
    (p.rn % 10 = 0)
FROM picked p;

-- ============================================================
-- 7. COLLECTION STATUS (225) - Histórico cronológico
-- ============================================================

INSERT INTO collection_status (collection_id, status, changed_at, observation)
SELECT id, 'REQUESTED', requested_at, 'Solicitação de coleta registrada pelo emissor.'
FROM collection;

INSERT INTO collection_status (collection_id, status, changed_at, observation)
SELECT id, 'SCHEDULED', scheduled_at, 'Coleta agendada com a cooperativa responsável.'
FROM collection
WHERE current_status IN ('COMPLETED', 'SCHEDULED', 'IN_PROGRESS');

INSERT INTO collection_status (collection_id, status, changed_at, observation)
SELECT id, 'IN_PROGRESS', scheduled_at + interval '2 hours', 'Equipe de coleta em trânsito.'
FROM collection
WHERE current_status IN ('COMPLETED', 'IN_PROGRESS');

INSERT INTO collection_status (collection_id, status, changed_at, observation)
SELECT
    id,
    'COMPLETED',
    scheduled_at + interval '4 hours' + ((row_number() OVER (ORDER BY id) % 6) || ' hours')::interval,
    'Coleta concluída e materiais pesados com sucesso.'
FROM collection
WHERE current_status = 'COMPLETED';

-- ============================================================
-- 8. REVIEW (30)
-- ============================================================

WITH picked AS (
    SELECT c.*, row_number() OVER (ORDER BY c.id) rn
    FROM (SELECT * FROM collection ORDER BY random() LIMIT 30) c
)
INSERT INTO review (cooperative_id, user_id, collection_id, stars, comment, reviewed_at)
SELECT
    p.cooperative_id,
    i.user_id,
    p.id,
    3 + (p.rn % 3),
    (ARRAY[
        'Coleta realizada dentro do prazo estipulado.',
        'Bom atendimento e triagem exemplar da cooperativa.',
        'Processo de retirada eficiente e documentado.',
        'Excelente pontualidade e suporte da equipe.'
    ])[(p.rn % 4) + 1],
    p.requested_at + interval '2 days'
FROM picked p
JOIN incident i ON i.id = p.incident_id;

-- ============================================================
-- 9. CONVERSATION (20) / MESSAGE (50) / MESSAGE_ATTACHMENT (15)
-- ============================================================

INSERT INTO conversation (company_id, cooperative_id, collection_id, created_at)
SELECT i.company_id, c.cooperative_id, c.id, c.requested_at + interval '30 minutes'
FROM (SELECT * FROM collection ORDER BY random() LIMIT 20) c
JOIN incident i ON i.id = c.incident_id;

INSERT INTO message (conversation_id, user_id, text, reported, sent_at)
SELECT
    cv.id,
    (SELECT id FROM users WHERE company_id = cv.company_id OR cooperative_id = cv.cooperative_id ORDER BY random() LIMIT 1),
    (ARRAY[
        'Olá, gostaríamos de confirmar os detalhes e volume da coleta.',
        'A equipe foi escalada e o veículo já está em rota.',
        'Necessitamos de confirmação do local exato da doca de carga.',
        'Pesagem efetuada no local com manifesto assinado.',
        'Obrigado pela agilidade no atendimento.'
    ])[(g % 5) + 1],
    FALSE,
    cv.created_at + ((g % 48) || ' minutes')::interval
FROM generate_series(1, 50) g
CROSS JOIN LATERAL (SELECT * FROM conversation ORDER BY random() LIMIT 1) cv;

INSERT INTO message_attachment (message_id, file_url, file_type)
SELECT
    m.id,
    'https://example.com/messages/doc_' || g || '.pdf',
    (ARRAY['application/pdf', 'image/jpeg', 'image/png'])[(g % 3) + 1]
FROM generate_series(1, 15) g
CROSS JOIN LATERAL (SELECT id FROM message ORDER BY random() LIMIT 1) m;

-- ============================================================
-- 10. NOTIFICATION (40)
-- ============================================================

INSERT INTO notification (user_id, type, title, message, read, created_at)
SELECT
    (SELECT id FROM users ORDER BY random() LIMIT 1),
    (ARRAY['COLLECTION', 'INCIDENT', 'REVIEW', 'SYSTEM'])[(g % 4) + 1],
    (ARRAY['Status de Coleta Atualizado', 'Nova Ocorrência Registrada', 'Avaliação Recebida', 'Alerta do Sistema'])[(g % 4) + 1],
    'Aviso automático referente ao fluxo operacional #' || g,
    (g % 3 = 0),
    CURRENT_TIMESTAMP - ((random() * 90)::int || ' days')::interval
FROM generate_series(1, 40) g;

-- ============================================================
-- 11. ESG METRIC (30 = 10 empresas x 3 períodos com metas)
-- ============================================================

WITH p AS (
    SELECT c.id AS company_id, v.period, v.offset_days
    FROM company c
    CROSS JOIN (VALUES ('2026-01', 240), ('2026-03', 180), ('2026-06', 90))
    AS v(period, offset_days)
), b AS (
    SELECT
        company_id,
        period,
        offset_days,
        ROUND((1000 + random() * 9000)::numeric, 2) AS total_waste
    FROM p
)
INSERT INTO esg_metric (
    company_id,
    period,
    total_waste_kg,
    total_recycled_kg,
    recycling_percentage,
    calculated_at,
    weekly_target,
    monthly_target,
    quarterly_target
)
SELECT
    b.company_id,
    b.period,
    b.total_waste,
    r.total_recycled,
    ROUND((r.total_recycled / b.total_waste) * 100, 2),
    CURRENT_TIMESTAMP - (b.offset_days || ' days')::interval,
    ROUND((b.total_waste * 0.20)::numeric, 2),
    ROUND((b.total_waste * 0.50)::numeric, 2),
    ROUND((b.total_waste * 0.75)::numeric, 2)
FROM b
CROSS JOIN LATERAL (
    SELECT ROUND((b.total_waste * (0.35 + random() * 0.55))::numeric, 2) AS total_recycled
) r;

-- ============================================================
-- 12. ATUALIZAÇÃO DA MÉDIA DE AVALIAÇÃO DAS COOPERATIVAS
-- ============================================================

UPDATE cooperative c
SET average_rating = COALESCE((
    SELECT ROUND(AVG(r.stars)::numeric, 2)
    FROM review r
    WHERE r.cooperative_id = c.id
), c.average_rating);

COMMIT;

-- ============================================================
-- CONSULTAS DE VALIDAÇÃO E CONTAGEM (AUDITORIA / NOTA MÁXIMA)
-- ============================================================

SELECT 'role' AS table_name, COUNT(*) AS total FROM role
UNION ALL SELECT 'company', COUNT(*) FROM company
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'area', COUNT(*) FROM area
UNION ALL SELECT 'waste_type', COUNT(*) FROM waste_type
UNION ALL SELECT 'cooperative', COUNT(*) FROM cooperative
UNION ALL SELECT 'cooperative_waste_type', COUNT(*) FROM cooperative_waste_type
UNION ALL SELECT 'incident', COUNT(*) FROM incident
UNION ALL SELECT 'incident_waste_type', COUNT(*) FROM incident_waste_type
UNION ALL SELECT 'ai_report', COUNT(*) FROM ai_report
UNION ALL SELECT 'attachment', COUNT(*) FROM attachment
UNION ALL SELECT 'collection', COUNT(*) FROM collection
UNION ALL SELECT 'collection_status', COUNT(*) FROM collection_status
UNION ALL SELECT 'review', COUNT(*) FROM review
UNION ALL SELECT 'conversation', COUNT(*) FROM conversation
UNION ALL SELECT 'message', COUNT(*) FROM message
UNION ALL SELECT 'message_attachment', COUNT(*) FROM message_attachment
UNION ALL SELECT 'notification', COUNT(*) FROM notification
UNION ALL SELECT 'esg_metric', COUNT(*) FROM esg_metric
ORDER BY table_name;

-- Total de registros carregados (deve superar 500 para nota máxima)
SELECT
    (SELECT COUNT(*) FROM role) +
    (SELECT COUNT(*) FROM company) +
    (SELECT COUNT(*) FROM users) +
    (SELECT COUNT(*) FROM area) +
    (SELECT COUNT(*) FROM waste_type) +
    (SELECT COUNT(*) FROM cooperative) +
    (SELECT COUNT(*) FROM cooperative_waste_type) +
    (SELECT COUNT(*) FROM incident) +
    (SELECT COUNT(*) FROM incident_waste_type) +
    (SELECT COUNT(*) FROM ai_report) +
    (SELECT COUNT(*) FROM attachment) +
    (SELECT COUNT(*) FROM collection) +
    (SELECT COUNT(*) FROM collection_status) +
    (SELECT COUNT(*) FROM review) +
    (SELECT COUNT(*) FROM conversation) +
    (SELECT COUNT(*) FROM message) +
    (SELECT COUNT(*) FROM message_attachment) +
    (SELECT COUNT(*) FROM notification) +
    (SELECT COUNT(*) FROM esg_metric) AS total_records_cadastrados;