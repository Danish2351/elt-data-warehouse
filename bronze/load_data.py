#!/usr/bin/env python3
"""
load_data.py
ELT Pipeline Script: Truncates PostgreSQL tables and reloads data from CSV files.
Can be executed with standard Python without requiring external database drivers.
"""

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BASE_DIR.parent

# Table to CSV file mapping
TABLE_MAPPING = [
    {
        "table": "bronze_crm_sales_details",
        "csv_host_path": PROJECT_ROOT / "datasets/source_crm/sales_details.csv",
        "csv_container_path": "/datasets/source_crm/sales_details.csv",
        "columns": [
            "sls_ord_num",
            "sls_prd_key",
            "sls_cust_id",
            "sls_order_dt",
            "sls_ship_dt",
            "sls_due_dt",
            "sls_sales",
            "sls_quantity",
            "sls_price",
        ],
    },
    {
        "table": "bronze_crm_prd_info",
        "csv_host_path": PROJECT_ROOT / "datasets/source_crm/prd_info.csv",
        "csv_container_path": "/datasets/source_crm/prd_info.csv",
        "columns": [
            "prd_id",
            "prd_key",
            "prd_nm",
            "prd_cost",
            "prd_line",
            "prd_start_dt",
            "prd_end_dt",
        ],
    },
    {
        "table": "bronze_crm_cust_info",
        "csv_host_path": PROJECT_ROOT / "datasets/source_crm/cust_info.csv",
        "csv_container_path": "/datasets/source_crm/cust_info.csv",
        "columns": [
            "cst_id",
            "cst_key",
            "cst_firstname",
            "cst_lastname",
            "cst_marital_status",
            "cst_gndr",
            "cst_create_date",
        ],
    },
    {
        "table": "bronze_erp_cust_az12",
        "csv_host_path": PROJECT_ROOT / "datasets/source_erp/CUST_AZ12.csv",
        "csv_container_path": "/datasets/source_erp/CUST_AZ12.csv",
        "columns": ["cid", "bdate", "gen"],
    },
    {
        "table": "bronze_erp_loc_a101",
        "csv_host_path": PROJECT_ROOT / "datasets/source_erp/LOC_A101.csv",
        "csv_container_path": "/datasets/source_erp/LOC_A101.csv",
        "columns": ["cid", "cntry"],
    },
    {
        "table": "bronze_erp_px_cat_g1v2",
        "csv_host_path": PROJECT_ROOT / "datasets/source_erp/PX_CAT_G1V2.csv",
        "csv_container_path": "/datasets/source_erp/PX_CAT_G1V2.csv",
        "columns": ["id", "cat", "subcat", "maintenance"],
    },
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
    parser = argparse.ArgumentParser(description="ELT Truncate & Load CSV to PostgreSQL")
    parser.add_argument(
        "--check", action="store_true", help="Only check and display row counts without loading"
    )
    args = parser.parse_args()

    load_env()
    db_user = os.environ.get("POSTGRES_USER", "postgres")
    db_name = os.environ.get("POSTGRES_DB", "elt_pipeline")

    print("=" * 65)
    print("           PostgreSQL ELT Pipeline Data Loader            ")
    print(f" Database: {db_name} | User: {db_user}")
    print("=" * 65)

    ensure_postgres_running(db_user, db_name)

    # Make sure tables exist
    create_tables_sql = (BASE_DIR / "01_create_tables.sql").read_text()
    run_docker_psql(create_tables_sql, db_user, db_name)

    if not args.check:
        print("\nTruncating tables and loading CSV data...")
        start_time = time.perf_counter()

        for item in TABLE_MAPPING:
            tbl = item["table"]
            c_path = item["csv_container_path"]
            cols = ", ".join(item["columns"])
            print(f" -> Truncating and loading table: {tbl} ... ", end="", flush=True)

            sql = f"""
            TRUNCATE TABLE {tbl};
            COPY {tbl} ({cols})
            FROM '{c_path}'
            WITH (FORMAT csv, HEADER true, NULL '');
            """
            t0 = time.perf_counter()
            run_docker_psql(sql, db_user, db_name)
            elapsed = (time.perf_counter() - t0) * 1000
            print(f"done ({elapsed:.1f} ms)")

        total_elapsed = time.perf_counter() - start_time
        print(f"\nAll tables loaded successfully in {total_elapsed:.2f} seconds!")

    # Display row count verification
    print("\n" + "=" * 65)
    print("                    Table Row Counts                      ")
    print("=" * 65)
    summary_sql = " UNION ALL ".join(
        [
            f"SELECT '{item['table']}' AS table_name, count(*) AS total_rows FROM {item['table']}"
            for item in TABLE_MAPPING
        ]
    )
    output = run_docker_psql(summary_sql, db_user, db_name)
    print(output)


if __name__ == "__main__":
    main()
