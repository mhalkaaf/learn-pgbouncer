# Component Overview: PgBouncer Architecture

## What is PgBouncer?

PgBouncer is a **lightweight connection pooler for PostgreSQL**. It sits between your applications and PostgreSQL database, managing connections efficiently.

```
Your Applications → PgBouncer → PostgreSQL Database
   (many clients)   (smart pooler)    (single process per conn)
```

---

## 🏗️ Core Components Explained

### 1. CONNECTION POOL MANAGER
**Location:** Core of PgBouncer process
**Function:** Maintains pools of idle backend connections

```
┌──────────────────────────────────┐
│     PgBouncer Connection Pool     │
├──────────────────────────────────┤
│ Database: testdb, User: postgres │
│  [Backend Conn 1] (idle)         │
│  [Backend Conn 2] (idle)         │
│  [Backend Conn 3] (in use)       │
│  [Backend Conn 4] (in use)       │
└──────────────────────────────────┘
  ↑                              ↑
  └──────────────────────────────┘
     Queue of waiting clients
```

**Why?** Creating a new database connection is expensive (~300ms). Reusing idle connections is fast (~1ms).

---

### 2. CLIENT CONNECTION HANDLER
**Responsibility:** Accept connections from applications

**What happens when a client connects:**
```
Client (app) → TCP connection to PgBouncer:6432
              ↓
         PgBouncer receives connection
              ↓
         Verify credentials in userlist.txt
              ↓
         If valid: Assign from pool or create new backend connection
         If invalid: Reject
```

**Configuration:** `listen_addr`, `listen_port`, `max_user_connections`

---

### 3. POOL MODES (Query Routing Strategy)
**Where:** Determined by `pool_mode` in pgbouncer.ini

#### Mode: SESSION (least pooling)
```
Timeline:
Client 1: CONNECT → BEGIN → SELECT → UPDATE → ROLLBACK → DISCONNECT
          [Using Backend Conn A for entire session]

Result: No connection reuse between sessions
```

#### Mode: TRANSACTION (default - best balance)
```
Timeline:
Client 1: CONNECT → BEGIN → SELECT → COMMIT → (Conn returned to pool)
          [Using Backend Conn A]
          BEGIN → SELECT → COMMIT → (Same conn or different from pool)
          [Using Backend Conn B (reused!)]

Result: Good connection reuse within transactions
```

#### Mode: STATEMENT (aggressive pooling)
```
Timeline:
Client 1: SELECT x (Backend Conn A) → returned to pool
          SELECT y (Backend Conn B) → returned to pool
          SELECT z (Backend Conn A) → returned to pool

Result: Maximum connection reuse
```

---

### 4. AUTHENTICATION LAYER
**Files:**
- `pgbouncer/userlist.txt` - User credentials
- `pgbouncer/pgbouncer.ini` - Auth settings

**Process:**
```
Client sends: "postgres" / "postgres_password"
                     ↓
         PgBouncer reads userlist.txt
                     ↓
         Match found! Credentials valid
                     ↓
         PgBouncer connects to PostgreSQL with configured credentials
                     ↓
         Client is authenticated, traffic flows
```

**Format in userlist.txt:**
```
"username" "password"
```

---

### 5. QUERY DISPATCHER
**Responsibility:** Route queries to correct backend connection

```
Client SQL: SELECT * FROM users
                  ↓
        PgBouncer receives query
                  ↓
        Determine: Which backend connection for this client?
                  ↓
        [Transaction mode] → Get from pool or wait
        [Session mode] → Use client's assigned connection
        [Statement mode] → Get from pool for single query
                  ↓
        Route to backend → Execute
                  ↓
        Return results to client
                  ↓
        [Transaction/Statement] → Return connection to pool
        [Session] → Keep connection with client
```

---

### 6. TIMEOUT MANAGEMENT
**Configuration parameters:**

| Component | Setting | Default | Purpose |
|-----------|---------|---------|---------|
| **Client Connection** | `client_idle_timeout` | 600s | Drop inactive clients |
| **Backend Connection** | `server_lifetime` | 3600s | Recycle old connections |
| **Connection Attempt** | `server_connect_timeout` | 15s | Give up on slow backend connections |
| **Idle Transaction** | `idle_in_transaction_session_timeout` | 900s | Close stalled transactions |
| **Query Wait** | `query_wait_timeout` | 120s | Max wait for pool connection |

**Timeline with timeouts:**
```
t=0s:   Client connects
        ↓
t=300s: No activity → Still connected (< idle_timeout)
        ↓
t=600s: Still idle → Client disconnected by PgBouncer
        ↓

OR if transaction starts:
t=0s:   BEGIN
        ↓
t=100s: SELECT (idle_in_transaction counter resets)
        ↓
t=900s: IDLE (no queries) → Connection/transaction killed
```

---

### 7. MONITORING & STATISTICS
**Special pgbouncer database** provides visibility:

```sql
-- Connection pool state
SHOW POOLS;
-- Shows: active clients, waiting clients, idle backend connections

-- Live clients
SHOW CLIENTS;
-- Shows: who's connected, where they're from, how long

-- Backend connections
SHOW SERVERS;
-- Shows: connection pool state, reuse count

-- Aggregate statistics
SHOW STATS;
-- Shows: query counts, bytes transferred, timing statistics
```

**Key metrics to watch:**
```
waiting_clients > 0  → Pool exhausted, clients waiting
sv_idle = 0         → All connections busy
total_query_time    → Aggregate query duration
```

---

### 8. RESOURCE MANAGEMENT
**Memory usage determined by:**
```
Memory ≈ (max_db_connections × connection_size) + overhead

Example with default settings:
  100 backend connections × ~1-2MB per connection = 100-200MB
  Plus client connections, buffers, etc.
```

**File descriptors:**
```
Needed for:
  - Each client connection (1 fd)
  - Each backend connection (1 fd)
  - Configuration files
  - Listening socket
```

---

## 🔄 Complete Request Flow Example

```
Application sends: SELECT * FROM users
                        ↓
          TCP packet arrives at PgBouncer:6432
                        ↓
         [CLIENT HANDLER]
          Extract query, verify connection valid
                        ↓
         [POOL MANAGER]
          Check transaction status → transaction mode
          Look for idle backend connection
                        ↓
         Available backend connection found!
                        ↓
         [QUERY DISPATCHER]
          Send query to backend via PostgreSQL protocol
                        ↓
         PostgreSQL processes query
                        ↓
         Results returned to PgBouncer
                        ↓
         Results forwarded to client
                        ↓
         [TRANSACTION COMPLETE]
          Backend connection marked as idle
          Connection returned to pool
                        ↓
         Application receives results
```

---

## ⚙️ Configuration Hierarchy

```
pgbouncer.ini
    ├─ [databases] section
    │   └─ Maps database names to actual PostgreSQL databases
    │
    └─ [pgbouncer] section
        ├─ Connection limits
        │   ├─ max_db_connections (per database+user)
        │   ├─ max_user_connections (per user)
        │   ├─ default_pool_size (target idle connections)
        │   └─ reserve_pool_size (for spikes)
        │
        ├─ Pool behavior
        │   ├─ pool_mode (session/transaction/statement)
        │   └─ Various timeouts
        │
        ├─ Connection settings
        │   ├─ listen_addr, listen_port
        │   ├─ server_connect_timeout
        │   └─ server_lifetime
        │
        ├─ Authentication
        │   ├─ auth_type (md5, plain, etc.)
        │   └─ auth_file (userlist.txt location)
        │
        └─ Operations
            ├─ admin_users (can run admin commands)
            ├─ stats_users (can query stats)
            ├─ log settings
            └─ stats_period
```

---

## 🎯 Key Concepts Summary

| Concept | What | Why | How |
|---------|------|-----|-----|
| **Connection Pooling** | Reuse connections | Fast response | Backend conn queue |
| **Pool Mode** | How connections allocated | Different use cases | session/transaction/statement |
| **Timeouts** | Connection lifecycle | Prevent resource waste | Configured parameters |
| **Authentication** | Verify identity | Security | userlist.txt |
| **Monitoring** | pgbouncer database | Visibility | Query special tables |
| **Resource Limits** | max_connections | Prevent exhaustion | Configuration settings |

---

## 📊 Performance Benefits

**Without PgBouncer:**
```
100 clients × 10 queries each = 1000 connections to PostgreSQL
Each connection = ~300ms setup + process overhead
Result: High latency, high memory usage
```

**With PgBouncer:**
```
100 clients → 25 pooled connections (4:1 ratio)
Connections reused = ~1ms connection assignment
Result: Lower latency, lower memory, higher throughput
```

---

Now you understand the architecture! Dive into the configuration and monitoring to see it in action. 🚀
