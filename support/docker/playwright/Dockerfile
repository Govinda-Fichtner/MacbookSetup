# Playwright MCP Server following official Playwright Docker best practices
FROM node:20-bookworm

# Install Playwright with system dependencies (official approach using latest version)
RUN npx -y playwright@1.53.1 install --with-deps

# Create pwuser for security
RUN useradd --create-home --shell /bin/bash pwuser

WORKDIR /app

# Copy source code (cloned by mcp_manager.sh into tmp/repositories)
COPY . .
RUN chown -R pwuser:pwuser /app

# Install Node dependencies and build as pwuser
USER pwuser
RUN npm install && npm run build

# Create output directory for screenshots and other files
RUN mkdir -p /app/output

# Start MCP server in STDIO mode with headless browser and output directory
ENTRYPOINT ["node", "cli.js", "--headless", "--browser", "chromium", "--no-sandbox", "--output-dir", "/app/output"]
