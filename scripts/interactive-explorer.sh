#!/bin/bash

# Script: Interactive PgBouncer Query Explorer
# Allows you to run various diagnostic queries

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

show_menu() {
    echo ""
    echo "PgBouncer Diagnostic Menu"
    echo "=========================="
    echo "1. Show pool statistics"
    echo "2. Show active clients"
    echo "3. Show server connections"
    echo "4. Show general statistics"
    echo "5. Show recent queries"
    echo "6. Test connection from pool"
    echo "7. Show PgBouncer version"
    echo "8. Exit"
    echo ""
    echo -n "Enter choice [1-8]: "
}

pool_stats() {
    psql_admin -c "SHOW POOLS;"
}

active_clients() {
    psql_admin -c "SHOW CLIENTS;"
}

server_connections() {
    psql_admin -c "SHOW SERVERS;"
}

statistics() {
    psql_admin -c "SHOW STATS;"
}

recent_queries() {
    echo "Currently tracked PgBouncer queries:"
    psql_admin -c "SHOW FDS;" 2>/dev/null || echo "SHOW FDS is not available in this PgBouncer build"
}

test_connection() {
    echo "Testing connection through PgBouncer pool..."
    psql_pgbouncer << EOF
SELECT 
    'Connection successful!' as status,
    NOW() as timestamp,
    pg_backend_pid() as backend_pid,
    (SELECT version()) as server_version;
EOF
}

version() {
    psql_admin -c "SHOW VERSION;"
}

# Main loop
while true; do
    show_menu
    read choice
    
    case $choice in
        1) pool_stats ;;
        2) active_clients ;;
        3) server_connections ;;
        4) statistics ;;
        5) recent_queries ;;
        6) test_connection ;;
        7) version ;;
        8) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid choice!" ;;
    esac
done
