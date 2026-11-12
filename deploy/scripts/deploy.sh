#!/usr/bin/env bash
# Updates the app with no downtime: one API copy at a time, each must answer
# its health check before the next; if the new version fails, the old one
# comes back. GitHub Actions runs this after every push to main:
#   bash scripts/deploy.sh ghcr.io/<owner>/madrasa-api:<commit>
set -euo pipefail
cd "$(dirname "$0")/.."

NEW_IMAGE="${1:?the image to deploy, e.g. ghcr.io/owner/madrasa-api:abc123}"
OLD_IMAGE="$(grep -E '^IMAGE=' .env | cut -d= -f2- || true)"

healthy() {
  local service=$1
  for _ in $(seq 1 30); do
    local state
    state="$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q "$service")" 2>/dev/null || echo starting)"
    [[ "$state" == "healthy" ]] && return 0
    sleep 3
  done
  return 1
}

set_image() {
  if grep -qE '^IMAGE=' .env; then
    sed -i "s|^IMAGE=.*|IMAGE=$1|" .env
  else
    echo "IMAGE=$1" >> .env
  fi
}

rollback() {
  echo "The new version didn't become healthy: going back to $OLD_IMAGE" >&2
  set_image "$OLD_IMAGE"
  docker compose up -d --no-deps api1 api2 worker
  exit 1
}

echo "Deploying $NEW_IMAGE"
set_image "$NEW_IMAGE"
docker compose pull api1 api2 worker

# The rest of the stack (Redis, Nginx, monitoring) when its config changed.
docker compose up -d redis nginx prometheus alertmanager grafana loki promtail node-exporter cadvisor

# One copy at a time: Nginx sends everyone to the other meanwhile.
for service in api1 api2; do
  docker compose up -d --no-deps "$service"
  healthy "$service" || rollback
  echo "$service is healthy"
  # Nginx skips a copy for 10 s after it failed (fail_timeout): let it take
  # this one back before the other restarts, or both look down at once.
  sleep 12
done
docker compose up -d --no-deps worker

docker image prune -f >/dev/null
echo "Deployed $NEW_IMAGE"
