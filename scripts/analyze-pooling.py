#!/usr/bin/env python3

"""
PgBouncer Connection Pool Analyzer

This script intentionally uses `docker compose exec postgres psql` instead of a
local PostgreSQL driver. That keeps the learning environment self-contained:
Docker is the only required runtime dependency.
"""

import concurrent.futures
import os
import re
import subprocess
import sys
import time


COMPOSE = os.environ.get("COMPOSE", "docker compose").split()
PGUSER = os.environ.get("PGUSER", "postgres")
PGPASSWORD = os.environ.get("PGPASSWORD", "postgres_password")
PGDATABASE = os.environ.get("PGDATABASE", "testdb")
QUERY_COUNT = int(os.environ.get("QUERY_COUNT", "20"))
MAX_WORKERS = int(os.environ.get("MAX_WORKERS", "10"))


class PoolTester:
    def __init__(self, use_pgbouncer=True):
        self.use_pgbouncer = use_pgbouncer
        self.connection_type = "PgBouncer" if use_pgbouncer else "PostgreSQL"

    def command(self, query_id):
        sql = (
            "SELECT "
            f"{query_id} AS query_id, "
            "pg_backend_pid() AS backend_pid, "
            "COUNT(*) AS row_count "
            "FROM testschema.users;"
        )

        if self.use_pgbouncer:
            target = ["-h", "pgbouncer", "-p", "6432"]
        else:
            target = []

        return [
            *COMPOSE,
            "exec",
            "-T",
            "postgres",
            "env",
            f"PGPASSWORD={PGPASSWORD}",
            "psql",
            *target,
            "-U",
            PGUSER,
            "-d",
            PGDATABASE,
            "-At",
            "-F",
            ",",
            "-c",
            sql,
        ]

    def run_query(self, query_id):
        start = time.time()
        proc = subprocess.run(
            self.command(query_id),
            text=True,
            capture_output=True,
            check=False,
        )
        elapsed = time.time() - start

        if proc.returncode != 0:
            return {"query_id": query_id, "error": proc.stderr.strip()}

        match = re.search(r"^(\d+),(\d+),(\d+)$", proc.stdout.strip(), re.MULTILINE)
        if not match:
            return {
                "query_id": query_id,
                "error": f"Unexpected psql output: {proc.stdout.strip()}",
            }

        return {
            "query_id": int(match.group(1)),
            "backend_pid": int(match.group(2)),
            "row_count": int(match.group(3)),
            "elapsed": elapsed,
        }

    def test_concurrent_queries(self, num_queries=QUERY_COUNT):
        print(f"\n{'=' * 64}")
        print(f"Testing {self.connection_type}: {num_queries} concurrent client sessions")
        print(f"{'=' * 64}")

        start = time.time()
        results = []
        errors = []
        backend_pids = {}

        with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            futures = [executor.submit(self.run_query, i) for i in range(1, num_queries + 1)]
            for future in concurrent.futures.as_completed(futures):
                result = future.result()
                if "error" in result:
                    errors.append(result)
                    continue
                results.append(result)
                backend_pids[result["backend_pid"]] = backend_pids.get(result["backend_pid"], 0) + 1

        total_time = time.time() - start

        if errors:
            print("\nErrors:")
            for error in errors[:5]:
                print(f"  Query {error['query_id']}: {error['error']}")
            if len(errors) > 5:
                print(f"  ...and {len(errors) - 5} more")

        if not results:
            raise RuntimeError(f"No successful queries for {self.connection_type}")

        elapsed_values = [result["elapsed"] for result in results]
        reuse = ((len(results) - len(backend_pids)) / len(results)) * 100

        print("\nResults Summary:")
        print(f"  Successful queries: {len(results)}")
        print(f"  Total wall time: {total_time:.3f}s")
        print(f"  Average client session time: {sum(elapsed_values) / len(elapsed_values):.3f}s")
        print(f"  Min client session time: {min(elapsed_values):.3f}s")
        print(f"  Max client session time: {max(elapsed_values):.3f}s")

        print("\nBackend Connection Reuse:")
        print(f"  Unique PostgreSQL backend PIDs: {len(backend_pids)}")
        print(f"  Connection reuse: {reuse:.1f}%")
        print("  PID distribution:")
        for pid, count in sorted(backend_pids.items()):
            print(f"    PID {pid}: {count} queries")

        return {
            "total_time": total_time,
            "avg_time": sum(elapsed_values) / len(elapsed_values),
            "unique_pids": len(backend_pids),
            "reuse": reuse,
        }


def compare_performance():
    print("\nPgBouncer vs Direct PostgreSQL Comparison")
    direct_results = PoolTester(use_pgbouncer=False).test_concurrent_queries()
    time.sleep(1)
    pooled_results = PoolTester(use_pgbouncer=True).test_concurrent_queries()

    print(f"\n{'=' * 64}")
    print("Comparison")
    print(f"{'=' * 64}")
    print(f"{'Metric':<32} {'Direct':<14} {'PgBouncer':<14}")
    print("-" * 64)
    print(f"{'Total wall time':<32} {direct_results['total_time']:.3f}s{'':<7} {pooled_results['total_time']:.3f}s")
    print(f"{'Avg client session time':<32} {direct_results['avg_time']:.3f}s{'':<7} {pooled_results['avg_time']:.3f}s")
    print(f"{'Unique backend PIDs':<32} {direct_results['unique_pids']:<14} {pooled_results['unique_pids']:<14}")
    print(f"{'Connection reuse':<32} {direct_results['reuse']:.1f}%{'':<8} {pooled_results['reuse']:.1f}%")


if __name__ == "__main__":
    try:
        compare_performance()
    except KeyboardInterrupt:
        print("\nTest interrupted")
        sys.exit(130)
    except Exception as exc:
        print(f"Error: {exc}")
        sys.exit(1)
