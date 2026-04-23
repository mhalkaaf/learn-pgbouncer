#!/bin/bash

# Script: Test PgBouncer Connection Pooling
# This script creates multiple connections to demonstrate pooling

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

CONNECTIONS="${1:-30}"
SLEEP_SECONDS="${2:-2}"

echo "Starting connection pool stress test..."
echo "This will create ${CONNECTIONS} parallel client connections through PgBouncer"
echo "Each query sleeps for ${SLEEP_SECONDS}s so SHOW POOLS has something to observe"
echo ""

# Function to run a query
run_query() {
    local query_num=$1
    psql_pgbouncer \
        -c "SELECT ${query_num} AS query_number, pg_sleep(${SLEEP_SECONDS}), pg_backend_pid() AS backend_pid;" 2>/dev/null
}

# Create parallel connections
for i in $(seq 1 "${CONNECTIONS}"); do
    run_query "${i}" &
done

# Wait for all to complete
wait

echo ""
echo "Test completed! Check with: ./monitor-pool.sh"
