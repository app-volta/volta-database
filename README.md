# VOLTA — Banco de Dados

Repositório responsável pela persistência, evolução e documentação da camada de dados do **VOLTA**, plataforma voltada à gestão de resíduos, ocorrências, coletas, cooperativas e indicadores ESG.

O PostgreSQL é o banco relacional principal do projeto. Este repositório concentra as migrations versionadas, scripts de apoio e o dataload para ambientes locais e de desenvolvimento. MongoDB é utilizado para o domínio de conversas, e Redis atende consultas de ranking de empresas com baixa latência.

## Índice

- [Arquitetura de dados](#arquitetura-de-dados)
- [Tecnologias](#tecnologias)
- [Modelo relacional](#modelo-relacional)
- [Estrutura esperada](#estrutura-esperada)
- [Pré-requisitos](#pré-requisitos)
- [Configuração e execução](#configuração-e-execução)
- [Ordem de execução](#ordem-de-execução)
- [Dataload](#dataload)
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
| Flyway                  | Versionamento e aplicação ordenada das alterações de schema.                                                                          |
| Docker / Docker Compose | Execução reproduzível dos serviços em ambiente local, quando disponibilizado pelo projeto.                                            |

## Tecnologias

- PostgreSQL 16+ (compatível com versões recentes do PostgreSQL)
- Extensão PostgreSQL `pgcrypto` para geração de UUIDs
- Flyway para migrations
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
├── docker-compose.yml                 # serviços locais, quando aplicável
├── Dockerfile                         # imagem do banco, quando aplicável
├── flyway.conf                        # configuração do Flyway, se utilizada localmente
├── migrations/                        # migrations versionadas
│   ├── V1__initial_schema.sql
│   └── V...__descricao_da_mudanca.sql
├── scripts/
│   ├── dataload.sql                   # carga inicial para desenvolvimento
│   └── validation.sql                 # consultas de validação, se existente
└── docs/
    └── normalizacao_banco_volta.md
```

Se o projeto usar o layout padrão do Flyway, as migrations podem estar em `src/main/resources/db/migration/`. Mantenha apenas um local configurado como fonte de migrations.

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

### 4. Aplicar as migrations com Flyway

Quando o Flyway for executado localmente, configure a URL e as credenciais do banco e rode:

```bash
flyway migrate
```

Antes de aplicar uma mudança, é útil conferir o estado atual:

```bash
flyway info
```

Caso o backend execute o Flyway na inicialização, não rode migrations manualmente em paralelo: escolha um único processo responsável pela aplicação.

## Ordem de execução

Para uma instalação local limpa, siga esta ordem:

1. Suba o PostgreSQL (via Docker ou instalação local).
2. Crie o banco e configure as variáveis de ambiente.
3. Aplique todas as migrations com Flyway.
4. Confirme que o schema e a extensão `pgcrypto` foram criados.
5. Execute o dataload apenas no ambiente de desenvolvimento/teste.
6. Rode as consultas de validação.
7. Suba MongoDB e Redis se for testar conversas e ranking.

Não altere uma migration que já tenha sido compartilhada ou aplicada em outro ambiente. Crie uma nova migration com o próximo número de versão, por exemplo `V5__add_collection_index.sql`.

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
psql -h localhost -U volta_user -d volta -f scripts/dataload.sql
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

### Validar migrations

```bash
flyway validate
flyway info
```

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

## Contribuição

1. Abra uma branch a partir da branch de integração do projeto.
2. Crie uma nova migration seguindo o padrão `V<versão>__<descricao>.sql`.
3. Use nomes em inglês, `snake_case` e UUIDs quando aplicável.
4. Não edite migrations já aplicadas em ambientes compartilhados.
5. Teste a migration em um banco vazio e em uma cópia de desenvolvimento representativa.
6. Rode `flyway validate` e as consultas de validação relevantes.
7. Atualize a documentação quando a mudança alterar o modelo, integrações ou operação local.
8. Abra um pull request descrevendo a alteração, a estratégia de rollback e como ela foi validada.

## Licença

Defina aqui a licença adotada pelo projeto, caso aplicável.
