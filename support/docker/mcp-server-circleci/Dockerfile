# Base image with Node.js and pnpm setup
FROM node:lts-alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable
WORKDIR /app

# Production dependencies stage
FROM base AS prod-deps
COPY package.json pnpm-lock.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --prod --frozen-lockfile --ignore-scripts

# Build stage
FROM base AS build
COPY package.json pnpm-lock.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile --ignore-scripts
COPY . .
RUN pnpm run build

# Final stage - clean minimal image
FROM node:lts-alpine
ENV NODE_ENV=production
WORKDIR /app

# Copy application files as root (read-only for security)
COPY --from=prod-deps /app/node_modules /app/node_modules
COPY --from=build /app/dist /app/dist
COPY package.json ./

# Create non-root user for security
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup -h /app && \
    mkdir -p /app/tmp /app/logs && \
    chown appuser:appgroup /app/tmp /app/logs && \
    chmod 755 /app/node_modules /app/dist && \
    chmod 644 /app/package.json

# Switch to non-root user
USER appuser

# Command to run the MCP server
ENTRYPOINT ["node", "dist/index.js"]
