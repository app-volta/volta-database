# VOLTA — Banco de Dados

Repositório responsável pela persistência, evolução e documentação da camada de dados do **VOLTA**, plataforma voltada à gestão de resíduos, ocorrências, coletas, cooperativas e indicadores ESG.

O PostgreSQL é o banco relacional principal do projeto. Este repositório concentra o schema atual, o legado separado, scripts de apoio, dataloads e o processo de migração para um destino de teste.

MongoDB é utilizado no domínio de conversas e Redis atende consultas de ranking de empresas com baixa latência.

## Índice

- [Arquitetura de dados](#arquitetura-de-dados)
- [Tecnologias](#tecnologias)
- [Modelo relacional](#modelo-relacional)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Pré-requisitos](#pré-requisitos)
- [Configuração e execução](#configuração-e-execução)
- [Ordem de execução](#ordem-de-execução)
- [Dataload](#dataload)
- [Migração do legado para teste](#migração-do-legado-para-teste)
- [RPA](#rpa)
- [Validação](#validação)
- [Decisões de modelagem](#decisões-de-modelagem)
- [Segurança](#segurança)
- [Contribuição](#contribuição)

## Arquitetura de dados

| Tecnologia             | Responsabilidade                                                                                                                              |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| PostgreSQL             | Fonte de verdade relacional para empresas, usuários, áreas, resíduos, ocorrências, coletas, avaliações, notificações e métricas ESG. |
| MongoDB                | Armazenamento utilizado no domínio de conversas e mensagens.                                                                                 |
| Redis                  | Ranking de empresas e dados de consulta rápida; não substitui a persistência definitiva.                                                   |
| Python                 | Execução do processo de migração entre o banco legado e o schema atual.                                                                   |
| Power Automate Desktop | Orquestração da execução da migração e tratamento do resultado do processo.                                                             |
| Scripts SQL            | Criação do schema, carga de dados e controles operacionais da migração.                                                                   |

## Tecnologias

- PostgreSQL 16+
- `pgcrypto`
- SQL
- Python
- `psycopg`
- `python-dotenv`
- Power Automate Desktop
- MongoDB
- Redis
- Docker / Docker Compose, quando utilizados no ambiente local

## Modelo relacional

O schema relacional atual possui **17 tabelas de negócio**, com nomes em inglês e chaves primárias do tipo UUID:

| Domínio                    | Tabelas                                                                                 |
| --------------------------- | --------------------------------------------------------------------------------------- |
| Acesso e organização      | `role`, `company`, `users`, `area`                                              |
| Resíduos e ocorrências    | `waste_type`, `incident`, `ai_report`, `attachment`                             |
| Operação de coleta        | `cooperative`, `collection`, `collection_status`, `review`                      |
| Comunicação e indicadores | `conversation`, `message`, `message_attachment`, `notification`, `esg_metric` |

Além delas, o processo de migração utiliza três tabelas operacionais:

- `migration_run`
- `migration_id_map`
- `migration_error`

Essas tabelas são utilizadas para controle e rastreabilidade da migração e **não fazem parte das 17 entidades de negócio**.

A documentação detalhada das tabelas, campos, constraints e relacionamentos está disponível em `schema.md`.

### Normalização

O modelo foi documentado até a **Terceira Forma Normal (3FN)**.

- **1FN:** atributos atômicos, registros identificados por chave primária e ausência de grupos repetitivos;
- **2FN:** atributos não-chave dependem integralmente do identificador do registro;
- **3FN:** informações com identidade própria ficam em tabelas próprias e são conectadas por chaves estrangeiras.

Exemplos dessa separação incluem:

- `company` e `users`;
- `incident` e `waste_type`;
- `collection` e `collection_status`;
- `company` e `esg_metric`.

Essa estrutura reduz redundância e anomalias de inserção, atualização e exclusão.

## Estrutura do repositório

Os principais artefatos relacionados ao banco de dados estão organizados da seguinte forma:

```text
.
├── scripts/
│   ├── 01-schema.sql
│   ├── 02-dataload.sql
│   └── 13-migration_control.sql
│
├── legacy/
│   ├── 01-legacy_schema.sql
│   └── 02-legacy_dataload.sql
│
├── rpa/
│   ├── migration.py
│   └── requirements.txt
│
├── docs/
│
├── schema.md
└── README.md
```

### Principais arquivos

`01-schema.sql`
: Define o schema relacional atual do VOLTA utilizando UUIDs.

`02-dataload.sql`
: Realiza a carga sintética utilizada para desenvolvimento, testes e demonstrações.

`13-migration_control.sql`
: Cria as tabelas responsáveis pelo controle da migração.

`legacy/`
: Contém o schema e os dados sintéticos que representam a estrutura legada baseada em IDs inteiros.

`rpa/migration.py`
: Executa a migração PostgreSQL → PostgreSQL, convertendo os relacionamentos do modelo legado para o modelo atual.

`schema.md`
: Documenta detalhadamente o modelo relacional atual.

## Pré-requisitos

Para executar a camada relacional e a migração:

- PostgreSQL;
- cliente SQL, como `psql`, pgAdmin ou editor SQL do provedor utilizado;
- Python 3;
- dependências presentes em `rpa/requirements.txt`.

MongoDB e Redis são necessários apenas para os módulos que utilizam esses serviços.

## Configuração e execução

### 1. PostgreSQL

Para um ambiente PostgreSQL local, um banco pode ser criado com credenciais próprias de desenvolvimento.

Exemplo:

```sql
CREATE USER volta_user WITH PASSWORD 'troque-esta-senha';
CREATE DATABASE volta OWNER volta_user;
```

Nunca utilize credenciais reais ou de produção nos arquivos versionados.

### 2. Variáveis de ambiente

As credenciais e URLs de conexão devem permanecer em um arquivo `.env` local e não versionado.

Para a migração são utilizadas duas conexões distintas:

```env
LEGACY_URL=postgresql://...
VOLTA_RPA_TEST_URL=postgresql://...
```

- `LEGACY_URL`: banco PostgreSQL com o modelo legado.
- `VOLTA_RPA_TEST_URL`: banco isolado utilizado como destino dos testes de migração.

O `.env.example` deve conter apenas placeholders.

### 3. Aplicar o schema atual

No banco de destino:

```bash
psql -h localhost -U volta_user -d volta -f scripts/01-schema.sql
```

Depois, crie as tabelas de controle:

```bash
psql -h localhost -U volta_user -d volta -f scripts/13-migration_control.sql
```

Para testar especificamente a migração do legado, **não execute o dataload atual no destino**, pois o processo deve partir de um schema de destino vazio.

## Ordem de execução

### Ambiente atual com dataload

1. Configure o PostgreSQL.
2. Execute `scripts/01-schema.sql`.
3. Execute `scripts/02-dataload.sql`.
4. Rode as consultas de validação.

### Teste da migração

1. Prepare o banco legado.
2. Execute o schema legado.
3. Carregue o dataload legado.
4. Prepare um banco separado como destino de teste.
5. Execute `scripts/01-schema.sql` no destino.
6. Execute `scripts/13-migration_control.sql`.
7. Configure `LEGACY_URL` e `VOLTA_RPA_TEST_URL`.
8. Instale as dependências Python.
9. Execute `rpa/migration.py`.
10. Valide `migration_run`, `migration_id_map` e `migration_error`.
11. Execute novamente para validar a idempotência.

## Dataload

O dataload atual fornece mais de 700 registros fictícios e coerentes para testes, demonstrações, relatórios e validação de consultas.

A distribuição planejada totaliza **714 registros** entre as 17 tabelas.

Ele inclui, entre outros:

- empresas;
- usuários;
- áreas;
- tipos de resíduos;
- ocorrências;
- relatórios de IA;
- anexos;
- cooperativas;
- coletas;
- avaliações;
- notificações;
- métricas ESG;
- históricos de coleta.

Para executar:

```bash
psql -h localhost -U volta_user -d volta -f scripts/02-dataload.sql
```

O script utiliza `generate_series()` e `gen_random_uuid()`.

A extensão necessária é criada pelo schema:

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

> O dataload é destinado exclusivamente a desenvolvimento e testes. Não deve ser executado em produção.

### Histórico de coletas

Para coletas concluídas, o dataload contempla a sequência operacional:

```text
REQUESTED
    ↓
SCHEDULED
    ↓
IN_PROGRESS
    ↓
COMPLETED
```

O último registro de `collection_status` deve corresponder ao valor de `collection.current_status`.

## Migração do legado para teste

O modelo legado do VOLTA utiliza IDs do tipo `INTEGER`, enquanto o modelo relacional atual utiliza UUIDs.

O processo implementado permite migrar os dados entre essas estruturas preservando os relacionamentos.

```text
PostgreSQL legado
     INTEGER IDs
          │
          ▼
   migration.py
          │
          ├── valida schemas
          ├── migra registros
          ├── gera UUIDs
          ├── reconstrói FKs
          └── registra mapeamentos
          │
          ▼
PostgreSQL destino
        UUID IDs
```

A tabela `complaint`, presente no legado, foi descontinuada e não participa da migração para o modelo atual.

### Controle da migração

O processo utiliza:

#### `migration_run`

Registra cada execução e seu resultado.

Entre as informações armazenadas estão:

- início;
- término;
- status;
- registros encontrados;
- registros migrados;
- registros com falha;
- mensagem de erro.

#### `migration_id_map`

Mantém a correspondência entre os identificadores:

```text
ID legado (INTEGER) → ID atual (UUID)
```

Esse mapeamento permite reconstruir corretamente as chaves estrangeiras no destino.

#### `migration_error`

Registra falhas relacionadas à execução da migração.

### Ordem da migração

Os registros são processados respeitando suas dependências relacionais.

Exemplo:

```text
role
company
  ↓
users
area
waste_type
  ↓
incident
  ↓
ai_report
attachment
cooperative
  ↓
collection
  ↓
collection_status
review
conversation
  ↓
message
  ↓
message_attachment
notification
esg_metric
```

### Senhas legadas

As senhas em texto puro presentes na massa sintética legada **não são copiadas para `password_hash`**.

O processo gera um marcador aleatório para indicar que a conta migrada precisa passar por redefinição de senha antes de ser utilizada.

O fluxo de redefinição de senha não faz parte desta entrega.

### Transação e falhas

A carga é executada dentro de uma transação.

Caso uma etapa falhe:

1. as alterações realizadas naquela execução são revertidas;
2. a falha é registrada nas tabelas de controle;
3. o processo retorna um código de saída diferente de zero.

O processo atual não implementa continuação da carga após falha individual de um registro.

### Idempotência

O `migration_id_map` também permite identificar registros já migrados.

Em uma nova execução:

```text
registro já mapeado
        ↓
não é inserido novamente
```

Isso evita duplicações durante reexecuções.

### Resultado validado

A massa sintética do banco legado possui **49 registros migráveis**.

A execução completa foi validada com:

```text
49 registros mapeados
4 incidentes
3 coletas
0 erros
```

Após a primeira carga, uma nova execução foi realizada com:

```text
source_records   = 49
migrated_records = 0
failed_records   = 0
status           = SUCCESS
```

Esse teste confirma a idempotência da migração para a massa utilizada.

## RPA

A execução da migração também foi integrada a um fluxo criado no **Power Automate Desktop**.

O fluxo executa:

```text
Iniciar fluxo
     │
     ▼
Executar migration.py
     │
     ▼
Aguardar processo
     │
     ▼
Capturar MigrationExitCode
     │
     ▼
MigrationExitCode = 0?
     │
   ┌─┴─┐
   │   │
  SIM NÃO
   │   │
   ▼   ▼
Sucesso Falha
```

O Power Automate executa:

```text
cmd.exe
```

com o comando:

```cmd
/c py rpa\migration.py
```

O fluxo aguarda o término do processo e captura:

- `MigrationProcessId`;
- `MigrationExitCode`.

Quando:

```text
MigrationExitCode = 0
```

o fluxo informa que a migração foi concluída com sucesso.

Caso contrário, informa a falha e orienta a consulta de:

- `migration_run`;
- `migration_error`.

Os dois caminhos foram testados manualmente.

## Validação

### Conferir tabelas

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
```

### Conferir `pgcrypto`

```sql
SELECT extname
FROM pg_extension
WHERE extname = 'pgcrypto';
```

### Contar registros por tabela

```sql
SELECT 'role' AS table_name, COUNT(*) AS total FROM role
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
```

### Validar a migração

```sql
SELECT
    source_table,
    COUNT(*) AS registros_mapeados
FROM migration_id_map
GROUP BY source_table
ORDER BY source_table;
```

Execuções:

```sql
SELECT
    status,
    source_records,
    migrated_records,
    failed_records,
    error_message
FROM migration_run
ORDER BY started_at DESC;
```

Erros:

```sql
SELECT *
FROM migration_error
ORDER BY created_at DESC;
```

### Validar consistência das coletas

```sql
WITH last_status AS (
    SELECT DISTINCT ON (collection_id)
        collection_id,
        status
    FROM collection_status
    ORDER BY collection_id, changed_at DESC
)
SELECT
    c.id,
    c.current_status,
    ls.status AS last_history_status
FROM collection c
LEFT JOIN last_status ls
    ON ls.collection_id = c.id
WHERE ls.status IS DISTINCT FROM c.current_status;
```

O resultado esperado é vazio.

### Validar métricas ESG

```sql
SELECT
    id,
    company_id,
    total_waste_kg,
    total_recycled_kg
FROM esg_metric
WHERE total_recycled_kg > total_waste_kg;
```

O resultado esperado é vazio.

## Decisões de modelagem

### UUIDs

Todas as entidades do modelo atual utilizam UUID como chave primária.

Isso permite geração descentralizada de identificadores e evita dependência de sequências numéricas globais.

### Integridade referencial

Chaves estrangeiras conectam as entidades e impedem referências inválidas.

### Histórico de coleta

`collection.current_status` mantém o estado operacional atual.

`collection_status` preserva o histórico de alterações.

### Indicadores ESG

`esg_metric` mantém medições históricas por empresa e período.

### Separação de responsabilidades

O PostgreSQL mantém o modelo relacional principal.

MongoDB é utilizado no domínio de conversas.

Redis é utilizado como camada de consulta rápida/ranking.

### Evolução do schema

Alterações compartilhadas no banco devem ser realizadas por novos scripts versionados quando for necessário preservar o histórico da evolução, evitando alterações silenciosas em scripts já utilizados por outros ambientes.

## Segurança

- Nunca versione senhas, tokens ou URLs contendo credenciais.
- Nunca versione arquivos `.env`.
- Utilize `.env.example` apenas com placeholders.
- Utilize credenciais diferentes para desenvolvimento, teste e produção.
- Não execute o dataload em produção.
- Não copie senhas em texto puro do legado para o banco atual.
- Restrinja o acesso aos bancos apenas aos ambientes necessários.
- Faça backup antes de alterações destrutivas.
- Revise os arquivos adicionados antes de cada commit.
- Não exponha PostgreSQL, MongoDB ou Redis diretamente à internet sem necessidade e proteção adequada.

## Contribuição

1. Crie uma branch a partir da branch de integração utilizada pelo projeto.
2. Implemente a alteração.
3. Teste em ambiente isolado.
4. Atualize a documentação quando necessário.
5. Revise os arquivos modificados.
6. Confirme que nenhuma credencial foi adicionada.
7. Abra um Pull Request descrevendo:
   - o que foi alterado;
   - como foi validado;
   - impactos conhecidos;
   - estratégia de rollback, quando aplicável.

## Licença

Defina aqui a licença adotada pelo projeto, caso aplicável.
