#!/usr/bin/env bash
# One-time setup of a fresh Ubuntu 24.04 server (Oracle Cloud). Run as the
# default "ubuntu" user, over SSH:
#   curl -fsSL <raw url of this file> | bash      (or copy it and: bash server-setup.sh)
#
# What it does:
#   1. updates, automatic security updates, fail2ban
#   2. SSH hardening: keys only, no root, few tries
#   3. firewall: 80/443 open; SSH and Grafana only over Tailscale (after lock-ssh.sh)
#   4. Docker (with log rotation) and Tailscale
#   5. /opt/madrasa for the app
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Run as the normal user (ubuntu), not root: it uses sudo." >&2
  exit 1
fi
APP_DIR=/opt/madrasa

echo "== 1. Updates and security packages"
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  unattended-upgrades fail2ban iptables-persistent ca-certificates curl gettext-base jq
# Security updates install themselves every night.
sudo dpkg-reconfigure -f noninteractive unattended-upgrades

echo "== 2. SSH hardening"
sudo tee /etc/ssh/sshd_config.d/99-madrasa.conf >/dev/null <<'EOF'
# Keys only: no passwords to guess.
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
# Nobody logs in as root; admins use sudo.
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowAgentForwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
sudo sshd -t && sudo systemctl reload ssh

# fail2ban: 5 failed SSH logins = banned for an hour.
sudo tee /etc/fail2ban/jail.d/sshd.local >/dev/null <<'EOF'
[sshd]
enabled = true
maxretry = 5
bantime = 1h
findtime = 10m
EOF
sudo systemctl enable --now fail2ban

echo "== 3. Firewall (the server's own; Oracle's cloud firewall is the other layer)"
# Oracle's Ubuntu images come with iptables rules that reject everything but
# SSH: add the web ports before that REJECT rule, and the Tailscale network.
for port in 80 443; do
  sudo iptables -C INPUT -p tcp --dport "$port" -m state --state NEW -j ACCEPT 2>/dev/null \
    || sudo iptables -I INPUT 5 -p tcp --dport "$port" -m state --state NEW -j ACCEPT
done
sudo iptables -C INPUT -i tailscale0 -j ACCEPT 2>/dev/null || sudo iptables -I INPUT 5 -i tailscale0 -j ACCEPT
sudo netfilter-persistent save

echo "== 4. Docker"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
fi
sudo usermod -aG docker "$USER"
# Logs never fill the disk: 3 files of 10 MB per container.
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "live-restore": true
}
EOF
sudo systemctl restart docker
# Redis wants this, to save to disk under memory pressure.
echo "vm.overcommit_memory = 1" | sudo tee /etc/sysctl.d/90-redis.conf >/dev/null
sudo sysctl --system >/dev/null

echo "== 5. Tailscale (private network for SSH and Grafana)"
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
sudo tailscale up --ssh=false || true

echo "== 6. The app's folder"
sudo mkdir -p "$APP_DIR"
sudo chown "$USER":"$USER" "$APP_DIR"

cat <<EOF

Done. Next:
  1. Open the Tailscale link above (if one was printed) to add this server.
  2. Log out and in again (Docker without sudo).
  3. From your PC, check SSH works over Tailscale:  ssh ubuntu@$(hostname)
  4. Then close public SSH:  bash $APP_DIR/deploy/scripts/lock-ssh.sh
EOF
