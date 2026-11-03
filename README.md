# VOLTA — Camada de Banco de Dados Relacional (PostgreSQL)

Repositório responsável pela modelagem, persistência, objetos programáveis, otimização, governança e migração da camada de dados do **VOLTA**, ecossistema integrado voltado à gestão de resíduos industriais, triagem assistida por IA, conexões com cooperativas e indicadores de sustentabilidade ESG.

O PostgreSQL é a fonte central de verdade transacional e analítica da plataforma, modelado rigorosamente até a **Terceira Forma Normal (3FN)** com chaves primárias em UUID (`pgcrypto`).

---

## Mapeamento de Entregáveis e Demandas Avaliadas

Para atender diretamente ao critério de avaliação acadêmica e facilitar a correção ponto a ponto pelos professores, a tabela abaixo consolida os links diretos para cada artefato de código e respectivo relatório de justificativa:

| Demanda / Requisito Avaliado                          | Link Direto do Artefato                                               | Relatório de Justificativa / Documentação                                 |
| :---------------------------------------------------- | :-------------------------------------------------------------------- | :--------------------------------------------------------------------------- |
| **Diagrama Entidade-Relacionamento (DER)**      | [`.drawbd/schema.png`](.drawbd/schema.png)                           | [`.drawbd/schema.dbml`](.drawbd/schema.dbml)                                |
| **Normalização (1FN, 2FN e 3FN)**             | [`scripts/01-schema.sql`](scripts/01-schema.sql)                     | [`docs/normalizacao_banco_volta.md`](docs/normalizacao_banco_volta.md)      |
| **Dicionário de Dados e Regras de Negócio**   | [`scripts/01-schema.sql`](scripts/01-schema.sql)                     | [`docs/schema.md`](docs/schema.md)                                          |
| **Massa de Dados (500+ Registros)**             | [`scripts/02-dataload.sql`](scripts/02-dataload.sql)                 | [Seção Dataload](#dataload-e-validação-quantitativa)                      |
| **Camada Analítica / Data Mart (BI)**          | [`scripts/03-bi_views.sql`](scripts/03-bi_views.sql)                 | [Seção Data Mart BI](#camada-analítica-e-bi)                               |
| **Consultas de Transformação (CTEs / ETL)**   | [`scripts/04-ctes.sql`](scripts/04-ctes.sql)                         | Comentários técnicos embutidos no script                                   |
| **Funções Analíticas (Window Functions)**    | [`scripts/05-window_functions.sql`](scripts/05-window_functions.sql) | Comentários técnicos embutidos no script                                   |
| **Funções de Domínio (Functions PL/pgSQL)**  | [`scripts/06-functions.sql`](scripts/06-functions.sql)               | [Seção Funções e Procedures](#objetos-programáveis-e-regras-de-negócio) |
| **Procedimentos com Transações (Procedures)** | [`scripts/07-procedures.sql`](scripts/07-procedures.sql)             | [Seção Funções e Procedures](#objetos-programáveis-e-regras-de-negócio) |
| **Triggers de Auditoria (Logs com NEW/OLD)**    | [`scripts/08-triggers.sql`](scripts/08-triggers.sql)                 | [Seção Triggers de Auditoria](#auditoria-e-segurança)                      |
| **Otimização (Indexes + EXPLAIN ANALYZE)**    | [`scripts/09-indexes_explain.sql`](scripts/09-indexes_explain.sql)   | Planos de custo antes/depois no script                                       |
| **Governança de Dados (Catálogo LGPD)**       | [`scripts/10-data_catalog.sql`](scripts/10-data_catalog.sql)         | [Seção Catálogo de Dados](#governança-e-catálogo-de-dados)               |
| **Monitoramento de Engajamento (DAU)**          | [`scripts/11-dau_monitoring.sql`](scripts/11-dau_monitoring.sql)     | Views e métricas diárias no script                                         |
| **Estruturas Avançadas (CTE Recursiva)**       | [`scripts/12-recursive_cte.sql`](scripts/12-recursive_cte.sql)       | Hierarquia de setores fabris no script                                       |
| **Segurança: Backup e Recuperação**          | [`backup/backup.sh`](backup/backup.sh)                               | [`docs/backup.md`](docs/backup.md)                                          |
| **Validação de Recuperação (Restore Test)** | [`backup/restore_test.sh`](backup/restore_test.sh)                   | [`docs/backup.md`](docs/backup.md)                                          |
| **Integração RPA (Migração Legado → 3FN)** | [`rpa/migration.py`](rpa/migration.py)                               | [`scripts/13-migration_control.sql`](scripts/13-migration_control.sql)      |

> **Nota de Acesso:** O repositório está com permissões liberadas para avaliação dos professores das disciplinas correlatas.

---

## Índice

* [Arquitetura de Dados](#arquitetura-de-dados)
* [Tecnologias Utilizadas](#tecnologias-utilizadas)
* [Modelo Relacional (3FN)](#modelo-relacional-3fn)
* [Estrutura do Repositório](#estrutura-do-repositório)
* [Configuração e Execução](#configuração-e-execução)
* [Ordem de Execução dos Scripts](#ordem-de-execução-dos-scripts)
* [Objetos Programáveis e Regras de Negócio](#objetos-programáveis-e-regras-de-negócio)
* [Processo de Migração Legado → 3FN (RPA)](#processo-de-migração-legado--3fn-rpa)
* [Dataload e Validação Quantitativa](#dataload-e-validação-quantitativa)
* [Auditoria e Segurança](#auditoria-e-segurança)
* [Governança e Catálogo de Dados](#governança-e-catálogo-de-dados)

---

## Arquitetura de Dados

| Camada / Tecnologia              | Responsabilidade no Projeto VOLTA                                                                   |
| :------------------------------- | :-------------------------------------------------------------------------------------------------- |
| **PostgreSQL 16+**         | Fonte relacional de verdade transacional (OLTP) e dimensional (Data Mart BI).                       |
| **`pgcrypto`**           | Geração descentralizada de UUIDs (`gen_random_uuid()`) e funções criptográficas.             |
| **Python 3 (`psycopg`)** | Motor de ETL e reconciliação idempotente da migração do banco legado para o modelo 3FN.         |
| **Power Automate Desktop** | Orquestração RPA para acionamento do pipeline de migração e captura de códigos de saída.      |
| **Bash / Shell Script**    | Rotinas padronizadas de backup físico/lógico (`pg_dump -F c`) e teste de restauração isolada. |

---

## Modelo Relacional (3FN)

O banco de dados do VOLTA é composto por **19 tabelas relacionais**, normalizadas para eliminar redundâncias e garantir integridade referencial:

| Domínio de Negócio               | Tabelas                                                                                 | Descrição                                                                                                  |
| :--------------------------------- | :-------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------- |
| **Organização e Acesso**   | `company`, `role`, `cooperative`, `users`, `area`                             | Cadastro de empresas clientes, cooperativas parceiras, controle RBAC e plantas industriais.                  |
| **Resíduos e Triagem (IA)** | `waste_type`, `incident`, `incident_waste_type`, `ai_report`, `attachment`    | Catálogo de materiais, ocorrências de campo, ligação N:N de resíduos, laudos de IA e fotos.             |
| **Operação de Coleta**     | `cooperative_waste_type`, `collection`, `collection_status`, `review`           | Associação N:N de materiais aceitos por cooperativas, despachos, histórico de status e avaliações.      |
| **Comunicação e ESG**      | `conversation`, `message`, `message_attachment`, `notification`, `esg_metric` | Chat integrado empresa-cooperativa, avisos do sistema e métricas de sustentabilidade com metas periódicas. |

Além das tabelas de domínio, o banco gerencia 4 tabelas de controle técnico e governança:

* `data_catalog`: Catálogo de metadados, regras de negócio e classificação de privacidade (LGPD).
* `audit_log`: Trilha de auditoria orientada a eventos via Triggers (`NEW`, `OLD`, `TG_OP`, `CURRENT_USER`).
* `user_daily_access`: Registro atômico para monitoramento de usuários ativos diários (DAU).
* `migration_run`, `migration_id_map`, `migration_relation_map`, `migration_error`: Rastreabilidade e de-para da migração RPA.

---

## Estrutura do Repositório

```text
volta-database/
├── .drawbd/
│   ├── schema.dbml                 # Definição do schema em formato DBML
│   └── schema.png                  # Diagrama Entidade-Relacionamento visual completo
│
├── backup/
│   ├── backup.sh                   # Script Bash automatizado para pg_dump custom format
│   ├── restore_test.sh             # Script Bash para validação periódica de restore
│   └── dumps/                      # Diretório local para armazenamento de cópias .dump
│
├── docs/
│   ├── backup.md                   # Política e manual de procedimentos de recuperação de falhas
│   ├── normalizacao_banco_volta.md # Memorial analítico das Formas Normais (1FN, 2FN, 3FN)
│   └── schema.md                   # Dicionário de dados exaustivo das 19 tabelas
│
├── legacy/
│   ├── 01-legacy_schema.sql        # Schema do banco de dados legado (IDs inteiros)
│   └── 02-legacy_dataload.sql      # Massa sintética legada para testes de migração
│
├── rpa/
│   ├── migration.py                # Script Python de migração transacional idempotente
│   └── requirements.txt            # Dependências do motor de migração
│
├── scripts/
│   ├── 01-schema.sql               # DDL das 19 tabelas e constraints de integridade
│   ├── 02-dataload.sql             # Carga de teste e sementes (600+ registros)
│   ├── 03-bi_views.sql             # Data Mart analítico (Star Schema: Fatos e Dimensões)
│   ├── 04-ctes.sql                 # Consultas de transformação (ETL SQL)
│   ├── 05-window_functions.sql     # Funções analíticas (Running Totals, Rankings, Deltas)
│   ├── 06-functions.sql            # Funções de negócio PL/pgSQL
│   ├── 07-procedures.sql           # Procedimentos armazenados com controle transacional
│   ├── 08-triggers.sql             # Triggers de auditoria e regras automáticas
│   ├── 09-indexes_explain.sql      # Estratégia de indexação e planos com EXPLAIN ANALYZE
│   ├── 10-data_catalog.sql         # Catálogo de dados e metadados de governança
│   ├── 11-dau_monitoring.sql       # Monitoramento de engajamento (DAU) no PostgreSQL
│   ├── 12-recursive_cte.sql        # CTE Recursiva para hierarquia de setores fabris
│   └── 13-migration_control.sql    # DDL das tabelas de controle de migração do RPA
│
├── .gitignore
└── README.md
```

---

## Configuração e Execução

### 1. Pré-requisitos

* PostgreSQL 16+ instalado e em execução;
* Python 3.10+ (para execução da reconciliação de dados);
* Utilitários de linha de comando: `psql`, `pg_dump`, `pg_restore`.

### 2. Variáveis de Ambiente

Crie um arquivo `.env` na raiz do projeto (ou no diretório `rpa/`) configurando as strings de conexão:

```env
# Banco de Produção / Desenvolvimento Principal
DATABASE_URL=postgresql://usuario:senha@localhost:5432/volta

# Conexões para execução do teste de migração RPA
LEGACY_URL=postgresql://usuario:senha@localhost:5432/volta_legacy
VOLTA_RPA_TEST_URL=postgresql://usuario:senha@localhost:5432/volta_rpa_test
```

---

## Ordem de Execução dos Scripts

Para provisionar o ambiente completo com todos os recursos, execute os scripts na sequência:

```bash
# 1. Estrutura relacional e controle
psql -d volta -f scripts/01-schema.sql
psql -d volta -f scripts/13-migration_control.sql

# 2. Carga sintética (600+ registros verossímeis)
psql -d volta -f scripts/02-dataload.sql

# 3. Camada analítica, cálculos e automações
psql -d volta -f scripts/03-bi_views.sql
psql -d volta -f scripts/06-functions.sql
psql -d volta -f scripts/07-procedures.sql
psql -d volta -f scripts/08-triggers.sql
psql -d volta -f scripts/09-indexes_explain.sql

# 4. Governança e monitoramento
psql -d volta -f scripts/10-data_catalog.sql
psql -d volta -f scripts/11-dau_monitoring.sql
psql -d volta -f scripts/12-recursive_cte.sql
```

---

## Objetos Programáveis e Regras de Negócio

### Funções PL/pgSQL

* `calculate_recycling_percentage(p_total_waste, p_total_recycled)`: Cálculo determinístico com tratamento de nulos e proteção contra divisão por zero.
* `calculate_collection_completion_hours(p_collection_id)`: Medição da duração real da coleta em horas entre os estados `REQUESTED` e `COMPLETED`.
* `calculate_company_esg_score(p_company_id)`: Consulta o percentual consolidado mais recente para métricas de ranking e cache.

### Procedures com Controle de Transação

* `update_collection_status(p_collection_id, p_new_status, p_observation)`: Atualiza o status atual e registra simultaneamente a entrada no histórico de `collection_status`.
* `schedule_collection(p_collection_id, p_scheduled_at)`: Altera a coleta para `SCHEDULED` e valida a consistência cronológica em relação a `requested_at`.
* `close_incident(p_incident_id)`: Encerra uma ocorrência e despacha automaticamente um alerta na tabela `notification` para o usuário responsável.

---

## Processo de Migração Legado → 3FN (RPA)

O ecossistema implementa reconciliação de dados entre o modelo legado (baseado em chaves inteiras sequenciais) e o novo modelo (normalizado em 3FN com chaves UUID):

1. **Validação de Schemas:** O script Python checa a conectividade e a existência de estruturas mínimas em ambas as pontas.
2. **De-Para Determinístico:** Utiliza a tabela `migration_id_map` para guardar o mapeamento de IDs de entidades simples e `migration_relation_map` para tabelas associativas N:N.
3. **Idempotência Garantida:** Reexecuções não duplicam dados; tuplas já processadas são identificadas e ignoradas.
4. **Tratamento de Exceções:** Falhas pontuais são registradas na tabela `migration_error` vinculadas ao lote em `migration_run`.

Execução via terminal:

```bash
pip install -r rpa/requirements.txt
python rpa/migration.py
```

---

## Dataload e Validação Quantitativa

A massa sintética populada pelo script `scripts/02-dataload.sql` ultrapassa **600 registros** distribuídos harmonicamente entre as 19 entidades, cumprindo o critério de verossimilhança para demonstrações e testes de carga.

### Consulta de Conferência de Registros

```sql
SELECT 'role' AS tabela, COUNT(*) FROM role
UNION ALL SELECT 'company', COUNT(*) FROM company
UNION ALL SELECT 'cooperative', COUNT(*) FROM cooperative
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'area', COUNT(*) FROM area
UNION ALL SELECT 'waste_type', COUNT(*) FROM waste_type
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
UNION ALL SELECT 'esg_metric', COUNT(*) FROM esg_metric;
```

### Validação de Integridade Organizacional Multi-Tenant

```sql
-- Deve retornar ZERO linhas: usuário pertence obrigatoriamente a empresa OU cooperativa
SELECT id, company_id, cooperative_id
FROM users
WHERE (company_id IS NULL AND cooperative_id IS NULL)
   OR (company_id IS NOT NULL AND cooperative_id IS NOT NULL);
```

---

## Auditoria e Segurança

* **Triggers de Auditoria Ativas:** As mutações (`INSERT`, `UPDATE`, `DELETE`) em `incident`, `collection` e `esg_metric` são capturadas automaticamente na tabela `audit_log` contendo snapshots em formato `JSONB`, usuário de sessão (`CURRENT_USER`) e timestamp.
* **Hashes Criptográficos:** O cadastro de usuários utiliza exclusivamente hashes Bcrypt no campo `password_hash`. Senhas do legado nunca são migradas em texto plano.
* **Isolamento de Credenciais:** Nenhuma senha, token ou URL de produção é versionada no repositório Git.

---

## Governança e Catálogo de Dados

O script `scripts/10-data_catalog.sql` implementa um dicionário corporativo vivo dentro do PostgreSQL. Cada tabela e atributo é classificado segundo os níveis de privacidade em conformidade com a LGPD:

* `PUBLIC`: Dados institucionais e categorias abertas;
* `INTERNAL`: Metadados operacionais e identificadores técnicos;
* `SENSITIVE`: Informações de identificação pessoal (PII) e localizações físicas;
* `RESTRICTED`: Hashes de credenciais e dados confidenciais de transação.
