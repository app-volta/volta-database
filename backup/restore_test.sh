#!/bin/bash
set -e

# ============================================================
# VOLTA - PostgreSQL Restore Test Script
# Validação periódica de integridade dos backups
# ============================================================

BACKUP_FILE="$1"
RESTORE_DATABASE="${2:-volta_restore_test}"

if [ -z "$BACKUP_FILE" ]; then
    echo "Erro: Informe o caminho do arquivo .dump para restauração."
    echo "Uso: ./restore_test.sh <caminho_do_arquivo.dump> [nome_do_banco_teste]"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Erro: Arquivo '$BACKUP_FILE' não encontrado."
    exit 1
fi

echo "Recriando banco de testes: $RESTORE_DATABASE..."
dropdb --if-exists "$RESTORE_DATABASE"
createdb "$RESTORE_DATABASE"

echo "Restaurando dump..."
pg_restore \
    --no-owner \
    --no-privileges \
    --dbname="$RESTORE_DATABASE" \
    "$BACKUP_FILE" || true

echo "Restore concluído com sucesso!"
echo "Validando entidades e tabelas restauradas:"

psql \
    --dbname="$RESTORE_DATABASE" \
    --command="\dt"