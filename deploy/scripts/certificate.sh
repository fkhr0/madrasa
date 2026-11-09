#!/usr/bin/env bash
# HTTPS certificate from Let's Encrypt (free), and its renewal.
#   bash scripts/certificate.sh          first time (Nginx not running yet)
#   bash scripts/certificate.sh renew    what the daily timer runs
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a

if [[ "${1:-}" == "renew" ]]; then
  # Nginx serves the check files from certbot-www; then it reloads the new one.
  docker compose run --rm certbot renew --webroot -w /var/www/certbot --quiet
  docker compose exec nginx nginx -s reload
  exit 0
fi

# First time: certbot answers Let's Encrypt itself on port 80.
docker compose stop nginx 2>/dev/null || true
docker compose run --rm -p 80:80 certbot certonly --standalone \
  -d "$DOMAIN" --email "$CERT_EMAIL" --agree-tos --no-eff-email --non-interactive

# Renew by itself every day at 03:30 (only acts when under 30 days are left).
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
