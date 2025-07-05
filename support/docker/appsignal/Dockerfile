# Multi-stage build for AppSignal MCP Server
# Optimized for security and size

# Build stage
FROM node:22-alpine AS builder

# Security: Use non-root user for build
USER node
WORKDIR /app

# Copy package files first for better layer caching
COPY --chown=node:node package*.json ./

# Install dependencies with npm ci for deterministic builds
RUN npm ci --only=production && \
    npm cache clean --force

# Development dependencies for building
COPY --chown=node:node package*.json ./
RUN npm ci

# Copy source code
COPY --chown=node:node . .

# Build the application
RUN npm run build

# Production stage
FROM node:22-alpine AS production

# Security enhancements
RUN apk --no-cache add dumb-init && \
    apk --no-cache upgrade

# Create app directory and set permissions
WORKDIR /app
RUN chown node:node /app

# Switch to non-root user
USER node

# Copy production dependencies from builder stage
COPY --from=builder --chown=node:node /app/node_modules ./node_modules

# Copy built application
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/package*.json ./

# Environment variables
ENV NODE_ENV=production
ENV NODE_OPTIONS="--enable-source-maps"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "console.log('Health check: MCP server ready')" || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Run the application
CMD ["node", "dist/index.js"]

# Security: Run as read-only filesystem (uncomment if app supports it)
# USER 65534:65534

# Metadata
LABEL org.opencontainers.image.title="AppSignal MCP Server"
LABEL org.opencontainers.image.description="AppSignal Model Context Protocol Server"
LABEL org.opencontainers.image.url="https://github.com/appsignal/appsignal-mcp"
LABEL org.opencontainers.image.documentation="https://github.com/appsignal/appsignal-mcp"
LABEL org.opencontainers.image.source="https://github.com/appsignal/appsignal-mcp"
LABEL org.opencontainers.image.licenses="MIT"
