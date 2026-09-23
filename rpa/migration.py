
from pathlib import Path
import os
import secrets

import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row
from psycopg import sql


ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

LEGACY_URL = os.getenv("LEGACY_URL")
TARGET_URL = os.getenv("VOLTA_RPA_TEST_URL")

if not LEGACY_URL or not TARGET_URL:
    raise RuntimeError(
        "Configure LEGACY_URL e "
        "VOLTA_RPA_TEST_URL no .env"
    )


# Ordem de dependência: cada tabela aparece depois das tabelas
# referenciadas por suas chaves estrangeiras.
#
# columns: coluna do legado -> coluna do destino
# fks: coluna do destino -> tabela de origem do mapeamento
TABLES = {
    "role": {
        "columns": {"type": "type"},
        "unique": "type",
    },
    "company": {
        "columns": {
            "name": "name",
            "cnpj": "cnpj",
            "address": "address",
        },
        "unique": "cnpj",
    },
    "users": {
        "columns": {
            "company_id": "company_id",
            "role_id": "role_id",
            "name": "name",
            "email": "email",
            "position": "position",
        },
        "fks": {
            "company_id": "company",
            "role_id": "role",
        },
        "unique": "email",
        "password_reset": True,
    },
    "area": {
        "columns": {
            "company_id": "company_id",
            "sector_name": "sector_name",
            "location_description": "location_description",
        },
        "fks": {"company_id": "company"},
    },
    "waste_type": {
        "columns": {
            "category": "category",
            "description": "description",
            "default_risk": "default_risk_level",
        },
    },
    "incident": {
        "columns": {
            "company_id": "company_id",
            "user_id": "user_id",
            "area_id": "area_id",
            "waste_type_id": "waste_type_id",
            "photo_url": "photo_url",
            "employee_description": "employee_description",
            "contamination_level": "contamination_level",
            "estimated_quantity": "estimated_quantity",
            "priority": "priority",
            "status": "status",
            "registered_at": "registered_at",
        },
        "fks": {
            "company_id": "company",
            "user_id": "users",
            "area_id": "area",
            "waste_type_id": "waste_type",
        },
    },
    "ai_report": {
        "columns": {
            "incident_id": "incident_id",
            "detected_waste": "detected_waste_type",
            "ai_contamination_level": "ai_contamination_level",
            "recommendations": "recommendations",
            "report_text": "report_text",
            "generated_at": "generated_at",
        },
        "fks": {"incident_id": "incident"},
    },
    "attachment": {
        "columns": {
            "incident_id": "incident_id",
            "file_url": "file_url",
            "file_type": "file_type",
        },
        "fks": {"incident_id": "incident"},
    },
    "cooperative": {
        "columns": {
            "name": "name",
            "cnpj": "cnpj",
            "latitude": "latitude",
            "longitude": "longitude",
            "average_rating": "average_rating",
            "specialties": "specialties",
        },
        "unique": "cnpj",
    },
    "collection": {
        "columns": {
            "incident_id": "incident_id",
            "cooperative_id": "cooperative_id",
            "request_date": "requested_at",
            "scheduled_date": "scheduled_at",
            "current_status": "current_status",
            "collection_type": "collection_type",
            "urgent": "urgent",
        },
        "fks": {
            "incident_id": "incident",
            "cooperative_id": "cooperative",
        },
    },
    "collection_status": {
        "columns": {
            "collection_id": "collection_id",
            "status": "status",
            "change_date": "changed_at",
            "observation": "observation",
        },
        "fks": {"collection_id": "collection"},
    },
    "review": {
        "columns": {
            "cooperative_id": "cooperative_id",
            "user_id": "user_id",
            "collection_id": "collection_id",
            "stars": "stars",
            "comment": "comment",
            "review_date": "reviewed_at",
        },
        "fks": {
            "cooperative_id": "cooperative",
            "user_id": "users",
            "collection_id": "collection",
        },
    },
    "conversation": {
        "columns": {
            "company_id": "company_id",
            "cooperative_id": "cooperative_id",
            "collection_id": "collection_id",
        },
        "fks": {
            "company_id": "company",
            "cooperative_id": "cooperative",
            "collection_id": "collection",
        },
    },
    "message": {
        "columns": {
            "conversation_id": "conversation_id",
            "user_id": "user_id",
            "text": "text",
            "reported": "reported",
            "sent_at": "sent_at",
        },
        "fks": {
            "conversation_id": "conversation",
            "user_id": "users",
        },
    },
    "message_attachment": {
        "columns": {
            "message_id": "message_id",
            "file_url": "file_url",
            "file_type": "file_type",
        },
        "fks": {"message_id": "message"},
    },
    "notification": {
        "columns": {
            "user_id": "user_id",
            "type": "type",
            "title": "title",
            "message": "message",
            "read": "read",
            "created_at": "created_at",
        },
        "fks": {"user_id": "users"},
    },
    "esg_metric": {
        "columns": {
            "company_id": "company_id",
            "period": "period",
            "total_kg_waste": "total_waste_kg",
            "total_kg_recycled": "total_recycled_kg",
            "recycling_percentage": "recycling_percentage",
            "calculated_at": "calculated_at",
        },
        "fks": {"company_id": "company"},
    },
}


def table_columns(connection, table):
    with connection.cursor(row_factory=dict_row) as cursor:
        cursor.execute(
            """
            SELECT
                column_name,
                is_nullable,
                character_maximum_length
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = %s
            """,
            (table,),
        )
        return {
            row["column_name"]: row
            for row in cursor.fetchall()
        }


def validate_schemas(source, target):
    """Verifica nomes de colunas antes de iniciar qualquer carga."""

    required_control = (
        "migration_run",
        "migration_id_map",
        "migration_error",
    )

    for table in required_control:
        if not table_columns(target, table):
            raise RuntimeError(
                f"Tabela de controle ausente no destino: {table}"
            )

    if table_columns(source, "migration_run"):
        raise RuntimeError(
            "A origem possui migration_run. "
            "Confira se as URLs não foram invertidas."
        )

    for table, config in TABLES.items():
        source_columns = table_columns(source, table)
        target_columns = table_columns(target, table)

        required_source = {"id", *config["columns"].keys()}
        required_target = {"id", *config["columns"].values()}

        if config.get("password_reset"):
            required_target.add("password_hash")

        missing_source = required_source - source_columns.keys()
        missing_target = required_target - target_columns.keys()

        if missing_source or missing_target:
            raise RuntimeError(
                f"Schema incompatível em {table}. "
                f"Ausentes no legado: {sorted(missing_source)}; "
                f"ausentes no destino: {sorted(missing_target)}"
            )


def get_target_id(cursor, source_table, source_id):
    if source_id is None:
        return None

    cursor.execute(
        """
        SELECT target_id
        FROM migration_id_map
        WHERE source_table = %s
          AND source_id = %s
        """,
        (source_table, source_id),
    )

    result = cursor.fetchone()

    if result is None:
        raise RuntimeError(
            f"FK sem mapeamento: {source_table} legado={source_id}"
        )

    return result["target_id"]


def already_migrated(cursor, table, source_id):
    cursor.execute(
        """
        SELECT target_id
        FROM migration_id_map
        WHERE source_table = %s
          AND source_id = %s
        """,
        (table, source_id),
    )

    result = cursor.fetchone()

    if result is None:
        return False

    cursor.execute(
        sql.SQL("SELECT id FROM {} WHERE id = %s").format(
            sql.Identifier(table)
        ),
        (result["target_id"],),
    )

    if cursor.fetchone() is None:
        raise RuntimeError(
            f"Mapeamento inválido: {table} legado={source_id}"
        )

    return True


def migrate_table(source, target, table, config):
    column_map = config["columns"]
    source_columns = list(column_map.keys())
    target_columns = list(column_map.values())

    with source.cursor(row_factory=dict_row) as cursor:
        cursor.execute(
            sql.SQL("SELECT {} FROM {} ORDER BY id").format(
                sql.SQL(", ").join(
                    sql.Identifier(column)
                    for column in ["id", *source_columns]
                ),
                sql.Identifier(table),
            )
        )
        records = cursor.fetchall()

    target_metadata = table_columns(target, table)
    inserted = 0
    skipped = 0

    with target.cursor(row_factory=dict_row) as cursor:
        for record in records:
            source_id = record["id"]

            if already_migrated(cursor, table, source_id):
                skipped += 1
                continue

            values = {
                target_column: record[source_column]
                for source_column, target_column
                in column_map.items()
            }

            # Reconstrói as FKs usando os UUIDs do destino.
            for column, referenced_table in config.get(
                "fks", {}
            ).items():
                values[column] = get_target_id(
                    cursor,
                    referenced_table,
                    values[column],
                )

            # Nunca copia a senha em texto puro do legado.
            if config.get("password_reset"):
                values["password_hash"] = (
                    "!MIGRATED_RESET_REQUIRED_"
                    + secrets.token_hex(24)
                )

            # Não inventa valores para campos obrigatórios.
            for column, value in values.items():
                metadata = target_metadata[column]

                if (
                    value is None
                    and metadata["is_nullable"] == "NO"
                ):
                    raise RuntimeError(
                        f"{table} legado={source_id}: "
                        f"{column} é obrigatório no destino, "
                        "mas está NULL no legado."
                    )

                max_length = metadata[
                    "character_maximum_length"
                ]

                if (
                    isinstance(value, str)
                    and max_length is not None
                    and len(value) > max_length
                ):
                    raise RuntimeError(
                        f"{table} legado={source_id}: "
                        f"{column} excede {max_length} caracteres."
                    )

            # Não associa automaticamente registros que já
            # existem no destino sem um mapeamento confirmado.
            unique_column = config.get("unique")

            if unique_column:
                cursor.execute(
                    sql.SQL(
                        "SELECT id FROM {} WHERE {} = %s"
                    ).format(
                        sql.Identifier(table),
                        sql.Identifier(unique_column),
                    ),
                    (values[unique_column],),
                )

                if cursor.fetchone() is not None:
                    raise RuntimeError(
                        f"{table} legado={source_id}: "
                        f"{unique_column} já existe no destino "
                        "sem mapeamento."
                    )

            insert_columns = list(values.keys())

            cursor.execute(
                sql.SQL(
                    "INSERT INTO {} ({}) VALUES ({}) RETURNING id"
                ).format(
                    sql.Identifier(table),
                    sql.SQL(", ").join(
                        sql.Identifier(column)
                        for column in insert_columns
                    ),
                    sql.SQL(", ").join(
                        sql.Placeholder()
                        for _ in insert_columns
                    ),
                ),
                tuple(values.values()),
            )

            target_id = cursor.fetchone()["id"]

            cursor.execute(
                """
                INSERT INTO migration_id_map (
                    source_table,
                    source_id,
                    target_table,
                    target_id
                )
                VALUES (%s, %s, %s, %s)
                """,
                (table, source_id, table, target_id),
            )

            inserted += 1

    return len(records), inserted, skipped


def main():
    print("=== VOLTA | MIGRAÇÃO LEGADO → TESTE ===")

    with psycopg.connect(LEGACY_URL) as source:
        with psycopg.connect(TARGET_URL) as target:

            validate_schemas(source, target)

            # Finaliza a transação de leitura da validação.
            target.commit()

            total_source = 0
            total_inserted = 0
            run_id = None

            try:
                # A execução inteira é atômica: se qualquer
                # tabela falhar, os inserts desta execução
                # e seus mapeamentos são revertidos.
                with target.transaction():
                    with target.cursor() as cursor:
                        cursor.execute(
                            """
                            INSERT INTO migration_run (status)
                            VALUES ('RUNNING')
                            RETURNING id
                            """
                        )
                        run_id = cursor.fetchone()[0]

                    for table, config in TABLES.items():
                        source_count, inserted, skipped = (
                            migrate_table(
                                source,
                                target,
                                table,
                                config,
                            )
                        )

                        total_source += source_count
                        total_inserted += inserted

                        print(
                            f"{table}: "
                            f"origem={source_count}, "
                            f"inseridos={inserted}, "
                            f"já migrados={skipped}"
                        )

                    with target.cursor() as cursor:
                        cursor.execute(
                            """
                            UPDATE migration_run
                            SET
                                status = 'SUCCESS',
                                finished_at = CURRENT_TIMESTAMP,
                                source_records = %s,
                                migrated_records = %s
                            WHERE id = %s
                            """,
                            (
                                total_source,
                                total_inserted,
                                run_id,
                            ),
                        )

                print("Migração concluída com sucesso!")

            except Exception as error:
                # A transação de carga foi revertida.
                # Registra a falha em uma nova transação.
                with target.transaction():
                    with target.cursor() as cursor:
                        cursor.execute(
                            """
                            INSERT INTO migration_run (
                                status,
                                finished_at,
                                source_records,
                                migrated_records,
                                failed_records,
                                error_message
                            )
                            VALUES (
                                'FAILED',
                                CURRENT_TIMESTAMP,
                                %s,
                                0,
                                1,
                                %s
                            )
                            RETURNING id
                            """,
                            (total_source, str(error)),
                        )
                        failed_run_id = cursor.fetchone()[0]

                        cursor.execute(
                            """
                            INSERT INTO migration_error (
                                migration_run_id,
                                source_table,
                                source_id,
                                error_message
                            )
                            VALUES (%s, %s, %s, %s)
                            """,
                            (
                                failed_run_id,
                                "migration",
                                None,
                                str(error),
                            ),
                        )

                print(f"Migração falhou: {error}")
                raise


if __name__ == "__main__":
    main()
