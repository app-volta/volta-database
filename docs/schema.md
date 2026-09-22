# Esquema do banco de dados — VOLTA

## Visão geral

O banco relacional do projeto **VOLTA** foi definido para PostgreSQL e organiza dados de empresas, usuários, áreas, ocorrências de resíduos, análises de IA, cooperativas, coletas, avaliações, conversas, notificações e indicadores ESG.

O esquema contém **17 tabelas**. Os relacionamentos são implementados por chaves estrangeiras e as principais regras de domínio presentes no próprio `schema.sql` são aplicadas por `NOT NULL`, `UNIQUE`, valores padrão e restrições `CHECK`.

> Esta documentação descreve somente o que está declarado no `schema.sql`. Campos textuais como `status`, `priority`, `type`, níveis e categorias não possuem enumeração ou `CHECK` de valores no esquema atual.

## PostgreSQL, `pgcrypto` e UUID

O script habilita a extensão:

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

Todas as tabelas usam uma coluna `id` do tipo `UUID` como chave primária, com geração automática por `gen_random_uuid()`. A função é disponibilizada pela extensão `pgcrypto` e evita a dependência de identificadores inteiros sequenciais.

Padrão aplicado às 17 tabelas:

```sql
id UUID PRIMARY KEY DEFAULT gen_random_uuid()
```

## Tabelas

### 1. `company`

Representa as empresas atendidas pela plataforma.

| Campo       | Tipo             | Regras                           | Descrição                                                                             |
| ----------- | ---------------- | -------------------------------- | --------------------------------------------------------------------------------------- |
| `id`      | `UUID`         | PK, padrão`gen_random_uuid()` | Identificador da empresa.                                                               |
| `name`    | `VARCHAR(150)` | `NOT NULL`                     | Nome da empresa.                                                                        |
| `cnpj`    | `VARCHAR(18)`  | `NOT NULL`, `UNIQUE`         | CNPJ da empresa. Criado inicialmente como`VARCHAR(14)` e ampliado ao final do script. |
| `address` | `VARCHAR(255)` | `NOT NULL`                     | Endereço da empresa.                                                                   |

Não possui chaves estrangeiras. É referenciada por `users`, `area`, `incident`, `conversation` e `esg_metric`.

### 2. `role`

Armazena os papéis associados aos usuários.

| Campo    | Tipo            | Regras                           | Descrição             |
| -------- | --------------- | -------------------------------- | ----------------------- |
| `id`   | `UUID`        | PK, padrão`gen_random_uuid()` | Identificador do papel. |
| `type` | `VARCHAR(50)` | `NOT NULL`, `UNIQUE`         | Nome ou tipo do papel.  |

O esquema garante que não existam dois papéis com o mesmo valor em `type`. A tabela é referenciada por `users`.

### 3. `users`

Armazena os usuários do sistema e os vincula a uma empresa e a um papel.

| Campo             | Tipo             | Regras                             | Descrição                          |
| ----------------- | ---------------- | ---------------------------------- | ------------------------------------ |
| `id`            | `UUID`         | PK, padrão`gen_random_uuid()`   | Identificador do usuário.           |
| `company_id`    | `UUID`         | `NOT NULL`, FK → `company.id` | Empresa à qual o usuário pertence. |
| `role_id`       | `UUID`         | `NOT NULL`, FK → `role.id`    | Papel associado ao usuário.         |
| `name`          | `VARCHAR(150)` | `NOT NULL`                       | Nome do usuário.                    |
| `email`         | `VARCHAR(150)` | `NOT NULL`, `UNIQUE`           | E-mail de acesso.                    |
| `password_hash` | `VARCHAR(255)` | `NOT NULL`                       | Hash da senha.                       |
| `position`      | `VARCHAR(100)` | Opcional                           | Cargo ou posição.                  |

Constraints nomeadas: `fk_users_company` e `fk_users_role`. A tabela é referenciada por `incident`, `review`, `message` e `notification`.

### 4. `area`

Representa setores ou áreas de uma empresa nos quais uma ocorrência pode ser registrada.

| Campo                    | Tipo             | Regras                             | Descrição                      |
| ------------------------ | ---------------- | ---------------------------------- | -------------------------------- |
| `id`                   | `UUID`         | PK, padrão`gen_random_uuid()`   | Identificador da área.          |
| `company_id`           | `UUID`         | `NOT NULL`, FK → `company.id` | Empresa responsável pela área. |
| `sector_name`          | `VARCHAR(100)` | `NOT NULL`                       | Nome do setor.                   |
| `location_description` | `VARCHAR(255)` | Opcional                           | Descrição da localização.    |

Constraint nomeada: `fk_area_company`. A tabela é referenciada por `incident`.

### 5. `waste_type`

Mantém o catálogo de tipos de resíduos utilizado nas ocorrências.

| Campo                  | Tipo             | Regras                           | Descrição                        |
| ---------------------- | ---------------- | -------------------------------- | ---------------------------------- |
| `id`                 | `UUID`         | PK, padrão`gen_random_uuid()` | Identificador do tipo de resíduo. |
| `category`           | `VARCHAR(100)` | `NOT NULL`                     | Categoria do resíduo.             |
| `description`        | `VARCHAR(255)` | Opcional                         | Descrição complementar.          |
| `default_risk_level` | `VARCHAR(50)`  | `NOT NULL`                     | Nível de risco padrão.           |

Não há restrição `UNIQUE` para `category`, nem lista fechada para `default_risk_level`. A tabela é referenciada por `incident`.

### 6. `incident`

Registra uma ocorrência de resíduo em determinada empresa e área, informada por um usuário.

| Campo                    | Tipo              | Regras                                      | Descrição                                   |
| ------------------------ | ----------------- | ------------------------------------------- | --------------------------------------------- |
| `id`                   | `UUID`          | PK, padrão`gen_random_uuid()`            | Identificador da ocorrência.                 |
| `company_id`           | `UUID`          | `NOT NULL`, FK → `company.id`          | Empresa relacionada.                          |
| `user_id`              | `UUID`          | `NOT NULL`, FK → `users.id`            | Usuário que registrou a ocorrência.         |
| `area_id`              | `UUID`          | `NOT NULL`, FK → `area.id`             | Área onde ocorreu o registro.                |
| `waste_type_id`        | `UUID`          | Opcional, FK →`waste_type.id`            | Tipo de resíduo associado, quando conhecido. |
| `photo_url`            | `VARCHAR(500)`  | Opcional                                    | URL de uma foto.                              |
| `employee_description` | `TEXT`          | `NOT NULL`                                | Descrição fornecida pelo funcionário.      |
| `contamination_level`  | `VARCHAR(50)`   | Opcional                                    | Nível de contaminação.                     |
| `estimated_quantity`   | `DECIMAL(12,2)` | Opcional,`CHECK`                          | Quantidade estimada.                          |
| `priority`             | `VARCHAR(30)`   | `NOT NULL`                                | Prioridade da ocorrência.                    |
| `status`               | `VARCHAR(50)`   | `NOT NULL`                                | Estado atual da ocorrência.                  |
| `registered_at`        | `TIMESTAMP`     | `NOT NULL`, padrão `CURRENT_TIMESTAMP` | Data e hora do registro.                      |

Chaves estrangeiras: `fk_incident_company`, `fk_incident_user`, `fk_incident_area` e `fk_incident_waste_type`.

A constraint `chk_incident_quantity` permite `estimated_quantity` nulo ou maior/igual a zero; valores negativos são rejeitados. A tabela é referenciada por `ai_report`, `attachment` e `collection`.

### 7. `ai_report`

Armazena o resultado de uma análise de inteligência artificial ligada a uma ocorrência.

| Campo                      | Tipo             | Regras                                      | Descrição                                |
| -------------------------- | ---------------- | ------------------------------------------- | ------------------------------------------ |
| `id`                     | `UUID`         | PK, padrão`gen_random_uuid()`            | Identificador do relatório.               |
| `incident_id`            | `UUID`         | `NOT NULL`, FK → `incident.id`         | Ocorrência analisada.                     |
| `detected_waste_type`    | `VARCHAR(100)` | Opcional                                    | Tipo de resíduo detectado pela IA.        |
| `ai_contamination_level` | `VARCHAR(50)`  | Opcional                                    | Nível de contaminação estimado pela IA. |
| `recommendations`        | `TEXT`         | Opcional                                    | Recomendações geradas.                   |
| `report_text`            | `TEXT`         | Opcional                                    | Conteúdo textual do relatório.           |
| `generated_at`           | `TIMESTAMP`    | `NOT NULL`, padrão `CURRENT_TIMESTAMP` | Data e hora da geração.                  |

Constraint nomeada: `fk_ai_report_incident`. Como `incident_id` não é `UNIQUE`, o esquema não limita uma ocorrência a um único relatório.

### 8. `attachment`

Registra arquivos anexados a uma ocorrência.

| Campo           | Tipo             | Regras                              | Descrição              |
| --------------- | ---------------- | ----------------------------------- | ------------------------ |
| `id`          | `UUID`         | PK, padrão`gen_random_uuid()`    | Identificador do anexo.  |
| `incident_id` | `UUID`         | `NOT NULL`, FK → `incident.id` | Ocorrência relacionada. |
| `file_url`    | `VARCHAR(500)` | `NOT NULL`                        | URL do arquivo.          |
| `file_type`   | `VARCHAR(100)` | `NOT NULL`                        | Tipo do arquivo.         |

Constraint nomeada: `fk_attachment_incident`. Uma ocorrência pode ser referenciada por vários anexos.

### 9. `cooperative`

Armazena as cooperativas aptas a participar das coletas.

| Campo              | Tipo             | Regras                           | Descrição                                                                  |
| ------------------ | ---------------- | -------------------------------- | ---------------------------------------------------------------------------- |
| `id`             | `UUID`         | PK, padrão`gen_random_uuid()` | Identificador da cooperativa.                                                |
| `name`           | `VARCHAR(150)` | `NOT NULL`                     | Nome da cooperativa.                                                         |
| `cnpj`           | `VARCHAR(18)`  | `NOT NULL`, `UNIQUE`         | CNPJ. Criado inicialmente como`VARCHAR(14)` e ampliado ao final do script. |
| `latitude`       | `DECIMAL(9,6)` | `NOT NULL`, `CHECK`          | Latitude geográfica.                                                        |
| `longitude`      | `DECIMAL(9,6)` | `NOT NULL`, `CHECK`          | Longitude geográfica.                                                       |
| `average_rating` | `DECIMAL(3,2)` | Padrão`0`, `CHECK`          | Avaliação média. O campo não foi declarado`NOT NULL`.                  |
| `specialties`    | `VARCHAR(500)` | Opcional                         | Especialidades da cooperativa.                                               |

Regras de domínio:

- `chk_cooperative_latitude`: latitude entre `-90` e `90`;
- `chk_cooperative_longitude`: longitude entre `-180` e `180`;
- `chk_cooperative_rating`: avaliação média entre `0` e `5`.

A tabela é referenciada por `collection`, `review` e `conversation`.

### 10. `collection`

Representa a solicitação e o agendamento de uma coleta para uma ocorrência, executada por uma cooperativa.

| Campo               | Tipo            | Regras                                      | Descrição                        |
| ------------------- | --------------- | ------------------------------------------- | ---------------------------------- |
| `id`              | `UUID`        | PK, padrão`gen_random_uuid()`            | Identificador da coleta.           |
| `incident_id`     | `UUID`        | `NOT NULL`, FK → `incident.id`         | Ocorrência que originou a coleta. |
| `cooperative_id`  | `UUID`        | `NOT NULL`, FK → `cooperative.id`      | Cooperativa responsável.          |
| `requested_at`    | `TIMESTAMP`   | `NOT NULL`, padrão `CURRENT_TIMESTAMP` | Momento da solicitação.          |
| `scheduled_at`    | `TIMESTAMP`   | Opcional,`CHECK`                          | Momento agendado.                  |
| `current_status`  | `VARCHAR(50)` | `NOT NULL`                                | Status atual.                      |
| `collection_type` | `VARCHAR(50)` | `NOT NULL`                                | Tipo da coleta.                    |
| `urgent`          | `BOOLEAN`     | `NOT NULL`, padrão `FALSE`             | Indica urgência.                  |

Constraints nomeadas: `fk_collection_incident`, `fk_collection_cooperative` e `chk_collection_dates`. A data agendada pode ser nula; quando informada, deve ser maior ou igual a `requested_at`.

A tabela é referenciada por `collection_status`, `review` e `conversation`.

### 11. `collection_status`

Registra o histórico de mudanças de status de uma coleta.

| Campo             | Tipo            | Regras                                      | Descrição                        |
| ----------------- | --------------- | ------------------------------------------- | ---------------------------------- |
| `id`            | `UUID`        | PK, padrão`gen_random_uuid()`            | Identificador do evento de status. |
| `collection_id` | `UUID`        | `NOT NULL`, FK → `collection.id`       | Coleta relacionada.                |
| `status`        | `VARCHAR(50)` | `NOT NULL`                                | Status registrado no evento.       |
| `changed_at`    | `TIMESTAMP`   | `NOT NULL`, padrão `CURRENT_TIMESTAMP` | Data e hora da mudança.           |
| `observation`   | `TEXT`        | Opcional                                    | Observação sobre a mudança.     |

Constraint nomeada: `fk_collection_status_collection`. O esquema permite vários eventos para a mesma coleta. Não há constraint que sincronize `collection.current_status` com o registro mais recente desta tabela.

### 12. `review`

Armazena a avaliação feita por um usuário sobre uma cooperativa, vinculada a uma coleta.

| Campo              | Tipo          | Regras                                      | Descrição                   |
| ------------------ | ------------- | ------------------------------------------- | ----------------------------- |
| `id`             | `UUID`      | PK, padrão`gen_random_uuid()`            | Identificador da avaliação. |
| `cooperative_id` | `UUID`      | `NOT NULL`, FK → `cooperative.id`      | Cooperativa avaliada.         |
| `user_id`        | `UUID`      | `NOT NULL`, FK → `users.id`            | Usuário avaliador.           |
| `collection_id`  | `UUID`      | `NOT NULL`, FK → `collection.id`       | Coleta relacionada.           |
| `stars`          | `INTEGER`   | `NOT NULL`, `CHECK`                     | Nota atribuída.              |
| `comment`        | `TEXT`      | Opcional                                    | Comentário da avaliação.   |
| `reviewed_at`    | `TIMESTAMP` | `NOT NULL`, padrão `CURRENT_TIMESTAMP` | Data e hora da avaliação.   |

Constraints nomeadas: `fk_review_cooperative`, `fk_review_user`, `fk_review_collection` e `chk_review_stars`. A nota deve estar entre `1` e `5`. Não há restrição `UNIQUE` que limite avaliações por usuário ou coleta.

### 13. `conversation`

Representa uma conversa entre o contexto de uma empresa e uma cooperativa, associada a uma coleta.

| Campo              | Tipo          | Regras                                      | Descrição                |
| ------------------ | ------------- | ------------------------------------------- | -------------------------- |
| `id`             | `UUID`      | PK, padrão`gen_random_uuid()`            | Identificador da conversa. |
| `company_id`     | `UUID`      | `NOT NULL`, FK → `company.id`          | Empresa relacionada.       |
| `cooperative_id` | `UUID`      | `NOT NULL`, FK → `cooperative.id`      | Cooperativa relacionada.   |
| `collection_id`  | `UUID`      | `NOT NULL`, FK → `collection.id`       | Coleta relacionada.        |
| `created_at`     | `TIMESTAMP` | `NOT NULL`, padrão `CURRENT_TIMESTAMP` | Data e hora de criação.  |

Constraints nomeadas: `fk_conversation_company`, `fk_conversation_cooperative` e `fk_conversation_collection`. `collection_id` não é `UNIQUE`; portanto, o esquema permite mais de uma conversa ligada à mesma coleta.

### 14. `message`

Armazena as mensagens enviadas dentro de uma conversa.

| Campo               | Tipo          | Regras                                      | Descrição                           |
| ------------------- | ------------- | ------------------------------------------- | ------------------------------------- |
| `id`              | `UUID`      | PK, padrão`gen_random_uuid()`            | Identificador da mensagem.            |
| `conversation_id` | `UUID`      | `NOT NULL`, FK → `conversation.id`     | Conversa à qual a mensagem pertence. |
| `user_id`         | `UUID`      | `NOT NULL`, FK → `users.id`            | Usuário remetente.                   |
| `text`            | `TEXT`      | `NOT NULL`                                | Conteúdo textual.                    |
| `reported`        | `BOOLEAN`   | `NOT NULL`, padrão `FALSE`             | Indica se a mensagem foi reportada.   |
| `sent_at`         | `TIMESTAMP` | `NOT NULL`, padrão `CURRENT_TIMESTAMP` | Data e hora do envio.                 |

Constraints nomeadas: `fk_message_conversation` e `fk_message_user`. A tabela é referenciada por `message_attachment`.

### 15. `message_attachment`

Registra arquivos associados a mensagens.

| Campo          | Tipo             | Regras                             | Descrição             |
| -------------- | ---------------- | ---------------------------------- | ----------------------- |
| `id`         | `UUID`         | PK, padrão`gen_random_uuid()`   | Identificador do anexo. |
| `message_id` | `UUID`         | `NOT NULL`, FK → `message.id` | Mensagem relacionada.   |
| `file_url`   | `VARCHAR(500)` | `NOT NULL`                       | URL do arquivo.         |
| `file_type`  | `VARCHAR(100)` | `NOT NULL`                       | Tipo do arquivo.        |

Constraint nomeada: `fk_message_attachment_message`. Uma mensagem pode ser referenciada por vários anexos.

### 16. `notification`

Armazena notificações destinadas aos usuários.

| Campo          | Tipo             | Regras                                      | Descrição                     |
| -------------- | ---------------- | ------------------------------------------- | ------------------------------- |
| `id`         | `UUID`         | PK, padrão`gen_random_uuid()`            | Identificador da notificação. |
| `user_id`    | `UUID`         | `NOT NULL`, FK → `users.id`            | Usuário destinatário.         |
| `type`       | `VARCHAR(50)`  | `NOT NULL`                                | Tipo da notificação.          |
| `title`      | `VARCHAR(150)` | `NOT NULL`                                | Título.                        |
| `message`    | `TEXT`         | `NOT NULL`                                | Conteúdo da notificação.     |
| `read`       | `BOOLEAN`      | `NOT NULL`, padrão `FALSE`             | Indica se foi lida.             |
| `created_at` | `TIMESTAMP`    | `NOT NULL`, padrão `CURRENT_TIMESTAMP` | Data e hora de criação.       |

Constraint nomeada: `fk_notification_user`. Os valores possíveis de `type` não são limitados por `CHECK`.

### 17. `esg_metric`

Armazena indicadores ESG de uma empresa por período.

| Campo                    | Tipo              | Regras                                      | Descrição                        |
| ------------------------ | ----------------- | ------------------------------------------- | ---------------------------------- |
| `id`                   | `UUID`          | PK, padrão`gen_random_uuid()`            | Identificador da métrica.         |
| `company_id`           | `UUID`          | `NOT NULL`, FK → `company.id`          | Empresa medida.                    |
| `period`               | `VARCHAR(20)`   | `NOT NULL`                                | Período de referência.           |
| `total_waste_kg`       | `DECIMAL(14,2)` | `NOT NULL`, padrão `0`, `CHECK`      | Total de resíduos em quilogramas. |
| `total_recycled_kg`    | `DECIMAL(14,2)` | `NOT NULL`, padrão `0`, `CHECK`      | Total reciclado em quilogramas.    |
| `recycling_percentage` | `DECIMAL(5,2)`  | `NOT NULL`, padrão `0`, `CHECK`      | Percentual de reciclagem.          |
| `calculated_at`        | `TIMESTAMP`     | `NOT NULL`, padrão `CURRENT_TIMESTAMP` | Data e hora do cálculo.           |

Constraint nomeada de FK: `fk_esg_metric_company`.

Regras de domínio:

- `chk_esg_total_waste`: `total_waste_kg >= 0`;
- `chk_esg_total_recycled`: `total_recycled_kg >= 0`;
- `chk_esg_percentage`: `recycling_percentage` entre `0` e `100`;
- `chk_esg_recycled_not_greater`: `total_recycled_kg <= total_waste_kg`.

O esquema não declara unicidade para o par empresa/período e não calcula automaticamente `recycling_percentage` a partir dos totais.

## Principais relacionamentos

Todas as FKs obrigatórias usam `NOT NULL`; a única FK opcional é `incident.waste_type_id`. Como o script não declara ações `ON DELETE` ou `ON UPDATE`, aplica-se o comportamento padrão do PostgreSQL.

| Origem                              | Destino             | Interpretação estrutural                                                  |
| ----------------------------------- | ------------------- | --------------------------------------------------------------------------- |
| `users.company_id`                | `company.id`      | Uma empresa pode ser referenciada por vários usuários.                    |
| `users.role_id`                   | `role.id`         | Um papel pode ser referenciado por vários usuários.                       |
| `area.company_id`                 | `company.id`      | Uma empresa pode possuir várias áreas.                                    |
| `incident.company_id`             | `company.id`      | Uma empresa pode possuir várias ocorrências.                              |
| `incident.user_id`                | `users.id`        | Um usuário pode registrar várias ocorrências.                            |
| `incident.area_id`                | `area.id`         | Uma área pode aparecer em várias ocorrências.                            |
| `incident.waste_type_id`          | `waste_type.id`   | Um tipo pode classificar várias ocorrências; a associação é opcional.  |
| `ai_report.incident_id`           | `incident.id`     | Uma ocorrência pode ter vários relatórios no esquema atual.              |
| `attachment.incident_id`          | `incident.id`     | Uma ocorrência pode ter vários anexos.                                    |
| `collection.incident_id`          | `incident.id`     | Uma ocorrência pode originar várias coletas no esquema atual.             |
| `collection.cooperative_id`       | `cooperative.id`  | Uma cooperativa pode executar várias coletas.                              |
| `collection_status.collection_id` | `collection.id`   | Uma coleta pode ter vários registros de histórico.                        |
| `review.cooperative_id`           | `cooperative.id`  | Uma cooperativa pode receber várias avaliações.                          |
| `review.user_id`                  | `users.id`        | Um usuário pode criar várias avaliações.                                |
| `review.collection_id`            | `collection.id`   | Uma coleta pode ser referenciada por várias avaliações no esquema atual. |
| `conversation.company_id`         | `company.id`      | Uma empresa pode participar de várias conversas.                           |
| `conversation.cooperative_id`     | `cooperative.id`  | Uma cooperativa pode participar de várias conversas.                       |
| `conversation.collection_id`      | `collection.id`   | Uma coleta pode ser associada a várias conversas no esquema atual.         |
| `message.conversation_id`         | `conversation.id` | Uma conversa pode conter várias mensagens.                                 |
| `message.user_id`                 | `users.id`        | Um usuário pode enviar várias mensagens.                                  |
| `message_attachment.message_id`   | `message.id`      | Uma mensagem pode possuir vários anexos.                                   |
| `notification.user_id`            | `users.id`        | Um usuário pode receber várias notificações.                            |
| `esg_metric.company_id`           | `company.id`      | Uma empresa pode possuir várias métricas ESG.                             |

## Fluxo textual dos relacionamentos

```text
role ────────────────┐
                     ▼
company ──────────► users ───────────────► notification
   │                 │
   │                 ├───────────────────► message ───► message_attachment
   │                 │                         ▲
   │                 ├──────────────┐          │
   │                 ▼              │          │
   ├──────────────► incident ◄──── area        │
   │                 ▲  │                      │
   │                 │  ├────► ai_report       │
   │       waste_type┘  ├────► attachment      │
   │                    ▼                      │
   │                 collection ───────────────┤
   │                    │  │                   │
   │                    │  ├────► collection_status
   │                    │  ├────► review ◄──── users
   │                    │  │         ▲
   │                    │  │         │
   │                    └──┼──► conversation ──┘
   │                       │         ▲
   │                       ▼         │
   │                  cooperative ───┘
   │
   └──────────────────────────────► esg_metric
```

Fluxo operacional principal:

```text
company
  └─ users + area
       └─ incident ──► ai_report / attachment
            └─ collection ──► collection_status
                  ├─ review
                  └─ conversation ──► message ──► message_attachment
```

## Regras de integridade

### Obrigatoriedade (`NOT NULL`)

São obrigatórios os identificadores relacionais centrais e os dados essenciais de cada entidade. Entre os campos opcionais estão `users.position`, `area.location_description`, `incident.waste_type_id`, `incident.photo_url`, `incident.contamination_level`, `incident.estimated_quantity`, os conteúdos opcionais de `ai_report`, `cooperative.specialties`, `collection.scheduled_at`, `collection_status.observation` e `review.comment`.

Embora `cooperative.average_rating` tenha valor padrão `0`, ele não possui `NOT NULL` no script.

### Unicidade (`UNIQUE`)

O esquema declara unicidade apenas para:

- `company.cnpj`;
- `cooperative.cnpj`;
- `role.type`;
- `users.email`.

Não há outras constraints `UNIQUE` compostas ou individuais.

### Quantidades e métricas

- `incident.estimated_quantity` aceita `NULL` ou valor maior/igual a zero.
- `esg_metric.total_waste_kg` e `total_recycled_kg` não podem ser negativos.
- O total reciclado não pode superar o total de resíduos.
- `esg_metric.recycling_percentage` deve estar entre `0` e `100`.

### Coordenadas e avaliações

- A latitude da cooperativa deve estar entre `-90` e `90`.
- A longitude deve estar entre `-180` e `180`.
- `cooperative.average_rating` deve estar entre `0` e `5` quando houver valor.
- `review.stars` é obrigatório e deve estar entre `1` e `5`.

### Datas de coleta

`collection.scheduled_at` pode ficar sem valor. Quando preenchido, não pode ser anterior a `collection.requested_at`.

O esquema não impõe ordenação entre registros de `collection_status.changed_at`, nem sincronização automática entre o histórico e `collection.current_status`.

## Alteração final do CNPJ

As tabelas `company` e `cooperative` são criadas inicialmente com `cnpj VARCHAR(14)`. Ao final, o script executa:

```sql
ALTER TABLE company
ALTER COLUMN cnpj TYPE VARCHAR(18);

ALTER TABLE cooperative
ALTER COLUMN cnpj TYPE VARCHAR(18);
```

Assim, o tipo efetivo após a execução completa do arquivo é `VARCHAR(18)` nas duas tabelas. A ampliação permite armazenar até 18 caracteres, comportando também uma representação formatada do CNPJ. As constraints `NOT NULL` e `UNIQUE` já existentes permanecem aplicadas; o script não adiciona validação de máscara, quantidade exata de dígitos ou cálculo dos dígitos verificadores.

## Decisões de modelagem observáveis no esquema

- **UUID em todas as entidades:** padroniza as chaves primárias e permite geração automática com `gen_random_uuid()`.
- **Separação entre dados cadastrais e operacionais:** empresas, papéis, usuários, áreas, tipos de resíduos e cooperativas ficam separados das ocorrências, coletas e mensagens.
- **Histórico de coleta separado:** `collection` mantém `current_status`, enquanto `collection_status` registra eventos ao longo do tempo. A consistência entre ambos não é automatizada pelo esquema atual.
- **Anexos como registros próprios:** anexos de ocorrência e de mensagem ficam em tabelas separadas, permitindo múltiplos arquivos sem colunas repetidas.
- **Resultado de IA desacoplado da ocorrência:** `ai_report` registra a análise sem incorporar seus campos diretamente em `incident`.
- **Avaliações ligadas ao contexto da coleta:** `review` referencia simultaneamente cooperativa, usuário e coleta.
- **Conversas contextualizadas:** `conversation` relaciona empresa, cooperativa e coleta; `message` e `message_attachment` formam a hierarquia de conteúdo da conversa.
- **Indicadores ESG históricos:** `esg_metric` referencia a empresa e possui um campo de período, permitindo vários registros ao longo do tempo, sem impor unicidade empresa/período.
- **Integridade declarativa focalizada:** quantidades, coordenadas, notas, datas e métricas possuem `CHECK`; campos textuais de estado e classificação permanecem abertos.
- **Sem cascatas explícitas:** nenhuma FK define `ON DELETE` ou `ON UPDATE`, portanto o banco usa as ações padrão do PostgreSQL.

## Resumo

O esquema do VOLTA centraliza a empresa como origem de usuários, áreas, ocorrências, conversas e métricas ESG. As ocorrências conectam o registro operacional aos relatórios de IA, anexos e coletas; as coletas conectam cooperativas, histórico de status, avaliações e conversas. As constraints declaradas protegem identificadores únicos, referências obrigatórias, valores numéricos válidos, coordenadas geográficas, avaliações, métricas ESG e coerência básica do agendamento.
