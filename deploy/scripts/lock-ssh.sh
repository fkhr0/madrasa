#!/usr/bin/env bash
# After Tailscale works: SSH only over Tailscale, closed to the internet.
# Run on the server, from an SSH session that came in over Tailscale
# (otherwise this cuts your own connection).
set -euo pipefail

if ! tailscale status >/dev/null 2>&1; then
  echo "Tailscale isn't connected: not closing SSH." >&2
  exit 1
fi
if [[ "${SSH_CONNECTION:-}" != 100.* ]]; then
  echo "You are not connected over Tailscale (100.x.x.x). Connect with:" >&2
  echo "  ssh ubuntu@$(tailscale ip -4)" >&2
  echo "and run this again." >&2
  exit 1
fi

# Remove "SSH from anywhere"; tailscale0 is already allowed.
while sudo iptables -C INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT 2>/dev/null; do
  sudo iptables -D INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
done
sudo netfilter-persistent save
echo "SSH now only over Tailscale. Also remove port 22 from Oracle's security list"
echo "(Terraform: ssh_allowed_cidr = \"\"), so both layers agree."
