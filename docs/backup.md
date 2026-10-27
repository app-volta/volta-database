# Backup e Recuperação de Falhas — PostgreSQL VOLTA

## 1. Objetivo

Definir um procedimento simples, repetível e auditável para fazer backup do PostgreSQL do VOLTA, testar a recuperação em um banco separado e recuperar o ambiente em caso de falha.

O procedimento usa o formato custom do PostgreSQL (`pg_dump -F c`), que permite restaurar o banco com `pg_restore` e selecionar objetos quando necessário.

## 2. Política proposta

- Executar backup completo diariamente, preferencialmente às 02:00.
- Manter, como ponto de partida, pelo menos 7 cópias diárias e 4 cópias semanais.
- Armazenar as cópias fora do diretório do repositório.
- Testar a restauração periodicamente em banco separado.
- Registrar data, tamanho, hash, resultado do restore e responsável.
- Nunca versionar senhas, tokens, arquivos `.pgpass`, `.pg_service.conf` ou strings de conexão com credenciais.

O exemplo de agendamento abaixo é apenas uma sugestão. Ele não significa que o job esteja ativo.

## 3. Pré-requisitos

Tenha disponível:

- PostgreSQL em execução;
- um banco VOLTA acessível, por exemplo `volta`;
- usuário com permissão de leitura para `pg_dump` e permissão de criação/restauração para o teste;
- `pg_dump`, `pg_restore` e `psql` instalados;
- espaço livre para o arquivo de backup e para o banco de teste;
- uma pasta de backup fora do repositório.

Confirme as versões:

```powershell
pg_dump --version
pg_restore --version
psql --version
```

Idealmente, use ferramentas da mesma versão principal do servidor PostgreSQL ou uma versão compatível.

## 4. Backup manual com `pg_dump -F c`

O comando base é:

```text
pg_dump -h localhost -p 5432 -U postgres -d volta -F c -f volta_backup.dump
```

Significado das opções:

- `-h localhost`: servidor;
- `-p 5432`: porta padrão;
- `-U postgres`: usuário;
- `-d volta`: banco de origem;
- `-F c`: formato custom;
- `-f`: arquivo de saída.

Se o PostgreSQL solicitar senha, informe-a apenas no prompt. Não coloque a senha diretamente no comando.

## 5. Passo a passo exato no Windows/PowerShell

Este é o roteiro local recomendado para o Lucas.

### 5.1 Criar uma pasta de teste

```powershell
$backupDir = Join-Path $env:USERPROFILE 'volta-backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
```

### 5.2 Gerar um backup com timestamp

```powershell
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupFile = Join-Path $backupDir "volta_$timestamp.dump"
pg_dump -h localhost -p 5432 -U postgres -d volta -F c -f $backupFile
```

Confira se o arquivo foi criado:

```powershell
Get-Item $backupFile | Select-Object FullName, Length, LastWriteTime
```

Opcionalmente, gere um hash para anexar como evidência:

```powershell
Get-FileHash $backupFile -Algorithm SHA256
```

### 5.3 Se `pg_dump` não for reconhecido

Localize a instalação do PostgreSQL. O caminho comum é semelhante a:

```text
C:\Program Files\PostgreSQL\16\bin
```

Execute usando o caminho completo:

```powershell
$pgBin = 'C:\Program Files\PostgreSQL\16\bin'
& (Join-Path $pgBin 'pg_dump.exe') -h localhost -p 5432 -U postgres -d volta -F c -f $backupFile
```

Faça o mesmo para as outras ferramentas:

```powershell
& (Join-Path $pgBin 'pg_restore.exe') --version
& (Join-Path $pgBin 'psql.exe') --version
```

Para adicionar o diretório ao PATH somente na sessão atual:

```powershell
$env:Path = "$pgBin;$env:Path"
pg_dump --version
```

Para tornar a alteração permanente, use as configurações de Variáveis de Ambiente do Windows e adicione o diretório `bin` do PostgreSQL ao PATH. Feche e abra o PowerShell depois da alteração.

### 5.4 Criar o banco separado de restore

Conecte ao banco administrativo `postgres` e crie `volta_restore_test`:

```powershell
psql -h localhost -p 5432 -U postgres -d postgres -c "CREATE DATABASE volta_restore_test;"
```

Se o banco já existir, não o reutilize sem antes confirmar que ele é apenas de teste. Para recriá-lo de forma controlada:

```powershell
psql -h localhost -p 5432 -U postgres -d postgres -c "DROP DATABASE IF EXISTS volta_restore_test WITH (FORCE);"
psql -h localhost -p 5432 -U postgres -d postgres -c "CREATE DATABASE volta_restore_test;"
```

O `DROP DATABASE` remove somente o banco de teste indicado. Nunca troque o nome pelo banco de produção sem uma autorização explícita e um plano de recuperação.

### 5.5 Restaurar o backup no banco de teste

```powershell
pg_restore -h localhost -p 5432 -U postgres -d volta_restore_test --clean --if-exists --no-owner --no-acl $backupFile
```

Se o arquivo tiver sido criado com um caminho diferente, use a variável correta ou o caminho completo entre aspas.

### 5.6 Validar com `psql` e `\dt`

Listar as tabelas:

```powershell
psql -h localhost -p 5432 -U postgres -d volta_restore_test -c '\dt'
```

Executar uma consulta simples:

```powershell
psql -h localhost -p 5432 -U postgres -d volta_restore_test -c 'SELECT COUNT(*) AS companies FROM company;'
```

Para abrir uma sessão interativa:

```powershell
psql -h localhost -p 5432 -U postgres -d volta_restore_test
```

Dentro do `psql`:

```text
\dt
\d users
SELECT COUNT(*) FROM users;
\q
```

### 5.7 Comparar contagens das principais tabelas

Execute no banco original e depois no banco restaurado. Os resultados devem coincidir, salvo alterações feitas entre o backup e a consulta.

```powershell
$countSql = @"
SELECT 'company' AS table_name, COUNT(*) AS row_count FROM company
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'incident', COUNT(*) FROM incident
UNION ALL SELECT 'collection', COUNT(*) FROM collection
UNION ALL SELECT 'collection_status', COUNT(*) FROM collection_status
UNION ALL SELECT 'message', COUNT(*) FROM message
UNION ALL SELECT 'esg_metric', COUNT(*) FROM esg_metric
ORDER BY table_name;
"@

psql -h localhost -p 5432 -U postgres -d volta -c $countSql
psql -h localhost -p 5432 -U postgres -d volta_restore_test -c $countSql
```

### 5.8 Verificar a integridade de `users`

A regra esperada é: cada usuário pertence a exatamente uma organização, empresa ou cooperativa.

```powershell
$integritySql = @"
SELECT id, company_id, cooperative_id
FROM users
WHERE (company_id IS NULL AND cooperative_id IS NULL)
   OR (company_id IS NOT NULL AND cooperative_id IS NOT NULL);
"@

psql -h localhost -p 5432 -U postgres -d volta_restore_test -c $integritySql
```

O resultado esperado é zero linhas.

Também confira as FKs e constraints pelo catálogo do PostgreSQL:

```powershell
psql -h localhost -p 5432 -U postgres -d volta_restore_test -c "SELECT conname, contype, conrelid::regclass FROM pg_constraint ORDER BY conrelid::regclass::text, conname;"
```

Verifique ainda se o catálogo técnico está presente:

```powershell
psql -h localhost -p 5432 -U postgres -d volta_restore_test -c "SELECT table_name, COUNT(*) FROM data_catalog GROUP BY table_name ORDER BY table_name;"
```

### 5.9 Limpar o banco de teste

Depois das validações, feche qualquer conexão aberta e remova somente o banco de teste:

```powershell
psql -h localhost -p 5432 -U postgres -d postgres -c "DROP DATABASE IF EXISTS volta_restore_test WITH (FORCE);"
```

O arquivo `.dump` pode ser mantido para evidência ou removido conforme a política local. Se ele contiver dados reais, trate-o como informação sensível.

## 6. Linux e macOS

Crie o diretório e gere o backup:

```bash
mkdir -p "$HOME/volta-backups"
timestamp="$(date +%Y%m%d_%H%M%S)"
backup_file="$HOME/volta-backups/volta_${timestamp}.dump"
pg_dump -h localhost -p 5432 -U postgres -d volta -F c -f "$backup_file"
```

Crie o banco de teste, restaure e liste as tabelas:

```bash
psql -h localhost -p 5432 -U postgres -d postgres -c 'CREATE DATABASE volta_restore_test;'
pg_restore -h localhost -p 5432 -U postgres -d volta_restore_test --clean --if-exists --no-owner --no-acl "$backup_file"
psql -h localhost -p 5432 -U postgres -d volta_restore_test -c '\dt'
```

Remova o banco de teste:

```bash
psql -h localhost -p 5432 -U postgres -d postgres -c 'DROP DATABASE IF EXISTS volta_restore_test WITH (FORCE);'
```

## 7. Exemplo de `backup.sh`

O arquivo abaixo é um exemplo. Ajuste usuário, host, banco e diretório antes de usar. Ele não fica ativo automaticamente.

```bash
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups/volta}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-volta}"
DB_USER="${DB_USER:-postgres}"

mkdir -p "$BACKUP_DIR"
timestamp="$(date +%Y%m%d_%H%M%S)"
file="$BACKUP_DIR/${DB_NAME}_${timestamp}.dump"

pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -F c -f "$file"
sha256sum "$file" > "$file.sha256"
find "$BACKUP_DIR" -type f -name '*.dump' -mtime +7 -delete
find "$BACKUP_DIR" -type f -name '*.sha256' -mtime +7 -delete
```

Permissão e execução manual:

```bash
chmod 700 backup.sh
./backup.sh
```

## 8. Exemplo de cron diário às 02:00

Linha de exemplo:

```cron
0 2 * * * /opt/volta/backup.sh >> /var/log/volta-backup.log 2>&1
```

Essa linha apenas demonstra a configuração esperada; não afirma que o cron esteja instalado ou ativo. Antes de habilitar, confirme permissões, armazenamento, rotação e monitoramento de falhas.

## 9. Procedimento de recuperação em falha

1. Identifique o incidente e registre horário, banco afetado e último backup válido.
2. Preserve logs e não sobrescreva o arquivo de backup original.
3. Confirme a integridade do arquivo com o hash, quando disponível.
4. Avalie se é possível recuperar em um banco ou servidor separado primeiro.
5. Crie um banco vazio ou um ambiente de contingência.
6. Execute `pg_restore` com o backup escolhido.
7. Valide tabelas, contagens, constraints e a regra de organização de `users`.
8. Valide a aplicação com uma conta de teste.
9. Só depois de aprovação técnica, direcione a aplicação para o ambiente recuperado.
10. Registre a causa, horário de recuperação, backup usado, comandos e evidências.

Para restaurar sobre um banco existente, confirme o alvo, faça uma avaliação de impacto e tenha outro backup disponível. Em situações críticas, prefira restaurar em ambiente separado e fazer a troca controlada.

## 10. Troubleshooting

### `pg_dump` ou `pg_restore` não é reconhecido no Windows

Use o caminho completo para `C:\Program Files\PostgreSQL\<versão>\bin\pg_dump.exe` ou adicione essa pasta ao PATH da sessão, conforme a seção 5.3.

### Falha de autenticação

Confirme host, porta, banco e usuário. Não registre a senha em scripts, histórico de shell ou Jira. Use o prompt de senha ou um mecanismo seguro de credenciais aprovado pela equipe.

### `database is being accessed by other users`

Feche sessões do banco de teste e, somente para o banco de teste, use `DROP DATABASE ... WITH (FORCE)`.

### `role ... does not exist` durante o restore

O comando recomendado usa `--no-owner --no-acl`. Se o backup depender de objetos específicos, verifique as roles no ambiente de destino antes de restaurar.

### Permissão negada ao criar banco

Use um usuário autorizado ou peça ao responsável pelo PostgreSQL para criar `volta_restore_test`. Não eleve permissões permanentemente só para um teste.

### O restore termina com warnings

Leia todo o output, identifique os objetos afetados e valide se são apenas owners, ACLs ou extensões ausentes. Não considere o teste aprovado sem conferir tabelas e contagens.

### Contagens diferentes

Confirme se o backup foi feito antes das consultas no banco original, se houve alterações durante o processo e se o restore apontou para o arquivo correto.

## 11. Evidências recomendadas para anexar ao Jira

- nome do arquivo `.dump` e tamanho;
- data e hora do backup;
- saída de `pg_dump --version`, `pg_restore --version` e `psql --version`;
- hash SHA-256 do arquivo;
- comando de restore usado, sem senha;
- saída de `\dt` no banco `volta_restore_test`;
- comparação das contagens das principais tabelas;
- consulta de integridade de `users` retornando zero linhas;
- confirmação de que o banco de teste foi removido;
- logs de erro, se houver, e a ação tomada.

Não anexe dumps com dados pessoais ou credenciais ao Jira sem autorização. Quando necessário, anexe apenas logs, contagens, hashes e capturas sem dados sensíveis.

## 12. Critério de aprovação do teste

O teste é considerado aprovado quando:

- o backup é criado sem erro;
- o arquivo possui tamanho e hash registrados;
- o restore termina sem falhas relevantes;
- `\dt` lista as tabelas esperadas;
- as contagens principais são coerentes;
- a consulta de integridade de `users` retorna zero linhas;
- constraints e catálogo técnico estão presentes;
- o banco `volta_restore_test` é removido ao final.
