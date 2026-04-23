#!/bin/bash

# Quick Start Guide for PgBouncer Learning Environment

echo "================================================"
echo "PgBouncer Learning Environment - Quick Start"
echo "================================================"
echo ""

echo "📦 Prerequisites:"
echo "  - Docker with Docker Compose v2 installed"
echo ""

echo "🚀 Step 1: Start the environment"
echo "  $ make up"
echo ""

echo "⏳ Wait for containers to be healthy (10-15 seconds)"
echo "  $ docker compose ps"
echo ""

echo "✅ Step 2: Test the setup"
echo ""

echo "  Connection test (direct PostgreSQL):"
echo "    $ make connect-direct"
echo "    testdb=# SELECT pg_backend_pid();"
echo "    testdb=# \\q"
echo ""

echo "  Connection test (through PgBouncer):"
echo "    $ make connect"
echo "    testdb=# SELECT pg_backend_pid();"
echo "    testdb=# \\q"
echo ""

echo "📊 Step 3: Monitor the pool"
echo "  $ make monitor"
echo ""

echo "🧪 Step 4: Run tests"
echo ""
echo "  Test 1 - Connection stress test:"
echo "    $ bash scripts/stress-test.sh"
echo ""

echo "  Test 2 - Compare direct vs pooled connections:"
echo "    $ bash scripts/compare-connections.sh"
echo ""

echo "  Test 3 - Python performance analysis:"
echo "    $ python3 scripts/analyze-pooling.py"
echo ""

echo "  Test 4 - Interactive explorer:"
echo "    $ bash scripts/interactive-explorer.sh"
echo ""

echo "🧠 Step 5: Learn the components"
echo "  Read the comprehensive README.md:"
echo "    - Connection Pool concept"
echo "    - Pool Modes (Session, Transaction, Statement)"
echo "    - Authentication & User Management"
echo "    - Connection Timeouts & Lifecycle"
echo "    - Statistics & Monitoring"
echo "    - Transaction Safety"
echo ""

echo "🔧 Step 6: Experiment with configuration"
echo "  Edit pgbouncer/pgbouncer.ini to change:"
echo "    - pool_mode (transaction/session/statement)"
echo "    - default_pool_size"
echo "    - max_db_connections"
echo "    - timeouts"
echo ""
echo "  Then reload: make reload"
echo ""

echo "🛑 Step 7: Cleanup when done"
echo "  $ make down"
echo "  $ make down-clean  # Also remove volumes"
echo ""

echo "================================================"
echo "Happy Learning! 🎓"
echo "================================================"
