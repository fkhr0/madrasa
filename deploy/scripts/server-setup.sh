#!/usr/bin/env bash
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
sudo dpkg-reconfigure -f noninteractive unattended-upgrades

echo "== 2. SSH hardening"
sudo tee /etc/ssh/sshd_config.d/99-madrasa.conf >/dev/null <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowAgentForwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
sudo sshd -t && sudo systemctl reload ssh

sudo tee /etc/fail2ban/jail.d/sshd.local >/dev/null <<'EOF'
[sshd]
enabled = true
maxretry = 5
bantime = 1h
findtime = 10m
EOF
sudo systemctl enable --now fail2ban

echo "== 3. Firewall (the server's own; the cloud firewall is the other layer)"
allow() { sudo iptables -C INPUT "$@" -j ACCEPT 2>/dev/null || sudo iptables -I INPUT 1 "$@" -j ACCEPT; }
allow -p tcp -m state --state NEW -m tcp --dport 22
allow -p tcp --dport 443 -m state --state NEW
allow -p tcp --dport 80 -m state --state NEW
allow -p udp --dport 41641
allow -i tailscale0
allow -i lo
allow -m state --state RELATED,ESTABLISHED
sudo iptables -P INPUT DROP
sudo netfilter-persistent save

echo "== 3b. Swap (small servers: a full memory slows down instead of crashing)"
if ! swapon --show | grep -q /swapfile; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile >/dev/null
  sudo swapon /swapfile
  echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
fi
echo "vm.swappiness = 10" | sudo tee /etc/sysctl.d/90-swap.conf >/dev/null

echo "== 4. Docker"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
fi
sudo usermod -aG docker "$USER"
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "live-restore": true
}
EOF
sudo systemctl restart docker
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
