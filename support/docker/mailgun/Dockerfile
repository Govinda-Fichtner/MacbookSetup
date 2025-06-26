# Multi-stage build for Mailgun MCP Server
FROM node:18-alpine AS builder

WORKDIR /app

# Clone the official Mailgun MCP Server repository
RUN apk add --no-cache git && \
    git clone https://github.com/mailgun/mailgun-mcp-server.git .

# Install dependencies (no build step needed - it's pure JS)
RUN npm install

# Final stage - runtime
FROM node:18-alpine

WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

# Copy application from builder stage
COPY --from=builder --chown=appuser:appgroup /app .

USER appuser

# Environment variables for Mailgun configuration
ENV MAILGUN_API_KEY=
ENV MAILGUN_DOMAIN=

# Use stdio communication (no port exposure needed)
ENTRYPOINT ["node", "src/mailgun-mcp.js"]
