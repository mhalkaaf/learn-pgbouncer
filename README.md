# PgBouncer Learning Environment

Welcome! This Docker environment is designed to help you understand how **PgBouncer** works and learn its key components.

## 📋 Quick Start

### Start the environment:
```bash
make up
```

### Stop the environment:
```bash
make down
```

### View logs:
```bash
make logs-pgbouncer
make logs-postgres
```

### Deploy to ECS:
```bash
# See ECS container, task, service, and Azure Pipelines templates
ls ecs
```

The production-oriented deployment assets live in [`ecs/`](ecs/README.md), and the Azure Pipelines definition is [`azure-pipelines.yml`](azure-pipelines.yml).

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                  Client Applications            │
│         (psql, Python, Node.js, etc.)           │
└─────────────────────┬───────────────────────────┘
                      │
                      │ TCP Port 6432
                      ▼
┌─────────────────────────────────────────────────┐
│            PgBouncer (Connection Pooler)        │
│  • Connection Pool Management                   │
│  • Query Routing                                │
│  • Statistics & Monitoring                      │
└─────────────────────┬───────────────────────────┘
                      │
                      │ TCP Port 5432
                      ▼
┌─────────────────────────────────────────────────┐
│         PostgreSQL Database Server              │
│  • Persistent Storage                           │
│  • Query Processing                             │
│  • Authentication                               │
└─────────────────────────────────────────────────┘
```

---

## 🔧 Key Components of PgBouncer

### 1. **Connection Pool**
The core feature of PgBouncer that reuses database connections.

**Why it matters:**
- PostgreSQL creates a new process for each connection (expensive)
- PgBouncer maintains a pool of persistent backend connections
- Client connections are mapped to backend connections efficiently
- Reduces connection overhead significantly

**Pool Configuration (in `pgbouncer.ini`):**
```ini
max_db_connections = 10       # Small lab limit so queueing is visible
default_pool_size = 5         # Main pool size per database/user pair
min_pool_size = 1             # Keep at least this many ready
reserve_pool_size = 2         # Extra for temporary spikes
```

---

### 2. **Pool Modes**
Controls how connections are allocated to clients.

#### **Session Mode** (least pooling)
```
┌─────────┐              ┌──────────────────┐
│ Client  │ ←──────────→ │ Backend Conn     │
│ Session │              │ (tied for entire │
└─────────┘              │  client session) │
                         └──────────────────┘
```
- One backend connection per client
- Connection lives for the entire client session
- Best for: Simple applications, minimal concurrency
- Pros: No session state issues
- Cons: No real pooling benefit

#### **Transaction Mode** (moderate pooling) ⭐ **Default in our setup**
```
┌──────────┐             ┌──────────────────┐
│ Client 1 ├──┐          │                  │
│          │  └─→ [Backend 1]              │
└──────────┘          │                  │
                      │ Pool of 5        │
┌──────────┐          │ connections      │
│ Client 2 ├──┐   ├───→ [Backend 2]      │
│          │  └─→ │     ...             │
└──────────┘  ┌─→ [Backend N]             │
                         └──────────────────┘
```
- Backend connection returned to pool after each transaction
- Most efficient for web applications
- Pros: Good pooling, works with most applications
- Cons: Cannot use session-level features (prepared statements, temp tables)

#### **Statement Mode** (aggressive pooling)
```
┌──────────┐   
│ Client 1 ├──┐ Query 1 → [Backend 1] → return
│          │  └─ Query 2 → [Backend 2] → return
│          │  ┌─ Query 3 → [Backend 3] → return
└──────────┘  └─
```
- Backend connection returned after each query
- Maximum pooling efficiency
- Pros: Best connection reuse
- Cons: Cannot use transactions, multi-statement queries, or prepared statements

---

### 3. **Authentication & User Management**

**Files involved:**
- `userlist.txt` - Contains user credentials (password hash or plaintext)
- `pgbouncer.ini` - `auth_type` and `auth_file` settings

**How it works:**
1. Client connects to PgBouncer with username/password
2. PgBouncer verifies against `userlist.txt`
3. If valid, PgBouncer creates/reuses a backend connection to PostgreSQL
4. PgBouncer authenticates to PostgreSQL (can use different credentials)

**User file format:**
```
"username" "password_or_hash"
```

---

### 4. **Connection Timeouts & Lifecycle**

Key settings in `pgbouncer.ini`:

| Setting | Value | Purpose |
|---------|-------|---------|
| `server_connect_timeout` | 15s | Max time to establish backend connection |
| `server_lifetime` | 3600s | Max age of backend connection |
| `client_idle_timeout` | 600s | Disconnect idle client after 600s |
| `idle_in_transaction_session_timeout` | 900s | Close idle transactions |
| `query_wait_timeout` | 120s | Max time client waits for connection from pool |

**Connection Lifecycle:**
```
Client connects (client_idle_timeout: 600s)
         ↓
Assigned backend connection (server_lifetime: 3600s)
         ↓
Query executes
         ↓
[Transaction mode] → Connection returned to pool
[Session mode] → Connection stays with client
         ↓
Client disconnects OR timeout reached
         ↓
Connection closed/recycled
```

---

### 5. **Statistics & Monitoring**

PgBouncer provides a special `pgbouncer` database for monitoring:

```bash
make admin

# View pool statistics
SHOW POOLS;

# View active clients
SHOW CLIENTS;

# View server connections
SHOW SERVERS;

# View statistics
SHOW STATS;
```

**Key metrics:**
- `client_connections` - Active client connections
- `server_connections` - Backend connections in pool
- `waiting_clients` - Clients waiting for a connection
- `total_query_count` - Queries processed
- `avg_query_time` - Average query duration

---

### 6. **Query Routing & Load Distribution**

How PgBouncer handles queries:

```
┌─────────────┐
│  Client Q1  │
└────────┬────┘
         │ SELECT ... FROM users
         ▼
   ┌──────────────┐
   │ PgBouncer    │
   │ • Verifies   │
   │ • Routes     │
   │ • Assigns    │
   └──────┬───────┘
          │
          ▼
    ┌─────────────────────┐
    │ Backend Connection  │
    │ (from pool)         │
    └─────────┬───────────┘
              │
              ▼
    ┌─────────────────────┐
    │ PostgreSQL Database │
    │ Executes query      │
    └──────────┬──────────┘
               │
               ▼
          Results back through PgBouncer to Client
```

---

### 7. **Transaction Safety**

**Transaction Isolation:**
- PgBouncer operates at the connection level
- Each transaction is isolated (ACID properties preserved)
- Session-level state is NOT shared between connections in transaction mode

**Session Variables Impact (Transaction Mode):**
```sql
-- ❌ Don't do this in transaction mode:
BEGIN;
SET search_path TO 'myschema';
SELECT * FROM users;  -- Uses set search_path
COMMIT;
-- Next transaction might get different connection without search_path set!
```

**Better approach:**
```sql
-- ✅ Do this:
BEGIN;
SET search_path TO 'myschema';  -- Set in same transaction
SELECT * FROM users;
COMMIT;
-- Or use schema-qualified names:
SELECT * FROM testschema.users;
```

---

## 🧪 Learning Exercises

### Exercise 1: Connect through PgBouncer

```bash
# Direct connection to PostgreSQL (port 5432)
make connect-direct

# Connection through PgBouncer (port 6432)
make connect
```

Both work! But through PgBouncer, you're reusing backend connections.

### Exercise 2: Monitor Active Connections

Terminal 1 - Watch pool statistics:
```bash
make monitor
```

Terminal 2 - Create some activity:
```bash
make test-stress
```

Observe how PgBouncer manages connections!

### Exercise 3: Pool Mode Behavior

In transaction mode (current setup), test:
```bash
make connect

BEGIN;
CREATE TEMP TABLE test (id INT);  -- ❌ This might be lost!
COMMIT;
```

### Exercise 4: Connection Timeout

```bash
# Start a long transaction
make connect
BEGIN;
SELECT pg_sleep(1000);  -- Sleep 1000 seconds

-- In another terminal, check what happens after idle timeout
```

---

## 📊 Configuration Deep Dive

### `pgbouncer.ini` Settings Explained

```ini
[databases]
# Maps virtual database names to real PostgreSQL databases
# Format: dbname = host=... port=... dbname=... user=... password=...

[pgbouncer]
# Core PgBouncer settings

listen_addr = 0.0.0.0          # Listen on all interfaces
listen_port = 6432            # PgBouncer port

pool_mode = transaction        # See "Pool Modes" section above

max_db_connections = 10        # Total backend connections to a database
default_pool_size = 5          # Main pool size per database/user pair
min_pool_size = 1              # Keep at least this many
reserve_pool_size = 2          # Extra for spikes

server_connect_timeout = 15    # Backend connection timeout
server_lifetime = 3600         # Recycle backend connections after 1 hour

client_idle_timeout = 600      # Drop idle clients after 10 min
idle_in_transaction_session_timeout = 900  # Close idle txns after 15 min

stats_period = 15              # Update stats every 15 seconds
```

---

## 🚀 Next Steps

1. **Experiment**: Modify `pgbouncer.ini` and observe effects
2. **Monitor**: Use `make monitor` or `SHOW STATS` to track connection behavior
3. **Load Test**: Create scripts to simulate realistic workloads
4. **Performance**: Compare direct PostgreSQL vs through PgBouncer
5. **Production**: Learn about SSL, security, and HA setups

---

## 📝 Troubleshooting

### PgBouncer won't start
```bash
docker compose logs pgbouncer
# Check pgbouncer.ini syntax
```

### Can't connect to PgBouncer
```bash
# Verify it's running
docker compose ps

# Check logs
docker compose logs pgbouncer

# Test connection
make connect
```

### Connection pool exhausted
- Check `max_db_connections` and `default_pool_size`
- Monitor with `make monitor` / `SHOW POOLS`
- Increase limits or reduce client connections

---

## 📚 Additional Resources

- **Official Docs**: https://www.pgbouncer.org/config.html
- **Pool Modes Guide**: https://www.pgbouncer.org/features.html
- **Configuration Details**: https://www.pgbouncer.org/config.html

---

Happy learning! 🚀
