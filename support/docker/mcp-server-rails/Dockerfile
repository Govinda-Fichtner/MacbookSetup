FROM ruby:3.3-alpine

# Install system dependencies for Rails MCP server
RUN apk add --no-cache \
    git \
    build-base \
    sqlite-dev \
    postgresql-dev \
    mysql-dev \
    linux-headers

# Set working directory
WORKDIR /app

# Install the Rails MCP Server gem directly
RUN gem install rails-mcp-server

# Create directories for configuration and projects
RUN mkdir -p /app/config /app/.config/rails-mcp /app/projects

# Create non-root user for security
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup -h /app && \
    mkdir -p /app/tmp /app/logs && \
    chown appuser:appgroup /app/.config /app/config /app/projects /app/tmp /app/logs && \
    chmod 755 /app

# Set up environment variables
ENV RAILS_MCP_ROOT_PATH=/rails-projects
ENV RAILS_MCP_CONFIG_HOME=/app/.config
ENV XDG_CONFIG_HOME=/app/.config

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD rails-mcp-server --help || exit 1

# Switch to non-root user
USER appuser

# Use the rails-mcp-server executable as entrypoint
ENTRYPOINT ["rails-mcp-server"]
