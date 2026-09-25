#!/usr/bin/env python3
"""
load_silver.py
ELT Pipeline Script: Creates Silver layer tables, transforms bronze data,
and loads cleaned/standardized records into PostgreSQL silver tables.
"""

import argparse
import os
import subprocess
import time
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BASE_DIR.parent

SILVER_TABLES = [
    "silver_crm_prd_info",
    "silver_crm_cust_info",
    "silver_erp_cust_az12",
    "silver_erp_loc_a101",
    "silver_crm_sales_details",
    "silver_erp_px_cat_g1v2",
]


def load_env():
    """Load simple KEY=VAL pairs from .env file into os.environ if present."""
    env_file = PROJECT_ROOT / ".env"
    if env_file.exists():
        with open(env_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    k, v = k.strip(), v.strip().strip("'\"")
                    if k not in os.environ:
                        os.environ[k] = v


def run_docker_psql(sql_command: str, db_user: str, db_name: str) -> str:
    """Executes a SQL command inside the postgres docker container via psql."""
    cmd = [
        "docker",
        "compose",
        "exec",
        "-T",
        "postgres",
        "psql",
        "-U",
        db_user,
        "-d",
        db_name,
        "-v",
        "ON_ERROR_STOP=1",
        "-c",
        sql_command,
    ]
    res = subprocess.run(cmd, cwd=str(PROJECT_ROOT), capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"Database command failed:\n{res.stderr.strip()}")
    return res.stdout


def ensure_postgres_running(db_user: str, db_name: str):
    """Checks if container is up and waits for PostgreSQL to be ready."""
    ps_cmd = [
        "docker",
        "compose",
        "ps",
        "--services",
        "--filter",
        "status=running",
    ]
    res = subprocess.run(ps_cmd, cwd=str(PROJECT_ROOT), capture_output=True, text=True)
    if "postgres" not in res.stdout:
        print("Starting postgres container via docker compose...")
        subprocess.run(["docker", "compose", "up", "-d"], cwd=str(PROJECT_ROOT), check=True)

    print("Waiting for PostgreSQL database to be healthy...")
    ready_cmd = [
        "docker",
        "compose",
        "exec",
        "-T",
        "postgres",
        "pg_isready",
        "-U",
        db_user,
        "-d",
        db_name,
    ]
    for _ in range(30):
        r = subprocess.run(ready_cmd, cwd=str(PROJECT_ROOT), capture_output=True)
        if r.returncode == 0:
            print("PostgreSQL is ready.")
            return
        time.sleep(1)
    raise TimeoutError("Timed out waiting for PostgreSQL container.")


def main():
    parser = argparse.ArgumentParser(description="ELT Silver Layer Data Transformation & Loader")
    parser.add_argument(
        "--check", action="store_true", help="Only check and display row counts without transforming"
    )
    args = parser.parse_args()

    load_env()
    db_user = os.environ.get("POSTGRES_USER", "postgres")
    db_name = os.environ.get("POSTGRES_DB", "elt_pipeline")

    print("=" * 65)
    print("        PostgreSQL ELT Pipeline: Silver Layer Loader      ")
    print(f" Database: {db_name} | User: {db_user}")
    print("=" * 65)

    ensure_postgres_running(db_user, db_name)

    # Make sure silver tables exist
    create_tables_sql = (BASE_DIR / "01_create_tables.sql").read_text()
    run_docker_psql(create_tables_sql, db_user, db_name)

    if not args.check:
        print("\nExecuting Silver layer transformation and loading...")
        start_time = time.perf_counter()

        transform_sql = (BASE_DIR / "02_transform_and_load.sql").read_text()
        run_docker_psql(transform_sql, db_user, db_name)

        elapsed = time.perf_counter() - start_time
        print(f"Silver layer transformed and loaded successfully in {elapsed:.2f} seconds!")

    # Display row count verification
    print("\n" + "=" * 65)
    print("                 Silver Table Row Counts                  ")
    print("=" * 65)
    summary_sql = " UNION ALL ".join(
        [
            f"SELECT '{tbl}' AS table_name, count(*) AS total_rows, MIN(dwh_created_at)::text AS sample_created_at FROM {tbl}"
            for tbl in SILVER_TABLES
        ]
    )
    output = run_docker_psql(summary_sql, db_user, db_name)
    print(output)


if __name__ == "__main__":
    main()
