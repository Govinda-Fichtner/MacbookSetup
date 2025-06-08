# Rails MCP Server Setup Guide

## 🎯 Overview

The Rails MCP Server provides AI assistants with powerful Rails project analysis and development assistance capabilities, including model inspection, route analysis, database schema exploration, and Rails command execution.

## 📋 Prerequisites

### System Requirements
- Docker installed and running
- Rails projects directory structure
- Ruby gems environment in your Rails projects

### Directory Structure
```
/Users/[username]/
├── rails-projects/           # Your Rails projects directory
│   ├── project1/            # Individual Rails applications
│   ├── project2/
│   └── blog/                # Example Rails project
└── .config/rails-mcp/       # Configuration directory
    ├── projects.yml         # Project definitions (CRITICAL: use container paths)
    └── log/                 # Server logs
        └── rails_mcp_server.log
```

## 🔧 Configuration Setup

### 1. Environment Variables

Add to your `.env` file:
```bash
# Rails MCP Server Configuration
RAILS_MCP_ROOT_PATH=/Users/[username]/rails-projects
RAILS_MCP_CONFIG_HOME=/Users/[username]/.config/rails-mcp
```

### 2. Project Configuration File

**CRITICAL**: Create `/Users/[username]/.config/rails-mcp/projects.yml` with **container paths**:

```yaml
# projects.yml - MUST use container paths, NOT host paths
blog: "/rails-projects/blog"
myapp: "/rails-projects/myapp"
api_server: "/rails-projects/api_server"
```

**⚠️ Path Mapping Requirements:**
- ❌ **NEVER use host paths**: `"/Users/username/rails-projects/blog"`
- ✅ **ALWAYS use container paths**: `"/rails-projects/blog"`
- The Rails MCP server runs inside a Docker container where your projects are mounted at `/rails-projects/`

## 🐳 Docker Configuration

### Generated Configuration
The MCP manager automatically generates this Docker configuration:

```json
{
  "rails": {
    "command": "docker",
    "args": [
      "run", "--rm", "-i",
      "--env-file", "/Users/gfichtner/MacbookSetup/.env",
      "--mount", "type=bind,src=/Users/[username]/rails-projects,dst=/rails-projects",
      "--mount", "type=bind,src=/Users/[username]/.config/rails-mcp,dst=/app/.config/rails-mcp",
      "--workdir", "/rails-projects",
      "local/mcp-server-rails:latest"
    ]
  }
}
```

### Key Configuration Elements

1. **Project Mount**: `src=/Users/[username]/rails-projects,dst=/rails-projects`
   - Maps your host Rails projects to container path `/rails-projects`

2. **Config Mount**: `src=/Users/[username]/.config/rails-mcp,dst=/app/.config/rails-mcp`
   - Maps configuration directory to container config path

3. **Working Directory**: `--workdir /rails-projects`
   - Sets container working directory for proper gem context
   - Essential for Rails commands to find Bundler environment

## 🚀 Setup Process

### 1. Build the Docker Image
```bash
./mcp_manager.sh setup rails
```

### 2. Create Project Configuration
```bash
# Create config directory
mkdir -p ~/.config/rails-mcp

# Create projects.yml with container paths
cat > ~/.config/rails-mcp/projects.yml << 'EOF'
blog: "/rails-projects/blog"
myapp: "/rails-projects/myapp"
EOF
```

### 3. Generate MCP Configurations
```bash
./mcp_manager.sh config-write
```

### 4. Restart Claude Desktop
Restart Claude Desktop to pick up the new configuration.

## 🎯 Capabilities

### Core Features
- **Project Analysis**: Analyze Rails application structure and components
- **Model Inspection**: Examine ActiveRecord models and relationships
- **Route Analysis**: View and analyze Rails routes (`rails routes`)
- **Database Schema**: Explore database schema and migrations
- **Gem Management**: Manage and analyze gem dependencies
- **Test Generation**: Generate and analyze test files
- **Controller Analysis**: Examine controller structure and actions
- **View Templates**: Analyze ERB templates and layouts
- **Migration Assistance**: Create and modify database migrations

### Advanced Features
- **Project Switching**: Dynamically switch between multiple Rails projects
- **Rails Command Execution**: Execute Rails commands with proper gem context
- **Bundle Integration**: All Rails commands executed via `bundle exec`
- **Log Monitoring**: Real-time access to server logs and debugging info

## 🧪 Testing Your Setup

### 1. Verify Container Running
```bash
docker ps | grep rails
```

### 2. Check Logs
```bash
docker exec [container_name] cat /app/.config/rails-mcp/log/rails_mcp_server.log
```

### 3. Test MCP Integration
In Claude Desktop, try these commands:
- "List my Rails projects"
- "Show me the routes for the blog project"
- "Analyze the User model in my Rails app"
- "What gems are used in the project?"

## 🐛 Troubleshooting

### Common Issues

#### 1. "Project not found" Errors
**Cause**: Incorrect paths in `projects.yml`
**Solution**: Ensure `projects.yml` uses container paths (`/rails-projects/[project]`)

#### 2. "Rails command failed" Errors
**Cause**: Missing gems or wrong working directory
**Solution**: Verify Rails project has proper `Gemfile` and `bundle install` completed

#### 3. "Permission denied" Errors
**Cause**: Docker mount permissions or file ownership
**Solution**: Ensure Rails project directories are readable by Docker

#### 4. "Configuration not found" Errors
**Cause**: Missing or incorrectly mounted config directory
**Solution**: Verify `~/.config/rails-mcp/` exists and contains `projects.yml`

### Debug Commands

```bash
# Check container mounts
docker exec [container] mount | grep rails

# Verify working directory
docker exec [container] pwd

# Check project configuration
docker exec [container] cat /app/.config/rails-mcp/projects.yml

# View server logs
docker exec [container] tail -f /app/.config/rails-mcp/log/rails_mcp_server.log
```

## 📝 Configuration Examples

### Single Project Setup
```yaml
# ~/.config/rails-mcp/projects.yml
my_blog: "/rails-projects/blog"
```

### Multiple Projects Setup
```yaml
# ~/.config/rails-mcp/projects.yml
blog: "/rails-projects/blog"
ecommerce: "/rails-projects/shop"
api: "/rails-projects/api_backend"
admin: "/rails-projects/admin_panel"
```

### Development vs Production Environments
```yaml
# ~/.config/rails-mcp/projects.yml
blog_dev: "/rails-projects/blog"
blog_staging: "/rails-projects/blog-staging"
api_v1: "/rails-projects/api/v1"
api_v2: "/rails-projects/api/v2"
```

## 🔧 Advanced Configuration

### Custom Rails Wrapper
The Docker image includes a `rails-wrapper.sh` script that ensures proper Bundler context:

```bash
#!/bin/bash
# rails-wrapper.sh
cd $1  # First argument is the project path
shift  # Remove the first argument
bundle exec ${@//bin\/rails/rails}  # Replace bin/rails with rails and prefix with bundle exec
```

This ensures all Rails commands run with the correct gem environment.

### Environment Variables
The server respects these environment variables:
- `RAILS_ENV`: Rails environment (default: development)
- `BUNDLE_PATH`: Custom bundle path for gems
- `DATABASE_URL`: Database connection string

## 🚀 Getting Started Checklist

- [ ] Docker installed and running
- [ ] Rails projects in `~/rails-projects/` (or custom path)
- [ ] Created `~/.config/rails-mcp/projects.yml` with **container paths**
- [ ] Added environment variables to `.env`
- [ ] Built Docker image: `./mcp_manager.sh setup rails`
- [ ] Generated configurations: `./mcp_manager.sh config-write`
- [ ] Restarted Claude Desktop
- [ ] Tested MCP integration with Rails commands

## 📚 References

- [Rails MCP Server Repository](https://github.com/maquina-app/rails-mcp-server)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [Claude Desktop MCP Guide](https://docs.anthropic.com/claude/docs/mcp)

---

**Last Updated**: January 2025
**Version**: 1.0
**Tested With**: Rails 7.x, Ruby 3.3, Docker 24.x
