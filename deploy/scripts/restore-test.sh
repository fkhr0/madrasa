#!/usr/bin/env bash
# Proves the backups work: restores the newest nightly dump into a throwaway
# PostgreSQL and counts what came back. A backup nobody restored isn't one.
#   bash scripts/restore-test.sh
set -euo pipefail
cd "$(dirname "$0")/.."

dump="$(docker compose exec -T worker sh -c 'ls -1t /data/backups/*.dump 2>/dev/null | head -1')"
[[ -n "$dump" ]] || { echo "No dump yet (the worker makes one at 02:00)." >&2; exit 1; }
echo "Newest dump: $dump"

docker compose exec -T worker cat "$dump" > /tmp/restore-test.dump
docker run -d --rm --name restore-test -e POSTGRES_PASSWORD=test postgres:18-alpine >/dev/null
trap 'docker stop restore-test >/dev/null; rm -f /tmp/restore-test.dump' EXIT
until docker exec restore-test pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done

docker cp /tmp/restore-test.dump restore-test:/tmp/backup.dump
docker exec restore-test pg_restore -U postgres -d postgres --no-owner /tmp/backup.dump
docker exec restore-test psql -U postgres -At -c \
  "SELECT 'schools', count(*) FROM institutions UNION ALL
   SELECT 'people', count(*) FROM users UNION ALL
   SELECT 'messages', count(*) FROM messages UNION ALL
   SELECT 'migrations', count(*) FROM schema_migrations"
echo "Restore worked."
