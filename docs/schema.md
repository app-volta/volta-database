# Esquema do Banco de Dados — VOLTA

## Visão Geral

O banco de dados relacional do projeto **VOLTA** foi projetado para o PostgreSQL e centraliza o fluxo operacional de gestão de resíduos industriais, auditoria de sustentabilidade, triagem com inteligência artificial e despacho para cooperativas de reciclagem credenciadas.

O esquema físico consolidado é composto por **19 tabelas**. Todas as relações utilizam integridade referencial estrita via chaves estrangeiras (`FOREIGN KEY`), restrições de unicidade (`UNIQUE`), valores padrão (`DEFAULT`) e restrições de domínio (`CHECK`).

## PostgreSQL, Extensões e Tipagem de Identificadores

O script inicializa habilitando o suporte criptográfico nativo:

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

Todas as 17 entidades convencionais utilizam como chave primária um identificador único universal (`UUID`), gerado dinamicamente via `gen_random_uuid()`. As 2 tabelas associativas (`cooperative_waste_type` e `incident_waste_type`) adotam chaves primárias compostas baseadas nos pares de chaves estrangeiras relacionadas.

---

## Detalhamento das Tabelas

### 1. `company`

Representa as empresas parceiras e geradoras de resíduos atendidas pela plataforma.

| Campo            | Tipo                 | Restrições                      | Descrição                         |
| :--------------- | :------------------- | :-------------------------------- | :---------------------------------- |
| `id`           | `UUID`             | PK, `DEFAULT gen_random_uuid()` | Identificador exclusivo da empresa  |
| `name`         | `VARCHAR(150)`     | `NOT NULL`                      | Razão Social ou Nome Fantasia      |
| `cnpj`         | `VARCHAR(18)`      | `NOT NULL`, `UNIQUE`          | CNPJ formatado da empresa           |
| `address`      | `VARCHAR(255)`     | `NOT NULL`                      | Endereço físico completo          |
| `latitude`     | `DOUBLE PRECISION` | Opcional                          | Coordenada geográfica de latitude  |
| `longitude`    | `DOUBLE PRECISION` | Opcional                          | Coordenada geográfica de longitude |
| `is_available` | `BOOLEAN`          | `NOT NULL`, `DEFAULT TRUE`    | Flag de atividade/disponibilidade   |

---

### 2. `role`

Catálogo de permissões e papéis de acesso ao ecossistema (`ADMIN`, `MANAGER`, `EMPLOYEE`).

| Campo    | Tipo            | Restrições                      | Descrição                            |
| :------- | :-------------- | :-------------------------------- | :------------------------------------- |
| `id`   | `UUID`        | PK, `DEFAULT gen_random_uuid()` | Identificador exclusivo do papel       |
| `type` | `VARCHAR(50)` | `NOT NULL`, `UNIQUE`          | Nome identificador do perfil de acesso |

---

### 3. `cooperative`

Entidades de reciclagem parceiras responsáveis pela coleta, triagem e destinação final de resíduos.

| Campo              | Tipo                         | Restrições                      | Descrição                                       |
| :----------------- | :--------------------------- | :-------------------------------- | :------------------------------------------------ |
| `id`             | `UUID`                     | PK, `DEFAULT gen_random_uuid()` | Identificador exclusivo da cooperativa            |
| `name`           | `VARCHAR(150)`             | `NOT NULL`                      | Razão Social / Nome da cooperativa               |
| `cnpj`           | `VARCHAR(18)`              | `NOT NULL`, `UNIQUE`          | CNPJ da cooperativa                               |
| `email`          | `VARCHAR(150)`             | `NOT NULL`                      | E-mail de contato para notificações e despachos |
| `latitude`       | `DECIMAL(9,6)`             | `CHECK (-90 a 90)`              | Latitude geográfica                              |
| `longitude`      | `DECIMAL(9,6)`             | `CHECK (-180 a 180)`            | Longitude geográfica                             |
| `average_rating` | `DECIMAL(3,2)`             | `DEFAULT 0`, `CHECK (0 a 5)`  | Reputação média ponderada                      |
| `specialties`    | `VARCHAR(500)`             | Opcional                          | Descritivo geral de materiais aceitos             |
| `created_at`     | `TIMESTAMP WITH TIME ZONE` | `DEFAULT CURRENT_TIMESTAMP`     | Data/hora de registro no sistema                  |

---

### 4. `users`

Usuários do sistema (geradores, gestores operacionais e operadores). O isolamento multi-inquilino é garantido via restrição de organização.

| Campo              | Tipo              | Restrições                      | Descrição                                 |
| :----------------- | :---------------- | :-------------------------------- | :------------------------------------------ |
| `id`             | `UUID`          | PK, `DEFAULT gen_random_uuid()` | Identificador do usuário                   |
| `company_id`     | `UUID`          | FK → `company.id`              | Vínculo com empresa geradora               |
| `cooperative_id` | `UUID`          | FK → `cooperative.id`          | Vínculo com cooperativa                    |
| `role_id`        | `UUID`          | `NOT NULL`, FK → `role.id`   | Nível de acesso e permissão               |
| `name`           | `VARCHAR(150)`  | `NOT NULL`                      | Nome completo                               |
| `email`          | `VARCHAR(150)`  | `NOT NULL`, `UNIQUE`          | Credencial de acesso (login)                |
| `password_hash`  | `VARCHAR(255)`  | `NOT NULL`                      | Hash Bcrypt da senha                        |
| `position`       | `VARCHAR(100)`  | Opcional                          | Cargo ou departamento interno               |
| `photo_url`      | `VARCHAR(2048)` | Opcional                          | URL da foto de perfil                       |
| `registered_at`  | `DATE`          | Opcional                          | Data de inclusão do cadastro               |
| `first_login`    | `BOOLEAN`       | Opcional                          | Flag indicadora de primeiro acesso pendente |

*Regra de Domínio:* A constraint `chk_users_organization` exige que o usuário pertença exclusivamente a uma empresa **OU** a uma cooperativa:

```sql
CHECK (
    (company_id IS NOT NULL AND cooperative_id IS NULL)
    OR
    (company_id IS NULL AND cooperative_id IS NOT NULL)
)
```

---

### 5. `area`

Setores ou áreas físicas operacionais cadastradas por empresa geradora.

| Campo                    | Tipo             | Restrições                       | Descrição                      |
| :----------------------- | :--------------- | :--------------------------------- | :------------------------------- |
| `id`                   | `UUID`         | PK, `DEFAULT gen_random_uuid()`  | Identificador da área           |
| `company_id`           | `UUID`         | `NOT NULL`, FK → `company.id` | Empresa à qual pertence         |
| `sector_name`          | `VARCHAR(100)` | `NOT NULL`                       | Nome do setor / galpão          |
| `location_description` | `VARCHAR(255)` | Opcional                           | Ponto de referência ou detalhes |

---

### 6. `waste_type`

Catálogo padronizado de categorias de resíduos industriais e seus riscos regulatórios.

| Campo                  | Tipo             | Restrições                      | Descrição                       |
| :--------------------- | :--------------- | :-------------------------------- | :-------------------------------- |
| `id`                 | `UUID`         | PK, `DEFAULT gen_random_uuid()` | Identificador do tipo de resíduo |
| `category`           | `VARCHAR(100)` | `NOT NULL`                      | Categoria de resíduo             |
| `description`        | `VARCHAR(255)` | Opcional                          | Especificações do resíduo      |
| `default_risk_level` | `VARCHAR(50)`  | `NOT NULL`                      | Nível de risco ambiental prévio |

---

### 7. `incident`

Chamados de descarte e ocorrências registradas nas dependências da empresa.

| Campo                    | Tipo              | Restrições                                | Descrição                            |
| :----------------------- | :---------------- | :------------------------------------------ | :------------------------------------- |
| `id`                   | `UUID`          | PK, `DEFAULT gen_random_uuid()`           | Identificador do chamado               |
| `company_id`           | `UUID`          | `NOT NULL`, FK → `company.id`          | Empresa de origem                      |
| `user_id`              | `UUID`          | `NOT NULL`, FK → `users.id`            | Operador relator                       |
| `area_id`              | `UUID`          | `NOT NULL`, FK → `area.id`             | Área/setor do incidente               |
| `photo_url`            | `VARCHAR(500)`  | Opcional                                    | Registro fotográfico primário        |
| `employee_description` | `TEXT`          | `NOT NULL`                                | Descrição fornecida pelo colaborador |
| `contamination_level`  | `VARCHAR(50)`   | Opcional                                    | Classificação da contaminação      |
| `estimated_quantity`   | `DECIMAL(12,2)` | `CHECK (>= 0)`                            | Volume estimado em kg ou unidades      |
| `priority`             | `VARCHAR(30)`   | `NOT NULL`                                | Nível de prioridade                   |
| `status`               | `VARCHAR(50)`   | `NOT NULL`                                | Situação do ciclo de vida            |
| `registered_at`        | `TIMESTAMP`     | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Data/hora da criação                 |
| `ai_description`       | `TEXT`          | Opcional                                    | Pré-análise textual do modelo de IA  |
| `title`                | `VARCHAR(100)`  | Opcional                                    | Título descritivo do incidente        |
| `change_reason`        | `VARCHAR(200)`  | Opcional                                    | Justificativa de eventual alteração  |
| `reviewed_by`          | `UUID`          | FK → `users.id`                          | Gestor que validou a triagem           |
| `reviewed_at`          | `TIMESTAMP`     | Opcional                                    | Data/hora da revisão humana           |

---

### 8. `ai_report`

Diagnóstico aprofundado gerado pelo pipeline de Inteligência Artificial para cada ocorrência.

| Campo                      | Tipo             | Restrições                                | Descrição                                    |
| :------------------------- | :--------------- | :------------------------------------------ | :--------------------------------------------- |
| `id`                     | `UUID`         | PK, `DEFAULT gen_random_uuid()`           | Identificador do relatório                    |
| `incident_id`            | `UUID`         | `NOT NULL`, FK → `incident.id`         | Ocorrência vinculada (1:1)                    |
| `detected_waste_type`    | `VARCHAR(100)` | Opcional                                    | Material identificado por visão computacional |
| `ai_contamination_level` | `VARCHAR(50)`  | Opcional                                    | Risco avaliado pela IA                         |
| `recommendations`        | `TEXT`         | Opcional                                    | Protocolos de manuseio e segurança            |
| `report_text`            | `TEXT`         | Opcional                                    | Parecer analítico consolidado                 |
| `generated_at`           | `TIMESTAMP`    | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Data/hora de conclusão da inferência         |

---

### 9. `attachment`

Arquivos complementares vinculados a uma ocorrência (evidências, FISPQ, etc.).

| Campo           | Tipo             | Restrições                        | Descrição                         |
| :-------------- | :--------------- | :---------------------------------- | :---------------------------------- |
| `id`          | `UUID`         | PK, `DEFAULT gen_random_uuid()`   | Identificador do anexo              |
| `incident_id` | `UUID`         | `NOT NULL`, FK → `incident.id` | Ocorrência vinculada               |
| `file_url`    | `VARCHAR(500)` | `NOT NULL`                        | Localização do arquivo no storage |
| `file_type`   | `VARCHAR(100)` | `NOT NULL`                        | Extensão / MIME Type               |

---

### 10. `collection`

Agendamento, autorização e realização da coleta de resíduos com uma cooperativa.

| Campo               | Tipo            | Restrições                                | Descrição                       |
| :------------------ | :-------------- | :------------------------------------------ | :-------------------------------- |
| `id`              | `UUID`        | PK, `DEFAULT gen_random_uuid()`           | Identificador da coleta           |
| `incident_id`     | `UUID`        | `NOT NULL`, FK → `incident.id`         | Chamado atendido                  |
| `cooperative_id`  | `UUID`        | `NOT NULL`, FK → `cooperative.id`      | Cooperativa designada             |
| `requested_at`    | `TIMESTAMP`   | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Horário de despacho              |
| `scheduled_at`    | `TIMESTAMP`   | `CHECK (scheduled_at >= requested_at)`    | Previsão de recolhimento         |
| `current_status`  | `VARCHAR(50)` | `NOT NULL`                                | Estado operacional consolidado    |
| `collection_type` | `VARCHAR(50)` | `NOT NULL`                                | Modalidade da logística          |
| `urgent`          | `BOOLEAN`     | `NOT NULL`, `DEFAULT FALSE`             | Indicador de urgência logística |

---

### 11. `collection_status`

Linha do tempo auditável de cada etapa percorrida pelo chamado de coleta.

| Campo             | Tipo            | Restrições                                | Descrição                      |
| :---------------- | :-------------- | :------------------------------------------ | :------------------------------- |
| `id`            | `UUID`        | PK, `DEFAULT gen_random_uuid()`           | Identificador da transição     |
| `collection_id` | `UUID`        | `NOT NULL`, FK → `collection.id`       | Coleta auditada                  |
| `status`        | `VARCHAR(50)` | `NOT NULL`                                | Status assumido                  |
| `changed_at`    | `TIMESTAMP`   | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Momento da alteração           |
| `observation`   | `TEXT`        | Opcional                                    | Parecer do motorista ou operador |

---

### 12. `review`

Avaliação de qualidade emitida pelo gerador após o recolhimento pela cooperativa.

| Campo              | Tipo          | Restrições                                | Descrição                  |
| :----------------- | :------------ | :------------------------------------------ | :--------------------------- |
| `id`             | `UUID`      | PK, `DEFAULT gen_random_uuid()`           | Identificador da avaliação |
| `cooperative_id` | `UUID`      | `NOT NULL`, FK → `cooperative.id`      | Cooperativa avaliada         |
| `user_id`        | `UUID`      | `NOT NULL`, FK → `users.id`            | Avaliador                    |
| `collection_id`  | `UUID`      | `NOT NULL`, FK → `collection.id`       | Coleta inspecionada          |
| `stars`          | `INTEGER`   | `NOT NULL`, `CHECK (1 a 5)`             | Pontuação concedida        |
| `comment`        | `TEXT`      | Opcional                                    | Feedback qualitativo         |
| `reviewed_at`    | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Data do registro             |

---

### 13. `conversation`

Canal de comunicação dedicado entre gerador e cooperativa para alinhar uma coleta.

| Campo              | Tipo          | Restrições                                | Descrição                       |
| :----------------- | :------------ | :------------------------------------------ | :-------------------------------- |
| `id`             | `UUID`      | PK, `DEFAULT gen_random_uuid()`           | Identificador da sala de conversa |
| `company_id`     | `UUID`      | `NOT NULL`, FK → `company.id`          | Empresa envolvida                 |
| `cooperative_id` | `UUID`      | `NOT NULL`, FK → `cooperative.id`      | Cooperativa envolvida             |
| `collection_id`  | `UUID`      | `NOT NULL`, FK → `collection.id`       | Coleta em negociação            |
| `created_at`     | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Momento de abertura               |

---

### 14. `message`

Mensagens enviadas pelos participantes dentro de uma conversa.

| Campo               | Tipo          | Restrições                                | Descrição               |
| :------------------ | :------------ | :------------------------------------------ | :------------------------ |
| `id`              | `UUID`      | PK, `DEFAULT gen_random_uuid()`           | Identificador da mensagem |
| `conversation_id` | `UUID`      | `NOT NULL`, FK → `conversation.id`     | Conversa de origem        |
| `user_id`         | `UUID`      | `NOT NULL`, FK → `users.id`            | Remetente                 |
| `text`            | `TEXT`      | `NOT NULL`                                | Conteúdo enviado         |
| `reported`        | `BOOLEAN`   | `NOT NULL`, `DEFAULT FALSE`             | Moderação / Denúncia   |
| `sent_at`         | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Horário de envio         |

---

### 15. `message_attachment`

Arquivos e mídias compartilhados via chat.

| Campo          | Tipo             | Restrições                       | Descrição            |
| :------------- | :--------------- | :--------------------------------- | :--------------------- |
| `id`         | `UUID`         | PK, `DEFAULT gen_random_uuid()`  | Identificador do anexo |
| `message_id` | `UUID`         | `NOT NULL`, FK → `message.id` | Mensagem vinculada     |
| `file_url`   | `VARCHAR(500)` | `NOT NULL`                       | Caminho do arquivo     |
| `file_type`  | `VARCHAR(100)` | `NOT NULL`                       | Tipo do arquivo        |

---

### 16. `notification`

Alertas e mensagens do sistema direcionadas aos operadores.

| Campo          | Tipo             | Restrições                                | Descrição                    |
| :------------- | :--------------- | :------------------------------------------ | :----------------------------- |
| `id`         | `UUID`         | PK, `DEFAULT gen_random_uuid()`           | Identificador da notificação |
| `user_id`    | `UUID`         | `NOT NULL`, FK → `users.id`            | Destinatário                  |
| `type`       | `VARCHAR(50)`  | `NOT NULL`                                | Classificação do alerta      |
| `title`      | `VARCHAR(150)` | `NOT NULL`                                | Título do aviso               |
| `message`    | `TEXT`         | `NOT NULL`                                | Corpo da notificação         |
| `read`       | `BOOLEAN`      | `NOT NULL`, `DEFAULT FALSE`             | Status de leitura              |
| `created_at` | `TIMESTAMP`    | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Registro do disparo            |

---

### 17. `esg_metric`

Métricas de sustentabilidade e metas ecológicas de cada empresa geradora.

| Campo                    | Tipo              | Restrições                                | Descrição                      |
| :----------------------- | :---------------- | :------------------------------------------ | :------------------------------- |
| `id`                   | `UUID`          | PK, `DEFAULT gen_random_uuid()`           | Identificador da medição       |
| `company_id`           | `UUID`          | `NOT NULL`, FK → `company.id`          | Empresa analisada                |
| `period`               | `VARCHAR(20)`   | `NOT NULL`                                | Período de apuração           |
| `total_waste_kg`       | `DECIMAL(14,2)` | `DEFAULT 0`, `CHECK (>= 0)`             | Total de resíduo gerado (kg)    |
| `total_recycled_kg`    | `DECIMAL(14,2)` | `DEFAULT 0`, `CHECK (<= total)`         | Total reciclado (kg)             |
| `recycling_percentage` | `DECIMAL(5,2)`  | `DEFAULT 0`, `CHECK (0 a 100)`          | Taxa de conversão reciclada (%) |
| `calculated_at`        | `TIMESTAMP`     | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Data do cálculo analítico      |
| `weekly_target`        | `NUMERIC(12,2)` | Opcional                                    | Meta semanal estipulada          |
| `weekly_date`          | `DATE`          | Opcional                                    | Data de apuração semanal       |
| `monthly_target`       | `NUMERIC(12,2)` | Opcional                                    | Meta mensal                      |
| `monthly_date`         | `DATE`          | Opcional                                    | Data de apuração mensal        |
| `quarterly_target`     | `NUMERIC(12,2)` | Opcional                                    | Meta trimestral consolidada      |
| `quarterly_date`       | `DATE`          | Opcional                                    | Data de apuração trimestral    |

---

### 18. `cooperative_waste_type`

Tabela associativa que implementa a relação Muitos-para-Muitos (N:N) entre cooperativas e tipos de materiais aceitos.

| Campo              | Tipo     | Restrições                           | Descrição             |
| :----------------- | :------- | :------------------------------------- | :---------------------- |
| `cooperative_id` | `UUID` | `NOT NULL`, FK → `cooperative.id` | Cooperativa credenciada |
| `waste_type_id`  | `UUID` | `NOT NULL`, FK → `waste_type.id`  | Material aceito         |

*PK Composta:* `(cooperative_id, waste_type_id)`.

---

### 19. `incident_waste_type`

Tabela associativa que implementa a relação Muitos-para-Muitos (N:N) entre ocorrências e categorias de resíduos identificados.

| Campo             | Tipo     | Restrições                                                | Descrição           |
| :---------------- | :------- | :---------------------------------------------------------- | :-------------------- |
| `incident_id`   | `UUID` | `NOT NULL`, FK → `incident.id` (`ON DELETE CASCADE`) | Chamado associado     |
| `waste_type_id` | `UUID` | `NOT NULL`, FK → `waste_type.id`                       | Resíduo identificado |

*PK Composta:* `(incident_id, waste_type_id)`.

---

## Matriz Resumida de Relacionamentos

| Origem                     | Chave Estrangeira                     | Destino                               | Cardinalidade  |
| :------------------------- | :------------------------------------ | :------------------------------------ | :------------- |
| `users`                  | `company_id`                        | `company.id`                        | N:1 (Opcional) |
| `users`                  | `cooperative_id`                    | `cooperative.id`                    | N:1 (Opcional) |
| `users`                  | `role_id`                           | `role.id`                           | N:1            |
| `area`                   | `company_id`                        | `company.id`                        | N:1            |
| `incident`               | `company_id`                        | `company.id`                        | N:1            |
| `incident`               | `user_id`                           | `users.id`                          | N:1            |
| `incident`               | `area_id`                           | `area.id`                           | N:1            |
| `incident`               | `reviewed_by`                       | `users.id`                          | N:1 (Opcional) |
| `ai_report`              | `incident_id`                       | `incident.id`                       | 1:1            |
| `attachment`             | `incident_id`                       | `incident.id`                       | N:1            |
| `collection`             | `incident_id`                       | `incident.id`                       | N:1            |
| `collection`             | `cooperative_id`                    | `cooperative.id`                    | N:1            |
| `collection_status`      | `collection_id`                     | `collection.id`                     | N:1            |
| `review`                 | `cooperative_id`                    | `cooperative.id`                    | N:1            |
| `review`                 | `user_id`                           | `users.id`                          | N:1            |
| `review`                 | `collection_id`                     | `collection.id`                     | N:1            |
| `conversation`           | `company_id`                        | `company.id`                        | N:1            |
| `conversation`           | `cooperative_id`                    | `cooperative.id`                    | N:1            |
| `conversation`           | `collection_id`                     | `collection.id`                     | N:1            |
| `message`                | `conversation_id`                   | `conversation.id`                   | N:1            |
| `message`                | `user_id`                           | `users.id`                          | N:1            |
| `message_attachment`     | `message_id`                        | `message.id`                        | N:1            |
| `notification`           | `user_id`                           | `users.id`                          | N:1            |
| `esg_metric`             | `company_id`                        | `company.id`                        | N:1            |
| `cooperative_waste_type` | `cooperative_id`, `waste_type_id` | `cooperative.id`, `waste_type.id` | N:N            |
| `incident_waste_type`    | `incident_id`, `waste_type_id`    | `incident.id`, `waste_type.id`    | N:N            |
