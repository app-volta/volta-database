#!/bin/bash

# ============================================================
# VOLTA - PostgreSQL Backup
# ============================================================

DATABASE="neondb"
BACKUP_DIR="./backups"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

mkdir -p "$BACKUP_DIR"

pg_dump \
    --format=custom \
    --file="$BACKUP_DIR/neondb_$TIMESTAMP.dump" \
    "$DATABASE"

echo "Backup criado em:"
echo "$BACKUP_DIR/neondb_$TIMESTAMP.dump"