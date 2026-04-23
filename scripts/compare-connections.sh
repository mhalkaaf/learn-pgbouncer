#!/bin/bash

# Script: Compare Direct PostgreSQL vs PgBouncer
# Shows the difference in connection management

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

QUERIES="${1:-12}"

echo "Connection Comparison: PostgreSQL vs PgBouncer"
echo "=============================================="
echo ""

# Direct PostgreSQL connection
echo "1. Checking PostgreSQL directly (port 5432):"
echo "   Trying ${QUERIES} simultaneous queries..."
for i in $(seq 1 "${QUERIES}"); do
    psql_direct \
        -c "SELECT ${i} AS query_id, 'direct' AS source, pg_sleep(1), pg_backend_pid() AS backend_pid;" 2>/dev/null &
done
wait
echo ""

# Through PgBouncer
echo "2. Same ${QUERIES} queries through PgBouncer (port 6432):"
echo "   Trying ${QUERIES} simultaneous queries..."
for i in $(seq 1 "${QUERIES}"); do
    psql_pgbouncer \
        -c "SELECT ${i} AS query_id, 'pgbouncer' AS source, pg_sleep(1), pg_backend_pid() AS backend_pid;" 2>/dev/null &
done
wait
echo ""

echo "Note: Backend PIDs show which actual PostgreSQL process handled the query"
echo "- Direct: Each query gets a unique PID (new connections)"
echo "- PgBouncer: PIDs reuse (connection pooling in action!)"
