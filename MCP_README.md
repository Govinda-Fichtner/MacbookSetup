# Model Context Protocol (MCP) Integration

This MacbookSetup project includes integrated support for **Model Context Protocol (MCP)** servers, providing seamless AI assistant connectivity to your development tools and workflows.

## 🎯 What is MCP?

Model Context Protocol (MCP) is an open standard that enables AI assistants to connect securely to external data sources and tools. This integration allows your AI assistant (like Claude in Cursor) to:

- **Interact with GitHub**: Create issues, review PRs, manage repositories
- **Monitor CI/CD**: Check CircleCI build status, analyze failures, trigger pipelines
- **Access Live Data**: Get real-time information from your development tools
- **Execute Actions**: Perform operations on your behalf with proper authentication

## 🚀 Quick Start

### 1. **Initial Setup**
```bash
# Run the main setup script (includes MCP setup)
./setup.sh

# Verify MCP servers are configured
./verify_setup.sh
```

### 2. **Configure Tokens**
Edit `.envrc` and add your API tokens:
```bash
# Phase 1 - Active MCP Servers
export GITHUB_TOKEN="ghp_your_github_token_here"
export CIRCLECI_TOKEN="your_circleci_token_here"

# Load the environment
direnv allow
```

### 3. **Start MCP Servers**
```bash
# Start all MCP servers
cd ~/.config/mcp
docker-compose up -d

# Check server status
docker-compose ps
```

### 4. **Connect Your AI Assistant**
- **Cursor**: MCP servers will be auto-discovered on ports 3001-3002
- **Other Clients**: Connect to `localhost:3001` (GitHub) and `localhost:3002` (CircleCI)

## 📋 Current MCP Servers

### **Phase 1 - Core Development Tools**

| Server | Category | Port | Status | Purpose |
|--------|----------|------|---------|----------|
| **github-mcp** | Code Integration | 3001 | ✅ Active | Repository management, PR workflows, issue tracking |
| **circleci-mcp** | CI/CD Integration | 3002 | ✅ Active | Build monitoring, pipeline management, test results |

### **Phase 2+ - Future Expansion**

| Category | Tools | Ports | Status |
|----------|-------|-------|---------|
| **Design** | Figma | 3010 | 🚧 Planned |
| **Quality** | SonarQube | 3020 | 🚧 Planned |
| **Infrastructure** | Terraform, AWS, DigitalOcean, Heroku, Serverless, Netlify | 3030-3035 | 🚧 Planned |
| **Monitoring** | Sentry, OpenTelemetry | 3040-3041 | 🚧 Planned |
| **Testing** | Playwright | 3050 | 🚧 Planned |
| **Project Management** | Linear, Slack | 3060-3061 | 🚧 Planned |

## 🔧 Configuration Management

### **Directory Structure**
```
~/.config/mcp/
├── docker-compose.yml          # Container orchestration
├── github-mcp.json            # GitHub server config
├── circleci-mcp.json          # CircleCI server config
└── logs/                      # Server logs
    ├── github-mcp.log
    └── circleci-mcp.log
```

### **Environment Variables**
```bash
# Core Configuration
export MCP_CONFIG_PATH="$HOME/.config/mcp"    # Config directory
export SKIP_MCP="false"                       # Disable MCP functionality

# Phase 1 Tokens
export GITHUB_TOKEN="ghp_..."                 # GitHub Personal Access Token
export CIRCLECI_TOKEN="..."                   # CircleCI API Token

# Future Phase Tokens (commented out)
# export FIGMA_TOKEN="..."                    # Figma API token
# export SONARQUBE_TOKEN="..."               # SonarQube token
# export AWS_ACCESS_KEY_ID="..."             # AWS credentials
# export DIGITALOCEAN_TOKEN="..."            # DigitalOcean API token
```

## 🛠️ Management Commands

### **Server Operations**
```bash
# Start all servers
docker-compose -f ~/.config/mcp/docker-compose.yml up -d

# Stop all servers
docker-compose -f ~/.config/mcp/docker-compose.yml down

# Restart specific server
docker-compose -f ~/.config/mcp/docker-compose.yml restart github-mcp

# View logs
docker-compose -f ~/.config/mcp/docker-compose.yml logs -f github-mcp
```

### **Health Checks**
```bash
# Verify all MCP components
./verify_setup.sh

# Check specific server health
curl -f http://localhost:3001/health  # GitHub MCP
curl -f http://localhost:3002/health  # CircleCI MCP
```

### **Troubleshooting**
```bash
# Check Docker status
docker info

# Verify configurations
jq . ~/.config/mcp/github-mcp.json
jq . ~/.config/mcp/circleci-mcp.json

# Reset MCP environment
SKIP_MCP=false ./setup.sh
```

## 🔐 Security & Token Management

### **GitHub Token Setup**
1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Create a new token with these scopes:
   - `repo` (Full repository access)
   - `user` (User information access)
   - `workflow` (GitHub Actions access)
3. Add to `.envrc`: `export GITHUB_TOKEN="ghp_your_token_here"`

### **CircleCI Token Setup**
1. Go to CircleCI App → User Settings → Personal API Tokens
2. Create a new token with appropriate permissions
3. Add to `.envrc`: `export CIRCLECI_TOKEN="your_token_here"`

### **Token Security**
- ✅ Tokens stored in `.envrc` (git-ignored)
- ✅ Docker containers use environment variables
- ✅ No tokens in configuration files
- ✅ Tokens never logged or exposed

## 🚀 Usage Examples

### **GitHub Integration**
```markdown
Hey Claude, can you:
- Check the status of PR #123 in this repo
- Create a new issue for the bug I found
- Review the latest commits on the main branch
- List all open issues assigned to me
```

### **CircleCI Integration**
```markdown
Hey Claude, can you:
- Check if the tests are passing in CI
- Show me the latest build status
- Help me debug the failing test in the pipeline
- Trigger a new build on the main branch
```

## 📈 Extending MCP Servers

### **Adding New Servers**
Follow the template-driven approach used in `docker-compose.yml`:

1. **Add server definition** in docker-compose.yml
2. **Create configuration file** (JSON format)
3. **Update setup.sh** with new server setup
4. **Update verify_setup.sh** with verification logic
5. **Add environment variables** to .envrc
6. **Update this README** with new server info

### **Template Example**
```yaml
# docker-compose.yml
new-tool-mcp:
  image: "mcp/new-tool:latest"
  container_name: "new-tool-mcp"
  ports:
    - "3070:3000"
  environment:
    - NEW_TOOL_TOKEN=${NEW_TOOL_TOKEN}
  volumes:
    - "./new-tool-mcp.json:/app/config.json:ro"
    - "./logs:/app/logs"
  restart: unless-stopped
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
    interval: 30s
    timeout: 10s
    retries: 3
```

## 🔄 CI/CD Integration

### **Environment Handling**
- **Local Development**: Full MCP functionality enabled
- **CI Environments**: MCP verification skipped with warnings
- **Skip Mode**: Use `SKIP_MCP=true` to disable entirely

### **Testing Pipeline**
```bash
# Standard testing (MCP disabled in CI)
./verify_setup.sh

# Local testing with MCP enabled
SKIP_MCP=false ./verify_setup.sh

# Local testing with MCP disabled
SKIP_MCP=true ./verify_setup.sh
```

## 🎯 Philosophy & Design

This MCP integration follows the project's **Minimal Complexity Principle**:

- ✅ **Template-driven expansion**: Easy to add new servers
- ✅ **Optional functionality**: Can be completely disabled
- ✅ **Existing patterns**: Reuses Docker, environment, and verification patterns
- ✅ **Non-invasive**: Doesn't change existing functionality
- ✅ **CI-compatible**: Graceful degradation in automated environments

## 📚 Resources

- **MCP Specification**: [Model Context Protocol Docs](https://github.com/modelcontextprotocol)
- **GitHub MCP Server**: [GitHub Integration Guide](https://github.com/modelcontextprotocol/servers/tree/main/src/github)
- **CircleCI MCP Server**: [CircleCI Integration Guide](https://github.com/modelcontextprotocol/servers/tree/main/src/circleci)
- **Docker Compose**: [Container Orchestration Guide](https://docs.docker.com/compose/)

---

**Questions or Issues?** Check the verification output with `./verify_setup.sh` or review the logs in `~/.config/mcp/logs/`
