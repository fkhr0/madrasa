# The school server and the web app, in one image (linux/arm64 for Oracle's
# free servers; amd64 works too). Built from the repository's root:
#   docker build -f server/Dockerfile -t madrasa-api .
# The web app (build/web) is built first: flutter build web.

# ── 1. Packages, without the test tools ──
FROM node:22-bookworm-slim AS deps
WORKDIR /app
COPY server/package.json server/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ── 2. What runs ──
FROM node:22-bookworm-slim

# pg_dump for the nightly backup (PostgreSQL 18's: newer works with older
# servers), and tini so Ctrl+C / docker stop reach Node and it closes cleanly.
# npm is gone: only stage 1 needs it, and its own packages had known holes.
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg tini \
 && install -d /usr/share/postgresql-common/pgdg \
 && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
 && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends postgresql-client-18 \
 && apt-get purge -y gnupg curl && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

ENV NODE_ENV=production \
    PORT=3000 \
    WEB_DIR=/app/web \
    UPLOADS_DIR=/data/uploads \
    BACKUPS_DIR=/data/backups \
    PG_DUMP=pg_dump

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY server/package.json ./
COPY server/src ./src
COPY server/public ./public
COPY build/web ./web

# Not root: a hole in the app can't take over the container.
RUN mkdir -p /data/uploads /data/backups && chown -R node:node /data
USER node

EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=5s --start-period=40s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "src/server.js"]
