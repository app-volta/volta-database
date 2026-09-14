-- ============================================================
-- VOLTA - CATÁLOGO DE DADOS
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
    ('company','id','UUID','Identificador da empresa.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('company','name','VARCHAR(150)','Nome da empresa.','Obrigatório para identificação da organização.','PUBLIC',FALSE,FALSE,FALSE),
    ('company','cnpj','VARCHAR(18)','CNPJ da empresa.','Deve identificar uma única empresa.','SENSITIVE',FALSE,FALSE,FALSE),
    ('company','address','VARCHAR(255)','Endereço da empresa.','Informação cadastral da organização.','SENSITIVE',FALSE,FALSE,FALSE),

    ('role','id','UUID','Identificador do perfil.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('role','type','VARCHAR','Tipo do perfil de acesso.','Define o papel funcional do usuário.','INTERNAL',FALSE,FALSE,FALSE),

    ('users','id','UUID','Identificador do usuário.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('users','company_id','UUID','Empresa do usuário, quando aplicável.','Exatamente uma entre company_id e cooperative_id deve ser preenchida.','INTERNAL',FALSE,TRUE,TRUE),
    ('users','cooperative_id','UUID','Cooperativa do usuário, quando aplicável.','Exatamente uma entre company_id e cooperative_id deve ser preenchida.','INTERNAL',FALSE,TRUE,TRUE),
    ('users','role_id','UUID','Perfil associado ao usuário.','Deve referenciar um registro existente em role.','INTERNAL',FALSE,TRUE,FALSE),
    ('users','name','VARCHAR','Nome do usuário.','Usado para identificação na aplicação.','SENSITIVE',FALSE,FALSE,FALSE),
    ('users','email','VARCHAR','E-mail do usuário.','Usado para autenticação e deve ser único.','SENSITIVE',FALSE,FALSE,FALSE),
    ('users','password_hash','VARCHAR','Hash da senha.','Nunca armazenar senha em texto puro.','RESTRICTED',FALSE,FALSE,FALSE),
    ('users','position','VARCHAR','Cargo ou posição do usuário.','Descreve a função do usuário na organização.','INTERNAL',FALSE,FALSE,TRUE),

    ('area','id','UUID','Identificador da área.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('area','company_id','UUID','Empresa proprietária da área.','Deve referenciar company.','INTERNAL',FALSE,TRUE,FALSE),
    ('area','sector_name','VARCHAR','Nome do setor.','Identifica o setor operacional.','INTERNAL',FALSE,FALSE,FALSE),
    ('area','location_description','VARCHAR','Descrição da localização.','Detalha onde a área está situada.','INTERNAL',FALSE,FALSE,TRUE),

    ('waste_type','id','UUID','Identificador do tipo de resíduo.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('waste_type','category','VARCHAR','Categoria do resíduo.','Classifica o resíduo.','PUBLIC',FALSE,FALSE,FALSE),
    ('waste_type','description','TEXT','Descrição do resíduo.','Explica as características do tipo.','PUBLIC',FALSE,FALSE,TRUE),
    ('waste_type','default_risk_level','VARCHAR','Nível de risco padrão.','Apoia a priorização de ocorrências.','INTERNAL',FALSE,FALSE,FALSE),

    ('incident','id','UUID','Identificador da ocorrência.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('incident','company_id','UUID','Empresa relacionada à ocorrência.','Deve referenciar company.','INTERNAL',FALSE,TRUE,FALSE),
    ('incident','user_id','UUID','Usuário que registrou a ocorrência.','Deve referenciar users.','SENSITIVE',FALSE,TRUE,FALSE),
    ('incident','waste_type_id','UUID','Tipo de resíduo identificado.','Deve referenciar waste_type.','INTERNAL',FALSE,TRUE,FALSE),
    ('incident','photo_url','VARCHAR','URL da evidência fotográfica.','Pode ser usada na análise de IA.','SENSITIVE',FALSE,FALSE,TRUE),
    ('incident','employee_description','TEXT','Descrição informada pelo colaborador.','Registra o contexto da ocorrência.','SENSITIVE',FALSE,FALSE,FALSE),
    ('incident','estimated_quantity','DECIMAL','Quantidade estimada de resíduo.','Não deve ser negativa.','INTERNAL',FALSE,FALSE,TRUE),
    ('incident','priority','VARCHAR','Prioridade da ocorrência.','Apoia a ordem de atendimento.','INTERNAL',FALSE,FALSE,FALSE),
    ('incident','status','VARCHAR','Status atual da ocorrência.','Representa o estágio de atendimento.','INTERNAL',FALSE,FALSE,FALSE),
    ('incident','registered_at','TIMESTAMP','Data e hora do registro.','Usada para ordenação e auditoria operacional.','INTERNAL',FALSE,FALSE,FALSE),

    ('ai_report','id','UUID','Identificador do relatório de IA.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('ai_report','incident_id','UUID','Ocorrência analisada.','Deve referenciar incident.','INTERNAL',FALSE,TRUE,FALSE),
    ('ai_report','detected_waste_type','VARCHAR','Tipo de resíduo detectado pela IA.','Resultado da classificação automática.','INTERNAL',FALSE,FALSE,TRUE),
    ('ai_report','ai_contamination_level','VARCHAR','Nível de contaminação identificado.','Resultado da análise automática.','INTERNAL',FALSE,FALSE,TRUE),
    ('ai_report','recommendations','TEXT','Recomendações geradas pela IA.','Apoiam o tratamento da ocorrência.','INTERNAL',FALSE,FALSE,TRUE),
    ('ai_report','report_text','TEXT','Texto completo do relatório.','Mantém a saída textual da análise.','INTERNAL',FALSE,FALSE,TRUE),
    ('ai_report','generated_at','TIMESTAMP','Data e hora da geração.','Registra quando a análise ocorreu.','INTERNAL',FALSE,FALSE,FALSE),

    ('attachment','id','UUID','Identificador do anexo.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('attachment','incident_id','UUID','Ocorrência do anexo.','Deve referenciar incident.','INTERNAL',FALSE,TRUE,FALSE),
    ('attachment','file_url','VARCHAR','URL do arquivo.','Aponta para o armazenamento do anexo.','SENSITIVE',FALSE,FALSE,FALSE),
    ('attachment','file_type','VARCHAR','Tipo do arquivo.','Identifica o formato do anexo.','INTERNAL',FALSE,FALSE,FALSE),

    ('cooperative','id','UUID','Identificador da cooperativa.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('cooperative','name','VARCHAR','Nome da cooperativa.','Identifica a organização parceira.','PUBLIC',FALSE,FALSE,FALSE),
    ('cooperative','cnpj','VARCHAR(18)','CNPJ da cooperativa.','Identificador cadastral da organização.','SENSITIVE',FALSE,FALSE,FALSE),
    ('cooperative','address','VARCHAR(255)','Endereço da cooperativa.','Informação cadastral da organização.','SENSITIVE',FALSE,FALSE,FALSE),
    ('cooperative','average_rating','DECIMAL','Avaliação média da cooperativa.','Calculada a partir das avaliações recebidas.','PUBLIC',FALSE,FALSE,TRUE),

    ('collection','id','UUID','Identificador da coleta.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('collection','incident_id','UUID','Ocorrência relacionada à coleta.','Deve referenciar incident.','INTERNAL',FALSE,TRUE,TRUE),
    ('collection','cooperative_id','UUID','Cooperativa responsável pela coleta.','Deve referenciar cooperative.','INTERNAL',FALSE,TRUE,FALSE),
    ('collection','requested_at','TIMESTAMP','Data e hora da solicitação.','Início do fluxo de coleta.','INTERNAL',FALSE,FALSE,FALSE),
    ('collection','scheduled_at','TIMESTAMP','Data e hora agendada.','Deve ser compatível com a solicitação.','INTERNAL',FALSE,FALSE,TRUE),
    ('collection','current_status','VARCHAR','Status atual da coleta.','Deve refletir o último status registrado.','INTERNAL',FALSE,FALSE,FALSE),

    ('collection_status','id','UUID','Identificador do histórico.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('collection_status','collection_id','UUID','Coleta cujo status mudou.','Deve referenciar collection.','INTERNAL',FALSE,TRUE,FALSE),
    ('collection_status','status','VARCHAR','Status registrado.','Mantém o histórico do fluxo da coleta.','INTERNAL',FALSE,FALSE,FALSE),
    ('collection_status','changed_at','TIMESTAMP','Data e hora da mudança.','Ordena a evolução dos status.','INTERNAL',FALSE,FALSE,FALSE),
    ('collection_status','observation','TEXT','Observação da mudança.','Registra contexto operacional adicional.','INTERNAL',FALSE,FALSE,TRUE),

    ('review','id','UUID','Identificador da avaliação.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('review','cooperative_id','UUID','Cooperativa avaliada.','Deve referenciar cooperative.','INTERNAL',FALSE,TRUE,FALSE),
    ('review','user_id','UUID','Usuário que avaliou.','Deve referenciar users.','SENSITIVE',FALSE,TRUE,FALSE),
    ('review','collection_id','UUID','Coleta avaliada.','Deve referenciar collection.','INTERNAL',FALSE,TRUE,FALSE),
    ('review','stars','INTEGER','Nota da avaliação.','Deve respeitar a escala definida pelo negócio.','PUBLIC',FALSE,FALSE,FALSE),
    ('review','comment','TEXT','Comentário da avaliação.','Pode conter opinião ou informação operacional.','SENSITIVE',FALSE,FALSE,TRUE),
    ('review','reviewed_at','TIMESTAMP','Data e hora da avaliação.','Registra quando a avaliação ocorreu.','INTERNAL',FALSE,FALSE,FALSE),

    ('conversation','id','UUID','Identificador da conversa.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('conversation','company_id','UUID','Empresa participante da conversa.','Deve referenciar company quando preenchido.','INTERNAL',FALSE,TRUE,TRUE),
    ('conversation','cooperative_id','UUID','Cooperativa participante da conversa.','Deve referenciar cooperative quando preenchido.','INTERNAL',FALSE,TRUE,TRUE),
    ('conversation','collection_id','UUID','Coleta relacionada à conversa.','Deve referenciar collection quando preenchido.','INTERNAL',FALSE,TRUE,TRUE),
    ('conversation','created_at','TIMESTAMP','Data e hora de criação.','Registra o início da conversa.','INTERNAL',FALSE,FALSE,FALSE),

    ('message','id','UUID','Identificador da mensagem.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('message','conversation_id','UUID','Conversa da mensagem.','Deve referenciar conversation.','INTERNAL',FALSE,TRUE,FALSE),
    ('message','user_id','UUID','Usuário remetente.','Deve referenciar users.','SENSITIVE',FALSE,TRUE,FALSE),
    ('message','text','TEXT','Conteúdo da mensagem.','Conteúdo privado da comunicação.','SENSITIVE',FALSE,FALSE,FALSE),
    ('message','reported','BOOLEAN','Indica se a mensagem foi denunciada.','Usado para moderação e segurança.','INTERNAL',FALSE,FALSE,FALSE),
    ('message','sent_at','TIMESTAMP','Data e hora do envio.','Registra a ordem das mensagens.','INTERNAL',FALSE,FALSE,FALSE),

    ('message_attachment','id','UUID','Identificador do anexo da mensagem.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('message_attachment','message_id','UUID','Mensagem do anexo.','Deve referenciar message.','INTERNAL',FALSE,TRUE,FALSE),
    ('message_attachment','file_url','VARCHAR','URL do arquivo.','Aponta para o armazenamento do anexo.','SENSITIVE',FALSE,FALSE,FALSE),
    ('message_attachment','file_type','VARCHAR','Tipo do arquivo.','Identifica o formato do anexo.','INTERNAL',FALSE,FALSE,FALSE),

    ('notification','id','UUID','Identificador da notificação.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('notification','user_id','UUID','Usuário destinatário.','Deve referenciar users.','SENSITIVE',FALSE,TRUE,FALSE),
    ('notification','type','VARCHAR','Tipo da notificação.','Classifica o evento notificado.','INTERNAL',FALSE,FALSE,FALSE),
    ('notification','title','VARCHAR','Título da notificação.','Resumo exibido ao usuário.','INTERNAL',FALSE,FALSE,FALSE),
    ('notification','message','TEXT','Texto da notificação.','Detalha o evento notificado.','INTERNAL',FALSE,FALSE,FALSE),
    ('notification','read','BOOLEAN','Indica se foi lida.','Controla o estado de leitura.','INTERNAL',FALSE,FALSE,FALSE),
    ('notification','created_at','TIMESTAMP','Data e hora de criação.','Registra quando foi gerada.','INTERNAL',FALSE,FALSE,FALSE),

    ('esg_metric','id','UUID','Identificador da métrica ESG.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('esg_metric','company_id','UUID','Empresa da métrica.','Deve referenciar company.','INTERNAL',FALSE,TRUE,FALSE),
    ('esg_metric','period','DATE','Período de referência.','Permite acompanhar a evolução temporal.','PUBLIC',FALSE,FALSE,FALSE),
    ('esg_metric','total_waste_kg','NUMERIC','Total de resíduos gerados em kg.','Deve ser não negativo.','INTERNAL',FALSE,FALSE,FALSE),
    ('esg_metric','total_recycled_kg','NUMERIC','Total reciclado em kg.','Não deve exceder o total de resíduos.','INTERNAL',FALSE,FALSE,FALSE),
    ('esg_metric','recycling_percentage','NUMERIC','Percentual reciclado.','Derivado dos totais de resíduos e reciclados.','PUBLIC',FALSE,FALSE,FALSE),
    ('esg_metric','calculated_at','TIMESTAMP','Data e hora do cálculo.','Registra quando o indicador foi calculado.','INTERNAL',FALSE,FALSE,FALSE),

    ('data_catalog','id','UUID','Identificador do metadado.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('data_catalog','table_name','VARCHAR(100)','Nome da tabela documentada.','Combinado com column_name forma uma chave única.','INTERNAL',FALSE,FALSE,FALSE),
    ('data_catalog','column_name','VARCHAR(100)','Nome da coluna documentada.','Combinado com table_name forma uma chave única.','INTERNAL',FALSE,FALSE,FALSE),
    ('data_catalog','data_type','VARCHAR(100)','Tipo de dado da coluna documentada.','Deve refletir o schema vigente.','INTERNAL',FALSE,FALSE,FALSE),
    ('data_catalog','description','TEXT','Descrição funcional da coluna.','Explica o significado do dado.','INTERNAL',FALSE,FALSE,FALSE),
    ('data_catalog','business_rule','TEXT','Regra de negócio da coluna.','Documenta validações e uso esperado.','INTERNAL',FALSE,FALSE,TRUE),
    ('data_catalog','access_level','VARCHAR(20)','Nível de acesso do dado.','Aceita PUBLIC, INTERNAL, SENSITIVE ou RESTRICTED.','INTERNAL',FALSE,FALSE,FALSE),
    ('data_catalog','is_primary_key','BOOLEAN','Indica se é chave primária.','Metadado estrutural.','INTERNAL',FALSE,FALSE,FALSE),
    ('data_catalog','is_foreign_key','BOOLEAN','Indica se é chave estrangeira.','Metadado estrutural.','INTERNAL',FALSE,FALSE,FALSE),
    ('data_catalog','is_nullable','BOOLEAN','Indica se a coluna aceita NULL.','Metadado estrutural.','INTERNAL',FALSE,FALSE,FALSE),

    ('audit_log','id','UUID','Identificador do registro de auditoria.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('audit_log','table_name','VARCHAR(100)','Nome da tabela que sofreu alteração.','Identifica a origem do evento auditado.','INTERNAL',FALSE,FALSE,FALSE),
    ('audit_log','record_id','UUID','Identificador do registro alterado.','Pode ser nulo quando a operação não estiver associada a um UUID específico.','INTERNAL',FALSE,FALSE,TRUE),
    ('audit_log','operation','VARCHAR(10)','Operação auditada.','Registra a operação executada no dado.','INTERNAL',FALSE,FALSE,FALSE),
    ('audit_log','old_data','JSONB','Estado anterior do registro.','Armazena dados anteriores quando aplicável.','RESTRICTED',FALSE,FALSE,TRUE),
    ('audit_log','new_data','JSONB','Estado posterior do registro.','Armazena dados posteriores quando aplicável.','RESTRICTED',FALSE,FALSE,TRUE),
    ('audit_log','changed_at','TIMESTAMP','Data e hora da alteração.','Preenchido automaticamente com CURRENT_TIMESTAMP.','INTERNAL',FALSE,FALSE,FALSE),
    ('audit_log','database_user','VARCHAR(100)','Usuário do banco que realizou a alteração.','Preenchido automaticamente com CURRENT_USER.','RESTRICTED',FALSE,FALSE,FALSE),

    ('user_daily_access','id','UUID','Identificador do acesso diário.','Gerado por gen_random_uuid().','INTERNAL',TRUE,FALSE,FALSE),
    ('user_daily_access','user_id','UUID','Usuário que acessou.','Deve referenciar users.','SENSITIVE',FALSE,TRUE,FALSE),
    ('user_daily_access','access_date','DATE','Data do acesso.','Há no máximo um registro por usuário e dia.','INTERNAL',FALSE,FALSE,FALSE),
    ('user_daily_access','first_access_at','TIMESTAMP','Primeiro acesso do dia.','Registra o início da atividade diária.','INTERNAL',FALSE,FALSE,FALSE),
    ('user_daily_access','last_access_at','TIMESTAMP','Último acesso do dia.','Atualizado a cada acesso no mesmo dia.','INTERNAL',FALSE,FALSE,FALSE),
    ('user_daily_access','access_count','INTEGER','Quantidade de acessos no dia.','Deve ser maior que zero.','INTERNAL',FALSE,FALSE,FALSE)
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

-- Validação 1: catálogo completo
SELECT * FROM data_catalog ORDER BY table_name, column_name;

-- Validação 2: quantidade de colunas catalogadas por tabela
SELECT table_name, COUNT(*) AS column_count
FROM data_catalog
GROUP BY table_name
ORDER BY table_name;

-- Validação 3: campos sensíveis e restritos
SELECT table_name, column_name, access_level, description
FROM data_catalog
WHERE access_level IN ('SENSITIVE', 'RESTRICTED')
ORDER BY access_level, table_name, column_name;