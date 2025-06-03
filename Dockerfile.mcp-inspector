# MCP Inspector Dockerfile
# Official Model Context Protocol Inspector in a container
FROM node:22-alpine

# Set working directory
WORKDIR /app

# Set environment variables for the inspector
ENV MCP_AUTO_OPEN_ENABLED=false
ENV CLIENT_PORT=6274
ENV SERVER_PORT=6277

# Install Docker CLI and the latest MCP Inspector globally
RUN apk add --no-cache docker-cli && \
    npm install -g @modelcontextprotocol/inspector@latest

# Expose the ports
EXPOSE 6274 6277

# Add comprehensive health check for both UI and Proxy
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=2 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:6274 && \
      wget --no-verbose --tries=1 --spider http://localhost:6277/health || exit 1

# Create entrypoint script
RUN echo '#!/bin/sh' > /entrypoint.sh && \
    echo 'exec npx @modelcontextprotocol/inspector "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# Default command - start both UI and proxy server
CMD []
