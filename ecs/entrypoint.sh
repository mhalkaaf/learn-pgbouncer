#!/bin/bash

set -euo pipefail

required_vars=(
    RDS_HOST
    RDS_DB
    RDS_USER
    RDS_PASSWORD
)

for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo "Missing required environment variable: ${var}" >&2
        exit 1
    fi
done

RDS_PORT="${RDS_PORT:-5432}"
PGBOUNCER_LISTEN_PORT="${PGBOUNCER_LISTEN_PORT:-6432}"
PGBOUNCER_DATABASE_ALIAS="${PGBOUNCER_DATABASE_ALIAS:-${RDS_DB}}"
PGBOUNCER_AUTH_TYPE="${PGBOUNCER_AUTH_TYPE:-plain}"
PGBOUNCER_POOL_MODE="${PGBOUNCER_POOL_MODE:-transaction}"
PGBOUNCER_MAX_CLIENT_CONN="${PGBOUNCER_MAX_CLIENT_CONN:-1000}"
PGBOUNCER_DEFAULT_POOL_SIZE="${PGBOUNCER_DEFAULT_POOL_SIZE:-20}"
PGBOUNCER_MIN_POOL_SIZE="${PGBOUNCER_MIN_POOL_SIZE:-5}"
PGBOUNCER_RESERVE_POOL_SIZE="${PGBOUNCER_RESERVE_POOL_SIZE:-10}"
PGBOUNCER_MAX_DB_CONNECTIONS="${PGBOUNCER_MAX_DB_CONNECTIONS:-80}"
PGBOUNCER_MAX_USER_CONNECTIONS="${PGBOUNCER_MAX_USER_CONNECTIONS:-500}"
PGBOUNCER_QUERY_WAIT_TIMEOUT="${PGBOUNCER_QUERY_WAIT_TIMEOUT:-120}"
PGBOUNCER_SERVER_CONNECT_TIMEOUT="${PGBOUNCER_SERVER_CONNECT_TIMEOUT:-15}"
PGBOUNCER_SERVER_LIFETIME="${PGBOUNCER_SERVER_LIFETIME:-3600}"
PGBOUNCER_SERVER_IDLE_TIMEOUT="${PGBOUNCER_SERVER_IDLE_TIMEOUT:-600}"
PGBOUNCER_CLIENT_IDLE_TIMEOUT="${PGBOUNCER_CLIENT_IDLE_TIMEOUT:-600}"
PGBOUNCER_ADMIN_USERS="${PGBOUNCER_ADMIN_USERS:-${RDS_USER}}"
PGBOUNCER_STATS_USERS="${PGBOUNCER_STATS_USERS:-${RDS_USER}}"

APP_DB_USER="${APP_DB_USER:-${RDS_USER}}"
APP_DB_PASSWORD="${APP_DB_PASSWORD:-${RDS_PASSWORD}}"

cat > /etc/pgbouncer/pgbouncer.ini <<EOF
[databases]
${PGBOUNCER_DATABASE_ALIAS} = host=${RDS_HOST} port=${RDS_PORT} dbname=${RDS_DB} user=${RDS_USER} password=${RDS_PASSWORD}

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = ${PGBOUNCER_LISTEN_PORT}
auth_type = ${PGBOUNCER_AUTH_TYPE}
auth_file = /etc/pgbouncer/userlist.txt
admin_users = ${PGBOUNCER_ADMIN_USERS}
stats_users = ${PGBOUNCER_STATS_USERS}
pool_mode = ${PGBOUNCER_POOL_MODE}
max_client_conn = ${PGBOUNCER_MAX_CLIENT_CONN}
default_pool_size = ${PGBOUNCER_DEFAULT_POOL_SIZE}
min_pool_size = ${PGBOUNCER_MIN_POOL_SIZE}
reserve_pool_size = ${PGBOUNCER_RESERVE_POOL_SIZE}
max_db_connections = ${PGBOUNCER_MAX_DB_CONNECTIONS}
max_user_connections = ${PGBOUNCER_MAX_USER_CONNECTIONS}
query_wait_timeout = ${PGBOUNCER_QUERY_WAIT_TIMEOUT}
server_connect_timeout = ${PGBOUNCER_SERVER_CONNECT_TIMEOUT}
server_lifetime = ${PGBOUNCER_SERVER_LIFETIME}
server_idle_timeout = ${PGBOUNCER_SERVER_IDLE_TIMEOUT}
client_idle_timeout = ${PGBOUNCER_CLIENT_IDLE_TIMEOUT}
server_reset_query = DISCARD ALL
log_connections = 1
log_disconnections = 1
ignore_startup_parameters = extra_float_digits
EOF

if [[ -n "${PGBOUNCER_USERLIST_RAW:-}" ]]; then
    printf "%b\n" "${PGBOUNCER_USERLIST_RAW}" > /etc/pgbouncer/userlist.txt
else
    printf '"%s" "%s"\n' "${APP_DB_USER}" "${APP_DB_PASSWORD}" > /etc/pgbouncer/userlist.txt
fi

chmod 0600 /etc/pgbouncer/pgbouncer.ini /etc/pgbouncer/userlist.txt

exec "$@"
