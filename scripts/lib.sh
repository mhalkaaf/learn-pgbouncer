#!/bin/bash

set -euo pipefail

COMPOSE="${COMPOSE:-docker compose}"
PGUSER="${PGUSER:-postgres}"
PGPASSWORD="${PGPASSWORD:-postgres_password}"
PGDATABASE="${PGDATABASE:-testdb}"

compose_exec() {
    ${COMPOSE} exec -T postgres "$@"
}

psql_direct() {
    compose_exec env PGPASSWORD="${PGPASSWORD}" psql -U "${PGUSER}" -d "${PGDATABASE}" "$@"
}

psql_pgbouncer() {
    compose_exec env PGPASSWORD="${PGPASSWORD}" psql -h pgbouncer -p 6432 -U "${PGUSER}" -d "${PGDATABASE}" "$@"
}

psql_admin() {
    compose_exec env PGPASSWORD="${PGPASSWORD}" psql -h pgbouncer -p 6432 -U "${PGUSER}" -d pgbouncer "$@"
}
