#!/bin/bash

# ============================================================
# VOLTA - PostgreSQL Restore Test
# ============================================================

BACKUP_FILE="$1"

RESTORE_DATABASE="volta_restore_test"

if [ -z "$BACKUP_FILE" ]; then
    echo "Informe o arquivo de backup."
    exit 1
fi


dropdb --if-exists "$RESTORE_DATABASE"

createdb "$RESTORE_DATABASE"

pg_restore \
    --dbname="$RESTORE_DATABASE" \
    "$BACKUP_FILE"


echo "Restore concluído."

echo "Validando tabelas..."

psql \
    --dbname="$RESTORE_DATABASE" \
    --command="\dt"