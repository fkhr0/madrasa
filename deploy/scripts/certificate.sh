#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
while IFS='=' read -r key value; do
  if [[ $key =~ ^[A-Z_][A-Z0-9_]*$ ]]; then export "$key=$value"; fi
done < .env

if [[ "${1:-}" == "renew" ]]; then
  docker compose run --rm certbot renew --webroot -w /var/www/certbot --quiet
  docker compose exec nginx nginx -s reload
  exit 0
fi

docker compose stop nginx 2>/dev/null || true
docker compose run --rm -p 80:80 certbot certonly --standalone \
  -d "$DOMAIN" --email "$CERT_EMAIL" --agree-tos --no-eff-email --non-interactive

sudo tee /etc/systemd/system/madrasa-cert.service >/dev/null <<EOF
[Unit]
Description=Renew the HTTPS certificate
[Service]
Type=oneshot
User=$USER
ExecStart=/usr/bin/bash $(pwd)/scripts/certificate.sh renew
EOF
sudo tee /etc/systemd/system/madrasa-cert.timer >/dev/null <<'EOF'
[Unit]
Description=Renew the HTTPS certificate daily
[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true
[Install]
WantedBy=timers.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now madrasa-cert.timer
echo "Certificate ready for $DOMAIN; renewal timer on."
