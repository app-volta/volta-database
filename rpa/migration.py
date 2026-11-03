# migration.py
"""Script de migracao – sincroniza o banco PostgreSQL legado para o esquema consolidado Volta.

O script roda indefinidamente, executando uma sincronizacao completa (INSERT/UPDATE/DELETE) a cada SYNC_INTERVAL segundos.
Ele utiliza as tabelas de controle definidas em 13-migration_control.sql (migration_run, migration_id_map,
migration_error e migration_relation_map) para registrar quais linhas ja foram migradas e para registrar erros.

A configuracao e feita via variaveis de ambiente:
    LEGACY_URL – string de conexao ao banco legado (PKs inteiros)
    DATABASE_URL – string de conexao ao novo banco Volta (PKs UUID)
    SYNC_INTERVAL – segundos entre ciclos de sincronizacao (padrao: 10)
"""

import os
import time
import logging
import uuid
import unicodedata
from typing import Any, Tuple, Optional
from datetime import datetime

import psycopg2
from psycopg2.extras import RealDictCursor

# ---------------------------------------------------------------------------
# Configuracao
# ---------------------------------------------------------------------------
LEGACY_URL = os.getenv("LEGACY_URL")
DATABASE_URL = os.getenv("DATABASE_URL")
SYNC_INTERVAL = int(os.getenv("SYNC_INTERVAL", "10"))

if not LEGACY_URL or not DATABASE_URL:
    raise RuntimeError("Variaveis de ambiente LEGACY_URL e DATABASE_URL sao obrigatorias.")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler("migration.log", encoding="utf-8"),
        logging.StreamHandler()
    ]
)

# ---------------------------------------------------------------------------
# Classes e funcoes auxiliares
# ---------------------------------------------------------------------------
class DB:
    """Wrapper simples para conexao psycopg2 usando cursor de dicionario."""
    def __init__(self, dsn: str):
        self.conn = psycopg2.connect(dsn, cursor_factory=RealDictCursor)
        self.conn.autocommit = False

    def __enter__(self):
        return self.conn

    def __exit__(self, exc_type, exc, tb):
        if exc:
            self.conn.rollback()
        else:
            self.conn.commit()
        self.conn.close()

def advisory_lock(conn) -> bool:
    """Obtem um advisory lock do PostgreSQL para evitar execucoes simultaneas."""
    with conn.cursor() as cur:
        cur.execute("SELECT pg_try_advisory_lock(8421731);")
        locked = cur.fetchone()["pg_try_advisory_lock"]
    return locked

def release_lock(conn):
    """Libera o advisory lock adquirido."""
    with conn.cursor() as cur:
        cur.execute("SELECT pg_advisory_unlock(8421731);")

def record_run_start(conn) -> str:
    """Registra o inicio de uma execucao e retorna o UUID do run."""
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO migration_run (status, source_records, migrated_records, failed_records)
            VALUES ('RUNNING', 0, 0, 0)
            RETURNING id;
            """
        )
        run_id = cur.fetchone()["id"]
    conn.commit()
    return str(run_id)

def record_run_finish(
    conn, 
    run_id: str, 
    success: bool, 
    migrated: int, 
    failed: int, 
    source_records: Optional[int] = None, 
    error_msg: Optional[str] = None
):
    if source_records is None:
        source_records = migrated + failed

    status_str = "SUCCESS" if success else "FAILED"

    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE migration_run 
            SET finished_at = CURRENT_TIMESTAMP, 
                status = %s, 
                source_records = %s,
                migrated_records = %s, 
                failed_records = %s,
                error_message = %s 
            WHERE id = %s
            """,
            (
                status_str,
                source_records,
                migrated,
                failed,
                error_msg,
                run_id
            ),
        )
    conn.commit()

def log_error(conn, run_id: str, table: str, source_id: Any, msg: str):
    """Grava o erro no banco garantindo que a transacao esteja limpa."""
    try:
        conn.rollback()
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO migration_error (migration_run_id, source_table, source_id, error_message) 
                VALUES (%s, %s, %s, %s)
                """,
                (run_id, table, str(source_id) if source_id is not None else None, str(msg)[:1000]),
            )
        conn.commit()
    except Exception as e:
        conn.rollback()
        logging.error("Falha ao registrar em migration_error: %s", e)

def get_uuid_mapping(conn, source_table: str, source_id: int) -> Optional[uuid.UUID]:
    """Busca o UUID mapeado para um registro de origem."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT target_id FROM migration_id_map WHERE source_table = %s AND source_id = %s",
            (source_table, source_id),
        )
        row = cur.fetchone()
        return uuid.UUID(str(row["target_id"])) if row else None

def set_uuid_mapping(conn, source_table: str, source_id: int, target_table: str, target_id: uuid.UUID):
    """Insere o mapeamento entre ID de origem e UUID de destino."""
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO migration_id_map (source_table, source_id, target_table, target_id) VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING",
            (source_table, source_id, target_table, str(target_id)),
        )
    conn.commit()

def set_relation_mapping(conn, source_table: str, s1: int, s2: int, target_table: str, t1: uuid.UUID, t2: uuid.UUID):
    """Registra o de-para para tabelas associativas N:N."""
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO migration_relation_map (source_table, source_id_1, source_id_2, target_table, target_id_1, target_id_2)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT DO NOTHING
            """,
            (source_table, s1, s2, target_table, str(t1), str(t2))
        )
    conn.commit()

def parse_coord(val: Any, default: float) -> float:
    """Converte valor para float tratando None, strings e tipos numericos."""
    if val is None:
        return default
    try:
        f = float(val)
        return f if f != 0.0 else default
    except (ValueError, TypeError):
        return default

# ---------------------------------------------------------------------------
# Lookups de referencia (role, waste_type)
# ---------------------------------------------------------------------------
ROLE_MAP = {
    "SYSTEM_ADMIN": ["ADMIN", "ADMINISTRADOR", "ADMINISTRADOR_SISTEMA", "SYSTEM_ADMIN"],
    "COMPANY_USER": ["USER", "USUARIO", "FUNCIONARIO", "OPERADOR", "COMPANY_USER", "EMPLOYEE"],
    "COOPERATIVE": ["COOPERATIVE", "COOPERATIVA", "OPERADOR_COOPERATIVA", "MANAGER", "EMPLOYEE"],
}

def lookup_role_uuid(conn, role_type: str) -> Optional[uuid.UUID]:
    clean_type = role_type.strip().upper()
    possible_names = ROLE_MAP.get(clean_type, [clean_type])
    if clean_type not in possible_names:
        possible_names.append(clean_type)

    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id FROM role 
            WHERE UPPER(type) = ANY(%s) OR type ILIKE %s
            LIMIT 1
            """,
            (possible_names, f"%{clean_type}%")
        )
        row = cur.fetchone()
        if row:
            return uuid.UUID(str(row["id"]))

        cur.execute("SELECT id FROM role ORDER BY id LIMIT 1")
        row = cur.fetchone()
        return uuid.UUID(str(row["id"])) if row else None

def normalize_text(text: str) -> str:
    if not text:
        return ""
    nfkd = unicodedata.normalize('NFKD', text)
    return "".join([c for c in nfkd if not unicodedata.combining(c)]).strip().upper()

WASTE_TYPE_MAP = {
    "PLASTICO": "PLASTICO",
    "PLASTIC": "PLASTICO",
    "PAPEL": "PAPEL",
    "PAPELAO": "PAPEL",
    "PAPER": "PAPEL",
    "VIDRO": "VIDRO",
    "GLASS": "VIDRO",
    "METAL": "METAL",
    "ORGANICO": "ORGANICO",
    "ORGANIC": "ORGANICO",
    "RESIDUO CONTAMINADO": "QUIMICO",
    "CONTAMINADO": "QUIMICO",
    "PERIGOSO": "QUIMICO",
    "HAZARDOUS": "QUIMICO",
    "QUIMICO": "QUIMICO",
    "ELETRONICO": "ELECTRONICO",
    "ELECTRONIC": "ELECTRONICO",
    "ELECTRONICO": "ELECTRONICO",
    "BATERIA": "ELECTRONICO",
    "BATTERY": "ELECTRONICO",
    "TEXTIL": "TEXTIL",
    "MADEIRA": "MADEIRA",
    "MISTO": "MISTO"
}

def lookup_waste_type_uuid(conn, category: str) -> Optional[uuid.UUID]:
    norm = normalize_text(category)
    mapped = WASTE_TYPE_MAP.get(norm, norm)
    
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id FROM waste_type 
            WHERE UPPER(category) = %s 
               OR UPPER(category) = %s 
               OR UPPER(category) = %s
            LIMIT 1
            """,
            (mapped, norm, category.strip().upper()),
        )
        row = cur.fetchone()
        if row:
            return uuid.UUID(str(row["id"]))

        cur.execute(
            """
            SELECT id FROM waste_type 
            WHERE category ILIKE %s OR category ILIKE %s
            LIMIT 1
            """,
            (f"%{mapped}%", f"%{norm}%"),
        )
        row = cur.fetchone()
        if row:
            return uuid.UUID(str(row["id"]))

        cur.execute("SELECT id FROM waste_type ORDER BY id LIMIT 1")
        row = cur.fetchone()
        if row:
            return uuid.UUID(str(row["id"]))

    return None

# ---------------------------------------------------------------------------
# Sincronizacao
# ---------------------------------------------------------------------------
def sync_company(legacy_conn, target_conn, run_id: str) -> Tuple[int, int]:
    processed = failed = 0
    with legacy_conn.cursor() as src_cur:
        src_cur.execute("SELECT * FROM company")
        rows = src_cur.fetchall()

    for row in rows:
        src_id = row["id"]
        try:
            target_uuid = get_uuid_mapping(target_conn, "company", src_id)
            
            name = row.get("name")
            cnpj = row.get("cnpj")
            address = row.get("address")
            
            # Puxa latitude e longitude diretamente das chaves (ou fallback de SP caso ausente)
            raw_lat = row.get("latitude") if "latitude" in row else row.get("lat")
            raw_lon = row.get("longitude") if "longitude" in row else row.get("lon")
            lat = parse_coord(raw_lat, -23.550520)
            lon = parse_coord(raw_lon, -46.633308)

            is_available = row.get("is_available") if row.get("is_available") is not None else True

            if not target_uuid:
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute("SELECT id FROM company WHERE cnpj = %s", (cnpj,))
                    existing = tgt_cur.fetchone()

                if existing:
                    target_uuid = uuid.UUID(str(existing["id"]))
                    with target_conn.cursor() as tgt_cur:
                        tgt_cur.execute(
                            """
                            UPDATE company 
                            SET name=%s, address=%s, latitude=%s, longitude=%s, is_available=%s
                            WHERE id=%s
                            """,
                            (name, address, lat, lon, is_available, str(target_uuid)),
                        )
                else:
                    target_uuid = uuid.uuid4()
                    with target_conn.cursor() as tgt_cur:
                        tgt_cur.execute(
                            """
                            INSERT INTO company (id, name, cnpj, address, latitude, longitude, is_available)
                            VALUES (%s, %s, %s, %s, %s, %s, %s)
                            """,
                            (str(target_uuid), name, cnpj, address, lat, lon, is_available),
                        )
                set_uuid_mapping(target_conn, "company", src_id, "company", target_uuid)
            else:
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute("SELECT name, cnpj, address, latitude, longitude, is_available FROM company WHERE id = %s", (str(target_uuid),))
                    tgt = tgt_cur.fetchone()

                tgt_lat = float(tgt.get("latitude")) if tgt.get("latitude") is not None else None
                tgt_lon = float(tgt.get("longitude")) if tgt.get("longitude") is not None else None

                diff = (
                    name != tgt.get("name")
                    or cnpj != tgt.get("cnpj")
                    or address != tgt.get("address")
                    or (tgt_lat is None or abs(lat - tgt_lat) > 0.00001)
                    or (tgt_lon is None or abs(lon - tgt_lon) > 0.00001)
                    or is_available != tgt.get("is_available")
                )
                if diff:
                    with target_conn.cursor() as tgt_cur:
                        tgt_cur.execute(
                            """
                            UPDATE company 
                            SET name=%s, cnpj=%s, address=%s, latitude=%s, longitude=%s, is_available=%s 
                            WHERE id=%s
                            """,
                            (name, cnpj, address, lat, lon, is_available, str(target_uuid)),
                        )
            target_conn.commit()
            processed += 1
        except Exception as e:
            target_conn.rollback()
            logging.exception("Erro ao sincronizar company id %s", src_id)
            log_error(target_conn, run_id, "company", src_id, str(e))
            failed += 1

    return processed, failed

def sync_role(legacy_conn, target_conn, run_id: str) -> Tuple[int, int]:
    processed = failed = 0
    with legacy_conn.cursor() as src_cur:
        src_cur.execute("SELECT id, type FROM role")
        rows = src_cur.fetchall()
    for row in rows:
        src_id = row["id"]
        try:
            if not get_uuid_mapping(target_conn, "role", src_id):
                role_uuid = lookup_role_uuid(target_conn, row["type"])
                if not role_uuid:
                    raise ValueError(f"Tipo de role '{row['type']}' nao encontrado no destino")
                set_uuid_mapping(target_conn, "role", src_id, "role", role_uuid)
            processed += 1
        except Exception as e:
            logging.exception("Erro ao processar role id %s", src_id)
            log_error(target_conn, run_id, "role", src_id, str(e))
            failed += 1
    return processed, failed

def sync_waste_type(legacy_conn, target_conn, run_id: str) -> Tuple[int, int]:
    processed = failed = 0
    with legacy_conn.cursor() as src_cur:
        src_cur.execute("SELECT id, category FROM waste_type")
        rows = src_cur.fetchall()
    for row in rows:
        src_id = row["id"]
        try:
            if not get_uuid_mapping(target_conn, "waste_type", src_id):
                wt_uuid = lookup_waste_type_uuid(target_conn, row["category"])
                if not wt_uuid:
                    raise ValueError(f"Tipo de waste '{row['category']}' nao encontrado no destino")
                set_uuid_mapping(target_conn, "waste_type", src_id, "waste_type", wt_uuid)
            processed += 1
        except Exception as e:
            logging.exception("Erro ao processar waste_type id %s", src_id)
            log_error(target_conn, run_id, "waste_type", src_id, str(e))
            failed += 1
    return processed, failed

def sync_cooperative(legacy_conn, target_conn, run_id: str) -> Tuple[int, int]:
    processed = failed = 0
    with legacy_conn.cursor() as src_cur:
        src_cur.execute("SELECT * FROM cooperative")
        rows = src_cur.fetchall()

    for row in rows:
        src_id = row["id"]
        try:
            target_uuid = get_uuid_mapping(target_conn, "cooperative", src_id)
            
            name = row.get("name")
            cnpj = row.get("cnpj")
            
            # Puxa latitude e longitude
            raw_lat = row.get("latitude") if "latitude" in row else row.get("lat")
            raw_lon = row.get("longitude") if "longitude" in row else row.get("lon")
            lat = parse_coord(raw_lat, -23.550520)
            lon = parse_coord(raw_lon, -46.633308)

            email = row.get("email")
            if not email:
                clean_name = normalize_text(name).lower().replace(" ", "")[:15]
                email = f"contato@{clean_name or 'coop'}.volta.local"

            rating = float(row.get("average_rating") or 4.50)
            specialties = row.get("specialties") or "Reciclaveis em geral"

            if not target_uuid:
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute("SELECT id FROM cooperative WHERE cnpj = %s", (cnpj,))
                    existing = tgt_cur.fetchone()

                if existing:
                    target_uuid = uuid.UUID(str(existing["id"]))
                    with target_conn.cursor() as tgt_cur:
                        tgt_cur.execute(
                            """
                            UPDATE cooperative 
                            SET name=%s, email=%s, latitude=%s, longitude=%s, average_rating=%s, specialties=%s
                            WHERE id=%s
                            """,
                            (name, email, lat, lon, rating, specialties, str(target_uuid)),
                        )
                else:
                    target_uuid = uuid.uuid4()
                    with target_conn.cursor() as tgt_cur:
                        tgt_cur.execute(
                            """
                            INSERT INTO cooperative (id, name, cnpj, email, latitude, longitude, average_rating, specialties)
                            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                            """,
                            (str(target_uuid), name, cnpj, email, lat, lon, rating, specialties),
                        )
                set_uuid_mapping(target_conn, "cooperative", src_id, "cooperative", target_uuid)
            else:
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute("SELECT name, cnpj, email, latitude, longitude FROM cooperative WHERE id = %s", (str(target_uuid),))
                    tgt = tgt_cur.fetchone()

                tgt_lat = float(tgt.get("latitude")) if tgt.get("latitude") is not None else None
                tgt_lon = float(tgt.get("longitude")) if tgt.get("longitude") is not None else None

                diff = (
                    name != tgt.get("name")
                    or cnpj != tgt.get("cnpj")
                    or email != tgt.get("email")
                    or (tgt_lat is None or abs(lat - tgt_lat) > 0.00001)
                    or (tgt_lon is None or abs(lon - tgt_lon) > 0.00001)
                )
                if diff:
                    with target_conn.cursor() as tgt_cur:
                        tgt_cur.execute(
                            """
                            UPDATE cooperative 
                            SET name=%s, email=%s, latitude=%s, longitude=%s, average_rating=%s, specialties=%s 
                            WHERE id=%s
                            """,
                            (name, email, lat, lon, rating, specialties, str(target_uuid)),
                        )
            target_conn.commit()
            processed += 1
        except Exception as e:
            target_conn.rollback()
            logging.exception("Erro ao sincronizar cooperative id %s", src_id)
            log_error(target_conn, run_id, "cooperative", src_id, str(e))
            failed += 1

    return processed, failed

def sync_cooperative_waste_types(legacy_conn, target_conn, run_id: str) -> Tuple[int, int]:
    processed = failed = 0
    try:
        with legacy_conn.cursor() as src_cur:
            src_cur.execute("SELECT * FROM cooperative_waste_type")
            rows = src_cur.fetchall()
    except Exception:
        legacy_conn.rollback()
        return 0, 0

    for row in rows:
        c_id = row.get("cooperative_id")
        w_id = row.get("waste_type_id")
        try:
            target_coop = get_uuid_mapping(target_conn, "cooperative", c_id)
            target_wt = get_uuid_mapping(target_conn, "waste_type", w_id)

            if target_coop and target_wt:
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute(
                        """
                        INSERT INTO cooperative_waste_type (cooperative_id, waste_type_id)
                        VALUES (%s, %s)
                        ON CONFLICT DO NOTHING
                        """,
                        (str(target_coop), str(target_wt))
                    )
                set_relation_mapping(target_conn, "cooperative_waste_type", c_id, w_id, "cooperative_waste_type", target_coop, target_wt)
                processed += 1
        except Exception as e:
            target_conn.rollback()
            log_error(target_conn, run_id, "cooperative_waste_type", f"{c_id}:{w_id}", str(e))
            failed += 1

    target_conn.commit()
    return processed, failed

DEFAULT_PASSWORD_HASH = "$2b$10$j8Cq0C4oEwUfE9nI6dY2.uV0I5lA5N3l3wUvYm8v1E4K0X8Q9Z5b6"

def sync_users(legacy_conn, target_conn, run_id: str) -> Tuple[int, int]:
    processed = failed = 0
    with legacy_conn.cursor() as src_cur:
        src_cur.execute("SELECT * FROM users")
        rows = src_cur.fetchall()

    for row in rows:
        src_id = row["id"]
        try:
            target_uuid = get_uuid_mapping(target_conn, "users", src_id)

            company_id = row.get("company_id")
            cooperative_id = row.get("cooperative_id")
            role_id = row.get("role_id")

            comp_uuid = get_uuid_mapping(target_conn, "company", company_id) if company_id else None
            coop_uuid = get_uuid_mapping(target_conn, "cooperative", cooperative_id) if cooperative_id else None
            role_uuid = get_uuid_mapping(target_conn, "role", role_id) if role_id else None

            if not role_uuid:
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute("SELECT id FROM role ORDER BY id LIMIT 1")
                    default_role = tgt_cur.fetchone()
                    if default_role:
                        role_uuid = uuid.UUID(str(default_role["id"]))

            if comp_uuid and coop_uuid:
                coop_uuid = None
            elif not comp_uuid and not coop_uuid:
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute("SELECT id FROM company LIMIT 1")
                    fallback_comp = tgt_cur.fetchone()
                    if fallback_comp:
                        comp_uuid = uuid.UUID(str(fallback_comp["id"]))

            name = row.get("name")
            email = row.get("email")
            position = row.get("position") or "Colaborador"
            photo_url = row.get("photo_url")
            registered_at = row.get("registered_at") or datetime.now().date()

            if not target_uuid:
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute("SELECT id FROM users WHERE email = %s", (email,))
                    existing = tgt_cur.fetchone()

                if existing:
                    target_uuid = uuid.UUID(str(existing["id"]))
                else:
                    target_uuid = uuid.uuid4()
                    with target_conn.cursor() as tgt_cur:
                        tgt_cur.execute(
                            """
                            INSERT INTO users (
                                id, company_id, cooperative_id, role_id, 
                                name, email, password_hash, position, 
                                photo_url, registered_at, first_login
                            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                            """,
                            (
                                str(target_uuid),
                                str(comp_uuid) if comp_uuid else None,
                                str(coop_uuid) if coop_uuid else None,
                                str(role_uuid) if role_uuid else None,
                                name,
                                email,
                                DEFAULT_PASSWORD_HASH,
                                position,
                                photo_url,
                                registered_at,
                                False,
                            ),
                        )
                set_uuid_mapping(target_conn, "users", src_id, "users", target_uuid)
            else:
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute("SELECT * FROM users WHERE id = %s", (str(target_uuid),))
                    tgt = tgt_cur.fetchone()

                diff = (
                    name != tgt.get("name")
                    or position != tgt.get("position")
                    or photo_url != tgt.get("photo_url")
                )
                if diff:
                    with target_conn.cursor() as tgt_cur:
                        tgt_cur.execute(
                            """
                            UPDATE users 
                            SET name=%s, position=%s, photo_url=%s 
                            WHERE id=%s
                            """,
                            (name, position, photo_url, str(target_uuid)),
                        )
            target_conn.commit()
            processed += 1
        except Exception as e:
            target_conn.rollback()
            logging.exception("Erro ao sincronizar users id %s", src_id)
            log_error(target_conn, run_id, "users", src_id, str(e))
            failed += 1

    return processed, failed

def sync_area(legacy_conn, target_conn, run_id: str) -> Tuple[int, int]:
    processed = failed = 0
    with legacy_conn.cursor() as src_cur:
        src_cur.execute("SELECT id, company_id, sector_name, location_description FROM area")
        rows = src_cur.fetchall()
    for row in rows:
        src_id = row["id"]
        try:
            target_uuid = get_uuid_mapping(target_conn, "area", src_id)
            comp_uuid = get_uuid_mapping(target_conn, "company", row["company_id"])
            if not target_uuid:
                target_uuid = uuid.uuid4()
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute(
                        "INSERT INTO area (id, company_id, sector_name, location_description) VALUES (%s, %s, %s, %s)",
                        (str(target_uuid), str(comp_uuid) if comp_uuid else None, row["sector_name"], row["location_description"]),
                    )
                set_uuid_mapping(target_conn, "area", src_id, "area", target_uuid)
            else:
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute("SELECT * FROM area WHERE id = %s", (str(target_uuid),))
                    tgt = tgt_cur.fetchone()
                diff = any(row[col] != tgt[col] for col in ["sector_name", "location_description"])
                if diff or (comp_uuid and str(comp_uuid) != tgt.get("company_id")):
                    with target_conn.cursor() as tgt_cur:
                        tgt_cur.execute(
                            "UPDATE area SET company_id=%s, sector_name=%s, location_description=%s WHERE id=%s",
                            (str(comp_uuid) if comp_uuid else None, row["sector_name"], row["location_description"], str(target_uuid)),
                        )
            target_conn.commit()
            processed += 1
        except Exception as e:
            target_conn.rollback()
            logging.exception("Erro ao sincronizar area id %s", src_id)
            log_error(target_conn, run_id, "area", src_id, str(e))
            failed += 1
    return processed, failed

def sync_incident(legacy_conn, target_conn, run_id: str) -> Tuple[int, int]:
    processed = failed = 0
    with legacy_conn.cursor() as src_cur:
        src_cur.execute("SELECT * FROM incident")
        rows = src_cur.fetchall()

    for row in rows:
        src_id = row["id"]
        try:
            target_uuid = get_uuid_mapping(target_conn, "incident", src_id)
            comp_uuid = get_uuid_mapping(target_conn, "company", row.get("company_id"))
            user_uuid = get_uuid_mapping(target_conn, "users", row.get("user_id"))
            area_uuid = get_uuid_mapping(target_conn, "area", row.get("area_id"))

            if not comp_uuid:
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute("SELECT id FROM company LIMIT 1")
                    fb_comp = tgt_cur.fetchone()
                    if fb_comp:
                        comp_uuid = uuid.UUID(str(fb_comp["id"]))

            if not user_uuid:
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute("SELECT id FROM users LIMIT 1")
                    fb_user = tgt_cur.fetchone()
                    if fb_user:
                        user_uuid = uuid.UUID(str(fb_user["id"]))

            photo_url = row.get("photo_url")
            employee_description = row.get("employee_description") or row.get("description")
            contamination_level = row.get("contamination_level")
            estimated_quantity = row.get("estimated_quantity")
            priority = row.get("priority")
            status = row.get("status")
            registered_at = row.get("registered_at")
            ai_description = row.get("ai_description")
            title = row.get("title") or f"Incidente #{src_id}"
            change_reason = row.get("change_reason")

            if not target_uuid:
                target_uuid = uuid.uuid4()
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute(
                        """
                        INSERT INTO incident (
                            id, company_id, user_id, area_id, photo_url, 
                            employee_description, contamination_level, estimated_quantity, 
                            priority, status, registered_at, ai_description, title, change_reason
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        """,
                        (
                            str(target_uuid),
                            str(comp_uuid) if comp_uuid else None,
                            str(user_uuid) if user_uuid else None,
                            str(area_uuid) if area_uuid else None,
                            photo_url,
                            employee_description,
                            contamination_level,
                            estimated_quantity,
                            priority,
                            status,
                            registered_at,
                            ai_description,
                            title,
                            change_reason,
                        ),
                    )
                set_uuid_mapping(target_conn, "incident", src_id, "incident", target_uuid)
            else:
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute("SELECT * FROM incident WHERE id = %s", (str(target_uuid),))
                    tgt = tgt_cur.fetchone()

                diff = any(
                    row.get(col) != tgt.get(col)
                    for col in ["photo_url", "contamination_level", "estimated_quantity", "priority", "status"]
                )
                if diff:
                    with target_conn.cursor() as tgt_cur:
                        tgt_cur.execute(
                            """
                            UPDATE incident 
                            SET photo_url=%s, contamination_level=%s, estimated_quantity=%s, priority=%s, status=%s 
                            WHERE id=%s
                            """,
                            (photo_url, contamination_level, estimated_quantity, priority, status, str(target_uuid)),
                        )

            legacy_wt_id = row.get("waste_type_id")
            if legacy_wt_id:
                target_wt_uuid = get_uuid_mapping(target_conn, "waste_type", legacy_wt_id)
                if target_wt_uuid:
                    with target_conn.cursor() as tgt_cur:
                        tgt_cur.execute(
                            """
                            INSERT INTO incident_waste_type (incident_id, waste_type_id)
                            VALUES (%s, %s)
                            ON CONFLICT DO NOTHING
                            """,
                            (str(target_uuid), str(target_wt_uuid)),
                        )
                    set_relation_mapping(
                        target_conn,
                        "incident_waste_type",
                        src_id,
                        legacy_wt_id,
                        "incident_waste_type",
                        target_uuid,
                        target_wt_uuid
                    )

            target_conn.commit()
            processed += 1
        except Exception as e:
            target_conn.rollback()
            logging.exception("Erro ao sincronizar incident id %s", src_id)
            log_error(target_conn, run_id, "incident", src_id, str(e))
            failed += 1

    return processed, failed

def sync_collection(legacy_conn, target_conn, run_id: str) -> Tuple[int, int]:
    processed = failed = 0
    with legacy_conn.cursor() as src_cur:
        src_cur.execute("SELECT * FROM collection")
        rows = src_cur.fetchall()

    for row in rows:
        src_id = row["id"]
        try:
            collection_type = row.get("collection_type") or "STANDARD"

            target_uuid = get_uuid_mapping(target_conn, "collection", src_id)
            incident_uuid = get_uuid_mapping(target_conn, "incident", row.get("incident_id"))
            coop_uuid = get_uuid_mapping(target_conn, "cooperative", row.get("cooperative_id"))

            if not incident_uuid:
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute("SELECT id FROM incident LIMIT 1")
                    fb_inc = tgt_cur.fetchone()
                    if fb_inc:
                        incident_uuid = uuid.UUID(str(fb_inc["id"]))

            requested_at = (
                row.get("requested_at")
                or row.get("created_at")
                or row.get("date")
                or datetime.now()
            )
            scheduled_at = row.get("scheduled_at")
            current_status = row.get("current_status") or row.get("status") or "REQUESTED"
            urgent = bool(row.get("urgent", False))

            if not target_uuid:
                target_uuid = uuid.uuid4()
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute(
                        """
                        INSERT INTO collection (
                            id, incident_id, cooperative_id, requested_at, 
                            scheduled_at, current_status, collection_type, urgent
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                        """,
                        (
                            str(target_uuid),
                            str(incident_uuid) if incident_uuid else None,
                            str(coop_uuid) if coop_uuid else None,
                            requested_at,
                            scheduled_at,
                            current_status,
                            collection_type,
                            urgent,
                        ),
                    )
                set_uuid_mapping(target_conn, "collection", src_id, "collection", target_uuid)
            else:
                with target_conn.cursor() as tgt_cur:
                    tgt_cur.execute("SELECT * FROM collection WHERE id = %s", (str(target_uuid),))
                    tgt = tgt_cur.fetchone()

                diff = (
                    scheduled_at != tgt.get("scheduled_at")
                    or current_status != tgt.get("current_status")
                    or urgent != tgt.get("urgent")
                )
                if diff:
                    with target_conn.cursor() as tgt_cur:
                        tgt_cur.execute(
                            """
                            UPDATE collection 
                            SET scheduled_at=%s, current_status=%s, urgent=%s 
                            WHERE id=%s
                            """,
                            (scheduled_at, current_status, urgent, str(target_uuid)),
                        )
            target_conn.commit()
            processed += 1
        except Exception as e:
            target_conn.rollback()
            logging.exception("Erro ao sincronizar collection id %s", src_id)
            log_error(target_conn, run_id, "collection", src_id, str(e))
            failed += 1

    return processed, failed

def sync_deletions(legacy_conn, target_conn, table_name: str, run_id: str) -> int:
    deleted_count = 0
    try:
        with legacy_conn.cursor() as leg_cur:
            leg_cur.execute(f"SELECT id FROM {table_name}")
            active_legacy_ids = {row["id"] for row in leg_cur.fetchall()}

        with target_conn.cursor() as tgt_cur:
            tgt_cur.execute(
                "SELECT source_id, target_id FROM migration_id_map WHERE source_table = %s",
                (table_name,)
            )
            mapped_records = tgt_cur.fetchall()

        for record in mapped_records:
            src_id = int(record["source_id"])
            target_id = record["target_id"]

            if src_id not in active_legacy_ids:
                with target_conn.cursor() as del_cur:
                    del_cur.execute(f"DELETE FROM {table_name} WHERE id = %s", (str(target_id),))
                    del_cur.execute(
                        "DELETE FROM migration_id_map WHERE source_table = %s AND source_id = %s",
                        (table_name, src_id)
                    )
                deleted_count += 1

        target_conn.commit()
    except Exception as e:
        target_conn.rollback()
        logging.exception("Erro ao sincronizar delecoes na tabela %s", table_name)
        log_error(target_conn, run_id, table_name, "DELETE_BATCH", str(e))

    return deleted_count

# ---------------------------------------------------------------------------
# Loop principal
# ---------------------------------------------------------------------------
def main():
    logging.info("Daemon de migracao iniciado – intervalo %s segundos", SYNC_INTERVAL)
    while True:
        try:
            with DB(LEGACY_URL) as legacy_conn, DB(DATABASE_URL) as target_conn:
                if not advisory_lock(target_conn):
                    logging.warning("Outra instancia de migracao em execucao – ciclo ignorado")
                    time.sleep(SYNC_INTERVAL)
                    continue

                run_id = record_run_start(target_conn)
                total_processed = total_failed = 0

                for fn in [
                    sync_company,
                    sync_role,
                    sync_waste_type,
                    sync_cooperative,
                    sync_cooperative_waste_types,
                    sync_users,
                    sync_area,
                    sync_incident,
                    sync_collection,
                ]:
                    proc, fail = fn(legacy_conn, target_conn, run_id)
                    total_processed += proc
                    total_failed += fail

                for table in [
                    "collection",
                    "incident",
                    "area",
                    "users",
                    "cooperative",
                    "company"
                ]:
                    dels = sync_deletions(legacy_conn, target_conn, table, run_id)
                    if dels > 0:
                        logging.info("Deletados %d registros orfaos da tabela %s", dels, table)

                record_run_finish(
                    target_conn,
                    run_id,
                    success=(total_failed == 0),
                    migrated=total_processed,
                    failed=total_failed,
                    source_records=(total_processed + total_failed)
                )
                release_lock(target_conn)
                logging.info("Run %s concluido – processados %s, falhas %s", run_id, total_processed, total_failed)

        except Exception as e:
            logging.exception("Erro inesperado no loop de migracao: %s", e)

        time.sleep(SYNC_INTERVAL)


if __name__ == "__main__":
    main()