-- ============================================================
-- VOLTA - CATÁLOGO DE DADOS (GOVERNANÇA E METADADOS)
-- Atende ao requisito: Tabela técnica de metadados descrevendo
-- tabelas, colunas, tipos, regras de negócio e níveis de acesso (LGPD)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS data_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(100) NOT NULL,
    column_name VARCHAR(100) NOT NULL,
    data_type VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    business_rule TEXT,
    access_level VARCHAR(20) NOT NULL,
    is_primary_key BOOLEAN NOT NULL DEFAULT FALSE,
    is_foreign_key BOOLEAN NOT NULL DEFAULT FALSE,
    is_nullable BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_data_catalog_table_column UNIQUE (table_name, column_name),
    CONSTRAINT chk_data_catalog_access_level
        CHECK (access_level IN ('PUBLIC', 'INTERNAL', 'SENSITIVE', 'RESTRICTED'))
);

INSERT INTO data_catalog (
    table_name, column_name, data_type, description, business_rule,
    access_level, is_primary_key, is_foreign_key, is_nullable
)
SELECT *
FROM (VALUES
    -- 1. COMPANY
    ('company','id','UUID','Identificador único da empresa.','Gerado automaticamente via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('company','name','VARCHAR(150)','Razão Social ou Nome Fantasia da empresa.','Obrigatório para identificação da organização contratante.','PUBLIC',FALSE,FALSE,FALSE),
    ('company','cnpj','VARCHAR(18)','CNPJ cadastral da empresa com máscara.','Identificador fiscal único no território nacional.','SENSITIVE',FALSE,FALSE,FALSE),
    ('company','address','VARCHAR(255)','Endereço completo da planta industrial.','Localização operacional física para coletas.','SENSITIVE',FALSE,FALSE,FALSE),
    ('company','latitude','DOUBLE PRECISION','Latitude geográfica das instalações.','Utilizado para cálculo geoespacial de proximidade e roteirização.','INTERNAL',FALSE,FALSE,TRUE),
    ('company','longitude','DOUBLE PRECISION','Longitude geográfica das instalações.','Utilizado para cálculo geoespacial de proximidade e roteirização.','INTERNAL',FALSE,FALSE,TRUE),
    ('company','is_available','BOOLEAN','Flag indicando se a empresa está ativa para chamados.','Controla a disponibilidade de agendamento de coletas.','INTERNAL',FALSE,FALSE,FALSE),

    -- 2. ROLE
    ('role','id','UUID','Identificador único do perfil funcional.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('role','type','VARCHAR(50)','Tipo do perfil de permissão (ADMIN, MANAGER, EMPLOYEE).','Define o controle de acesso baseado em funções (RBAC).','INTERNAL',FALSE,FALSE,FALSE),

    -- 3. COOPERATIVE
    ('cooperative','id','UUID','Identificador único da cooperativa parceira.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('cooperative','name','VARCHAR(150)','Nome institucional da cooperativa.','Identifica a cooperativa habilitada para reciclagem.','PUBLIC',FALSE,FALSE,FALSE),
    ('cooperative','cnpj','VARCHAR(18)','CNPJ cadastral da cooperativa.','Identificador fiscal único da entidade parceira.','SENSITIVE',FALSE,FALSE,FALSE),
    ('cooperative','email','VARCHAR(150)','E-mail oficial de contato operacional.','Canal direto para envio de despachos, notificações e chamados.','SENSITIVE',FALSE,FALSE,FALSE),
    ('cooperative','latitude','DECIMAL(9,6)','Latitude geográfica da central de triagem.','Restrito pelo CHECK de latitude entre -90 e 90.','INTERNAL',FALSE,FALSE,TRUE),
    ('cooperative','longitude','DECIMAL(9,6)','Longitude geográfica da central de triagem.','Restrito pelo CHECK de longitude entre -180 e 180.','INTERNAL',FALSE,FALSE,TRUE),
    ('cooperative','average_rating','DECIMAL(3,2)','Classificação média de avaliações (0.00 a 5.00).','Calculado periodicamente pela média das reviews de coletas.','PUBLIC',FALSE,FALSE,TRUE),
    ('cooperative','specialties','VARCHAR(500)','Materiais prioritários aceitos pela cooperativa.','Texto descritivo de materiais complementando o vínculo N:N.','PUBLIC',FALSE,FALSE,TRUE),
    ('cooperative','created_at','TIMESTAMP WITH TIME ZONE','Momento exato do credenciamento da cooperativa.','Preenchido automaticamente com CURRENT_TIMESTAMP.','INTERNAL',FALSE,FALSE,TRUE),

    -- 4. USERS
    ('users','id','UUID','Identificador único do usuário.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('users','company_id','UUID','Empresa à qual o colaborador pertence.','Restrito por chk_users_organization: preenchido exclusivamente se cooperative_id for nulo.','INTERNAL',FALSE,TRUE,TRUE),
    ('users','cooperative_id','UUID','Cooperativa à qual o operador pertence.','Restrito por chk_users_organization: preenchido exclusivamente se company_id for nulo.','INTERNAL',FALSE,TRUE,TRUE),
    ('users','role_id','UUID','Perfil de acesso e permissão do usuário.','Deve referenciar uma role válida existente.','INTERNAL',FALSE,TRUE,FALSE),
    ('users','name','VARCHAR(150)','Nome completo do colaborador.','Identificação pessoal do operador (dado protegido por LGPD).','SENSITIVE',FALSE,FALSE,FALSE),
    ('users','email','VARCHAR(150)','E-mail de login corporativo.','Identificador único de autenticação no sistema.','SENSITIVE',FALSE,FALSE,FALSE),
    ('users','password_hash','VARCHAR(255)','Hash criptográfico seguro da senha (Bcrypt).','Nunca persistir senha em texto plano; verificado no login.','RESTRICTED',FALSE,FALSE,FALSE),
    ('users','position','VARCHAR(100)','Cargo funcional do usuário.','Descrição da função desempenhada na instituição.','INTERNAL',FALSE,FALSE,TRUE),
    ('users','photo_url','VARCHAR(2048)','URL do avatar do usuário em storage seguro.','Exibido no perfil das aplicações Web e Mobile.','SENSITIVE',FALSE,FALSE,TRUE),
    ('users','registered_at','DATE','Data cadastral do colaborador na plataforma.','Data de homologação do acesso do usuário.','INTERNAL',FALSE,FALSE,TRUE),
    ('users','first_login','BOOLEAN','Flag de primeiro acesso para troca obrigatória de senha.','Obriga a alteração da credencial padrão inicial.','INTERNAL',FALSE,FALSE,TRUE),

    -- 5. AREA
    ('area','id','UUID','Identificador único do setor ou área fabril.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('area','company_id','UUID','Empresa proprietária do setor.','Deve referenciar company.id.','INTERNAL',FALSE,TRUE,FALSE),
    ('area','sector_name','VARCHAR(100)','Nome do setor operacional.','Identifica a linha de produção ou armazém (ex: Doca, Pátio).','INTERNAL',FALSE,FALSE,FALSE),
    ('area','location_description','VARCHAR(255)','Informações complementares de acesso à área.','Auxilia o operador na localização exata do ponto de descarte.','INTERNAL',FALSE,FALSE,TRUE),

    -- 6. WASTE_TYPE
    ('waste_type','id','UUID','Identificador único do tipo de resíduo.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('waste_type','category','VARCHAR(100)','Classificação do resíduo (ex: PLASTICO, METAL, QUIMICO).','Categoria mestre utilizada na triagem e no BI.','PUBLIC',FALSE,FALSE,FALSE),
    ('waste_type','description','VARCHAR(255)','Descrição detalhada das propriedades do resíduo.','Especificações de periculosidade e manuseio.','PUBLIC',FALSE,FALSE,TRUE),
    ('waste_type','default_risk_level','VARCHAR(50)','Nível de periculosidade padrão (LOW, MEDIUM, HIGH).','Subsidia a priorização dos alertas operacionais.','INTERNAL',FALSE,FALSE,FALSE),

    -- 7. INCIDENT (3FN - Sem waste_type_id direto)
    ('incident','id','UUID','Identificador único da ocorrência registrada.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('incident','company_id','UUID','Empresa onde o resíduo foi identificado.','Deve referenciar company.id.','INTERNAL',FALSE,TRUE,FALSE),
    ('incident','user_id','UUID','Colaborador autor do chamado.','Usuário remetente que detectou o incidente.','SENSITIVE',FALSE,TRUE,FALSE),
    ('incident','area_id','UUID','Setor físico onde a contaminação/resíduo se encontra.','Deve referenciar area.id.','INTERNAL',FALSE,TRUE,FALSE),
    ('incident','photo_url','VARCHAR(500)','URL da foto capturada em campo via app móvel.','Evidência visual para auditoria e entrada do modelo de IA.','SENSITIVE',FALSE,FALSE,TRUE),
    ('incident','employee_description','TEXT','Relato operacional detalhado pelo funcionário.','Descrição de campo do problema de descarte.','SENSITIVE',FALSE,FALSE,FALSE),
    ('incident','contamination_level','VARCHAR(50)','Gravidade estimada do risco ambiental.','Classificação qualitativa do nível de perigo.','INTERNAL',FALSE,FALSE,TRUE),
    ('incident','estimated_quantity','DECIMAL(12,2)','Volume estimado em quilogramas (kg).','Restrito por chk_incident_quantity para valores não negativos.','INTERNAL',FALSE,FALSE,TRUE),
    ('incident','priority','VARCHAR(30)','Urgência do atendimento (LOW, MEDIUM, HIGH, URGENT).','Determina a fila de despacho para as cooperativas.','INTERNAL',FALSE,FALSE,FALSE),
    ('incident','status','VARCHAR(50)','Estado atual do ciclo de vida da ocorrência.','OPEN, ANALYZING, COLLECTION_REQUESTED, RESOLVED, CLOSED.','INTERNAL',FALSE,FALSE,FALSE),
    ('incident','registered_at','TIMESTAMP','Momento do registro do chamado.','Timestamp oficial do incidente.','INTERNAL',FALSE,FALSE,FALSE),
    ('incident','ai_description','TEXT','Parecer resumido retornado pela API de IA.','Síntese gerada após a análise multimodal da imagem.','INTERNAL',FALSE,FALSE,TRUE),
    ('incident','title','VARCHAR(100)','Título conciso do chamado.','Resumo de cabeçalho para listagens rápidas em dashboards.','INTERNAL',FALSE,FALSE,TRUE),
    ('incident','change_reason','VARCHAR(200)','Justificativa de alterações cadastrais.','Rastreabilidade de revisões manuais efetuadas por gestores.','INTERNAL',FALSE,FALSE,TRUE),
    ('incident','reviewed_by','UUID','Gestor supervisor responsável pela homologação do chamado.','Referencia users.id do analista que aprovou o chamado.','INTERNAL',FALSE,TRUE,TRUE),
    ('incident','reviewed_at','TIMESTAMP','Data e hora em que a revisão foi formalizada.','Marco temporal da auditoria humana sobre o chamado.','INTERNAL',FALSE,FALSE,TRUE),

    -- 8. INCIDENT_WASTE_TYPE (Associativa N:N - 3FN)
    ('incident_waste_type','incident_id','UUID','Identificador da ocorrência relacionada.','PK composta com waste_type_id; cascade delete configurado.','INTERNAL',TRUE,TRUE,FALSE),
    ('incident_waste_type','waste_type_id','UUID','Identificador do tipo de resíduo presente.','PK composta com incident_id; suporta múltiplos resíduos por chamado.','INTERNAL',TRUE,TRUE,FALSE),

    -- 9. AI_REPORT
    ('ai_report','id','UUID','Identificador único da emissão do relatório de IA.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('ai_report','incident_id','UUID','Ocorrência associada ao processamento da IA.','Referência 1:1 estrita para a tabela incident.','INTERNAL',FALSE,TRUE,FALSE),
    ('ai_report','detected_waste_type','VARCHAR(100)','Material identificado pela visão computacional.','Resultado da inferência dos modelos neurais.','INTERNAL',FALSE,FALSE,TRUE),
    ('ai_report','ai_contamination_level','VARCHAR(50)','Nível de risco químico/biológico diagnosticado.','Diagnóstico preventivo automatizado.','INTERNAL',FALSE,FALSE,TRUE),
    ('ai_report','recommendations','TEXT','Instruções técnicas para manuseio e EPI.','Diretrizes de segurança repassadas aos operadores.','INTERNAL',FALSE,FALSE,TRUE),
    ('ai_report','report_text','TEXT','Memorial descritivo consolidado da inferência.','Texto estruturado com as justificativas da classificação.','INTERNAL',FALSE,FALSE,TRUE),
    ('ai_report','generated_at','TIMESTAMP','Data e hora em que a IA concluiu a análise.','Registro de latência de resposta do agente.','INTERNAL',FALSE,FALSE,FALSE),

    -- 10. ATTACHMENT
    ('attachment','id','UUID','Identificador do arquivo anexo.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('attachment','incident_id','UUID','Ocorrência documentada pelo anexo.','Deve referenciar incident.id.','INTERNAL',FALSE,TRUE,FALSE),
    ('attachment','file_url','VARCHAR(500)','Link de acesso ao arquivo em bucket de nuvem.','Armazenamento de laudos, PDFs ou fotos adicionais.','SENSITIVE',FALSE,FALSE,FALSE),
    ('attachment','file_type','VARCHAR(100)','MIME Type do documento (image/jpeg, application/pdf).','Garante validação de segurança de uploads.','INTERNAL',FALSE,FALSE,FALSE),

    -- 11. COOPERATIVE_WASTE_TYPE (Associativa N:N)
    ('cooperative_waste_type','cooperative_id','UUID','Identificador da cooperativa parceira.','PK composta que mapeia os resíduos aceitos pela cooperativa.','INTERNAL',TRUE,TRUE,FALSE),
    ('cooperative_waste_type','waste_type_id','UUID','Identificador do tipo de resíduo aceito.','PK composta garantindo que não existam duplicações de cadastro.','INTERNAL',TRUE,TRUE,FALSE),

    -- 12. COLLECTION
    ('collection','id','UUID','Identificador único da ordem de coleta.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('collection','incident_id','UUID','Ocorrência resolvida pela coleta.','Deve referenciar incident.id.','INTERNAL',FALSE,TRUE,FALSE),
    ('collection','cooperative_id','UUID','Cooperativa designada para retirada do lote.','Deve referenciar cooperative.id.','INTERNAL',FALSE,TRUE,FALSE),
    ('collection','requested_at','TIMESTAMP','Data e hora da solicitação da coleta.','Início do ciclo operacional de transporte.','INTERNAL',FALSE,FALSE,FALSE),
    ('collection','scheduled_at','TIMESTAMP','Data e hora acordadas para chegada do caminhão.','Restrito por chk_collection_dates (>= requested_at).','INTERNAL',FALSE,FALSE,TRUE),
    ('collection','current_status','VARCHAR(50)','Status atual da coleta (REQUESTED, SCHEDULED, IN_PROGRESS, COMPLETED).','Sincronizado com a última entrada em collection_status.','INTERNAL',FALSE,FALSE,FALSE),
    ('collection','collection_type','VARCHAR(50)','Modalidade operacional (STANDARD, SELECTIVE, URGENT).','Define o tipo de veículo e protocolo de pesagem.','INTERNAL',FALSE,FALSE,FALSE),
    ('collection','urgent','BOOLEAN','Flag indicadora de coleta prioritária/crítica.','Prioriza a ordem no painel de expedição.','INTERNAL',FALSE,FALSE,FALSE),

    -- 13. COLLECTION_STATUS
    ('collection_status','id','UUID','Identificador do evento de transição de status.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('collection_status','collection_id','UUID','Coleta cujo status sofreu modificação.','Deve referenciar collection.id.','INTERNAL',FALSE,TRUE,FALSE),
    ('collection_status','status','VARCHAR(50)','Novo status registrado no evento.','Rastreamento histórico da linha do tempo.','INTERNAL',FALSE,FALSE,FALSE),
    ('collection_status','changed_at','TIMESTAMP','Timestamp da ocorrência da mudança.','Ordena a cronologia dos eventos operacionais.','INTERNAL',FALSE,FALSE,FALSE),
    ('collection_status','observation','TEXT','Justificativas operacionais sobre o status.','Comentários do motorista ou operador de balança.','INTERNAL',FALSE,FALSE,TRUE),

    -- 14. REVIEW
    ('review','id','UUID','Identificador único da avaliação.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('review','cooperative_id','UUID','Cooperativa avaliada pelo serviço executado.','Deve referenciar cooperative.id.','INTERNAL',FALSE,TRUE,FALSE),
    ('review','user_id','UUID','Usuário autor da nota de serviço.','Deve referenciar users.id.','SENSITIVE',FALSE,TRUE,FALSE),
    ('review','collection_id','UUID','Coleta específica submetida à avaliação.','Deve referenciar collection.id.','INTERNAL',FALSE,TRUE,FALSE),
    ('review','stars','INTEGER','Nota quantitativa atribuída (1 a 5 estrelas).','Validado por chk_review_stars.','PUBLIC',FALSE,FALSE,FALSE),
    ('review','comment','TEXT','Feedback qualitativo da atuação da cooperativa.','Opinião e sugestão registrada pelo contratante.','SENSITIVE',FALSE,FALSE,TRUE),
    ('review','reviewed_at','TIMESTAMP','Momento em que a avaliação foi formalizada.','Preenchido com CURRENT_TIMESTAMP.','INTERNAL',FALSE,FALSE,FALSE),

    -- 15. CONVERSATION
    ('conversation','id','UUID','Identificador único da sala de negociação.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('conversation','company_id','UUID','Empresa envolvida no alinhamento de coleta.','Deve referenciar company.id.','INTERNAL',FALSE,TRUE,FALSE),
    ('conversation','cooperative_id','UUID','Cooperativa participante da tratativa.','Deve referenciar cooperative.id.','INTERNAL',FALSE,TRUE,FALSE),
    ('conversation','collection_id','UUID','Coleta que contextualiza o chat.','Garante que mensagens estejam atreladas a um chamado real.','INTERNAL',FALSE,TRUE,FALSE),
    ('conversation','created_at','TIMESTAMP','Abertura da sessão de chat.','Início da trilha de comunicação entre as partes.','INTERNAL',FALSE,FALSE,FALSE),

    -- 16. MESSAGE
    ('message','id','UUID','Identificador único da mensagem de texto enviada.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('message','conversation_id','UUID','Sessão de conversa onde a mensagem trafegou.','Deve referenciar conversation.id.','INTERNAL',FALSE,TRUE,FALSE),
    ('message','user_id','UUID','Colaborador remetente da mensagem.','Deve referenciar users.id.','SENSITIVE',FALSE,TRUE,FALSE),
    ('message','text','TEXT','Conteúdo textual da mensagem.','Mensagem protegida por sigilo de comunicação.','SENSITIVE',FALSE,FALSE,FALSE),
    ('message','reported','BOOLEAN','Flag de moderação para conteúdo impróprio ou ofensivo.','Aciona revisão administrativa em caso de reporte.','INTERNAL',FALSE,FALSE,FALSE),
    ('message','sent_at','TIMESTAMP','Momento do envio e gravação da mensagem.','Ordena o chat cronologicamente.','INTERNAL',FALSE,FALSE,FALSE),

    -- 17. MESSAGE_ATTACHMENT
    ('message_attachment','id','UUID','Identificador único do anexo transmitido no chat.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('message_attachment','message_id','UUID','Mensagem à qual o documento pertence.','Deve referenciar message.id.','INTERNAL',FALSE,TRUE,FALSE),
    ('message_attachment','file_url','VARCHAR(500)','Link de download do manifesto de transporte / pesagem.','Armazenamento de comprovantes em storage corporativo.','SENSITIVE',FALSE,FALSE,FALSE),
    ('message_attachment','file_type','VARCHAR(100)','Tipo do documento transmitido (PDF, PNG, etc).','Validação de conformidade de formato de arquivo.','INTERNAL',FALSE,FALSE,FALSE),

    -- 18. NOTIFICATION
    ('notification','id','UUID','Identificador único do alerta gerado pelo sistema.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('notification','user_id','UUID','Destinatário da notificação.','Deve referenciar users.id.','SENSITIVE',FALSE,TRUE,FALSE),
    ('notification','type','VARCHAR(50)','Categoria do evento (INCIDENT, COLLECTION, REVIEW, SYSTEM).','Filtra o tipo de alerta no sininho do app e web.','INTERNAL',FALSE,FALSE,FALSE),
    ('notification','title','VARCHAR(150)','Título do aviso.','Mensagem curta para push notifications.','INTERNAL',FALSE,FALSE,FALSE),
    ('notification','message','TEXT','Texto explicativo completo da notificação.','Detalhamento das ações requeridas ao usuário.','INTERNAL',FALSE,FALSE,FALSE),
    ('notification','read','BOOLEAN','Status de leitura pelo destinatário.','Controla contador de mensagens não lidas.','INTERNAL',FALSE,FALSE,FALSE),
    ('notification','created_at','TIMESTAMP','Data e hora da emissão do aviso.','Ordena a listagem de notificações.','INTERNAL',FALSE,FALSE,FALSE),

    -- 19. ESG_METRIC
    ('esg_metric','id','UUID','Identificador da medição de indicadores ambientais.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('esg_metric','company_id','UUID','Empresa monitorada pela métrica ESG.','Deve referenciar company.id.','INTERNAL',FALSE,TRUE,FALSE),
    ('esg_metric','period','VARCHAR(20)','Período de referência temporal (ex: 2026-01, 2026-Q1).','Permite agrupamentos mensais e trimestrais no BI.','PUBLIC',FALSE,FALSE,FALSE),
    ('esg_metric','total_waste_kg','DECIMAL(14,2)','Total de resíduos brutos gerados pela empresa.','Restrito por chk_esg_total_waste (>= 0).','INTERNAL',FALSE,FALSE,FALSE),
    ('esg_metric','total_recycled_kg','DECIMAL(14,2)','Volume total comprovadamente reciclado via coletas.','Restrito por chk_esg_recycled_not_greater (<= total_waste).','INTERNAL',FALSE,FALSE,FALSE),
    ('esg_metric','recycling_percentage','DECIMAL(5,2)','Taxa percentual de reaproveitamento atingida (0 a 100%).','Restrito por chk_esg_percentage.','PUBLIC',FALSE,FALSE,FALSE),
    ('esg_metric','calculated_at','TIMESTAMP','Data e hora da consolidação do cálculo ESG.','Registro do momento de fechamento do indicador.','INTERNAL',FALSE,FALSE,FALSE),
    ('esg_metric','weekly_target','NUMERIC(12,2)','Meta de reciclagem semanal estipulada em kg.','Monitoramento de curto prazo da política de resíduos.','INTERNAL',FALSE,FALSE,TRUE),
    ('esg_metric','weekly_date','DATE','Data limite para atingimento da meta semanal.','Gerenciado por trigger de expiração fn_reset_esg_targets.','INTERNAL',FALSE,FALSE,TRUE),
    ('esg_metric','monthly_target','NUMERIC(12,2)','Meta mensal de desvio de aterro em kg.','Meta intermediária corporativa.','INTERNAL',FALSE,FALSE,TRUE),
    ('esg_metric','monthly_date','DATE','Data limite da meta mensal.','Gerenciado por trigger de expiração fn_reset_esg_targets.','INTERNAL',FALSE,FALSE,TRUE),
    ('esg_metric','quarterly_target','NUMERIC(12,2)','Meta trimestral de sustentabilidade e economia circular.','Meta estratégica para relatórios executivos.','INTERNAL',FALSE,FALSE,TRUE),
    ('esg_metric','quarterly_date','DATE','Data de fechamento do trimestre.','Gerenciado por trigger de expiração fn_reset_esg_targets.','INTERNAL',FALSE,FALSE,TRUE),

    -- TABELAS TÉCNICAS E DE GOVERNANÇA
    ('data_catalog','id','UUID','Identificador único do metadado no catálogo.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('data_catalog','table_name','VARCHAR(100)','Nome da tabela catalogada.','Chave única composta com column_name.','INTERNAL',FALSE,FALSE,FALSE),
    ('data_catalog','column_name','VARCHAR(100)','Nome da coluna catalogada.','Chave única composta com table_name.','INTERNAL',FALSE,FALSE,FALSE),
    ('data_catalog','data_type','VARCHAR(100)','Tipo de dado técnico declarado na DDL.','Garante sincronia com o dicionário de dados do banco.','INTERNAL',FALSE,FALSE,FALSE),
    ('data_catalog','description','TEXT','Definição funcional e utilidade de negócio do atributo.','Explica a finalidade do campo para analistas e auditores.','INTERNAL',FALSE,FALSE,FALSE),
    ('data_catalog','business_rule','TEXT','Regra de negócio ou restrição CHECK aplicável.','Descreve as premissas de domínio e integridade.','INTERNAL',FALSE,FALSE,TRUE),
    ('data_catalog','access_level','VARCHAR(20)','Classificação de privacidade (PUBLIC, INTERNAL, SENSITIVE, RESTRICTED).','Define governança alinhada às exigências da LGPD.','INTERNAL',FALSE,FALSE,FALSE),
    ('data_catalog','is_primary_key','BOOLEAN','Flag indicadora de chave primária.','Metadado de arquitetura relacional.','INTERNAL',FALSE,FALSE,FALSE),
    ('data_catalog','is_foreign_key','BOOLEAN','Flag indicadora de integridade referencial.','Metadado de relacionamentos.','INTERNAL',FALSE,FALSE,FALSE),
    ('data_catalog','is_nullable','BOOLEAN','Flag de permissão de valores nulos (NOT NULL).','Metadado de obrigatoriedade.','INTERNAL',FALSE,FALSE,FALSE),

    ('audit_log','id','UUID','Identificador único do registro de auditoria.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('audit_log','table_name','VARCHAR(100)','Nome da tabela que sofreu mutação DML.','Identifica a origem do evento auditado por trigger.','INTERNAL',FALSE,FALSE,FALSE),
    ('audit_log','record_id','UUID','Chave do registro modificado ou excluído.','Rastreabilidade unitária da tupla.','INTERNAL',FALSE,FALSE,TRUE),
    ('audit_log','operation','VARCHAR(10)','Comando executado (INSERT, UPDATE ou DELETE).','Capturado via TG_OP na trigger de auditoria.','INTERNAL',FALSE,FALSE,FALSE),
    ('audit_log','old_data','JSONB','Snapshot anterior dos dados em formato JSONB.','Preenchido em UPDATEs e DELETEs para rollback de auditoria.','RESTRICTED',FALSE,FALSE,TRUE),
    ('audit_log','new_data','JSONB','Novo snapshot dos dados em formato JSONB.','Preenchido em INSERTs e UPDATEs para auditoria.','RESTRICTED',FALSE,FALSE,TRUE),
    ('audit_log','changed_at','TIMESTAMP','Momento exato da alteração no banco.','Timestamp preenchido com CURRENT_TIMESTAMP.','INTERNAL',FALSE,FALSE,FALSE),
    ('audit_log','database_user','VARCHAR(100)','Usuário de banco de dados responsável pela transação.','Capturado via CURRENT_USER na trigger de auditoria.','RESTRICTED',FALSE,FALSE,FALSE),

    ('user_daily_access','id','UUID','Identificador único do sumário de acesso diário.','Gerado via gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('user_daily_access','user_id','UUID','Usuário autenticado monitorado.','Deve referenciar users.id.','SENSITIVE',FALSE,TRUE,FALSE),
    ('user_daily_access','access_date','DATE','Data do dia de atividade registrada.','Chave única diária por usuário para métrica DAU.','INTERNAL',FALSE,FALSE,FALSE),
    ('user_daily_access','first_access_at','TIMESTAMP','Horário do primeiro login realizado no dia.','Início da jornada diária do operador.','INTERNAL',FALSE,FALSE,FALSE),
    ('user_daily_access','last_access_at','TIMESTAMP','Horário do acesso mais recente registrado no dia.','Atualizado a cada nova requisição da sessão.','INTERNAL',FALSE,FALSE,FALSE),
    ('user_daily_access','access_count','INTEGER','Total consolidado de requisições do usuário na data.','Contador cumulativo de atividade na plataforma.','INTERNAL',FALSE,FALSE,FALSE)
) AS catalog(
    table_name, column_name, data_type, description, business_rule,
    access_level, is_primary_key, is_foreign_key, is_nullable
)
ON CONFLICT (table_name, column_name) DO UPDATE SET
    data_type = EXCLUDED.data_type,
    description = EXCLUDED.description,
    business_rule = EXCLUDED.business_rule,
    access_level = EXCLUDED.access_level,
    is_primary_key = EXCLUDED.is_primary_key,
    is_foreign_key = EXCLUDED.is_foreign_key,
    is_nullable = EXCLUDED.is_nullable;

-- ============================================================
-- CONSULTAS DE VALIDAÇÃO PARA O AVALIADOR
-- ============================================================

-- Validação 1: Contagem de colunas catalogadas por tabela (comprova cobertura das 19 tabelas + técnicas)
SELECT table_name, COUNT(*) AS total_colunas_catalogadas
FROM data_catalog
GROUP BY table_name
ORDER BY table_name;

-- Validação 2: Distribuição por nível de sensibilidade de dados (Governança / LGPD)
SELECT access_level, COUNT(*) AS total_campos
FROM data_catalog
GROUP BY access_level
ORDER BY total_campos DESC;

-- Validação 3: Amostra de campos restritos e sensíveis
SELECT table_name, column_name, access_level, business_rule
FROM data_catalog
WHERE access_level IN ('SENSITIVE', 'RESTRICTED')
ORDER BY table_name, column_name;