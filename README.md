# MacbookSetup

[![CircleCI](https://dl.circleci.com/status-badge/img/circleci/Nbcyu2F7rJ4pmU9Bk5nmUi/47yWoqvLZ54GqPdNEnuU4V/tree/main.svg?style=shield)](https://app.circleci.com/pipelines/circleci/Nbcyu2F7rJ4pmU9Bk5nmUi)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=Govinda-Fichtner_MacbookSetup&metric=alert_status)](https://sonarcloud.io/project/overview?id=Govinda-Fichtner_MacbookSetup)

A streamlined, automated setup script for macOS development environments. Get your Mac ready for development in minutes, not hours.

## 🚀 Purpose

Setting up a new Mac for development is time-consuming and error-prone. This project aims to solve that by providing:

- A single command to install all necessary development tools
- Consistent configuration across different machines
- Reproducible development environments
- Easy onboarding for new team members or after OS reinstalls

## 📦 What's Included

This setup automates the installation and configuration of:

### Core Tools
- **Homebrew**: Package manager for macOS
- **Git**: Version control system
- **Direnv**: Environment variable management per directory

### Development Environments
- **Ruby** (via rbenv): Ruby version manager with latest stable Ruby
- **Python** (via pyenv): Python version manager with latest stable Python
- **Node.js** (via nvm): Node.js version manager with latest LTS Node.js

### Containerization and Infrastructure
- **OrbStack**: Fast Docker & Linux VM manager with Kubernetes support
- **Kubernetes Tools**: kubectl, helm, k9s, kubectx, kustomize
- **Container Utilities**: dive, ctop, buildkit
- **Infrastructure as Code**: Terraform, Packer
- **System Monitoring**: htop for process monitoring

### Knowledge Management and Productivity
- **Obsidian**: Advanced knowledge base and note-taking app with AI integration
  - **MCP Integration**: Included MCP server for AI-enhanced vault management
  - **Local REST API**: Enables programmatic access to your knowledge base
  - **AI Workflows**: Search, create, and organize notes through AI assistants

### About Packer Installation

#### Why Packer is Installed Directly (Not via Homebrew)

HashiCorp's Packer is installed directly from the official HashiCorp releases rather than through Homebrew. This is because:

- HashiCorp changed Packer's license to BUSL (Business Source License)
- This license change conflicts with Homebrew's requirement for open-source licenses
- Homebrew has disabled the Packer formula with the message: "Disabled because it will change its license to BUSL on the next release!"

The setup script downloads the official binary from HashiCorp's release page, verifies it, and installs it to the system.

#### Packer as a Complementary Tool for OrbStack

Packer provides the following functionality alongside OrbStack:

- **Custom VM Images**: Creation of machine images for use with OrbStack's VM capabilities
- **Environment Standardization**: Versioned machine images for consistent development environments
- **Test Environment Automation**: Automated creation of test environments with predefined configurations
- **Infrastructure as Code**: VM lifecycle management alongside Terraform

### About Terraform Installation

#### Why Terraform is Installed Directly (Not via Homebrew)

Like Packer, Terraform is installed directly from the official HashiCorp releases rather than through Homebrew. This is because:

- HashiCorp changed Terraform's license to BUSL (Business Source License)
- This license change conflicts with Homebrew's requirement for open-source licenses
- Homebrew has disabled the Terraform formula with the message: "Disabled because it will change its license to BUSL on the next release!"

The setup script downloads the official binary from HashiCorp's release page, verifies it, and installs it to the system.

#### Terraform as a Core Infrastructure Tool

Terraform provides the following functionality:

- **Infrastructure as Code**: Infrastructure definition and versioning
- **Provider Support**: Integration with AWS, Azure, GCP, and local providers like Docker
- **State Management**: Infrastructure state tracking and change management
- **Team Collaboration**: Infrastructure code sharing and versioning

The setup script configures Terraform with:
- Shell completions
- Provider plugin management
- State file handling
- Workspace management

### MCP Server Integration

The setup includes comprehensive integration with Model Context Protocol (MCP) servers, which provide enhanced AI capabilities through specialized Docker containers. This feature enables seamless integration between AI tools (Cursor IDE, Claude Desktop) and external services.

#### Available MCP Servers
- **GitHub MCP Server**: Repository management and code analysis
  - **Features**: Repository management, issue tracking, pull requests, code search, file operations
  - **Docker Image**: `mcp/github-mcp-server:latest`
  - **Requires**: `GITHUB_TOKEN` and `GITHUB_PERSONAL_ACCESS_TOKEN`

- **CircleCI MCP Server**: CI/CD pipeline monitoring and management
  - **Features**: Pipeline monitoring, job management, artifact access, environment variables
  - **Docker Image**: `local/mcp-server-circleci:latest`
  - **Requires**: `CIRCLECI_TOKEN` and `CIRCLECI_BASE_URL`

- **Heroku MCP Server**: Manage Heroku apps, pipelines, dynos, and add-ons
  - **Features**: App management, deployment, dyno scaling, logs, add-on provisioning, pipeline operations, team and space management, PostgreSQL database tools
  - **Docker Image**: `local/heroku-mcp-server:latest`
  - **Requires**: `HEROKU_API_KEY` (Heroku API token)

  The Heroku MCP server is built automatically during setup, along with all other MCP servers. To enable Heroku integration, add your Heroku API key to `.env`:
  ```
  HEROKU_API_KEY=your_heroku_api_key_here
  ```
  Then test the server:
  ```bash
  ./mcp_manager.sh test heroku
  ```

  The Dockerfile for the Heroku MCP server is located at `support/docker/mcp-server-heroku/Dockerfile`.

- **Filesystem MCP Server**: Local file system operations and management
  - **Features**: File operations, directory management, file search, file metadata, secure access
  - **Docker Image**: `mcp/filesystem:latest`
  - **Configuration**: Uses directory path arguments (not environment variables)
  - **Mount Setup**: Automatically mounts project directory to `/project` inside container
  - **Default Access**: Current MacbookSetup project directory by default
  - **Security**: Restricts access to explicitly mounted directories only

  **Available Tools**:
  - `read_file` / `read_multiple_files` - Read file contents
  - `write_file` - Create or overwrite files with new content
  - `list_directory` - Get detailed directory listings
  - `create_directory` - Create new directories
  - `move_file` - Move or rename files and directories
  - `delete_file` - Delete files or directories (with recursive option)
  - `search_files` - Search for files matching patterns
  - `get_file_info` - Get file metadata (size, timestamps, permissions)
  - `list_allowed_directories` - Show accessible directory paths

  **Note**: The filesystem server operates differently from other MCP servers - it requires directory paths as command line arguments rather than environment variables. Our Docker configuration automatically mounts the current project directory (`$(pwd)`) to `/project` inside the container.

- **Terraform MCP Server (HashiCorp Official)**: Registry API access and documentation
  - **Features**: Provider documentation access, module discovery, registry search, resource documentation
  - **Docker Image**: `hashicorp/terraform-mcp-server:latest`
  - **Type**: Standalone (no authentication required)
  - **Purpose**: Research and discovery phase of infrastructure development

- **Terraform CLI Controller (Custom)**: Direct Terraform CLI execution and state management
  - **Features**: Terraform CLI execution, state management, infrastructure provisioning, plan generation, workspace management, Docker provider support
  - **Docker Image**: `local/terraform-cli-controller:latest`
  - **Type**: Privileged (Docker socket + credential access)
  - **Purpose**: Actual infrastructure deployment and management

- **Context7 MCP Server**: Library documentation and code examples
  - **Features**: Library documentation access, current code examples, library ID resolution, topic-focused documentation, version-specific documentation
  - **Docker Image**: `local/context7-mcp:latest`
  - **Type**: Standalone (no authentication required)
  - **Purpose**: Development research and library documentation discovery
  - **Source**: Built from [Upstash Context7](https://github.com/upstash/context7.git)

  **Available Tools**:
  - `get_library_docs` - Get comprehensive documentation for any library
  - `get_current_code` - Get current, up-to-date code examples
  - `resolve_library_id` - Resolve library names to standardized identifiers
  - `get_topic_docs` - Get focused documentation on specific topics
  - `get_version_docs` - Get version-specific documentation and migration guides

  **Use Cases**:
  - **Library Research**: Quickly understand how to use any programming library
  - **Code Examples**: Get current, working code examples for specific use cases
  - **Migration Assistance**: Find version-specific documentation for library upgrades
  - **Topic Learning**: Get focused documentation on specific programming topics
  - **API Discovery**: Explore library APIs and available functionality

  **Example Usage**:
  ```bash
  # Test the Context7 server
  ./mcp_manager.sh test context7

  # Build the server (if not already built)
  ./mcp_manager.sh setup context7
  ```

  **Note**: Context7 requires no authentication and provides immediate access to library documentation. The server is built from source during setup and provides comprehensive programming library assistance.

- **Linear MCP Server**: Project management via Cloudflare-hosted MCP server
  - **Features**: Issue tracking, project management, team collaboration
  - **Type**: Remote (hosted by Cloudflare)
  - **Purpose**: AI-enhanced Linear project management workflows
  - **URL**: `https://mcp.linear.app/sse`
  - **Proxy**: Uses `mcp-remote` via npx for remote server connectivity

  **Prerequisites**:
  - **Node.js and npm**: Required for `npx` command (included in MacbookSetup via nvm)
  - **Internet connection**: For connecting to Cloudflare-hosted server
  - **mcp-remote package**: Auto-installed via `npx -y mcp-remote` (no manual setup needed)

  **What's NOT Required**:
  - ❌ Docker (remote servers don't use containers)
  - ❌ Local server setup (everything runs in the cloud)
  - ❌ API tokens (Linear MCP server handles authentication)
  - ❌ Manual package installation (npx handles dependencies)

  **Usage**:
  ```bash
  # Test the Linear MCP server connectivity
  ./mcp_manager.sh test linear

  # Generate configuration for AI tools
  ./mcp_manager.sh config-write
  ```

  **Note**: Linear MCP server is hosted remotely by Cloudflare and requires minimal local setup. It uses Server-Sent Events (SSE) for real-time communication and is accessed via the `mcp-remote` proxy command. This is the first example of our remote MCP server architecture that enables AI tools to connect to cloud-hosted MCP services.

- **Obsidian MCP Server**: Comprehensive vault management for knowledge workers
  - **Features**: Note management, vault search, tag operations, frontmatter manipulation, file operations, folder management, link management, metadata access
  - **Docker Image**: `local/obsidian-mcp-server:latest`
  - **Type**: API-based (requires Obsidian Local REST API plugin)
  - **Purpose**: AI-enhanced knowledge management and note-taking workflows
  - **Source**: Built from [cyanheads/obsidian-mcp-server](https://github.com/cyanheads/obsidian-mcp-server.git)

  **Available Tools**:
  - `search_notes` - Global search across vault (when cache enabled)
  - `read_note` / `read_notes` - Read note contents and metadata
  - `write_note` - Create or update notes with content and frontmatter
  - `delete_note` - Delete notes from vault
  - `list_notes` - List notes in folder or entire vault
  - `create_folder` / `delete_folder` - Folder management operations
  - `get_tags` / `get_notes_by_tag` - Tag-based organization
  - `get_frontmatter` / `update_frontmatter` - YAML frontmatter manipulation

  **Host Setup Requirements**:

  To use the Obsidian MCP server, you need to set up the Obsidian Local REST API plugin on your host machine:

  1. **Install Obsidian Local REST API Plugin**:
     - Open Obsidian → Settings → Community Plugins
     - Search for "Local REST API" by coddingtonbear
     - Install and enable the plugin

  2. **Configure the Plugin**:
     - Go to Plugin Settings for "Local REST API"
     - **Enable** the REST API server
     - **Set Port**: Use `27124` (default, or choose your preferred port)
     - **Enable HTTPS**: Recommended for security
     - **Generate API Key**: Copy the generated API key for environment configuration
     - **Enable CORS**: Required for Docker container communication

  3. **Environment Configuration**:
     Add the following to your `.env` file:
     ```bash
     # Obsidian MCP Server Configuration
     OBSIDIAN_API_KEY=your_api_key_from_plugin_settings
     OBSIDIAN_BASE_URL=https://host.docker.internal:27124
     OBSIDIAN_VERIFY_SSL=false  # For self-signed certificates
     OBSIDIAN_ENABLE_CACHE=true  # Enables global search capabilities
     MCP_TRANSPORT_TYPE=stdio
     MCP_LOG_LEVEL=debug
     ```

  4. **Network Configuration**:
     - The MCP server uses `host.docker.internal:27124` to connect from Docker containers to your local Obsidian instance
     - This works automatically on macOS with Docker Desktop
     - Ensure Obsidian is running and the Local REST API plugin is active

  5. **Testing the Setup**:
     ```bash
     # Test the Obsidian MCP server
     ./mcp_manager.sh test obsidian

     # Build the server (if not already built)
     ./mcp_manager.sh setup obsidian
     ```

  **Use Cases**:
  - **AI-Enhanced Note Taking**: Let AI assistants help organize and search your knowledge base
  - **Content Generation**: Generate notes, outlines, and documentation directly in your vault
  - **Research Workflows**: AI can search and reference your existing notes while helping with new content
  - **Knowledge Graph Navigation**: AI can understand relationships between notes via links and tags
  - **Automated Organization**: AI can help with tagging, linking, and structuring your vault

  **Performance Notes**:
  - **Cache Building**: When `OBSIDIAN_ENABLE_CACHE=true`, the server builds an index of your vault on startup (20s timeout)
  - **Global Search**: Cache enables powerful full-text search across your entire vault
  - **Silent Server**: The server doesn't log startup messages, so enhanced readiness detection is used

  **Security Considerations**:
  - API key provides full access to your Obsidian vault
  - Keep your API key secure and never commit it to version control
  - The Local REST API plugin runs locally, so data doesn't leave your machine
  - Docker container communicates only with your local Obsidian instance

#### Terraform Infrastructure Workflow

The MacbookSetup project includes **two complementary Terraform MCP servers** that work together to provide a complete Infrastructure as Code development experience:

##### 🔍 **Discovery & Research Phase**
Use the **HashiCorp Terraform MCP Server** for:
- **Provider Documentation**: Get detailed documentation for AWS, Azure, GCP, and other providers
- **Module Discovery**: Find and explore community modules from the Terraform Registry
- **Resource Documentation**: Understand resource schemas, arguments, and attributes
- **Best Practices**: Access HashiCorp's official documentation and examples

```bash
# Test the discovery server
./mcp_manager.sh test terraform
```

##### 🚀 **Development & Deployment Phase**
Use the **Terraform CLI Controller** for:
- **Infrastructure Provisioning**: Actually deploy resources to cloud providers
- **State Management**: Track and manage Terraform state files
- **Plan Generation**: Create and review execution plans before applying changes
- **Workspace Management**: Manage multiple environments (dev, staging, prod)
- **Docker Integration**: Deploy containerized applications alongside cloud infrastructure

```bash
# Test the CLI controller
./mcp_manager.sh test terraform-cli-controller
```

##### 🔗 **Multi-Cloud Credential Management**

The **Terraform CLI Controller** uses a sophisticated mount strategy to provide secure access to cloud provider credentials:

**Current Mount Points:**
```bash
# AWS Credentials (read-only)
$HOME/.aws:/root/.aws:ro

# Terraform Configuration and Cache
$HOME/.terraform.d:/root/.terraform.d

# Docker Socket for Container Management
/var/run/docker.sock:/var/run/docker.sock
```

**Extending to Other Cloud Providers:**

For **DigitalOcean**:
```bash
# Add to your .env file
DIGITALOCEAN_TOKEN=your_digitalocean_token_here

# Or mount credential file
$HOME/.config/doctl:/root/.config/doctl:ro
```

For **Azure**:
```bash
# Mount Azure credentials
$HOME/.azure:/root/.azure:ro

# Environment variables in .env
AZURE_CLIENT_ID=your_client_id
AZURE_CLIENT_SECRET=your_client_secret
AZURE_TENANT_ID=your_tenant_id
AZURE_SUBSCRIPTION_ID=your_subscription_id
```

For **Google Cloud Platform**:
```bash
# Mount service account key
$HOME/.config/gcloud:/root/.config/gcloud:ro

# Environment variable in .env
GOOGLE_APPLICATION_CREDENTIALS=/root/.config/gcloud/service-account-key.json
```

**Multi-Provider Terraform Example:**
```hcl
# terraform/multi-cloud-infrastructure.tf

# AWS Resources
provider "aws" {
  region = "us-east-1"
  # Uses mounted ~/.aws/credentials
}

# DigitalOcean Resources
provider "digitalocean" {
  token = var.digitalocean_token  # From .env file
}

# Docker Resources (Local)
provider "docker" {
  host = "unix:///var/run/docker.sock"  # Uses mounted Docker socket
}

# Deploy across multiple providers
resource "aws_s3_bucket" "backups" {
  bucket = "my-app-backups"
}

resource "digitalocean_droplet" "web" {
  image  = "ubuntu-20-04-x64"
  name   = "web-server"
  region = "nyc1"
  size   = "s-1vcpu-1gb"
}

resource "docker_container" "monitoring" {
  image = "grafana/grafana:latest"
  name  = "monitoring-dashboard"
}
```

##### 💡 **Best Practices for Combined Usage**

1. **Start with Discovery**: Use the HashiCorp server to research providers and modules
2. **Plan with CLI Controller**: Use the CLI controller to create and test infrastructure plans
3. **Secure Credentials**: Store sensitive credentials in mounted directories or environment files
4. **Multi-Environment**: Use Terraform workspaces for different deployment environments
5. **Version Control**: Keep Terraform files in Git, exclude sensitive state files

**Example Workflow:**
```bash
# 1. Research AWS provider documentation (HashiCorp server)
# Ask AI: "Show me AWS S3 bucket resource documentation"

# 2. Create infrastructure (CLI controller)
# Ask AI: "Create an S3 bucket with versioning enabled"

# 3. Test locally with Docker (CLI controller)
# Ask AI: "Deploy a local monitoring stack with Docker containers"

# 4. Deploy to multiple clouds (CLI controller)
# Ask AI: "Apply this infrastructure to both AWS and DigitalOcean"
```

This dual-server approach provides comprehensive infrastructure development capabilities, from initial research to production deployment across multiple cloud providers.

##### 🔧 **Extending Multi-Cloud Support**

To add support for additional cloud providers, you can extend the **Terraform CLI Controller** configuration by modifying the `mcp_server_registry.yml` file:

**Example: Adding Google Cloud Platform Support**
```yaml
# Add to mcp_server_registry.yml under terraform-cli-controller volumes:
volumes:
  - "/var/run/docker.sock:/var/run/docker.sock"
  - "$HOME/.terraform.d:/root/.terraform.d"
  - "$HOME/.aws:/root/.aws:ro"
  - "$HOME/.config/gcloud:/root/.config/gcloud:ro"  # Add GCP credentials
  - "$HOME/.azure:/root/.azure:ro"                  # Add Azure credentials
```

**Example: Adding DigitalOcean Support**
```yaml
# Add to mcp_server_registry.yml under terraform-cli-controller environment_variables:
environment_variables:
  - "DIGITALOCEAN_TOKEN"     # Add DigitalOcean token
  - "LINODE_TOKEN"           # Add Linode token
  - "HETZNER_TOKEN"          # Add Hetzner token
```

After modifying the registry, rebuild the configuration:
```bash
# Regenerate configurations with new mount points
./mcp_manager.sh config-write

# Test the updated controller
./mcp_manager.sh test terraform-cli-controller
```

**Credential Strategy Options:**

1. **File-based (Recommended for CLI tools)**:
   - Mount provider-specific credential directories
   - Uses each provider's standard credential location
   - Examples: `~/.aws`, `~/.config/gcloud`, `~/.azure`

2. **Environment Variables (Recommended for API tokens)**:
   - Add tokens to `.env` file
   - Suitable for simple token-based authentication
   - Examples: `DIGITALOCEAN_TOKEN`, `LINODE_TOKEN`

3. **Hybrid Approach (Best of both)**:
   - Use file mounts for complex authentication (AWS, GCP, Azure)
   - Use environment variables for simple tokens (DigitalOcean, Linode)

**Security Considerations:**
- Always use `:ro` (read-only) for credential mounts
- Store tokens in `.env` file, never in configuration files
- Use IAM roles and service accounts when possible
- Regularly rotate access keys and tokens
- Consider using temporary credentials for production deployments

#### MCP Server Management

The setup includes a comprehensive MCP server manager (`mcp_manager.sh`) that provides:

1. **Health Testing**
   ```bash
   # Test all servers with comprehensive health checks
   ./mcp_manager.sh test

   # Test specific server
   ./mcp_manager.sh test github
   ./mcp_manager.sh test filesystem

   # Health testing includes:
   # - Basic MCP protocol validation (CI-friendly, no auth required)
   # - Advanced functionality testing (when real tokens detected)
   # - Container environment variable verification
   ```

2. **Configuration Generation**
   ```bash
   # Generate client configurations and environment templates
   ./mcp_manager.sh config-write

   # Preview configurations without writing files
   ./mcp_manager.sh config cursor    # Preview Cursor config
   ./mcp_manager.sh config claude    # Preview Claude Desktop config
   ./mcp_manager.sh config env       # Preview environment variables
   ```

3. **Environment Management**
   ```bash
   # The script automatically:
   # - Creates .env_example with placeholder tokens
   # - Preserves existing .env files (never overwrites)
   # - Validates tokens against placeholders
   # - Tests environment variables inside Docker containers
   ```

#### Client Integration

MCP servers integrate with AI tools using a secure, Docker-based approach:

1. **Cursor IDE**
   - **Configuration file**: `~/.cursor/mcp.json`
   - **Format**: Direct server mapping with Docker commands
   - **Environment**: Uses `--env-file /path/to/.env` approach

2. **Claude Desktop**
   - **Configuration file**: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - **Format**: Nested under `mcpServers` object
   - **Environment**: Uses `--env-file /path/to/.env` approach

#### Security and Environment Handling

The MCP integration follows security best practices:

- **Environment File Safety**:
  - ✅ Generates `.env_example` with placeholders like `your_github_token_here`
  - ✅ Never overwrites existing `.env` files
  - ✅ Uses absolute paths for environment files
  - ❌ Never includes real tokens in configuration files

- **Token Validation**:
  - Reads tokens from `.env` file, not host environment variables
  - Validates tokens against placeholder patterns
  - Tests environment variable visibility inside Docker containers
  - Provides clear guidance for missing or invalid tokens

- **Configuration Approach**:
  - Uses `--env-file` instead of inline environment variables in JSON
  - Maintains environment-agnostic configuration files
  - Supports both authenticated and basic protocol testing

#### MCP Inspector Integration

The setup includes a **Docker-based MCP Inspector** for visual testing and debugging of MCP servers:

- **Official MCP Inspector**: `@modelcontextprotocol/inspector` containerized with enhanced resilience
- **Web Interface**: Accessible at `http://localhost:6274` when running
- **Dual Architecture**: UI Server (port 6274) + Proxy Server (port 6277)
- **Auto-Restart**: Built-in health monitoring and automatic crash recovery
- **Docker Integration**: Full access to host Docker and file system for testing

##### Inspector Commands

```bash
# Launch visual web interface
./mcp_manager.sh inspect --ui

# Monitor health with auto-healing
./mcp_manager.sh inspect --health

# Stop inspector
./mcp_manager.sh inspect --stop

# Validate client configurations
./mcp_manager.sh inspect --validate-config

# Debug specific server with logs
./mcp_manager.sh inspect github --debug
```

##### Inspector Features

- **✅ Visual Server Testing**: Interactive web UI for testing MCP server tools and capabilities
- **✅ Real-time Debugging**: View server logs, requests, and responses in real-time
- **✅ Configuration Export**: Generate client configurations for Cursor and Claude Desktop
- **✅ Health Monitoring**: Automatic detection and recovery from proxy server crashes
- **✅ Environment Validation**: Test environment variables and Docker container setup

#### Getting Started with MCP Servers

1. **Generate Initial Configuration**:
   ```bash
   ./mcp_manager.sh config-write
   ```

2. **Set Up Environment Variables**:
   ```bash
   # Copy the example file
   cp .env_example .env

   # Edit .env with your real tokens
   # Replace placeholder values like "your_github_token_here" with actual tokens
   ```

3. **Test Server Health**:
   ```bash
   # Basic protocol tests (no authentication required)
   ./mcp_manager.sh test

   # Advanced tests (requires real tokens in .env)
   # Will automatically run when real tokens are detected
   ```

4. **Launch MCP Inspector** (Recommended):
   ```bash
   # Start visual debugging interface
   ./mcp_manager.sh inspect --ui

   # Visit http://localhost:6274 in your browser
   # Use Docker command: docker run --rm -i --env-file .env mcp/github-mcp-server:latest
   ```

5. **Use with AI Tools**:
   - **Cursor**: Restart Cursor IDE to pick up `~/.cursor/mcp.json`
   - **Claude Desktop**: Restart Claude Desktop to pick up configuration changes

#### Environment Requirements

For full MCP functionality:
- **Container Runtime**: OrbStack or Docker for container management
- **API Tokens**: Valid tokens for each service (stored in `.env` file)
- **Network Access**: Proper connectivity for container communication

#### Shell Completion

The setup includes comprehensive tab completion for `mcp_manager.sh`:

```bash
# After setup, you can use tab completion for all commands
./mcp_manager.sh <TAB><TAB>           # Shows: config, config-write, test, health
./mcp_manager.sh test <TAB><TAB>      # Shows: github, circleci, filesystem
./mcp_manager.sh config <TAB><TAB>    # Shows: cursor, claude, env
```

Completion features:
- **Command completion**: All available commands and subcommands
- **Server name completion**: Auto-complete server names for test commands
- **Configuration type completion**: Auto-complete config types (cursor, claude, env)

#### Troubleshooting

- **"No tools available" warnings**: Usually indicates token lacks required permissions
- **JSON parsing errors**: Check that no debug output is contaminating configuration files
- **Environment variable issues**: Use `./mcp_manager.sh test` to verify container environment
- **Configuration not loading**: Ensure AI tools are restarted after configuration changes
- **Tab completion not working**: Ensure shell completion is properly sourced: `source _mcp_manager`

### Terminal and Editor Tools
- **iTerm2**: Enhanced terminal emulator
- **Warp**: Modern terminal with AI features
- **Zinit**: Z shell plugin manager
- **Starship**: Cross-shell customizable prompt
- **Nerd Fonts**: Special fonts that include icons needed for Starship prompt
- **Other tools**: See the Brewfile for the complete list

### Configuration
- Shell environment configuration (.zshrc)
- Tool initialization and setup
- Path configuration

### Terminal Appearance

#### Starship Prompt and Nerd Fonts

Starship provides a customizable command-line prompt that displays contextual information while you work. To get the full visual experience with all icons and symbols:

1. **Install Nerd Fonts** (done automatically by the setup script)
   - The setup includes FiraCode Nerd Font and JetBrains Mono Nerd Font

2. **Configure Your Terminal**:

   **For iTerm2:**
   - Open iTerm2 Preferences (⌘,)
   - Go to Profiles > Text
   - Click on Font and select one of:
     - `FiraCode Nerd Font`
     - `FiraCode Nerd Font Mono` (fixed width)
     - `JetBrainsMono Nerd Font`
     - `JetBrainsMono Nerd Font Mono` (fixed width)
   - Adjust the font size as needed

   **For Warp:**
   - Open Settings (⌘,)
   - Navigate to Appearance > Fonts
   - Click on the font dropdown and select one of the Nerd Fonts
   - You may need to restart Warp for changes to take effect

3. **Verify Starship Icons**
   - Once configured, you should see icons for Git branches, programming languages, and other status indicators in your prompt
   - If you see squares or question marks instead of icons, your terminal is not using a Nerd Font

#### Troubleshooting Font Issues

- If icons aren't displaying correctly after installing fonts, try restarting your terminal application
- Some terminal applications might require the "Mono" variant of the font
- You may need to log out and back in for the fonts to be fully recognized by the system

## 🔧 Usage

### Quick Start

```bash
# Clone the repository
git clone https://github.com/Govinda-Fichtner/MacbookSetup.git
cd MacbookSetup

# Make the script executable
chmod +x setup.sh

# Run the setup
./setup.sh
```

### What It Does

1. Checks if Homebrew is installed; installs it if needed
2. Installs all packages from the Brewfile
3. Configures your shell with necessary tool integrations
4. Installs the latest stable Ruby and Python versions
5. Sets up development environments ready to use

### Customization

To customize your setup, modify the `Brewfile` before running the script. Add or remove packages as needed:

```ruby
# Add a formula (CLI tool)
brew "your-package-name"

# Add a cask (GUI application)
cask "your-app-name"
```

## 📋 Requirements

- macOS Catalina (10.15) or newer
- Administrative privileges on your Mac
- Internet connection
- For Apple Silicon Macs (M1/M2/M3): Rosetta 2 is recommended (`softwareupdate --install-rosetta`)

## 🧪 Testing

### Testing Strategy

The testing employs a focused strategy to efficiently validate the core functionality:

#### What We Test

- **Shell Configuration**: Verifies that `.zshrc` is properly set up with all required tool integrations (rbenv, pyenv, direnv, Starship, etc.)
- **Command-line Tools**: Tests the installation and availability of essential CLI tools that form the backbone of the development environment
- **Environment Initialization**: Ensures that version managers and shell extensions initialize correctly
- **Shell Completions**: Validates that command-line completions are properly configured for all installed tools

#### Testing Approach

The CI testing differentiates between several types of components:

1. **Essential CLI Tools** (fully tested):
   - Tools like Git, rbenv, pyenv, direnv, and Starship
   - These are verified to be installed, available in PATH, and properly configured
   - They represent the core functionality needed for development

2. **GUI Applications** (not tested in CI):
   - Applications like iTerm2, Warp, and Visual Studio Code
   - These are skipped during CI testing as they:
     - Cannot be meaningfully tested in a headless environment
     - Take longer to install and consume more resources
     - Don't affect the functionality of other development tools

3. **Optional Utilities** (not tested in CI):
   - Additional command-line utilities that enhance the development experience
   - While valuable for users, they're not essential for validating the setup process

This targeted testing approach ensures that:
- Test runs remain efficient
- Core functionality is thoroughly validated
- The setup script's reliability is maintained

When you run the setup script on your actual machine, it will install all tools including GUI applications and optional utilities as specified in the Brewfile.

#### Shell Completion Testing

The setup includes a comprehensive completion testing framework that verifies:

1. **Multiple Completion Types**:
   - Zinit plugin completions (e.g., Terraform)
   - Built-in Zsh completions (e.g., Git)
   - Custom completions (e.g., rbenv, pyenv, kubectl)

2. **Tested Tools**:
   - Core Development: Git, rbenv, pyenv, direnv
   - Infrastructure: Terraform, Packer
   - Kubernetes: kubectl, helm, kubectx
   - Shell Enhancements: Starship

3. **Verification Process**:
   - Checks if completion plugins are properly installed
   - Validates that completion functions are loaded
   - Tests basic completion functionality for common commands
   - Provides detailed logging for troubleshooting

4. **Extensibility**:
   - Structured configuration for adding new tool completions
   - Support for different completion mechanisms
   - Easy integration of new completion tests

This completion testing ensures that developers have full access to command-line completions, improving productivity and reducing errors.

#### CI Output Standardization

The project implements consistent output formatting across all verification scripts:

1. **Standardized Skip Messages**:
   - Format: `[SKIPPED] <what was skipped> (<reason>)`
   - Examples: `[SKIPPED] Terminal font verification (CI environment)`
   - Color-coded with yellow for easy identification

2. **Environment-Aware Testing**:
   - CI environments automatically skip GUI-dependent tests
   - Container runtime checks adapt to available infrastructure
   - Completion tests validate all available tools, only skipping truly unavailable ones

3. **Error Classification**:
   - `[ERROR]`: Critical failures that stop the build
   - `[WARNING]`: Issues that don't prevent continuation
   - `[SKIPPED]`: Intentionally bypassed checks (environment-specific)
   - `[INFO]`: Informational messages for context

4. **Clean Output**:
   - No debug variable contamination in logs
   - Consistent tree-structure formatting
   - Clear separation between test categories

This standardization ensures CI logs are readable and maintainable, making it easier to identify actual issues versus expected environment limitations.

## 🧹 Maintenance

### Cleaning Temporary Files

The project uses organized temporary directories for builds and testing. To clean up temporary files and directories:

```bash
# Clean all temporary directories (repositories, test files, etc.)
rm -rf tmp/*
```

This script cleans:
- `tmp/repositories/` - Git repositories cloned during MCP server builds
- `tmp/test_home/` - Test environment directories from ShellSpec tests
- Any other temporary files in the `tmp/` directory

The script is safe to run anytime and will show what it's cleaning up.

## 📄 License

This project is licensed under the MIT License - see below for details:

```
MIT License

Copyright (c) 2025 Govinda Fichtner

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Testing

### Shellspec Tests

Comprehensive tests for `mcp_manager.sh` are located in the `spec/` directory and cover:

- **Configuration Generation**: Valid JSON output for both Cursor and Claude Desktop
- **Environment File Safety**: Proper `.env_example` generation without overwriting existing files
- **Debug Output Prevention**: Ensures clean output without variable contamination
- **JSON Structure Validation**: Proper configuration format and structure
- **Server Integration**: Complete coverage of GitHub and CircleCI server configurations

To run all tests:

```sh
shellspec
```

To run only the MCP manager test suite:

```sh
shellspec spec/mcp_manager_spec.sh
```

### Test Categories

The test suite includes several focused categories:

1. **Configuration Generation Tests**
   - Valid JSON generation for both clients
   - Proper `--env-file` usage
   - Environment variable handling

2. **Debug Output Regression Tests**
   - Prevents debug variable contamination in JSON files
   - Ensures clean terminal output
   - Validates JSON parsing reliability

3. **Environment File Generation Tests**
   - `.env_example` creation with proper placeholders
   - Safety checks against overwriting existing `.env` files
   - Proper environment variable inclusion

4. **JSON Structure Validation Tests**
   - Validates configuration format consistency
   - Tests server configuration structure
   - Ensures proper args array formatting

This comprehensive testing ensures reliability and prevents regressions in MCP server configuration generation.

## Docker MCP Server Implementation

### Overview
The Docker MCP server has been implemented and tested using a Test-Driven Development (TDD) approach. This server allows for privileged access to Docker, enabling operations such as listing containers and managing Docker resources.

### Key Features
- **Privileged Configuration**: The server is configured with privileged access to Docker, allowing for advanced operations.
- **Socket Mounting**: The Docker socket is mounted to enable communication with the Docker daemon.
- **Network Settings**: The server is configured to use the host network for seamless integration.

### Testing
- **Unit Tests**: Comprehensive tests have been added to ensure the server's functionality, including handling Docker unavailability gracefully.
- **Integration Tests**: The server integrates seamlessly with existing MCP servers, maintaining configuration consistency.

### Usage
To use the Docker MCP server, ensure Docker is installed and running on your system. The server can be tested using the `./mcp_manager.sh test docker` command.

### Documentation
For more details, refer to the `spec/mcp_manager_spec.sh` file for test cases and the `mcp_server_registry.yml` for configuration details.
