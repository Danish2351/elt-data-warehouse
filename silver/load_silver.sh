#!/usr/bin/env bash
# ==============================================================================
# Script: load_silver.sh
# Purpose: Creates Silver layer tables, transforms bronze data, and loads silver.
# ==============================================================================

set -euo pipefail

# Script directory & project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Load environment variables if .env exists
if [ -f "$PROJECT_ROOT/.env" ]; then
  set -a
  source "$PROJECT_ROOT/.env"
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-elt_pipeline}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
SERVICE_NAME="postgres"

echo "============================================================"
echo "          ELT Pipeline: Silver Layer Data Loader            "
echo "============================================================"
echo "Database:  ${POSTGRES_DB}"
echo "User:      ${POSTGRES_USER}"
echo "Port:      ${POSTGRES_PORT}"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo "Error: 'docker' command not found. Please install Docker." >&2
  exit 1
fi

# Ensure Postgres container is up and running
echo "[1/4] Checking PostgreSQL container status..."
if ! docker compose ps --services --filter "status=running" | grep -q "^${SERVICE_NAME}$"; then
  echo "PostgreSQL container is not running. Starting it now..."
  docker compose up -d
fi

# Wait for PostgreSQL to become ready
echo "[2/4] Waiting for database to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0
until docker compose exec -T "${SERVICE_NAME}" pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" &> /dev/null; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
    echo "Error: Timed out waiting for PostgreSQL to be ready." >&2
    exit 1
  fi
  sleep 1
done
echo "PostgreSQL is ready!"

# Ensure silver tables exist
echo "[3/4] Ensuring Silver layer tables are created..."
docker compose exec -T "${SERVICE_NAME}" psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 < "$SCRIPT_DIR/01_create_tables.sql" > /dev/null

# Transform and load silver data
echo "[4/4] Transforming bronze data into silver tables..."
START_TIME=$(date +%s%N)

docker compose exec -T "${SERVICE_NAME}" psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 < "$SCRIPT_DIR/02_transform_and_load.sql"

END_TIME=$(date +%s%N)
DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))

echo ""
echo "============================================================"
echo "                   Silver Load Summary                      "
echo "============================================================"

# Verification query to check counts in all silver tables
docker compose exec -T "${SERVICE_NAME}" psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -P border=2 << 'EOF'
SELECT 
    'silver_crm_prd_info' AS table_name, 
    COUNT(*) AS total_rows,
    MIN(dwh_created_at)::text AS sample_dwh_created_at
FROM silver_crm_prd_info
UNION ALL
SELECT 
    'silver_crm_cust_info', 
    COUNT(*),
    MIN(dwh_created_at)::text
FROM silver_crm_cust_info
UNION ALL
SELECT 
    'silver_erp_cust_az12', 
    COUNT(*),
    MIN(dwh_created_at)::text
FROM silver_erp_cust_az12
UNION ALL
SELECT 
    'silver_erp_loc_a101', 
    COUNT(*),
    MIN(dwh_created_at)::text
FROM silver_erp_loc_a101
UNION ALL
SELECT 
    'silver_crm_sales_details', 
    COUNT(*),
    MIN(dwh_created_at)::text
FROM silver_crm_sales_details
UNION ALL
SELECT 
    'silver_erp_px_cat_g1v2', 
    COUNT(*),
    MIN(dwh_created_at)::text
FROM silver_erp_px_cat_g1v2;
EOF

echo "Silver load completed successfully in ${DURATION_MS} ms!"
echo "============================================================"
