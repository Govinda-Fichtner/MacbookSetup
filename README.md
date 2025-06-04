# MacbookSetup

[![Build Status](https://api.cirrus-ci.com/github/Govinda-Fichtner/MacbookSetup.svg)](https://cirrus-ci.com/github/Govinda-Fichtner/MacbookSetup)

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

- **Filesystem MCP Server**: Local file system operations and management
  - **Features**: File operations, directory management, file search, file metadata, secure access
  - **Docker Image**: `mcp/filesystem:latest`
  - **Requires**: `FILESYSTEM_ALLOWED_DIRS` (comma-separated directory paths)
  - **Security**: Restricts access to explicitly specified directories only

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

## 🧪 Continuous Integration

This project uses Cirrus CI to validate the setup script on real macOS environments:

- Every commit is tested on macOS ARM (Apple Silicon) virtual machines
- The setup script is executed in a clean environment
- Installation of tools and configuration is verified

You can view CI build history on the [Cirrus CI dashboard](https://cirrus-ci.com/github/Govinda-Fichtner/MacbookSetup).

### Testing Strategy

The CI pipeline employs a focused testing strategy to efficiently validate the core functionality:

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
- CI runs remain efficient (typically under 15 minutes)
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
