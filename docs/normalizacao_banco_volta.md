# Documentação da Normalização do Banco de Dados — VOLTA

## 1. Objetivo

A normalização do banco de dados do projeto **VOLTA** tem como objetivo organizar as informações de forma estruturada, reduzir redundâncias e evitar anomalias relacionadas à inserção, atualização e exclusão de dados.

O banco de dados relacional foi modelado utilizando o PostgreSQL e estruturado considerando as três primeiras formas normais:

- Primeira Forma Normal — **1FN**;
- Segunda Forma Normal — **2FN**;
- Terceira Forma Normal — **3FN**.

A modelagem é composta pelas entidades:

- `company`
- `role`
- `users`
- `area`
- `waste_type`
- `incident`
- `ai_report`
- `attachment`
- `cooperative`
- `collection`
- `collection_status`
- `review`
- `conversation`
- `message`
- `message_attachment`
- `notification`
- `esg_metric`

---

# 2. Primeira Forma Normal — 1FN

A **Primeira Forma Normal (1FN)** estabelece que os dados devem ser organizados de forma que:

- cada tabela possua uma identificação para seus registros;
- cada atributo armazene um valor individual;
- não existam grupos repetitivos de informações.

No VOLTA, todas as entidades possuem um campo `id` utilizado como chave primária. Os identificadores utilizam o tipo `UUID`.

## Exemplo: Company

```text
company

id
name
cnpj
address
```

Cada atributo possui uma finalidade específica:

| Atributo | Informação |
|---|---|
| `id` | Identificador único da empresa |
| `name` | Nome da empresa |
| `cnpj` | CNPJ da empresa |
| `address` | Endereço da empresa |

Não existe, por exemplo, um único campo contendo múltiplas empresas ou diversos CNPJs.

## Aplicação da 1FN no VOLTA

A Primeira Forma Normal é atendida através de:

- utilização de uma chave primária em cada tabela;
- uso de UUIDs como identificadores;
- separação dos atributos em campos específicos;
- ausência de grupos repetitivos dentro das entidades;
- armazenamento individual das informações.

Outro exemplo é a tabela `attachment`.

```text
attachment

id
incident_id
file_url
file_type
```

Em vez de armazenar diversos arquivos dentro de uma única ocorrência utilizando campos repetidos, cada anexo possui seu próprio registro.

Dessa forma, uma ocorrência pode possuir vários anexos sem a necessidade de criar grupos repetitivos de atributos.

---

# 3. Segunda Forma Normal — 2FN

A **Segunda Forma Normal (2FN)** estabelece que uma tabela deve:

1. estar na Primeira Forma Normal;
2. possuir atributos não-chave dependentes completamente da chave primária.

No banco do VOLTA, as tabelas utilizam uma chave primária individual (`id`). Isso contribui para que os atributos de cada entidade estejam relacionados ao registro identificado pelo seu UUID.

## Exemplo: Users

A tabela `users` possui a seguinte estrutura conceitual:

```text
users

id
company_id
role_id
name
email
password_hash
position
```

O registro é identificado por `id`.

As informações `name`, `email`, `password_hash` e `position` pertencem especificamente ao usuário identificado pelo UUID.

As informações da empresa não são armazenadas diretamente nessa tabela. Por exemplo, a tabela `users` não possui:

```text
company_name
company_cnpj
company_address
```

Essas informações pertencem à entidade `company`. A relação é realizada através de `company_id`.

Da mesma forma, o papel do usuário é associado à tabela `role` através do campo `role_id`.

Essa separação reduz a repetição de dados.

## Exemplo: Area

A tabela `area` possui:

```text
area

id
company_id
sector_name
location_description
```

As informações relacionadas à empresa não são repetidas dentro da tabela `area`. A relação é feita através de `company_id`.

Isso permite que uma empresa possua diversas áreas:

```text
Company
    │
    ├── Area 1
    ├── Area 2
    └── Area 3
```

Assim, os dados da empresa permanecem centralizados em `company`.

## Aplicação da 2FN no VOLTA

A Segunda Forma Normal é atendida através de:

- utilização de chaves primárias individuais;
- dependência dos atributos em relação ao registro identificado pelo `id`;
- separação das entidades;
- utilização de chaves estrangeiras;
- redução da duplicação de informações entre tabelas.

---

# 4. Terceira Forma Normal — 3FN

A **Terceira Forma Normal (3FN)** estabelece que:

1. a tabela esteja na 2FN;
2. atributos não-chave não dependam de outros atributos não-chave.

Em outras palavras, informações que possuem uma identidade própria devem ser armazenadas em entidades separadas.

No VOLTA, essa separação pode ser observada em diversas partes da modelagem.

---

# 5. Aplicação da 3FN no VOLTA

## 5.1 Company e Users

Seria inadequado armazenar todas as informações dos usuários dentro da tabela `company`.

Um modelo não normalizado poderia ser:

```text
company

company_id
company_name
cnpj
user_name
user_email
user_position
```

Isso causaria repetição das informações da empresa para cada usuário.

No VOLTA, as informações foram separadas:

```text
company

id
name
cnpj
address
```

```text
users

id
company_id
role_id
name
email
password_hash
position
```

A relação ocorre através de:

```text
users.company_id → company.id
```

Dessa forma, as informações da empresa permanecem centralizadas em sua própria entidade.

---

## 5.2 Users e Role

Os papéis dos usuários foram separados na tabela `role`.

```text
role

id
type
```

A tabela `users` possui apenas a referência `role_id`.

A relação é:

```text
users.role_id → role.id
```

Essa separação evita a necessidade de repetir informações relacionadas aos papéis dos usuários.

Vários usuários podem estar associados a um mesmo papel.

---

## 5.3 Company e Area

As áreas operacionais foram separadas da entidade `company`.

A tabela `company` armazena os dados gerais da empresa.

Já a tabela `area` armazena:

```text
id
company_id
sector_name
location_description
```

A relação é:

```text
area.company_id → company.id
```

Uma empresa pode possuir diversas áreas operacionais.

Essa estrutura evita a repetição de informações da empresa para cada área.

---

## 5.4 Incident e Waste Type

Os tipos de resíduos foram separados em uma entidade própria.

```text
waste_type

id
category
description
default_risk_level
```

A tabela `incident` possui apenas a referência `waste_type_id`.

Relação:

```text
incident.waste_type_id → waste_type.id
```

Isso evita repetir informações sobre um mesmo tipo de resíduo em diversas ocorrências.

---

## 5.5 Incident e AI Report

Os dados produzidos pela Inteligência Artificial foram separados da ocorrência.

A tabela `incident` contém os dados principais da ocorrência.

Já a tabela `ai_report` possui informações específicas da análise realizada pela IA:

```text
ai_report

id
incident_id
detected_waste_type
ai_contamination_level
recommendations
report_text
generated_at
```

A relação é:

```text
ai_report.incident_id → incident.id
```

Essa separação evita que informações específicas do módulo de Inteligência Artificial sejam incorporadas diretamente à estrutura principal da ocorrência.

---

## 5.6 Incident e Attachment

Os arquivos relacionados a uma ocorrência foram separados na tabela `attachment`.

```text
attachment

id
incident_id
file_url
file_type
```

Uma ocorrência pode possuir vários anexos:

```text
Incident
    │
    ├── Attachment 1
    ├── Attachment 2
    └── Attachment 3
```

Essa estrutura evita a criação de campos repetitivos como `attachment_1`, `attachment_2` e `attachment_3`.

---

## 5.7 Collection e Collection Status

O histórico dos status de uma coleta foi separado da tabela principal.

A tabela `collection` armazena o status atual:

```text
collection

current_status
```

Enquanto o histórico é armazenado em:

```text
collection_status

id
collection_id
status
changed_at
observation
```

A relação é:

```text
collection_status.collection_id → collection.id
```

Exemplo de histórico:

```text
REQUESTED
    ↓
SCHEDULED
    ↓
IN_PROGRESS
    ↓
COMPLETED
```

Cada alteração pode ser registrada individualmente na tabela `collection_status`.

### Observação

O campo `current_status` representa o status atual da coleta, enquanto `collection_status` registra o histórico das alterações.

Portanto, o sistema deve garantir que:

> `current_status` corresponda ao último status registrado no histórico.

---

## 5.8 Collection e Review

As avaliações das cooperativas foram separadas das coletas.

```text
review

id
cooperative_id
user_id
collection_id
stars
comment
reviewed_at
```

A tabela permite relacionar a cooperativa avaliada, o usuário responsável pela avaliação, a coleta relacionada, a quantidade de estrelas e o comentário.

A separação evita que informações de avaliação sejam armazenadas diretamente na tabela `collection`.

---

## 5.9 Conversation e Message

As conversas e mensagens foram separadas.

A entidade `conversation` representa uma conversa:

```text
conversation

id
company_id
cooperative_id
collection_id
created_at
```

As mensagens são armazenadas separadamente:

```text
message

id
conversation_id
user_id
text
reported
sent_at
```

A relação é:

```text
message.conversation_id → conversation.id
```

Isso permite que uma conversa possua diversas mensagens.

---

## 5.10 Message e Message Attachment

Os arquivos enviados através das mensagens foram separados.

```text
message_attachment

id
message_id
file_url
file_type
```

Uma mensagem pode possuir diversos anexos relacionados através de `message_id`.

Isso evita atributos repetitivos e mantém os anexos como registros independentes.

---

## 5.11 Users e Notification

As notificações foram modeladas como uma entidade independente.

```text
notification

id
user_id
type
title
message
read
created_at
```

A relação:

```text
notification.user_id → users.id
```

permite que um usuário possua diversas notificações.

As informações das notificações não precisam ser armazenadas diretamente na tabela `users`.

---

## 5.12 Company e ESG Metric

As métricas ESG foram separadas da entidade `company`.

```text
esg_metric

id
company_id
period
total_waste_kg
total_recycled_kg
recycling_percentage
calculated_at
```

Uma empresa pode possuir diversas métricas calculadas em diferentes períodos.

A relação é realizada através de `company_id`.

Essa estrutura evita que métricas históricas sejam armazenadas diretamente na tabela da empresa.

---

# 6. Resumo da Aplicação das Formas Normais

| Forma Normal | Aplicação no VOLTA |
|---|---|
| **1FN** | Cada tabela possui chave primária e atributos individuais |
| **2FN** | Os atributos dependem completamente da identificação do registro |
| **3FN** | Entidades e informações relacionadas foram separadas em tabelas próprias |

---

# 7. Principais Relações Normalizadas

A estrutura do banco apresenta diversas relações entre entidades.

```text
Company
   │
   ├── Users
   ├── Area
   ├── Incident
   ├── Conversation
   └── ESG Metric
```

```text
Role
   │
   └── Users
```

```text
Waste Type
   │
   └── Incident
```

```text
Incident
   │
   ├── AI Report
   ├── Attachment
   └── Collection
```

```text
Collection
   │
   ├── Collection Status
   ├── Review
   └── Conversation
```

```text
Conversation
   │
   └── Message
          │
          └── Message Attachment
```

Essa separação contribui para reduzir a duplicação e manter os dados organizados.

---

# 8. Benefícios da Normalização

A aplicação das formas normais no banco de dados do VOLTA proporciona diversos benefícios.

## Redução da Redundância

As informações são armazenadas em suas respectivas entidades.

Por exemplo:

- empresas em `company`;
- usuários em `users`;
- papéis em `role`;
- resíduos em `waste_type`;
- ocorrências em `incident`.

## Maior Consistência

As relações são controladas através de chaves estrangeiras.

Exemplo:

```text
users.company_id → company.id
```

Isso garante que os relacionamentos sejam realizados entre registros existentes.

## Redução de Anomalias

A separação das informações reduz problemas relacionados a:

- inserção;
- atualização;
- exclusão.

## Melhor Manutenção

A divisão das entidades facilita a manutenção e evolução do banco.

Novas funcionalidades podem ser adicionadas sem necessariamente modificar as estruturas já existentes.

## Maior Organização

Cada tabela possui uma responsabilidade específica.

| Entidade | Responsabilidade |
|---|---|
| `company` | Empresas |
| `users` | Usuários |
| `incident` | Ocorrências |
| `collection` | Coletas |
| `collection_status` | Histórico de status |
| `review` | Avaliações |
| `esg_metric` | Métricas ESG |

---

# 9. Conclusão

O banco de dados relacional do projeto **VOLTA** foi estruturado considerando os princípios de normalização até a **Terceira Forma Normal (3FN)**.

A aplicação da normalização permitiu separar adequadamente as entidades do sistema e estabelecer relações através de chaves estrangeiras.

A **Primeira Forma Normal (1FN)** é atendida pela utilização de identificadores únicos e pela organização dos atributos em campos individuais.

A **Segunda Forma Normal (2FN)** é atendida pela organização das entidades de forma que seus atributos estejam relacionados aos respectivos registros identificados pelas chaves primárias.

A **Terceira Forma Normal (3FN)** é atendida pela separação das informações em entidades específicas, evitando que informações pertencentes a diferentes conceitos sejam armazenadas na mesma tabela.

Dessa forma, a modelagem contribui para:

- reduzir redundâncias;
- melhorar a integridade dos dados;
- facilitar a manutenção;
- evitar anomalias;
- organizar as relações entre entidades;
- permitir a evolução futura do sistema.
