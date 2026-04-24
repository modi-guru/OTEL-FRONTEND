# ---------------------------
# Stage 1: Build app
# ---------------------------
FROM docker.io/library/node:24-slim AS builder

WORKDIR /app

# Install dependencies
COPY package.json package.json
COPY package-lock.json package-lock.json
RUN npm ci

# Copy source code
COPY components/ components/
COPY gateways/ gateways/
COPY pages/ pages/
COPY protos/ protos/
COPY providers/ providers/
COPY services/ services/
COPY styles/ styles/
COPY types/ types/

COPY utils/enums/ utils/enums/
COPY utils/telemetry/ utils/telemetry/
COPY utils/imageLoader.js utils/imageLoader.js
COPY utils/Request.ts utils/Request.ts

COPY next.config.js next.config.js
COPY tsconfig.json tsconfig.json

# Build Next.js app
RUN npm run build

# ---------------------------
# Stage 2: Install prod deps
# ---------------------------
FROM docker.io/library/node:24-slim AS deps

WORKDIR /app

COPY package.json package.json
COPY package-lock.json package-lock.json
RUN npm ci --omit=dev

# ---------------------------
# Stage 3: Final runtime (distroless)
# ---------------------------
FROM gcr.io/distroless/nodejs24-debian13:nonroot

WORKDIR /app

# Copy built app
COPY --from=builder /app/.next/standalone/ ./
COPY --from=builder /app/.next/static/ .next/static/

# Copy production dependencies
COPY --from=deps /app/node_modules/ node_modules/

# Copy static assets
COPY public/ public/

# Copy telemetry instrumentation
COPY utils/telemetry/Instrumentation.js Instrumentation.js

# Expose port (safe default)
EXPOSE 8080

# Start app
CMD ["--require=./Instrumentation.js", "server.js"]