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

# Set up environment variables
ENV RAILS_MCP_ROOT_PATH=/rails-projects
ENV RAILS_MCP_CONFIG_HOME=/app/.config
ENV XDG_CONFIG_HOME=/app/.config

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD rails-mcp-server --help || exit 1

# Use the rails-mcp-server executable as entrypoint
ENTRYPOINT ["rails-mcp-server"]
