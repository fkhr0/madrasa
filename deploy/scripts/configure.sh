#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -f .env ]] || { echo "No .env: copy .env.example to .env and fill it in." >&2; exit 1; }
while IFS='=' read -r key value; do
  if [[ $key =~ ^[A-Z_][A-Z0-9_]*$ ]]; then export "$key=$value"; fi
done < .env

missing=()
for name in DOMAIN IMAGE DATABASE_URL JWT_ACCESS_SECRET JWT_REFRESH_SECRET \
            VAPID_PUBLIC_KEY VAPID_PRIVATE_KEY GRAFANA_PASSWORD CERT_EMAIL; do
  [[ -n "${!name:-}" ]] || missing+=("$name")
done
if ((${#missing[@]})); then
  echo "Fill these in .env: ${missing[*]}" >&2
  exit 1
fi

if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
  envsubst '${TELEGRAM_BOT_TOKEN} ${TELEGRAM_CHAT_ID}' \
    < monitoring/alertmanager/alertmanager.yml.template \
    > monitoring/alertmanager/alertmanager.yml
  chmod 600 monitoring/alertmanager/alertmanager.yml
else
  printf 'route:\n  receiver: none\nreceivers:\n  - name: none\n' > monitoring/alertmanager/alertmanager.yml
fi
chmod 600 .env
echo "Settings look complete."
