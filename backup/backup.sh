#!/bin/bash
set -e

# ============================================================
# VOLTA - PostgreSQL Backup Script
# Atende aos requisitos de Governança de Dados / Continuidade
# ============================================================

# Diretório padrão alinhado à estrutura do repositório
BACKUP_DIR="$(dirname "$0")/dumps"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/neondb_$TIMESTAMP.dump"

mkdir -p "$BACKUP_DIR"

echo "Iniciando backup do banco de dados..."

# Se DATABASE_URL estiver configurada (ex: carregada do .env), utiliza-a
if [ -n "$DATABASE_URL" ]; then
    pg_dump \
        --format=custom \
        --no-owner \
        --no-privileges \
        --dbname="$DATABASE_URL" \
        --file="$BACKUP_FILE"
else
    DATABASE="${1:-neondb}"
    pg_dump \
        --format=custom \
        --no-owner \
        --no-privileges \
        --dbname="$DATABASE" \
        --file="$BACKUP_FILE"
fi

echo "Backup concluído com sucesso!"
echo "Arquivo gerado: $BACKUP_FILE"