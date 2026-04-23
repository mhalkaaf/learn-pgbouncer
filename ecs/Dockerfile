FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    pgbouncer \
    postgresql-client \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /etc/pgbouncer /var/run/pgbouncer \
    && chown -R postgres:postgres /etc/pgbouncer /var/run/pgbouncer

COPY entrypoint.sh /usr/local/bin/pgbouncer-entrypoint
COPY healthcheck.sh /usr/local/bin/pgbouncer-healthcheck

RUN chmod +x /usr/local/bin/pgbouncer-entrypoint /usr/local/bin/pgbouncer-healthcheck

EXPOSE 6432

USER postgres

ENTRYPOINT ["/usr/local/bin/pgbouncer-entrypoint"]
CMD ["pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
