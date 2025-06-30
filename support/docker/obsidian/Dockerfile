# Obsidian MCP Server Dockerfile
# Based on https://github.com/cyanheads/obsidian-mcp-server
FROM node:23-alpine

WORKDIR /usr/src/app

# Install dependencies, clone repository, build, and set up user
RUN apk add --no-cache git && \
    git clone https://github.com/cyanheads/obsidian-mcp-server.git . && \
    npm ci --ignore-scripts && \
    npm run build && \
    npm ci --only=production --ignore-scripts && \
    rm -rf .git && \
    mkdir -p /usr/src/app/logs && \
    addgroup -S appgroup && \
    adduser -S appuser -G appgroup && \
    chown -R appuser:appgroup /usr/src/app

USER appuser
ENV NODE_ENV=production

# Start MCP server in STDIO mode
CMD ["node", "dist/index.js"]
