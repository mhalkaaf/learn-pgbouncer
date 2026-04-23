#!/bin/bash

set -euo pipefail

pg_isready \
    -h 127.0.0.1 \
    -p "${PGBOUNCER_LISTEN_PORT:-6432}" \
    -d pgbouncer
