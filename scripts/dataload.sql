-- ============================================================
-- VOLTA - DATA LOAD (600+ REGISTROS)
-- PostgreSQL | Requer schema atual + pgcrypto
-- ============================================================

BEGIN;

-- ============================================================
-- 1. DADOS FIXOS
-- ============================================================

INSERT INTO role (type) VALUES
('ADMIN'),('MANAGER'),('EMPLOYEE'),('OPERATOR')
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

INSERT INTO cooperative (name,cnpj,latitude,longitude,average_rating,specialties) VALUES
('Cooperativa Verde São Paulo','11.111.111/0001-01',-23.550520,-46.633308,4.50,'Plástico, papel e metal'),
('Recicla SP Cooperativa','22.222.222/0001-02',-23.561414,-46.655881,4.30,'Papel e papelão'),
('Coop Ambiental Paulista','33.333.333/0001-03',-23.548943,-46.638818,4.70,'Vidro e plástico'),
('EcoCoop Campinas','44.444.444/0001-04',-22.905560,-47.060830,4.20,'Plástico e orgânicos'),
('Cooperativa Novo Ciclo','55.555.555/0001-05',-23.179440,-45.886940,4.60,'Metal e eletrônicos'),
('Coop Reciclagem Santos','66.666.666/0001-06',-23.960830,-46.333610,4.10,'Vidro e papel'),
('Cooperativa Futuro Verde','77.777.777/0001-07',-23.501530,-46.875000,4.40,'Plástico e metal'),
('Coop Circular Jundiaí','88.888.888/0001-08',-23.185700,-46.897800,4.80,'Papel, plástico e vidro'),
('Cooperativa Sustenta Brasil','99.999.999/0001-09',-23.532900,-46.791700,4.50,'Resíduos industriais'),
('Coop EcoAção','10.101.010/0001-10',-23.550000,-46.650000,4.00,'Resíduos orgânicos'),
('Reciclagem Solidária ABC','20.202.020/0001-11',-23.674000,-46.543000,4.30,'Metal e plástico'),
('Cooperativa Reutilizar','30.303.030/0001-12',-23.499000,-46.850000,4.60,'Eletrônicos'),
('Coop Planeta Limpo','40.404.040/0001-13',-23.610000,-46.700000,4.20,'Papel e vidro'),
('Cooperativa Vida Circular','50.505.050/0001-14',-23.480000,-46.620000,4.70,'Plástico e orgânicos'),
('EcoCoop Metropolitana','60.606.060/0001-15',-23.570000,-46.680000,4.40,'Resíduos industriais e recicláveis')
ON CONFLICT (cnpj) DO NOTHING;

INSERT INTO waste_type (category,description,default_risk_level) VALUES
('PLASTIC','Resíduos plásticos recicláveis','LOW'),
('PAPER','Papel e papelão para reciclagem','LOW'),
('GLASS','Garrafas e materiais de vidro','MEDIUM'),
('METAL','Latas, alumínio e metais diversos','LOW'),
('ORGANIC','Resíduos orgânicos biodegradáveis','MEDIUM'),
('ELECTRONIC','Equipamentos e componentes eletrônicos','HIGH'),
('CHEMICAL','Resíduos químicos industriais','HIGH'),
('TEXTILE','Tecidos e materiais têxteis','LOW'),
('WOOD','Madeira e derivados','MEDIUM'),
('MIXED','Resíduos recicláveis misturados','MEDIUM');

-- ============================================================
-- 2. USERS (40)
-- ============================================================

INSERT INTO users (company_id,role_id,name,email,password_hash,position)
SELECT
  (SELECT id FROM company ORDER BY random() LIMIT 1),
  (SELECT id FROM role ORDER BY random() LIMIT 1),
  'Usuário VOLTA '||g,
  'usuario'||g||'@volta.local',
  '$2a$10$hash_ficticio_dataload_'||g,
  (ARRAY['Analista Ambiental','Operador','Supervisor','Gerente','Técnico'])[(g%5)+1]
FROM generate_series(1,40) g
ON CONFLICT (email) DO NOTHING;

-- ============================================================
-- 3. AREA (30)
-- ============================================================

INSERT INTO area (company_id,sector_name,location_description)
SELECT
  (SELECT id FROM company ORDER BY random() LIMIT 1),
  (ARRAY['Produção','Armazenamento','Logística','Escritório','Manutenção','Recebimento'])[(g%6)+1]||' '||g,
  'Área operacional fictícia '||g
FROM generate_series(1,30) g;

-- ============================================================
-- 4. INCIDENT (100)
-- O usuário é sempre escolhido da mesma empresa da área.
-- ============================================================

INSERT INTO incident
(company_id,user_id,area_id,waste_type_id,photo_url,employee_description,
 contamination_level,estimated_quantity,priority,status,registered_at)
SELECT
  a.company_id,
  u.id,
  a.id,
  (SELECT id FROM waste_type ORDER BY random() LIMIT 1),
  'https://example.com/incidents/photo_'||g||'.jpg',
  'Ocorrência fictícia #'||g||' para testes do sistema VOLTA.',
  (ARRAY['LOW','MEDIUM','HIGH','CRITICAL'])[(g%4)+1],
  ROUND((10+random()*990)::numeric,2),
  (ARRAY['LOW','MEDIUM','HIGH','URGENT'])[(g%4)+1],
  (ARRAY['OPEN','ANALYZING','COLLECTION_REQUESTED','RESOLVED','CLOSED'])[(g%5)+1],
  CURRENT_TIMESTAMP - ((random()*180)::int||' days')::interval
FROM generate_series(1,100) g
CROSS JOIN LATERAL (SELECT * FROM area ORDER BY random() LIMIT 1) a
CROSS JOIN LATERAL (
  SELECT id FROM users WHERE company_id=a.company_id ORDER BY random() LIMIT 1
) u;

-- ============================================================
-- 5. AI REPORT (50) / ATTACHMENT (30)
-- ============================================================

INSERT INTO ai_report
(incident_id,detected_waste_type,ai_contamination_level,recommendations,report_text,generated_at)
SELECT i.id, COALESCE(w.category,'MIXED'),
       (ARRAY['LOW','MEDIUM','HIGH'])[(row_number() OVER ()%3)+1],
       'Separar materiais, verificar contaminação e encaminhar para coleta adequada.',
       'Relatório fictício gerado pela IA para a ocorrência.',
       i.registered_at + interval '30 minutes'
FROM (SELECT * FROM incident ORDER BY random() LIMIT 50) i
LEFT JOIN waste_type w ON w.id=i.waste_type_id;

INSERT INTO attachment (incident_id,file_url,file_type)
SELECT i.id,'https://example.com/attachments/incident_'||g||'.jpg',
       (ARRAY['image/jpeg','application/pdf','image/png'])[(g%3)+1]
FROM generate_series(1,30) g
CROSS JOIN LATERAL (SELECT id FROM incident ORDER BY random() LIMIT 1) i;

-- ============================================================
-- 6. COLLECTION (80)
-- 40 COMPLETED, 15 SCHEDULED, 15 REQUESTED, 10 IN_PROGRESS
-- ============================================================

WITH picked AS (
 SELECT i.*, row_number() OVER (ORDER BY i.id) rn
 FROM (SELECT * FROM incident ORDER BY random() LIMIT 80) i
)
INSERT INTO collection
(incident_id,cooperative_id,requested_at,scheduled_at,current_status,collection_type,urgent)
SELECT
 p.id,
 (SELECT id FROM cooperative ORDER BY random() LIMIT 1),
 p.registered_at + interval '1 hour',
 p.registered_at + interval '1 day' + ((p.rn%12)||' hours')::interval,
 CASE WHEN p.rn<=40 THEN 'COMPLETED'
      WHEN p.rn<=55 THEN 'SCHEDULED'
      WHEN p.rn<=70 THEN 'REQUESTED'
      ELSE 'IN_PROGRESS' END,
 (ARRAY['STANDARD','SELECTIVE','URGENT'])[(p.rn%3)+1],
 (p.rn%10=0)
FROM picked p;

-- ============================================================
-- 7. COLLECTION STATUS (225)
-- SCRUM-1905:
-- COMPLETED: REQUESTED -> SCHEDULED -> IN_PROGRESS -> COMPLETED
-- ============================================================

INSERT INTO collection_status (collection_id,status,changed_at,observation)
SELECT id,'REQUESTED',requested_at,'Solicitação de coleta registrada.'
FROM collection;

INSERT INTO collection_status (collection_id,status,changed_at,observation)
SELECT id,'SCHEDULED',scheduled_at,'Coleta agendada com a cooperativa.'
FROM collection
WHERE current_status IN ('COMPLETED','SCHEDULED','IN_PROGRESS');

INSERT INTO collection_status (collection_id,status,changed_at,observation)
SELECT id,'IN_PROGRESS',scheduled_at+interval '2 hours','Coleta iniciada.'
FROM collection
WHERE current_status IN ('COMPLETED','IN_PROGRESS');

INSERT INTO collection_status (collection_id,status,changed_at,observation)
SELECT id,'COMPLETED',
       scheduled_at+interval '4 hours'+((row_number() OVER (ORDER BY id)%6)||' hours')::interval,
       'Coleta concluída com sucesso.'
FROM collection
WHERE current_status='COMPLETED';

-- ============================================================
-- 8. REVIEW (30)
-- ============================================================

WITH picked AS (
 SELECT c.*,row_number() OVER (ORDER BY c.id) rn
 FROM (SELECT * FROM collection ORDER BY random() LIMIT 30) c
)
INSERT INTO review (cooperative_id,user_id,collection_id,stars,comment,reviewed_at)
SELECT p.cooperative_id,i.user_id,p.id,3+(p.rn%3),
       (ARRAY['Coleta realizada dentro do prazo.','Bom atendimento da cooperativa.',
              'Processo eficiente e organizado.','Experiência positiva com a coleta.'])[(p.rn%4)+1],
       p.requested_at+interval '2 days'
FROM picked p JOIN incident i ON i.id=p.incident_id;

-- ============================================================
-- 9. CONVERSATION (20) / MESSAGE (50) / MESSAGE_ATTACHMENT (15)
-- ============================================================

INSERT INTO conversation (company_id,cooperative_id,collection_id,created_at)
SELECT i.company_id,c.cooperative_id,c.id,c.requested_at+interval '30 minutes'
FROM (SELECT * FROM collection ORDER BY random() LIMIT 20) c
JOIN incident i ON i.id=c.incident_id;

INSERT INTO message (conversation_id,user_id,text,reported,sent_at)
SELECT cv.id,
       (SELECT id FROM users WHERE company_id=cv.company_id ORDER BY random() LIMIT 1),
       (ARRAY[
         'Olá, gostaria de confirmar os detalhes da coleta.',
         'A coleta foi agendada conforme combinado.',
         'Precisamos atualizar o horário da coleta.',
         'A equipe está a caminho.',
         'Obrigado pela confirmação.'
       ])[(g%5)+1],
       FALSE,
       cv.created_at+((g%48)||' minutes')::interval
FROM generate_series(1,50) g
CROSS JOIN LATERAL (SELECT * FROM conversation ORDER BY random() LIMIT 1) cv;

INSERT INTO message_attachment (message_id,file_url,file_type)
SELECT m.id,'https://example.com/messages/file_'||g||'.pdf',
       (ARRAY['application/pdf','image/jpeg','image/png'])[(g%3)+1]
FROM generate_series(1,15) g
CROSS JOIN LATERAL (SELECT id FROM message ORDER BY random() LIMIT 1) m;

-- ============================================================
-- 10. NOTIFICATION (40)
-- ============================================================

INSERT INTO notification (user_id,type,title,message,read,created_at)
SELECT
 (SELECT id FROM users ORDER BY random() LIMIT 1),
 (ARRAY['COLLECTION','INCIDENT','REVIEW','SYSTEM'])[(g%4)+1],
 (ARRAY['Atualização de coleta','Nova ocorrência','Nova avaliação','Atualização do sistema'])[(g%4)+1],
 'Notificação fictícia #'||g||' gerada para testes.',
 (g%3=0),
 CURRENT_TIMESTAMP-((random()*90)::int||' days')::interval
FROM generate_series(1,40) g;

-- ============================================================
-- 11. ESG METRIC (30 = 10 empresas x 3 períodos)
-- ============================================================

WITH p AS (
 SELECT c.id company_id,v.period,v.offset_days
 FROM company c
 CROSS JOIN (VALUES ('2026-01',240),('2026-03',180),('2026-06',90))
 AS v(period,offset_days)
), b AS (
 SELECT company_id,period,offset_days,
        ROUND((1000+random()*9000)::numeric,2) total_waste
 FROM p
)
INSERT INTO esg_metric
(company_id,period,total_waste_kg,total_recycled_kg,recycling_percentage,calculated_at)
SELECT b.company_id,b.period,b.total_waste,r.total_recycled,
       ROUND((r.total_recycled/b.total_waste)*100,2),
       CURRENT_TIMESTAMP-(b.offset_days||' days')::interval
FROM b
CROSS JOIN LATERAL (
 SELECT ROUND((b.total_waste*(0.35+random()*0.55))::numeric,2) total_recycled
) r;

-- ============================================================
-- 12. ATUALIZA MÉDIA DAS COOPERATIVAS
-- ============================================================

UPDATE cooperative c
SET average_rating=COALESCE((
 SELECT ROUND(AVG(r.stars)::numeric,2)
 FROM review r WHERE r.cooperative_id=c.id
),c.average_rating);

COMMIT;

-- ============================================================
-- VALIDAÇÕES
-- ============================================================

SELECT 'role' table_name,COUNT(*) total FROM role
UNION ALL SELECT 'company',COUNT(*) FROM company
UNION ALL SELECT 'users',COUNT(*) FROM users
UNION ALL SELECT 'area',COUNT(*) FROM area
UNION ALL SELECT 'waste_type',COUNT(*) FROM waste_type
UNION ALL SELECT 'incident',COUNT(*) FROM incident
UNION ALL SELECT 'ai_report',COUNT(*) FROM ai_report
UNION ALL SELECT 'attachment',COUNT(*) FROM attachment
UNION ALL SELECT 'cooperative',COUNT(*) FROM cooperative
UNION ALL SELECT 'collection',COUNT(*) FROM collection
UNION ALL SELECT 'collection_status',COUNT(*) FROM collection_status
UNION ALL SELECT 'review',COUNT(*) FROM review
UNION ALL SELECT 'conversation',COUNT(*) FROM conversation
UNION ALL SELECT 'message',COUNT(*) FROM message
UNION ALL SELECT 'message_attachment',COUNT(*) FROM message_attachment
UNION ALL SELECT 'notification',COUNT(*) FROM notification
UNION ALL SELECT 'esg_metric',COUNT(*) FROM esg_metric
ORDER BY table_name;

SELECT current_status,COUNT(*) total
FROM collection GROUP BY current_status ORDER BY current_status;

SELECT status,COUNT(*) total
FROM collection_status GROUP BY status ORDER BY status;

-- Deve retornar ZERO linhas:
SELECT c.id,c.current_status,cs.status latest_status
FROM collection c
JOIN LATERAL (
 SELECT status FROM collection_status
 WHERE collection_id=c.id
 ORDER BY changed_at DESC,id DESC LIMIT 1
) cs ON TRUE
WHERE c.current_status<>cs.status;

SELECT
 (SELECT COUNT(*) FROM role)+(SELECT COUNT(*) FROM company)+
 (SELECT COUNT(*) FROM users)+(SELECT COUNT(*) FROM area)+
 (SELECT COUNT(*) FROM waste_type)+(SELECT COUNT(*) FROM incident)+
 (SELECT COUNT(*) FROM ai_report)+(SELECT COUNT(*) FROM attachment)+
 (SELECT COUNT(*) FROM cooperative)+(SELECT COUNT(*) FROM collection)+
 (SELECT COUNT(*) FROM collection_status)+(SELECT COUNT(*) FROM review)+
 (SELECT COUNT(*) FROM conversation)+(SELECT COUNT(*) FROM message)+
 (SELECT COUNT(*) FROM message_attachment)+(SELECT COUNT(*) FROM notification)+
 (SELECT COUNT(*) FROM esg_metric) AS total_records;