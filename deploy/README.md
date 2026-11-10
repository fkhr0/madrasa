# Deploying Madrasa

```
Phones / browsers ──https──► Nginx (Let's Encrypt, rate limits, load balancing)
                                 ├─► api1 ┐  Node, two copies: one restarts
                                 └─► api2 ┘  while the other serves
                     worker (jobs, nightly backup) ── Redis (cache, live updates, queue)
                     Neon PostgreSQL (managed)      S3 bucket (off-site backups)
 Monitoring: Prometheus ─ Grafana ─ Loki/Promtail ─ Alertmanager → Telegram
 Access:     SSH and Grafana only over Tailscale
```

The server is one ARM machine on AWS (t4g.small, 2 GB, on the free plan's
credits); Oracle Cloud's Always Free tier works too, with the same scripts.
Everything else is free: Neon, DuckDNS, Let's Encrypt, GitHub Actions,
Tailscale.

## Files

| Path | What |
|---|---|
| `terraform/aws/` | AWS: the server with a fixed IP, cloud firewall, backup bucket (keyless, a role), budget alert |
| `terraform/oracle/` | The same on Oracle Cloud Always Free |
| `scripts/server-setup.sh` | Once: updates, SSH hardening, fail2ban, firewall, swap, Docker, Tailscale |
| `scripts/lock-ssh.sh` | After Tailscale works: SSH closed to the internet |
| `scripts/configure.sh` | Checks `.env`, writes Alertmanager's config |
| `scripts/certificate.sh` | First HTTPS certificate, then a daily renewal timer |
| `scripts/deploy.sh` | Rolling update, health-checked, rolls back on failure |
| `scripts/restore-test.sh` | Restores the newest backup into a scratch database |
| `docker-compose.yml` | The 12 services |
| `nginx/` | The front door |
| `monitoring/` | Prometheus rules, Grafana dashboard, Loki, Alertmanager |
| `../.github/workflows/` | CI (tests, scanners), CodeQL, deploy |

## First time

1. `tofu apply` or `terraform apply` (in `terraform/aws/`, with `terraform.tfvars`).
2. Point the DuckDNS name at the server's IP.
3. On the server: `bash server-setup.sh`, then connect Tailscale and run `lock-ssh.sh`.
4. `git clone` the repository to `/opt/madrasa`, `cp deploy/.env.example deploy/.env`, fill it in.
5. Put `firebase.json` in `deploy/secrets/`.
6. `bash deploy/scripts/configure.sh && bash deploy/scripts/certificate.sh`
7. `docker compose up -d` in `deploy/`. From then on, every push to `main` deploys.

## Everyday

```bash
docker compose ps                    # what runs, and health
docker compose logs -f --tail 100 api1
bash scripts/deploy.sh <image>       # by hand (GitHub Actions does it)
bash scripts/restore-test.sh         # monthly: do the backups restore?
```

Grafana: `http://<server's Tailscale IP>:3001` (user `admin`, `GRAFANA_PASSWORD`).
