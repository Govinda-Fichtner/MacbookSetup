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

The setup includes integration with Model Context Protocol (MCP) servers, which provide enhanced AI capabilities through specialized Docker containers. This feature enables:

#### Available MCP Servers
- **GitHub MCP Server**: Repository management and code analysis
  - Features: Repository management, issue tracking, pull requests, code search
  - Requires: GitHub Personal Access Token or GitHub Token

- **CircleCI MCP Server**: Pipeline monitoring and management
  - Features: Pipeline monitoring, job management, artifact access, environment variables
  - Requires: CircleCI Token

#### MCP Server Management

The setup includes a comprehensive MCP server manager (`mcp_manager.sh`) that provides:

1. **Server Setup**
   ```bash
   # Set up all MCP servers
   ./mcp_manager.sh setup

   # Set up specific server
   ./mcp_manager.sh setup github
   ```

2. **Health Testing**
   ```bash
   # Test all servers
   ./mcp_manager.sh test

   # Test specific server
   ./mcp_manager.sh test circleci
   ```

3. **Configuration Management**
   ```bash
   # Preview configurations
   ./mcp_manager.sh config

   # Write configurations to client files
   ./mcp_manager.sh config-write
   ```

#### Client Integration

MCP servers can be integrated with:

1. **Cursor IDE**
   - Configuration file: `~/.cursor/mcp.json`
   - Automatic token management
   - Docker-based server execution

2. **Claude Desktop**
   - Configuration file: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - Environment variable support
   - Containerized server execution

#### Configuration Structure

MCP servers are configured through `mcp_server_registry.yml`, which defines:
- Server metadata (name, description, category)
- Source configuration (Docker image or build)
- Environment variables
- Health test parameters
- Server capabilities

#### Environment Requirements

For full MCP functionality:
- OrbStack or Docker for container management
- Valid API tokens for each service
- Proper network connectivity for container communication

The setup script automatically:
- Creates necessary configuration directories
- Sets up default configuration files
- Validates server health
- Manages client integrations

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
