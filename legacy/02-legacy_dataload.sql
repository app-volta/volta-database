
--Dataload SQL
-- carga de dados de teste do volta (dados fictícios)
-- só tem avaliação de coleta concluída e incidente resolvido tem coleta concluída
 
-- Executar a carga completa em tabelas vazias, apos sql/tabelasVolta.sql.
-- No DBeaver, executar como script e sem uma transacao anterior em aberto.
-- A carga nao e idempotente: repetir causa conflito de chaves e aborta a transacao.
-- Em caso de erro, executar ROLLBACK antes de tentar novamente; nao executar trechos isolados.
-- SETVAL nao e revertido por ROLLBACK; executar sem gravacoes concorrentes.

BEGIN;
 
INSERT INTO role (id, type)
OVERRIDING SYSTEM VALUE
VALUES (1, 'ADMINISTRADOR'), (2, 'FUNCIONARIO'), (3, 'GERENTE');
 
INSERT INTO company (id, name, cnpj, cep, address)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 'Empresa Verde Alimentos LTDA', '12345678000195', '01001000', 'Rua das Indústrias, 1200, São Paulo - SP'),
    (2, 'Alimentos Sustentáveis Brasil LTDA', '98765432000110', '01002000', 'Avenida Paulista, 850, São Paulo - SP');
 
INSERT INTO cooperative (id, name, cnpj, cep, latitude, longitude, opening_time, closing_time, monthly_capacity)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 'Cooperativa Recicla São Paulo', '11222333000181', '01001000', -23.5505200, -46.6333080, '08:00', '17:00', 5000.00),
    (2, 'Cooperativa Eco Futuro', '44555666000172', '01310100', -23.5616840, -46.6253780, '08:30', '17:30', 3500.00),
    (3, 'Cooperativa Circular Verde', '77888999000163', '04038001', -23.5733000, -46.6417000, '07:30', '16:30', 4200.00);
 
INSERT INTO users (id, company_id, cooperative_id, role_id, name, email, password, position)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, NULL, 1, 'Carlos Silva', 'carlos.silva@empresa.com', MD5('volta-sintetico-carlos'), 'Administrador'),
    (2, 1, NULL, 2, 'Mariana Souza', 'mariana.souza@empresa.com', MD5('volta-sintetico-mariana'), 'Funcionária'),
    (3, 1, NULL, 3, 'João Oliveira', 'joao.oliveira@empresa.com', MD5('volta-sintetico-joao'), 'Gerente'),
    (4, 2, NULL, 1, 'Ana Costa', 'ana.costa@alimentos.com', MD5('volta-sintetico-ana'), 'Administradora'),
    (5, NULL, 1, 2, 'Rafael Lima', 'rafael.lima@reciclasp.org', MD5('volta-sintetico-rafael'), 'Operador de triagem'),
    (6, NULL, 2, 3, 'Paula Santos', 'paula.santos@ecofuturo.org', MD5('volta-sintetico-paula'), 'Coordenadora'),
    (7, NULL, 3, 2, 'Marcos Pereira', 'marcos.pereira@circularverde.org', MD5('volta-sintetico-marcos'), 'Operador de coleta');
 
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
 
-- Especialidades (antes: texto em cooperative.specialties).
-- 'Resíduos Industriais' foi associado a 'Resíduo Contaminado' (a confirmar pelo grupo).
INSERT INTO cooperative_waste_type (cooperative_id, waste_type_id)
VALUES (1, 1), (1, 2), (1, 3), (2, 1), (2, 2), (3, 3), (3, 4);
 
INSERT INTO incident (id, user_id, area_id, waste_type_id, photo_url, employee_description, contamination_level, priority, status, registered_at, estimated_weight)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 2, 1, 1, 'https://exemplo.com/foto_plastico_01.jpg', 'Grande quantidade de embalagens plásticas acumuladas na área de produção.', 'MEDIO', 'ALTA', 'EM_ANALISE', '2026-09-01 08:30:00', 250.50),
    (2, 3, 2, 2, 'https://exemplo.com/foto_papelao_01.jpg', 'Caixas de papelão disponíveis para reciclagem.', 'BAIXO', 'MEDIA', 'EM_ANALISE', '2026-09-02 10:15:00', 180.00),
    (3, 2, 3, 3, 'https://exemplo.com/foto_metal_01.jpg', 'Materiais metálicos separados para coleta.', 'BAIXO', 'BAIXA', 'RESOLVIDA', '2026-09-03 13:45:00', 75.25),
    (4, 4, 4, 4, 'https://exemplo.com/foto_contaminado_01.jpg', 'Material contaminado identificado próximo à área de produção.', 'ALTO', 'URGENTE', 'EM_ANALISE', '2026-09-04 16:20:00', 40.00),
    (5, 3, 1, 2, 'https://exemplo.com/foto_papelao_02.jpg', 'Papelão de embalagens separado na produção.', 'BAIXO', 'BAIXA', 'RESOLVIDA', '2026-09-05 09:00:00', 120.00);
 
INSERT INTO ai_report (id, incident_id, detected_waste, ai_contamination_level, recommendations, report_text, generated_at)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 'Plástico', 'MEDIO', 'Separar o material e solicitar coleta de cooperativa especializada.', 'A inteligência artificial identificou uma grande concentração de resíduos plásticos recicláveis.', '2026-09-01 08:35:00'),
    (2, 4, 'Resíduo Contaminado', 'ALTO', 'Isolar a área e encaminhar o material para tratamento adequado.', 'A inteligência artificial identificou possível risco ambiental devido à contaminação do material.', '2026-09-04 16:25:00');
 
-- Arquivos extras da ocorrência (a foto principal fica em incident.photo_url)
INSERT INTO attachment (id, incident_id, file_url, file_type)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 'https://exemplo.com/anexo_incidente_01.pdf', 'PDF'),
    (2, 2, 'https://exemplo.com/anexo_incidente_02.jpg', 'JPG');
 
-- current_status é o último status do histórico de cada coleta
INSERT INTO collection (id, incident_id, cooperative_id, request_date, scheduled_date, current_status, collection_type, urgent, estimated_time)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 1, '2026-09-01 09:00:00', '2026-09-02 09:00:00', 'ACEITA', 'PADRAO', TRUE, '02:00:00'),
    (2, 2, 2, '2026-09-02 11:00:00', '2026-09-03 14:00:00', 'AGENDADA', 'PADRAO', FALSE, '01:30:00'),
    (3, 3, 3, '2026-09-03 14:30:00', '2026-09-04 09:00:00', 'CONCLUIDA', 'PADRAO', FALSE, '01:00:00'),
    (4, 5, 1, '2026-09-05 09:30:00', '2026-09-06 10:00:00', 'CONCLUIDA', 'PADRAO', FALSE, '01:30:00');
 
INSERT INTO collection_status (id, collection_id, status, change_date, observation)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 'SOLICITADA', '2026-09-01 09:00:00', 'Solicitação enviada para a cooperativa.'),
    (2, 1, 'ACEITA', '2026-09-01 12:00:00', 'Cooperativa confirmou disponibilidade para coleta.'),
    (3, 2, 'SOLICITADA', '2026-09-02 11:00:00', 'Solicitação enviada para a cooperativa.'),
    (4, 2, 'AGENDADA', '2026-09-02 11:05:00', 'Coleta agendada para o período da tarde.'),
    (5, 3, 'SOLICITADA', '2026-09-03 14:30:00', 'Solicitação enviada para a cooperativa.'),
    (6, 3, 'ACEITA', '2026-09-03 15:00:00', 'Cooperativa aceitou a coleta.'),
    (7, 3, 'AGENDADA', '2026-09-03 15:30:00', 'Coleta agendada para a manhã seguinte.'),
    (8, 3, 'EM_ANDAMENTO', '2026-09-04 09:00:00', 'Equipe chegou ao local.'),
    (9, 3, 'CONCLUIDA', '2026-09-04 10:00:00', 'Material retirado.'),
    (10, 4, 'SOLICITADA', '2026-09-05 09:30:00', 'Solicitação enviada para a cooperativa.'),
    (11, 4, 'ACEITA', '2026-09-05 10:00:00', 'Cooperativa aceitou a coleta.'),
    (12, 4, 'AGENDADA', '2026-09-05 10:30:00', 'Coleta agendada para o dia seguinte.'),
    (13, 4, 'EM_ANDAMENTO', '2026-09-06 10:00:00', 'Equipe chegou ao local.'),
    (14, 4, 'CONCLUIDA', '2026-09-06 11:30:00', 'Material retirado.');
 
-- Avaliações apenas de coletas CONCLUIDA (coletas 3 e 4)
INSERT INTO review (id, user_id, collection_id, stars, comment, review_date)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 3, 3, 5, 'Cooperativa muito organizada e atendimento eficiente.', '2026-09-04 17:00:00'),
    (2, 3, 4, 4, 'A coleta foi organizada e realizada conforme o combinado.', '2026-09-06 18:00:00');
 
INSERT INTO conversation (id, company_id, cooperative_id, collection_id, created_at)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 1, 1, '2026-09-01 09:10:00'),
    (2, 1, 2, 2, '2026-09-02 11:10:00'),
    (3, 1, 3, 3, '2026-09-03 14:40:00');
 
-- Mensagens de usuários da empresa e das cooperativas
INSERT INTO message (id, conversation_id, user_id, text, reported, sent_at)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 2, 'Olá, gostaríamos de confirmar a coleta dos materiais plásticos.', FALSE, '2026-09-01 09:11:00'),
    (2, 1, 5, 'Confirmado! Nossa equipe passa amanhã às 9h.', FALSE, '2026-09-01 09:20:00'),
    (3, 1, 3, 'A empresa estará disponível para a retirada no horário agendado.', FALSE, '2026-09-01 09:25:00'),
    (4, 2, 2, 'Precisamos confirmar o horário da coleta.', FALSE, '2026-09-02 11:11:00'),
    (5, 2, 6, 'O horário está confirmado para as 14h.', FALSE, '2026-09-02 11:30:00'),
    (6, 3, 7, 'Nossa equipe chega às 9h para retirar o metal.', FALSE, '2026-09-03 14:45:00');
 
INSERT INTO message_attachment (id, message_id, file_url, file_type)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 'https://exemplo.com/comprovante_coleta.pdf', 'PDF'),
    (2, 4, 'https://exemplo.com/foto_residuo.jpg', 'JPG');
 
INSERT INTO notification (id, user_id, type, title, message, read, created_at)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 2, 'INCIDENTE', 'Novo relatório gerado', 'A inteligência artificial gerou um relatório para o incidente registrado.', FALSE, '2026-09-01 08:40:00'),
    (2, 3, 'COLETA', 'Coleta agendada', 'Uma coleta foi agendada para os próximos dias.', FALSE, '2026-09-02 11:15:00'),
    (3, 1, 'SISTEMA', 'Atualização do sistema', 'Os dados ambientais foram atualizados com sucesso.', TRUE, '2026-09-04 17:00:00');
 
-- recycling_percentage é gerada pelo banco: não entra no INSERT
INSERT INTO esg_metric (id, company_id, period, total_kg_waste, total_kg_recycled, calculated_at)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, '2026-07', 1300.00, 910.00, '2026-08-01 08:00:00'),
    (2, 1, '2026-08', 1500.00, 1125.00, '2026-09-01 08:00:00'),
    (3, 2, '2026-08', 980.00, 686.00, '2026-09-01 08:30:00');
 
INSERT INTO complaint (id, cooperative_id, incident_id, photo, description, complaint_date)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 1, 'https://exemplo.com/denuncia_01.jpg', 'Material recebido não correspondia ao descrito na ocorrência.', '2026-09-02'),
    (2, 3, 3, NULL, 'Peso do metal retirado diferente do peso estimado.', '2026-09-04');
 
-- ids fixos não avançam as sequences, então ajusta para o próximo insert
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('role', 'id'), MAX(id)) FROM role;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('company', 'id'), MAX(id)) FROM company;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('cooperative', 'id'), MAX(id)) FROM cooperative;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('users', 'id'), MAX(id)) FROM users;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('area', 'id'), MAX(id)) FROM area;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('waste_type', 'id'), MAX(id)) FROM waste_type;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('incident', 'id'), MAX(id)) FROM incident;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('ai_report', 'id'), MAX(id)) FROM ai_report;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('attachment', 'id'), MAX(id)) FROM attachment;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('collection', 'id'), MAX(id)) FROM collection;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('collection_status', 'id'), MAX(id)) FROM collection_status;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('review', 'id'), MAX(id)) FROM review;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('conversation', 'id'), MAX(id)) FROM conversation;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('message', 'id'), MAX(id)) FROM message;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('message_attachment', 'id'), MAX(id)) FROM message_attachment;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('notification', 'id'), MAX(id)) FROM notification;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('esg_metric', 'id'), MAX(id)) FROM esg_metric;
SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('complaint', 'id'), MAX(id)) FROM complaint;
 
-- Conferência: quantidade de registros por tabela
SELECT 'role' AS table_name, COUNT(*) AS records FROM role
UNION ALL SELECT 'company', COUNT(*) FROM company
UNION ALL SELECT 'cooperative', COUNT(*) FROM cooperative
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'area', COUNT(*) FROM area
UNION ALL SELECT 'waste_type', COUNT(*) FROM waste_type
UNION ALL SELECT 'cooperative_waste_type', COUNT(*) FROM cooperative_waste_type
UNION ALL SELECT 'incident', COUNT(*) FROM incident
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
UNION ALL SELECT 'complaint', COUNT(*) FROM complaint
ORDER BY table_name;
 
COMMIT;
 
