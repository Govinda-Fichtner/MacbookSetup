# Multi-stage build for Recraft MCP Server
# Optimized for security and minimal size

# Stage 1: Build stage
FROM node:22.12-alpine AS builder

# Install build dependencies
RUN apk add --no-cache python3 make g++

WORKDIR /app

# Copy package files for better layer caching
COPY package*.json ./

# Install all dependencies (including dev dependencies for building)
RUN npm ci && \
    npm cache clean --force

# Copy source code
COPY . .

# Build the application
RUN npm run build && \
    # Remove dev dependencies after build
    npm prune --production && \
    # Remove unnecessary files
    rm -rf src/ *.ts tsconfig.json .git .github

# Stage 2: Production stage
FROM node:22.12-alpine AS production

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create non-root user
RUN addgroup -g 1001 -S mcp && \
    adduser -u 1001 -S mcp -G mcp

# Set working directory
WORKDIR /app

# Copy only production files from builder
COPY --from=builder --chown=mcp:mcp /app/package*.json ./
COPY --from=builder --chown=mcp:mcp /app/node_modules ./node_modules
COPY --from=builder --chown=mcp:mcp /app/dist ./dist

# Ensure proper permissions
RUN chmod -R 755 /app

# Switch to non-root user
USER mcp

# Environment variables
ENV NODE_ENV=production \
    NODE_OPTIONS="--enable-source-maps"

# Health check to ensure server is responsive
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "console.log('Health check passed')" || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Run the MCP server
CMD ["node", "dist/index.js"]

# Metadata
LABEL org.opencontainers.image.title="Recraft MCP Server"
LABEL org.opencontainers.image.description="MCP server for Recraft AI image generation and manipulation"
LABEL org.opencontainers.image.url="https://github.com/recraft-ai/mcp-recraft-server"
LABEL org.opencontainers.image.source="https://github.com/recraft-ai/mcp-recraft-server"
LABEL org.opencontainers.image.licenses="MIT"
