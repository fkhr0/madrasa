#!/usr/bin/env bash
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

docker compose up -d redis prometheus alertmanager grafana loki promtail node-exporter cadvisor

NGINX_SUM="$(cat nginx/nginx.conf nginx/templates/* | sha256sum | cut -d' ' -f1)"
if [[ "$NGINX_SUM" != "$(cat .nginx-config-sum 2>/dev/null || true)" ]]; then
  if docker compose run --rm --no-deps nginx nginx -t >/dev/null 2>&1; then
    docker compose up -d --force-recreate nginx
    echo "$NGINX_SUM" > .nginx-config-sum
  else
    echo "nginx config check failed, nginx keeps the old config:" >&2
    docker compose run --rm --no-deps nginx nginx -t >&2 || true
  fi
else
  docker compose up -d nginx
fi

for service in api1 api2; do
  docker compose up -d --no-deps "$service"
  healthy "$service" || rollback
  echo "$service is healthy"
  sleep 12
done
docker compose up -d --no-deps worker

docker image prune -f >/dev/null
echo "Deployed $NEW_IMAGE"
