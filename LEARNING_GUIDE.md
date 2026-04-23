# 🎓 PgBouncer Learning Guide

Welcome to your PgBouncer learning environment! This guide will help you navigate all the resources and understand pgbouncer from the ground up.

## 📚 Documentation Structure

### 1. **Start Here**: [README.md](README.md)
- Quick start instructions
- Architecture overview
- Pool modes explained with diagrams
- Configuration reference
- Learning exercises

**Time to read:** 20 minutes

---

### 2. **Components Deep Dive**: [COMPONENTS.md](COMPONENTS.md)
- Detailed explanation of each internal component
- Request flow diagrams
- Configuration hierarchy
- Performance benefits explained

**Time to read:** 15 minutes

---

### 3. **Configuration Files**
Located in `pgbouncer/` directory:

#### `pgbouncer.ini`
- Main configuration file
- All parameters explained with current values
- Covers: databases, pools, timeouts, authentication

#### `userlist.txt`
- User credentials for PgBouncer
- Simple format: `"username" "password"`

#### `init.sql`
- Database initialization script
- Creates test schema and sample data
- Runs automatically when PostgreSQL starts

---

## 🧪 Learning Hands-On Exercises

### Phase 1: Setup & Basic Understanding (10 minutes)

```bash
# Start the environment
make up

# Wait for health checks to pass
docker compose ps

# Test direct PostgreSQL connection
make connect-direct

# Test PgBouncer connection
make connect
```

✅ Both work! But one goes through connection pooling.

---

### Phase 2: Monitor & Observe (15 minutes)

**Terminal 1 - Watch the connection pool:**
```bash
make monitor
```

**Terminal 2 - Generate activity:**
```bash
bash scripts/stress-test.sh
```

**What to observe:**
- `cl_active` increases when you run stress test
- `sv_active` shows how many backend connections are being used
- `sv_idle` shows connections waiting in the pool

---

### Phase 3: Compare Approaches (10 minutes)

**See the difference between direct vs pooled:**
```bash
bash scripts/compare-connections.sh
```

**What to notice:**
- Direct PostgreSQL: Many different PIDs (each query gets new connection)
- Through PgBouncer: Same PIDs repeated (connections reused)

---

### Phase 4: Python Performance Test (10 minutes)

**Benchmark concurrent queries:**
```bash
python3 scripts/analyze-pooling.py
```

**Outputs:**
- Total query time (PgBouncer usually faster)
- Connection reuse statistics
- Backend PID distribution (shows pooling in action)

---

### Phase 5: Interactive Exploration (20 minutes)

**Launch the interactive explorer:**
```bash
bash scripts/interactive-explorer.sh
```

Menu options:
1. Show pool statistics
2. Show active clients
3. Show server connections
4. Show general statistics
5. Recent queries
6. Test connection
7. Show version

Try all options to get familiar with monitoring tables!

---

## 🔬 Key Experiments to Try

### Experiment 1: Pool Mode Behavior

**Current setup uses: Transaction Mode**

```bash
# In pgbouncer/pgbouncer.ini, try changing:
pool_mode = statement  # or session, or transaction

# Restart PgBouncer:
docker compose restart pgbouncer

# Re-run tests and observe differences
bash scripts/compare-connections.sh
```

### Experiment 2: Connection Limits

```bash
# Change in pgbouncer.ini:
default_pool_size = 3  # Reduce from 5

# Restart and run stress test:
docker compose restart pgbouncer
bash scripts/stress-test.sh
```

**Observe:** Pool exhaustion, waiting clients increase.

### Experiment 3: Timeouts

```bash
# Start a long-running query
make connect
BEGIN;
SELECT pg_sleep(700);  -- Sleep 700 seconds (longer than timeout)

# In another terminal, wait and watch what happens
# Check: client_idle_timeout = 600, so connection should close
```

### Experiment 4: Session Variables in Transaction Mode

```bash
# Connection through PgBouncer (transaction mode)
make connect

-- Set a session variable
SET search_path = 'testschema';

-- Query works (uses testschema)
SELECT * FROM users;

-- After COMMIT, new transaction gets different connection!
COMMIT;
BEGIN;

-- This might fail or act differently because connection changed!
SELECT * FROM users;  -- Using default search_path now?

-- Always use schema-qualified names or set in same transaction
```

---

## 📊 Monitoring Queries Cheat Sheet

```bash
# Connect to monitoring database
make admin

# View pool statistics
SHOW POOLS;

# View active clients
SHOW CLIENTS;

# View backend connections
SHOW SERVERS;

# View aggregate statistics
SHOW STATS;

# Show version
SELECT version();

# Reload configuration (without restart)
RELOAD;

# Show running queries
SHOW FDS;

# Disconnect all clients
CLOSE DATABASE testdb;

# Shutdown PgBouncer (graceful)
SHUTDOWN;
```

---

## 🎯 Learning Milestones

### ✅ Beginner (Day 1)
- [x] Understand what PgBouncer is
- [x] Set up Docker environment
- [x] Successfully connect via PgBouncer
- [x] See pool statistics
- [x] Run stress test

**Checkpoint:** Can you explain connection pooling to a friend?

### ✅ Intermediate (Day 2)
- [x] Understand all 3 pool modes
- [x] Know when to use each mode
- [x] Modify configuration and observe effects
- [x] Monitor pool statistics
- [x] Identify bottlenecks

**Checkpoint:** Can you predict pool behavior before changing config?

### ✅ Advanced (Day 3+)
- [x] Optimize configuration for specific workloads
- [x] Understand transaction safety issues
- [x] Design pool sizing for production
- [x] Monitor and analyze metrics
- [x] Troubleshoot issues

**Checkpoint:** Can you design a pooler setup for a real application?

---

## 🚨 Common Issues & Debugging

### Issue: Can't connect to PgBouncer
```bash
# Check if containers are running
docker compose ps

# Check logs
docker compose logs pgbouncer

# Verify port is available
lsof -i :6432
```

### Issue: "Connection pool exhausted"
```sql
-- In pgbouncer database:
SHOW POOLS;
-- Check: cl_waiting > 0 indicates clients waiting for connection

-- Solution: Increase pool size in pgbouncer.ini:
-- default_pool_size = 8  (increase from 5)
```

### Issue: Queries failing in transaction mode
```sql
-- Don't rely on session state:
SET search_path = 'testschema';  -- ❌ Lost after COMMIT

-- Better:
SET search_path = 'testschema';
SELECT * FROM users;  -- In same transaction, fine
COMMIT;
SELECT * FROM testschema.users;  -- Schema-qualified, always works
```

### Issue: PgBouncer using too much memory
```bash
# Check current limits in pgbouncer.ini:
# max_db_connections = 10
# default_pool_size = 5

# Reduce:
# max_db_connections = 8
# default_pool_size = 3

docker compose restart pgbouncer
```

---

## 📖 Additional Learning Resources

### In This Repository:
- `pgbouncer/pgbouncer.ini` - Fully commented configuration
- `init.sql` - Database schema setup
- `docker compose.yml` - Complete environment definition
- `scripts/` - Practical testing tools

### External Resources:
- **Official Documentation:** https://www.pgbouncer.org/
- **Configuration Guide:** https://www.pgbouncer.org/config.html
- **Pool Modes Detailed:** https://www.pgbouncer.org/features.html
- **PostgreSQL Connection Management:** https://www.postgresql.org/docs/current/runtime-config-connection.html

---

## 💡 Pro Tips

1. **Always set `pool_mode` explicitly** - Don't rely on defaults
2. **Monitor before tuning** - Use queries to understand current behavior
3. **Use transaction mode for web apps** - Best balance of pooling and compatibility
4. **Watch for waiting clients** - Sign that pool is too small
5. **Test configuration changes** - Use scripts to benchmark
6. **Keep connections short** - Reduces pool pressure
7. **Use prepared statements** - Only in session/transaction modes, not statement mode
8. **Monitor memory usage** - Each connection consumes memory

---

## 🧹 Cleanup

```bash
# Stop containers
docker compose down

# Remove volumes (delete data)
docker compose down -v

# Check what's running
docker compose ps
```

---

## 🎓 Next Steps After Learning

Once you master this environment, try:

1. **Upgrade to PostgreSQL High Availability:**
   - Add replication
   - Configure PgBouncer for multi-server setup

2. **Add Monitoring:**
   - Prometheus for metrics
   - Grafana for dashboards

3. **Real-world scenarios:**
   - Simulate traffic spikes
   - Test failover behavior
   - Performance tuning

4. **Production Hardening:**
   - SSL/TLS connections
   - Security best practices
   - Backup strategies

---

## 📞 Questions to Ask Yourself

As you learn, test your understanding:

1. Why does PgBouncer exist? What problem does it solve?
2. What's the difference between session and transaction mode?
3. When would statement mode be useful?
4. What happens when the pool is exhausted?
5. How do timeouts protect your system?
6. Why can't you use session variables in transaction mode?
7. How does PgBouncer know which connection to use?
8. What's the cost of a connection to PostgreSQL?

---

Happy learning! 🚀

Start with README.md, then follow the exercises above. Questions? Check COMPONENTS.md for deep dives!
