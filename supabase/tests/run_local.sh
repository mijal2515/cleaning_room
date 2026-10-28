#!/usr/bin/env bash
# 임시 Postgres를 띄워 마이그레이션 + 시드 + 테스트를 실행한다.
# Supabase CLI(도커)가 없는 환경에서 SQL만 빠르게 검사하는 용도.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
pg_bin="${PG_BIN:-$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -1)}"
data="$(mktemp -d)"
port="${PG_PORT:-54329}"

if [ "$(id -u)" = "0" ]; then
  chown -R postgres "$data"
  as_pg() { su postgres -c "$*"; }
else
  as_pg() { bash -c "$*"; }
fi

cleanup() { as_pg "$pg_bin/pg_ctl -D $data -m immediate stop" >/dev/null 2>&1 || true; rm -rf "$data"; }
trap cleanup EXIT

as_pg "$pg_bin/initdb -D $data -U postgres -A trust" >/dev/null
as_pg "$pg_bin/pg_ctl -D $data -o '-p $port -k /tmp' -l $data/log -w start" >/dev/null

psql_run() { psql -h /tmp -p "$port" -U postgres -d postgres -v ON_ERROR_STOP=1 -q "$@"; }

psql_run -f "$here/local_stub.sql"
for f in "$root"/migrations/*.sql; do psql_run -f "$f"; done
psql_run -f "$root/seed.sql"
psql_run -f "$here/rls_and_rewards.sql"
