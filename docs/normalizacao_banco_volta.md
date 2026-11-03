# Documentação da Normalização do Banco de Dados — VOLTA

## 1. Objetivo

A normalização do banco de dados do projeto **VOLTA** tem como objetivo organizar as informações de forma estruturada, reduzir redundâncias e evitar anomalias de inserção, atualização e exclusão de dados.

O banco de dados relacional foi modelado utilizando o PostgreSQL e estruturado rigorosamente em conformidade com as três primeiras formas normais:

* Primeira Forma Normal — **1FN**;
* Segunda Forma Normal — **2FN**;
* Terceira Forma Normal — **3FN**.

A modelagem física consolidada é composta por 19 tabelas:

1. `company`
2. `role`
3. `cooperative`
4. `users`
5. `area`
6. `waste_type`
7. `incident`
8. `ai_report`
9. `attachment`
10. `collection`
11. `collection_status`
12. `review`
13. `conversation`
14. `message`
15. `message_attachment`
16. `notification`
17. `esg_metric`
18. `cooperative_waste_type` (Associativa N:N)
19. `incident_waste_type` (Associativa N:N)

---

## 2. Primeira Forma Normal — 1FN

A **Primeira Forma Normal (1FN)** estabelece que:

* Cada tabela possua uma chave primária que identifique univocamente seus registros;
* Cada atributo seja atômico (indivisível), armazenando apenas um único valor por linha/coluna;
* Não existam grupos repetitivos de atributos ou arrays multivalorados em colunas.

No VOLTA, todas as entidades regulares possuem um campo `id` do tipo `UUID` gerado automaticamente (`gen_random_uuid()`) como chave primária.

### Chaves Primárias Compostas (Tabelas Associativas N:N)

As tabelas associativas `cooperative_waste_type` e `incident_waste_type` não utilizam um identificador artificial unitário. Suas chaves primárias são compostas pelos pares de chaves estrangeiras:

* `cooperative_waste_type`: PK `(cooperative_id, waste_type_id)`
* `incident_waste_type`: PK `(incident_id, waste_type_id)`

### Exemplo: Company

```text
company
├── id (UUID, PK)
├── name (VARCHAR)
├── cnpj (VARCHAR)
├── address (VARCHAR)
├── latitude (DOUBLE PRECISION)
├── longitude (DOUBLE PRECISION)
└── is_available (BOOLEAN)
```

Cada atributo possui atomicidade:

| Atributo                     | Finalidade                                   |
| :--------------------------- | :------------------------------------------- |
| `id`                       | Identificador único da empresa (UUID)       |
| `name`                     | Razão Social / Nome da empresa              |
| `cnpj`                     | Cadastro Nacional da Pessoa Jurídica        |
| `address`                  | Endereço formatado                          |
| `latitude` / `longitude` | Coordenadas geográficas individuais         |
| `is_available`             | Flag booleana de disponibilidade operacional |

### Eliminação de Grupos Repetitivos

Em vez de criar colunas fixas como `waste_type_1`, `waste_type_2` na tabela `incident`, ou armazenar strings com resíduos concatenados por vírgula (`"Plástico, Vidro, Metal"`), cada associação é decomposta em linhas individuais na tabela associativa `incident_waste_type`. O mesmo princípio é aplicado para múltiplos anexos (`attachment`) vinculados a uma única ocorrência.

---

## 3. Segunda Forma Normal — 2FN

A **Segunda Forma Normal (2FN)** exige que:

1. A entidade já esteja em conformidade com a 1FN;
2. Todos os atributos não-chave dependam funcionalmente e por completo da chave primária (ausência de dependência parcial).

Nas tabelas com chave primária simples (`id`), a 2FN é garantida por definição, pois qualquer atributo não-chave depende diretamente do UUID do registro.

Nas tabelas com chave primária composta:

* Em `cooperative_waste_type`, todos os campos compõem a própria chave primária `(cooperative_id, waste_type_id)`. Não há atributos satélites não-chave, garantindo dependência plena.
* Em `incident_waste_type`, a chave é estritamente composta por `(incident_id, waste_type_id)`.

### Exemplo: Users

A tabela `users` centraliza credenciais e identidade:

```text
users
├── id (PK)
├── role_id (FK)
├── company_id (FK, Opcional)
├── cooperative_id (FK, Opcional)
├── name
├── email
├── password_hash
├── position
├── photo_url
├── registered_at
└── first_login
```

Atributos como `name`, `email` e `password_hash` dependem exclusivamente da pessoa física cadastrada (`id`). Dados cadastrais da empresa contratante ou da cooperativa parceira não são repetidos em `users`; utiliza-se apenas a referência (`company_id` ou `cooperative_id`).

---

## 4. Terceira Forma Normal — 3FN

A **Terceira Forma Normal (3FN)** exige que:

1. A tabela atenda a todos os requisitos da 2FN;
2. Não existam dependências transitivas entre atributos não-chave (ou seja, nenhum atributo não-chave pode depender de outro atributo não-chave).

Informações que possuem ciclo de vida e identidade próprios foram isoladas em tabelas dedicadas.

---

## 5. Aplicação Prática da 3FN no VOLTA

### 5.1 Company e Users

Evita que dados corporativos sejam replicados em cada registro de usuário.

* **Modelo Não Normalizado:** `users (id, name, company_name, company_cnpj, company_address)`
* **No VOLTA (3FN):** `users (id, company_id, ...) → company (id, name, cnpj, address)`

### 5.2 Users e Role

As permissões e cargos foram extraídos para a tabela `role` (`ADMIN`, `MANAGER`, `EMPLOYEE`), evitando inconsistências de escrita e permitindo auditoria centralizada.

* `users.role_id → role.id`

### 5.3 Vínculo Organizacional Exclusivo

Um usuário do sistema pertence ou a uma empresa geradora ou a uma cooperativa de reciclagem. Em vez de criar tabelas duplicadas para cada tipo de usuário, a tabela `users` implementa a constraint de integridade:

```sql
CONSTRAINT chk_users_organization CHECK (
    (company_id IS NOT NULL AND cooperative_id IS NULL)
    OR
    (company_id IS NULL AND cooperative_id IS NOT NULL)
)
```

### 5.4 Incident, Waste Type e Incident Waste Type

Um chamado/incidente pode envolver diferentes categorias de resíduos. Para evitar redundância transitiva e permitir flexibilidade na triagem:

* `incident`: Detalhes da ocorrência (local, gravidade, descrição, fotos).
* `waste_type`: Cadastro mestre das categorias de resíduos e riscos ambientais.
* `incident_waste_type`: Tabela associativa que resolve a relação N:N (`incident_id` + `waste_type_id`).

### 5.5 Cooperative e Cooperative Waste Type

Similarmente, cada cooperativa atua com materiais específicos. A associação muitos-para-muitos é resolvida pela tabela `cooperative_waste_type`:

* `cooperative.id ← cooperative_waste_type.cooperative_id`
* `waste_type.id ← cooperative_waste_type.waste_type_id`

### 5.6 Incident e AI Report

Informações analíticas produzidas pelo modelo de Inteligência Artificial (`ai_contamination_level`, `recommendations`, `report_text`) possuem ciclo de processamento próprio e podem não existir no instante imediato da criação do chamado. Por isso, foram isoladas na tabela `ai_report`:

* `ai_report.incident_id → incident.id` (Relacionamento 1:1 estrito).

### 5.7 Collection e Collection Status (Histórico Auditável)

Para rastrear a linha do tempo da coleta sem gerar linhas duplicadas para o agendamento:

* `collection`: Registra o estado consolidado (`current_status`).
* `collection_status`: Registra as transições cronológicas (`changed_at`, `status`, `observation`).
* `collection_status.collection_id → collection.id` (1:N).

### 5.8 Comunicação: Conversation, Message e Attachment

O chat entre cooperativa e gerador foi decomposto em três camadas para garantir integridade e suporte a múltiplos anexos:

* `conversation`: Contexto da negociação de uma coleta específica.
* `message`: Registro das mensagens individuais enviadas pelos usuários.
* `message_attachment`: Arquivos anexados a mensagens pontuais.

### 5.9 ESG Metrics

As metas e volumes consolidados de descarte e reciclagem variam por período (semanal, mensal, trimestral). Separar `esg_metric` de `company` impede que o cadastro da empresa precise ser alterado a cada novo cálculo de sustentabilidade.

---

## 6. Resumo das Formas Normais

| Forma Normal  | Regra Básica                                                   | Aplicação no Projeto VOLTA                                                                                |
| :------------ | :-------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------- |
| **1FN** | Atributos atômicos e ausência de grupos repetitivos           | UUIDs como PKs; anexos e múltiplos resíduos desacoplados em tabelas associativas/filhas.                  |
| **2FN** | Dependência funcional total da chave primária                 | Eliminação de dependências parciais; chaves compostas restritas a tabelas de ligação N:N.              |
| **3FN** | Ausência de dependência transitiva entre atributos não-chave | Separação das entidades `company`, `role`, `cooperative`, `area`, `waste_type` e `ai_report`. |

---

## 7. Mapa de Relacionamentos do Sistema

```text
company (1) ──< area (N)
company (1) ──< users (N)
company (1) ──< incident (N)
company (1) ──< conversation (N)
company (1) ──< esg_metric (N)

role (1) ──< users (N)

cooperative (1) ──< users (N)
cooperative (1) ──< collection (N)
cooperative (1) ──< conversation (N)
cooperative (1) ──< review (N)

cooperative (N) >── cooperative_waste_type ──< (N) waste_type
incident (N)    >── incident_waste_type    ──< (N) waste_type

incident (1) ──< attachment (N)
incident (1) ─── ai_report (1)
incident (1) ──< collection (N)

collection (1) ──< collection_status (N)
collection (1) ──< review (N)
collection (1) ──< conversation (N)

conversation (1) ──< message (N) ──< message_attachment (N)
users (1) ──< notification (N)
```

---

## 8. Conclusão

A normalização adotada na modelagem relacional do projeto **VOLTA** atende com rigor às exigências conceituais até a **3FN**. Essa arquitetura assegura:

1. **Integridade Referencial:** Todas as interações dependem de chaves estrangeiras validadas por constraints.
2. **Eliminação de Anomalias:** Atualizações cadastrais em empresas ou cooperativas não corrompem o histórico de incidentes e relatórios de IA.
3. **Escalabilidade:** Novas categorias de resíduos ou novos parâmetros de auditoria podem ser integrados sem necessidade de refatoração do esquema principal.
