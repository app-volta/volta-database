-- ==============================================
-- VOLTA — carga sintética para o schema legado
-- ==============================================

BEGIN;

INSERT INTO role (id, type)
OVERRIDING SYSTEM VALUE
VALUES (1, 'ADMIN'), (2, 'EMPLOYEE'), (3, 'MANAGER');

INSERT INTO company (id, name, cnpj, address)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 'Empresa Verde Alimentos LTDA', '12345678000195', 'Rua das Indústrias, 1200, São Paulo - SP'),
    (2, 'Alimentos Sustentáveis Brasil LTDA', '98765432000110', 'Avenida Paulista, 850, São Paulo - SP');

INSERT INTO users (id, company_id, role_id, name, email, password, position)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 1, 'Carlos Silva', 'carlos.silva@empresa.com', md5('volta-sintetico-carlos'), 'Administrador'),
    (2, 1, 2, 'Mariana Souza', 'mariana.souza@empresa.com', md5('volta-sintetico-mariana'), 'Funcionária'),
    (3, 1, 3, 'João Oliveira', 'joao.oliveira@empresa.com', md5('volta-sintetico-joao'), 'Gerente'),
    (4, 2, 1, 'Ana Costa', 'ana.costa@alimentos.com', md5('volta-sintetico-ana'), 'Administradora');

INSERT INTO area (id, company_id, sector_name, location_description)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 'Produção', 'Galpão principal da fábrica'),
    (2, 1, 'Estoque', 'Área de armazenamento de embalagens'),
    (3, 1, 'Expedição', 'Setor responsável pelo envio dos produtos'),
    (4, 2, 'Produção', 'Unidade de processamento de alimentos');

INSERT INTO waste_type (id, category, description, default_risk)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 'Plástico', 'Embalagens plásticas utilizadas nos produtos', 'MEDIO'),
    (2, 'Papelão', 'Caixas e embalagens de papelão', 'BAIXO'),
    (3, 'Metal', 'Latas e materiais metálicos', 'MEDIO'),
    (4, 'Resíduo Contaminado', 'Materiais contaminados que precisam de tratamento', 'ALTO');

INSERT INTO incident (
    id, company_id, user_id, area_id, waste_type_id, photo_url,
    employee_description, contamination_level, estimated_quantity,
    priority, status, registered_at, estimated_weight
)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 2, 1, 1, 'https://exemplo.com/foto_plastico_01.jpg', 'Grande quantidade de embalagens plásticas acumuladas na área de produção.', 'MEDIO', 250.50, 'ALTA', 'EM_ANALISE', '2026-09-01 08:30:00', 250.50),
    (2, 1, 3, 2, 2, 'https://exemplo.com/foto_papelao_01.jpg', 'Caixas de papelão disponíveis para reciclagem.', 'BAIXO', 180.00, 'MEDIA', 'PENDENTE', '2026-09-02 10:15:00', 180.00),
    (3, 1, 2, 3, 3, 'https://exemplo.com/foto_metal_01.jpg', 'Materiais metálicos separados para coleta.', 'BAIXO', 75.25, 'BAIXA', 'RESOLVIDA', '2026-09-03 13:45:00', 75.25),
    (4, 2, 4, 4, 4, 'https://exemplo.com/foto_contaminado_01.jpg', 'Material contaminado identificado próximo à área de produção.', 'ALTO', 40.00, 'URGENTE', 'EM_ANALISE', '2026-09-04 16:20:00', 40.00);

INSERT INTO ai_report (id, incident_id, detected_waste, ai_contamination_level, recommendations, report_text, generated_at)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 'Plástico', 'MEDIO', 'Separar o material e solicitar coleta de cooperativa especializada.', 'A inteligência artificial identificou uma grande concentração de resíduos plásticos recicláveis.', '2026-09-01 08:35:00'),
    (2, 4, 'Resíduo Contaminado', 'ALTO', 'Isolar a área e encaminhar o material para tratamento adequado.', 'A inteligência artificial identificou possível risco ambiental devido à contaminação do material.', '2026-09-04 16:25:00');

INSERT INTO attachment (id, incident_id, file_url, file_type)
OVERRIDING SYSTEM VALUE
VALUES (1, 1, 'https://exemplo.com/anexo_incidente_01.pdf', 'PDF'), (2, 2, 'https://exemplo.com/anexo_incidente_02.jpg', 'JPG');

INSERT INTO cooperative (id, name, cnpj, latitude, longitude, average_rating, specialties, opening_time, monthly_capacity)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 'Cooperativa Recicla São Paulo', '11222333000181', -23.5505200, -46.6333080, 4.80, 'Plástico, Papelão e Metal', '08:00:00', 5000.00),
    (2, 'Cooperativa Eco Futuro', '44555666000172', -23.5616840, -46.6253780, 4.50, 'Plástico e Papelão', '08:30:00', 3500.00),
    (3, 'Cooperativa Circular Verde', '77888999000163', -23.5733000, -46.6417000, 4.70, 'Metal e Resíduos Industriais', '07:30:00', 4200.00);

INSERT INTO collection (id, incident_id, cooperative_id, request_date, scheduled_date, current_status, collection_type, urgent, estimated_time)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 1, '2026-09-01 09:00:00', '2026-09-02 09:00:00', 'ACEITA', 'STANDARD', TRUE, '02:00:00'),
    (2, 2, 2, '2026-09-02 11:00:00', '2026-09-03 14:00:00', 'AGENDADA', 'STANDARD', FALSE, '01:30:00'),
    (3, 3, 3, '2026-09-03 14:30:00', NULL, 'SOLICITADA', 'STANDARD', FALSE, NULL);

INSERT INTO collection_status (id, collection_id, status, change_date, observation)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 'SOLICITADA', '2026-09-01 09:00:00', 'Solicitação enviada para a cooperativa.'),
    (2, 1, 'ACEITA', '2026-09-01 12:00:00', 'Cooperativa confirmou disponibilidade para coleta.'),
    (3, 2, 'AGENDADA', '2026-09-02 11:05:00', 'Coleta agendada para o período da tarde.');

INSERT INTO review (id, cooperative_id, user_id, collection_id, stars, comment, review_date)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 2, 1, 5, 'Cooperativa muito organizada e atendimento eficiente.', '2026-09-02 17:00:00'),
    (2, 2, 3, 2, 4, 'A coleta foi organizada e realizada conforme o combinado.', '2026-09-03 18:00:00');

INSERT INTO conversation (id, company_id, cooperative_id, collection_id, created_at)
OVERRIDING SYSTEM VALUE
VALUES (1, 1, 1, 1, '2026-09-01 09:10:00'), (2, 1, 2, 2, '2026-09-02 11:10:00');

INSERT INTO message (id, conversation_id, user_id, text, reported, sent_at)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 2, 'Olá, gostaríamos de confirmar a coleta dos materiais plásticos.', FALSE, '2026-09-01 09:11:00'),
    (2, 1, 3, 'A empresa estará disponível para a retirada no horário agendado.', FALSE, '2026-09-01 09:12:00'),
    (3, 2, 2, 'Precisamos confirmar o horário da coleta.', FALSE, '2026-09-02 11:11:00');

INSERT INTO message_attachment (id, message_id, file_url, file_type)
OVERRIDING SYSTEM VALUE
VALUES (1, 1, 'https://exemplo.com/comprovante_coleta.pdf', 'PDF'), (2, 3, 'https://exemplo.com/foto_residuo.jpg', 'JPG');

INSERT INTO notification (id, user_id, type, title, message, read, created_at)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 2, 'INCIDENT', 'Novo relatório gerado', 'A inteligência artificial gerou um relatório para o incidente registrado.', FALSE, '2026-09-01 08:40:00'),
    (2, 3, 'COLLECTION', 'Coleta agendada', 'Uma coleta foi agendada para os próximos dias.', FALSE, '2026-09-02 11:15:00'),
    (3, 1, 'SYSTEM', 'Atualização do sistema', 'Os dados ambientais foram atualizados com sucesso.', TRUE, '2026-09-04 17:00:00');

INSERT INTO esg_metric (id, company_id, period, total_kg_waste, total_kg_recycled, recycling_percentage, calculated_at)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, '2026-07', 1300.00, 910.00, 70.00, '2026-08-01 08:00:00'),
    (2, 1, '2026-08', 1500.00, 1125.00, 75.00, '2026-09-01 08:00:00'),
    (3, 2, '2026-08', 980.00, 686.00, 70.00, '2026-09-01 08:30:00');

-- IDs explícitos não deixam as sequences prontas para a próxima inserção.
SELECT setval(pg_get_serial_sequence('role', 'id'), MAX(id)) FROM role;
SELECT setval(pg_get_serial_sequence('company', 'id'), MAX(id)) FROM company;
SELECT setval(pg_get_serial_sequence('users', 'id'), MAX(id)) FROM users;
SELECT setval(pg_get_serial_sequence('area', 'id'), MAX(id)) FROM area;
SELECT setval(pg_get_serial_sequence('waste_type', 'id'), MAX(id)) FROM waste_type;
SELECT setval(pg_get_serial_sequence('incident', 'id'), MAX(id)) FROM incident;
SELECT setval(pg_get_serial_sequence('ai_report', 'id'), MAX(id)) FROM ai_report;
SELECT setval(pg_get_serial_sequence('attachment', 'id'), MAX(id)) FROM attachment;
SELECT setval(pg_get_serial_sequence('cooperative', 'id'), MAX(id)) FROM cooperative;
SELECT setval(pg_get_serial_sequence('collection', 'id'), MAX(id)) FROM collection;
SELECT setval(pg_get_serial_sequence('collection_status', 'id'), MAX(id)) FROM collection_status;
SELECT setval(pg_get_serial_sequence('review', 'id'), MAX(id)) FROM review;
SELECT setval(pg_get_serial_sequence('conversation', 'id'), MAX(id)) FROM conversation;
SELECT setval(pg_get_serial_sequence('message', 'id'), MAX(id)) FROM message;
SELECT setval(pg_get_serial_sequence('message_attachment', 'id'), MAX(id)) FROM message_attachment;
SELECT setval(pg_get_serial_sequence('notification', 'id'), MAX(id)) FROM notification;
SELECT setval(pg_get_serial_sequence('esg_metric', 'id'), MAX(id)) FROM esg_metric;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM incident i LEFT JOIN company c ON c.id = i.company_id WHERE c.id IS NULL)
       OR EXISTS (SELECT 1 FROM incident i LEFT JOIN users u ON u.id = i.user_id WHERE u.id IS NULL)
       OR EXISTS (SELECT 1 FROM incident i LEFT JOIN area a ON a.id = i.area_id WHERE a.id IS NULL)
       OR EXISTS (SELECT 1 FROM incident i LEFT JOIN waste_type w ON w.id = i.waste_type_id WHERE w.id IS NULL)
       OR EXISTS (SELECT 1 FROM collection c LEFT JOIN incident i ON i.id = c.incident_id WHERE i.id IS NULL)
       OR EXISTS (SELECT 1 FROM collection c LEFT JOIN cooperative co ON co.id = c.cooperative_id WHERE co.id IS NULL)
       OR EXISTS (SELECT 1 FROM message m LEFT JOIN conversation c ON c.id = m.conversation_id WHERE c.id IS NULL)
       OR EXISTS (SELECT 1 FROM message m LEFT JOIN users u ON u.id = m.user_id WHERE u.id IS NULL)
    THEN RAISE EXCEPTION 'Falha de integridade referencial no dataload legado.';
    END IF;
END;
$$;

SELECT 'role' AS table_name, COUNT(*) AS records FROM role
UNION ALL SELECT 'company', COUNT(*) FROM company
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'area', COUNT(*) FROM area
UNION ALL SELECT 'waste_type', COUNT(*) FROM waste_type
UNION ALL SELECT 'incident', COUNT(*) FROM incident
UNION ALL SELECT 'ai_report', COUNT(*) FROM ai_report
UNION ALL SELECT 'attachment', COUNT(*) FROM attachment
UNION ALL SELECT 'cooperative', COUNT(*) FROM cooperative
UNION ALL SELECT 'collection', COUNT(*) FROM collection
UNION ALL SELECT 'collection_status', COUNT(*) FROM collection_status
UNION ALL SELECT 'review', COUNT(*) FROM review
UNION ALL SELECT 'conversation', COUNT(*) FROM conversation
UNION ALL SELECT 'message', COUNT(*) FROM message
UNION ALL SELECT 'message_attachment', COUNT(*) FROM message_attachment
UNION ALL SELECT 'notification', COUNT(*) FROM notification
UNION ALL SELECT 'esg_metric', COUNT(*) FROM esg_metric
ORDER BY table_name;

COMMIT;