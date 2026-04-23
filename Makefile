COMPOSE ?= docker compose
PGPASSWORD ?= postgres_password

.PHONY: help up down down-clean logs logs-pgbouncer logs-postgres monitor connect connect-direct admin test-stress test-compare test-python explore edit-config edit-init reload quickstart learn clean

help:
	@echo "PgBouncer Learning Environment - Makefile Commands"
	@echo ""
	@echo "Setup:"
	@echo "  make up              - Start containers"
	@echo "  make down            - Stop containers"
	@echo "  make down-clean      - Stop containers and remove volumes"
	@echo ""
	@echo "Development:"
	@echo "  make logs            - View all logs"
	@echo "  make logs-pgbouncer  - View PgBouncer logs"
	@echo "  make logs-postgres   - View PostgreSQL logs"
	@echo ""
	@echo "Monitoring & Testing:"
	@echo "  make monitor         - Show pool statistics (continuous)"
	@echo "  make connect         - Connect to PgBouncer via psql"
	@echo "  make connect-direct  - Connect directly to PostgreSQL via psql"
	@echo "  make admin           - Open PgBouncer admin console"
	@echo "  make test-stress     - Run connection stress test"
	@echo "  make test-compare    - Compare direct vs pooled connections"
	@echo "  make test-python     - Run Python performance analysis"
	@echo "  make explore         - Open interactive diagnostic menu"
	@echo ""
	@echo "Configuration:"
	@echo "  make edit-config     - Edit pgbouncer.ini"
	@echo "  make edit-init       - Edit init.sql"
	@echo "  make reload          - Reload PgBouncer config"
	@echo ""
	@echo "Documentation:"
	@echo "  make quickstart      - Show quick start guide"

up:
	$(COMPOSE) up -d --build
	@echo "Waiting for containers to be healthy..."
	@sleep 10
	@$(COMPOSE) ps

down:
	$(COMPOSE) down

down-clean:
	$(COMPOSE) down -v

logs:
	$(COMPOSE) logs -f

logs-pgbouncer:
	$(COMPOSE) logs -f pgbouncer

logs-postgres:
	$(COMPOSE) logs -f postgres

monitor:
	bash scripts/monitor-pool.sh --watch

connect:
	$(COMPOSE) exec postgres env PGPASSWORD=$(PGPASSWORD) psql -h pgbouncer -p 6432 -U postgres -d testdb

connect-direct:
	$(COMPOSE) exec postgres env PGPASSWORD=$(PGPASSWORD) psql -U postgres -d testdb

admin:
	$(COMPOSE) exec postgres env PGPASSWORD=$(PGPASSWORD) psql -h pgbouncer -p 6432 -U postgres -d pgbouncer

test-stress:
	bash scripts/stress-test.sh

test-compare:
	bash scripts/compare-connections.sh

test-python:
	python3 scripts/analyze-pooling.py

explore:
	bash scripts/interactive-explorer.sh

edit-config:
	nano pgbouncer/pgbouncer.ini

edit-init:
	nano init.sql

reload:
	$(COMPOSE) exec postgres env PGPASSWORD=$(PGPASSWORD) psql -h pgbouncer -p 6432 -U postgres -d pgbouncer -c "RELOAD;"

quickstart:
	bash scripts/QUICKSTART.sh

# One-command learning path
learn: up
	@echo ""
	@echo "Environment started!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Read: cat LEARNING_GUIDE.md"
	@echo "2. Monitor: make monitor (in another terminal)"
	@echo "3. Test: make test-stress"
	@echo "4. Explore: make connect"
	@echo ""
