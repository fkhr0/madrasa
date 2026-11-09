#!/usr/bin/env bash
# Checks .env and writes the files made from it (Alertmanager's, with the
# Telegram bot's token). Run in /opt/madrasa/deploy after editing .env.
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -f .env ]] || { echo "No .env: copy .env.example to .env and fill it in." >&2; exit 1; }
set -a; source .env; set +a

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
  # No Telegram yet: alerts are kept in Alertmanager (see them in Grafana).
  printf 'route:\n  receiver: none\nreceivers:\n  - name: none\n' > monitoring/alertmanager/alertmanager.yml
fi
chmod 600 .env
echo "Settings look complete."
