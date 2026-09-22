# VOLTA — Banco de Dados

Repositório responsável pela persistência, evolução e documentação da camada de dados do **VOLTA**, plataforma voltada à gestão de resíduos, ocorrências, coletas, cooperativas e indicadores ESG.

O PostgreSQL é o banco relacional principal do projeto. Este repositório concentra o schema atual, o legado separado, scripts de apoio, dataloads e a migração para um destino de teste. MongoDB é utilizado para o domínio de conversas, e Redis atende consultas de ranking de empresas com baixa latência.

## Índice

- [Arquitetura de dados](#arquitetura-de-dados)
- [Tecnologias](#tecnologias)
- [Modelo relacional](#modelo-relacional)
- [Estrutura esperada](#estrutura-esperada)
- [Pré-requisitos](#pré-requisitos)
- [Configuração e execução](#configuração-e-execução)
- [Ordem de execução](#ordem-de-execução)
- [Dataload](#dataload)
- [Migração do legado para teste](#migração-do-legado-para-teste)
- [Validação](#validação)
- [Decisões de modelagem](#decisões-de-modelagem)
- [Segurança](#segurança)
- [Contribuição](#contribuição)

## Arquitetura de dados

| Tecnologia              | Responsabilidade                                                                                                                          |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| PostgreSQL              | Fonte de verdade relacional: empresas, usuários, áreas, resíduos, ocorrências, coletas, avaliações, notificações e métricas ESG. |
| MongoDB                 | Conversas, mensagens e anexos de mensagens, adequados a um domínio com conteúdo e volume variáveis.                                    |
| Redis                   | Ranking de empresas e dados de consulta rápida; não substitui a persistência definitiva no PostgreSQL.                                 |
| Scripts SQL              | Versionamento e aplicação ordenada do schema, cargas e controles operacionais.                                                        |
| Docker / Docker Compose | Execução reproduzível dos serviços em ambiente local, quando disponibilizado pelo projeto.                                            |

## Tecnologias

- PostgreSQL 16+ (compatível com versões recentes do PostgreSQL)
- Extensão PostgreSQL `pgcrypto` para geração de UUIDs
- `psql` para execução dos scripts SQL
- MongoDB para o módulo de conversas
- Redis para ranking de empresas
- Docker e Docker Compose (opcionais, recomendados para desenvolvimento local)

## Modelo relacional

O schema relacional atual possui 17 tabelas, com nomes em inglês e chaves primárias do tipo UUID:

| Domínio                    | Tabelas                                                                                 |
| --------------------------- | --------------------------------------------------------------------------------------- |
| Acesso e organização      | `role`, `company`, `users`, `area`                                              |
| Resíduos e ocorrências    | `waste_type`, `incident`, `ai_report`, `attachment`                             |
| Operação de coleta        | `cooperative`, `collection`, `collection_status`, `review`                      |
| Comunicação e indicadores | `conversation`, `message`, `message_attachment`, `notification`, `esg_metric` |

> A arquitetura pode manter tabelas relacionais de referência ou legado para comunicação. No desenho distribuído, o MongoDB é o armazenamento proprietário do fluxo de conversas e mensagens. Evite duplicar dados entre PostgreSQL e MongoDB sem uma regra explícita de sincronização.

### Normalização

O modelo foi documentado até a **Terceira Forma Normal (3FN)**:

- **1FN:** atributos atômicos, registros identificados por chave primária e ausência de grupos repetitivos;
- **2FN:** atributos não-chave dependem integralmente do identificador do registro;
- **3FN:** informações com identidade própria ficam em tabelas próprias, ligadas por chaves estrangeiras.

Exemplos práticos são a separação entre `company` e `users`, `incident` e `waste_type`, `collection` e `collection_status`, e `company` e `esg_metric`. Essa organização reduz redundância e anomalias de inserção, atualização e exclusão.

## Estrutura esperada

A estrutura pode variar ligeiramente conforme a organização do repositório, mas os artefatos devem seguir uma separação semelhante à abaixo:

```text
.
├── scripts/01-schema.sql              # schema relacional atual, UUID
├── scripts/02-dataload.sql             # carga sintética do destino atual
├── scripts/13-migration_control.sql    # tabelas de controle da migração
├── legacy/01-legacy_schema.sql         # schema legado, INTEGER
├── legacy/02-legacy_dataload.sql       # carga sintética do legado
├── rpa/migration.py                     # migração PostgreSQL → PostgreSQL
├── rpa/requirements.txt
└── docs/                                # modelagem e normalização
```

Este checkout não contém arquivos de collections, scripts ou configuração de MongoDB. A documentação do domínio Mongo não deve ser tratada como uma entrega de arquivos Mongo neste repositório.

## Pré-requisitos

- PostgreSQL em execução e acesso a um banco de desenvolvimento;
- cliente `psql` ou ferramenta equivalente;
- Flyway CLI, caso as migrations não sejam executadas pelo backend/contêiner;
- Docker Desktop e Docker Compose, caso o projeto forneça `docker-compose.yml`;
- acesso ao MongoDB e Redis apenas para executar os módulos que dependem desses serviços.

## Configuração e execução

### 1. Criar o banco e o usuário local

Substitua os valores de exemplo por credenciais locais. Não use credenciais de produção.

```sql
CREATE USER volta_user WITH PASSWORD 'troque-esta-senha';
CREATE DATABASE volta OWNER volta_user;
```

### 2. Configurar variáveis de ambiente

Crie um arquivo `.env` local a partir de um exemplo fornecido pelo projeto, ou configure as variáveis no terminal/sistema:

```env
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=volta
POSTGRES_USER=volta_user
POSTGRES_PASSWORD=troque-esta-senha

MONGO_URI=mongodb://localhost:27017/volta
REDIS_URL=redis://localhost:6379
```

### 3. Subir com Docker (quando disponível)

Na raiz que contém o arquivo de composição:

```bash
docker compose up -d
```

Verifique os serviços:

```bash
docker compose ps
```

Para acompanhar a inicialização do PostgreSQL:

```bash
docker compose logs -f postgres
```

O nome do serviço pode ser diferente no seu `docker-compose.yml`; ajuste o último comando se necessário.

### 4. Aplicar o schema e os controles

No checkout atual, os scripts SQL são a fonte de execução. Configure a conexão do destino de teste e rode:

```bash
psql -h localhost -U volta_user -d volta -f scripts/01-schema.sql
psql -h localhost -U volta_user -d volta -f scripts/13-migration_control.sql
```

O projeto não contém configuração Flyway neste checkout. Caso a aplicação use outro executor de migrations, mantenha apenas um processo responsável pela aplicação das alterações.

## Ordem de execução

Para uma instalação local limpa, siga esta ordem:

1. Suba o PostgreSQL (via Docker ou instalação local).
2. Crie o banco e configure as variáveis de ambiente.
3. Aplique `scripts/01-schema.sql` e `scripts/13-migration_control.sql`.
4. Confirme que o schema e a extensão `pgcrypto` foram criados.
5. Execute o dataload apenas no ambiente de desenvolvimento/teste.
6. Rode as consultas de validação.
7. Suba MongoDB e Redis se for testar conversas e ranking.

Não altere um script SQL já compartilhado ou aplicado em outro ambiente sem alinhar a estratégia de evolução. Prefira um novo script versionado quando a mudança precisar ser rastreável.

## Dataload

O dataload fornece mais de 700 registros fictícios e coerentes para testes, demonstrações, relatórios e validação de consultas. A distribuição planejada totaliza **714 registros** entre as 17 tabelas.

Ele inclui, entre outros:

- empresas, usuários, áreas e tipos de resíduos;
- ocorrências, relatórios de IA e anexos;
- cooperativas, coletas e avaliações;
- notificações e métricas ESG em períodos distintos;
- dados adequados para testes de gráficos e ranking;
- históricos de coleta consistentes com o status atual.

Para executar o script (ajuste o caminho conforme o repositório):

```bash
psql -h localhost -U volta_user -d volta -f scripts/02-dataload.sql
```

O script utiliza `generate_series()` e `gen_random_uuid()`. Por isso, a extensão `pgcrypto` deve estar disponível antes da carga:

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

> O dataload é destinado a desenvolvimento e testes. Execute-o em um banco limpo ou em uma base descartável, pois uma nova execução pode criar dados duplicados se o script não tiver sido projetado como idempotente.

### Histórico de coletas

Para coletas concluídas, o dataload contempla a sequência operacional definida no SCRUM-1905:

```text
REQUESTED → SCHEDULED → IN_PROGRESS → COMPLETED
```

O último registro em `collection_status` deve corresponder a `collection.current_status`.

## Migração do legado para teste

O legado PostgreSQL fica separado em `legacy/` e usa chaves `INTEGER`. O destino de teste é o schema atual de `scripts/01-schema.sql`, que usa UUID. A migração é executada por `rpa/migration.py` e recebe duas conexões distintas:

- `LEGACY_URL`: origem legada;
- `VOLTA_RPA_TEST_URL`: destino de teste.

Antes da carga, o script valida os schemas, confirma que as tabelas `migration_run`, `migration_id_map` e `migration_error` existem no destino e recusa URLs invertidas. As FKs do destino são reconstruídas a partir de `migration_id_map`; a senha legada não é copiada e o usuário migrado recebe um marcador aleatório que exige redefinição.

A carga sintética legada fornecida possui **49 registros**. Em uma execução completa, espera-se uma entrada correspondente por registro em `migration_id_map`, respeitando a ordem das 17 tabelas e suas dependências. A execução é idempotente: registros já mapeados são ignorados, enquanto uma colisão no destino sem mapeamento confirmado gera erro.

Cada execução registra estado em `migration_run`. A carga ocorre em transação única; em caso de falha, a transação de dados é revertida e a falha é registrada em `migration_run` e `migration_error`. Isso não significa que exista tratamento individual concluído para cada registro.

### RPA no Power Automate Desktop

O fluxo do Power Automate Desktop executa `rpa\migration.py` por `cmd.exe`, armazena o ID do processo e o código de saída, e exibe sucesso somente quando `MigrationExitCode = 0`. Caso contrário, informa a falha e orienta a verificar `migration_run` e `migration_error` no destino de teste. Login seguro e tratamento individual por registro não devem ser descritos como concluídos nesta etapa.

## Validação

Após migrations e dataload, conecte-se ao banco:

```bash
psql -h localhost -U volta_user -d volta
```

### Conferir as tabelas

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
```

### Conferir a extensão de UUID

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

### Validar consistência das coletas

Esta consulta identifica coletas cujo status atual não coincide com o último status registrado no histórico:

```sql
WITH last_status AS (
  SELECT DISTINCT ON (collection_id)
    collection_id,
    status
  FROM collection_status
  ORDER BY collection_id, changed_at DESC
)
SELECT c.id, c.current_status, ls.status AS last_history_status
FROM collection c
LEFT JOIN last_status ls ON ls.collection_id = c.id
WHERE ls.status IS DISTINCT FROM c.current_status;
```

O resultado esperado é vazio.

### Validar métricas ESG

```sql
SELECT id, company_id, total_waste_kg, total_recycled_kg
FROM esg_metric
WHERE total_recycled_kg > total_waste_kg;
```

O resultado esperado é vazio.

### Validar scripts

Confirme que os scripts foram executados na ordem documentada e que as tabelas de controle da migração existem no destino de teste.

## Decisões de modelagem

- **UUIDs como identificadores:** permitem geração descentralizada de IDs e evitam expor sequências numéricas previsíveis.
- **`users` no plural:** evita conflito com palavras reservadas e mantém uma convenção de nomes clara.
- **Chaves estrangeiras e constraints:** preservam integridade referencial e impedem relações inválidas.
- **Status atual e histórico separados:** `collection.current_status` favorece consultas operacionais; `collection_status` preserva rastreabilidade.
- **Dados ESG históricos:** `esg_metric` registra medições por período, sem sobrescrever resultados anteriores.
- **Persistência por responsabilidade:** PostgreSQL é a fonte relacional; MongoDB é destinado a conversas; Redis é uma camada de cache/ranking reconstruível.
- **Migrations imutáveis:** Flyway cria histórico auditável e reprodutível da evolução do schema.

## Segurança

- Nunca versione senhas, tokens, URLs com credenciais, dumps reais ou arquivos `.env`.
- Use credenciais distintas e com menor privilégio possível para desenvolvimento, testes e produção.
- Restrinja a exposição de PostgreSQL, MongoDB e Redis a redes necessárias; Redis não deve ficar publicamente acessível.
- Faça backup antes de migrations destrutivas e teste-as em ambiente não produtivo.
- Não execute o dataload em produção.
- Armazene apenas hashes de senha, nunca senhas em texto puro.
- Revise permissões de leitura/escrita de anexos e URLs assinadas antes de liberar o ambiente.
- O `.gitignore` exclui `.env`, arquivos de ambiente derivados, dumps e logs; `.env.example` contém apenas placeholders.
- Antes de preparar um commit, confirme que `git status --ignored` não mostra credenciais versionáveis e revise URLs, tokens, chaves e dumps adicionados.

## Contribuição

1. Abra uma branch a partir da branch de integração do projeto.
2. Crie um novo script SQL versionado quando a alteração precisar ser preservada.
3. Use nomes em inglês, `snake_case` e UUIDs quando aplicável.
4. Não edite scripts já aplicados em ambientes compartilhados.
5. Teste a migration em um banco vazio e em uma cópia de desenvolvimento representativa.
6. Rode `flyway validate` e as consultas de validação relevantes.
7. Atualize a documentação quando a mudança alterar o modelo, integrações ou operação local.
8. Abra um pull request descrevendo a alteração, a estratégia de rollback e como ela foi validada.

## Licença

Defina aqui a licença adotada pelo projeto, caso aplicável.
