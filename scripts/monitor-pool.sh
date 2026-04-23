#!/bin/bash

# Script: Monitor PgBouncer Connection Pool
# This script watches real-time connection pool statistics

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

QUERY="SHOW POOLS;"

run_monitor() {
echo "Connecting to PgBouncer monitoring database..."
echo ""
echo "Connection Pool Statistics:"
echo "============================"
echo ""

psql_admin -c "${QUERY}"

echo ""
echo "============================"
echo ""
echo "Legend:"
echo "  cl_active  = Active client connections"
echo "  cl_waiting = Waiting client connections"
echo "  sv_active  = Active backend connections"
echo "  sv_idle    = Idle backend connections in pool"
echo "  sv_used    = Recently used connections"
echo "  maxwait    = Max time a client waited for connection (ms)"
echo ""
}

if [[ "${1:-}" == "--watch" ]]; then
    while true; do
        clear
        run_monitor
        sleep 2
    done
else
    run_monitor
fi
