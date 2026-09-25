#!/usr/bin/env bash
# ==============================================================================
# Script: load_gold.sh
# Purpose: Creates and refreshes Gold layer views for Star Schema analytics.
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
echo "          ELT Pipeline: Gold Layer View Loader              "
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
echo "[1/3] Checking PostgreSQL container status..."
if ! docker compose ps --services --filter "status=running" | grep -q "^${SERVICE_NAME}$"; then
  echo "PostgreSQL container is not running. Starting it now..."
  docker compose up -d
fi

# Wait for PostgreSQL to become ready
echo "[2/3] Waiting for database to be ready..."
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

# Create Gold layer views
echo "[3/3] Creating Gold layer views in schema 'gold'..."
START_TIME=$(date +%s%N)

docker compose exec -T "${SERVICE_NAME}" psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 < "$SCRIPT_DIR/01_create_gold_views.sql"

END_TIME=$(date +%s%N)
DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))

echo ""
echo "============================================================"
echo "                   Gold Views Summary                       "
echo "============================================================"

# Verification query to check counts in all gold views
docker compose exec -T "${SERVICE_NAME}" psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -P border=2 << 'EOF'
SELECT 
    'gold.dim_customers' AS view_name, 
    COUNT(*) AS total_rows 
FROM gold.dim_customers
UNION ALL
SELECT 
    'gold.dim_products', 
    COUNT(*) 
FROM gold.dim_products
UNION ALL
SELECT 
    'gold.fact_sales', 
    COUNT(*) 
FROM gold.fact_sales;
EOF

echo "Gold views created successfully in ${DURATION_MS} ms!"
echo "============================================================"
