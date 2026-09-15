# syntax=docker/dockerfile:1.7
#
# Multi-stage Dockerfile for the codebase Next.js app.
#
# This reproduces what .zscripts/build.sh does — install deps, run
# `bun run build`, copy the standalone output and public assets — but
# without the deployment-sandbox-specific paths (/home/z/my-project,
# /tmp/build_fullstack_$BUILD_ID, etc.).
#
# Image is published to GitHub Container Registry by
# .github/workflows/docker-publish.yml. The owner placeholder is set
# via IMAGE_NAME in the workflow (derived from github.repository) — this
# Dockerfile does not hardcode a registry path.
#
# Tag examples (set by the workflow):
#   ghcr.io/<owner>/codebase:latest
#   ghcr.io/<owner>/codebase:<sha>
#   ghcr.io/<owner>/codebase:v1.2.3

# ---- builder ----
FROM oven/bun:1 AS builder
WORKDIR /app

# Install deps first to leverage Docker layer cache. `--frozen-lockfile`
# refuses to update bun.lock, so the lockfile + package.json alone
# determine this layer's cache key — code changes won't bust it.
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile

# Generate Prisma client BEFORE the build so .prisma/ exists. The build
# step below (next build) and the prisma generate both want the client
# at /app/node_modules/.prisma and /app/node_modules/@prisma — without
# this explicit generate, Bun sometimes doesn't materialize the client
# and the buildx cache-key step fails with "not found".
COPY prisma ./prisma
RUN bunx prisma generate

# Build the standalone bundle. next.config.ts already sets output:"standalone",
# so this produces .next/standalone/server.js + .next/static + public.
COPY . .
RUN bun run build

# ---- runtime ----
FROM oven/bun:1-slim AS runtime

# Caddy isn't in the bun:1-slim image, so we install it. Pin to a specific
# version if your cluster requires reproducible builds.
RUN apt-get update \
 && apt-get install -y --no-install-recommends caddy ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the standalone build (server.js + node_modules + .next/standalone tree).
COPY --from=builder /app/.next/standalone ./

# Copy static + public — standalone omits these.
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

# Copy the prisma schema + generated client. The standalone bundle already
# includes its own node_modules subset, but Bun's layout puts .prisma
# separately — we copy both the schema dir (so runtime prisma CLI works)
# and the generated client.
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma

# Optional: bake in a starter DB. The PVC overlays /app/db at runtime, so
# any file we copy here is only useful as a fallback for first-boot.
COPY --from=builder /app/db ./db

# Container entrypoint: Caddy is the main process, matching the existing
# start.sh (`exec caddy run --config Caddyfile --adapter caddyfile`).
# Caddyfile is supplied by the ConfigMap mount at /etc/caddy/Caddyfile.
ENTRYPOINT ["/usr/bin/caddy"]
CMD ["run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]

# Caddy listens on :81 inside the container, exposed via the Service.
EXPOSE 81
