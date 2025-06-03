#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2296,SC2034,SC1091

# macOS Development Environment Setup Script
#
# This script automates the installation and configuration of a development environment on macOS.
# It installs Homebrew, all tools specified in the Brewfile, and configures the shell environment.
#
# Usage: ./setup.sh

# Enable strict error handling
set -e

# Script configuration
readonly SCRIPT_VERSION="1.0.0"
readonly ZSHRC_PATH="${HOME}/.zshrc"
ZDOTDIR="${ZDOTDIR:-$HOME}"
readonly COMPLETION_DIR="${ZDOTDIR}/.zsh/completions"
readonly ZCOMPCACHE_DIR="${ZDOTDIR}/.zcompcache"
readonly ANTIDOTE_PLUGINS_FILE="${ZDOTDIR}/.zsh_plugins.txt"
# shellcheck disable=SC2155
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$1" >&2; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1" >&2; }
log_warning() { printf "${YELLOW}[WARNING]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }
log_debug() { printf "DEBUG: %s\n" "$1" >&2; }

# Progress spinner function
show_progress() {
  local prefix="$1"
  local message="$2"
  local pid="$3"

  # In CI, just show static message
  if [[ "${CI:-false}" == "true" ]]; then
    printf "%s %b[INSTALLING]%b %s (running in background)\n" "$prefix" "$BLUE" "$NC" "$message"
    return 0
  fi

  local spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  local i=0
  local start_time
  start_time=$(date +%s)

  # Hide cursor
  printf "\033[?25l"

  while kill -0 "$pid" 2> /dev/null; do
    local current_time
    current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    local time_str=""

    if [[ $mins -gt 0 ]]; then
      time_str=$(printf "%dm %02ds" "$mins" "$secs")
    else
      time_str=$(printf "%ds" "$secs")
    fi

    printf "\r%s %b[INSTALLING]%b %s %c (%s)" \
      "$prefix" "$BLUE" "$NC" "$message" \
      "${spinner:$i:1}" "$time_str"

    i=$(((i + 1) % ${#spinner}))
    sleep 0.2
  done

  # Show cursor and clear line
  printf "\033[?25h\r\033[K"
}

# Helper function to extract clean version numbers (shared with verify_setup.sh)
extract_version() {
  local version_string="$1"
  local tool="$2"

  # Handle empty version strings
  [[ -z "$version_string" ]] && echo "" && return

  case "$tool" in
    brew)
      # "Homebrew 4.5.3" -> "4.5.3"
      echo "$version_string" | sed -n 's/.*Homebrew \([0-9][0-9.]*\).*/\1/p'
      ;;
    git)
      # "git version 2.49.0" -> "2.49.0"
      echo "$version_string" | sed -n 's/.*version \([0-9][0-9.]*\).*/\1/p'
      ;;
    rbenv | pyenv | starship)
      # "rbenv 1.3.2" -> "1.3.2"
      echo "$version_string" | sed -n 's/.* \([0-9][0-9.]*\).*/\1/p'
      ;;
    direnv)
      # "2.36.0" -> "2.36.0" (direnv outputs just the version number)
      echo "$version_string" | sed -n 's/^\([0-9][0-9.]*\).*/\1/p'
      ;;
    terraform)
      # "Terraform v1.12.1" -> "1.12.1"
      echo "$version_string" | sed -n 's/.*v\([0-9][0-9.]*\).*/\1/p'
      ;;
    packer)
      # "Packer v1.12.0" -> "1.12.0"
      echo "$version_string" | sed -n 's/.*Packer v\([0-9][0-9.]*\).*/\1/p'
      ;;
    *)
      # For other tools, try to extract the first version-like pattern
      echo "$version_string" | sed -n 's/.*\([0-9][0-9.]*[0-9]\).*/\1/p' | head -1
      ;;
  esac
}

# Utility functions
check_command() {
  command -v "$1" > /dev/null 2>&1
}

# Function to ensure directory exists
ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir" 2> /dev/null || {
      log_warning "Failed to create directory: $dir"
      return 1
    }
  fi
  return 0
}

# Function to ensure completion directory exists
ensure_completion_dir() {
  ensure_dir "$COMPLETION_DIR" || return 1
  # Add completion directory to fpath if not already there
  if [[ ":${fpath}:" != *":${COMPLETION_DIR}:"* ]]; then
    fpath=("$COMPLETION_DIR" "${fpath[@]}")
  fi
  return 0
}

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local timestamp
    timestamp=$(date +"%Y%m%d%H%M%S")
    local backup="${file}.backup.${timestamp}"
    cp "$file" "$backup" || {
      printf "│   └── %b[ERROR]%b Failed to create backup of %s\n" "$RED" "$NC" "$file"
      return 1
    }
  fi
}

# Function to ensure MCP server config files exist
ensure_mcp_server_config() {
  local server_name="$1"
  local connector="$2" # For tree structure (e.g., "│  ")
  local mcp_config_dir="${HOME}/.config/mcp/${server_name}"
  local mcp_config_file="${mcp_config_dir}/config.json"

  printf "%s %b[CONFIG]%b Ensuring MCP server config for %s\n" "$connector" "$BLUE" "$NC" "$server_name"

  if ! ensure_dir "$mcp_config_dir"; then
    printf "│   └── %b[ERROR]%b Failed to create MCP config directory for %s\n" "$RED" "$NC" "$server_name"
    return 1
  fi

  if [[ ! -f "$mcp_config_file" ]]; then
    printf "│   ├── %b[CREATING]%b Default config.json for %s\n" "$BLUE" "$NC" "$server_name"
    # Create a minimal valid JSON config with placeholder token
    if [[ "$server_name" == "github-mcp-server" ]]; then
      echo '{ "token": "your_github_token_here" }' > "$mcp_config_file"
    elif [[ "$server_name" == "circleci-mcp-server" ]]; then
      echo '{ "token": "your_circleci_token_here", "host": "https://circleci.com" }' > "$mcp_config_file"
    else
      echo "{}" > "$mcp_config_file"
    fi

    if [ ! -f "$mcp_config_file" ]; then
      printf "│   │   └── %b[ERROR]%b Failed to create default config.json for %s\n" "$RED" "$NC" "$server_name"
      return 1
    fi
    printf "│   └── %b[SUCCESS]%b Created default config.json for %s\n" "$GREEN" "$NC" "$server_name"
  else
    printf "│   └── %b[EXISTS]%b config.json found for %s\n" "$GREEN" "$NC" "$server_name"
  fi
  return 0
}

# System validation
validate_system() {
  echo -e "\n=== System Validation ==="

  printf "├── %b[CHECKING]%b Operating system\n" "$BLUE" "$NC"
  # Check OS
  if [[ "$(uname)" != "Darwin" ]]; then
    printf "│   └── %b[ERROR]%b This script requires macOS\n" "$RED" "$NC"
    return 1
  fi
  printf "│   └── %b[SUCCESS]%b macOS detected\n" "$GREEN" "$NC"

  printf "└── %b[CHECKING]%b User permissions\n" "$BLUE" "$NC"
  # Check if running as root
  if [[ $EUID -eq 0 ]]; then
    printf "    └── %b[ERROR]%b Do not run as root - use regular user\n" "$RED" "$NC"
    return 1
  fi
  printf "    └── %b[SUCCESS]%b Running as regular user\n" "$GREEN" "$NC"

  return 0
}

# HashiCorp tool installation
install_hashicorp_tool() {
  local tool="$1"
  local version="$2"
  local arch
  local connector="$3"

  printf "%s %b[CHECKING]%b %s\n" "$connector" "$BLUE" "$NC" "$tool"
  if check_command "$tool"; then
    local current_version
    current_version=$("$tool" --version 2> /dev/null | head -1)
    # Extract clean version for display
    local clean_version
    clean_version=$(extract_version "$current_version" "$tool")
    printf "│   └── %b[SUCCESS]%b Already installed (v%s)\n" "$GREEN" "$NC" "$clean_version"
    return 0
  fi

  # Determine architecture
  if [[ "$(uname -m)" == "arm64" ]]; then
    arch="arm64"
  else
    arch="amd64"
  fi

  # Create temporary directory
  local tmp_dir
  tmp_dir=$(mktemp -d) || {
    printf "│   └── %b[ERROR]%b Failed to create temporary directory\n" "$RED" "$NC"
    return 1
  }

  local download_url="https://releases.hashicorp.com/$tool/$version/${tool}_${version}_darwin_${arch}.zip"
  local zip_file="$tmp_dir/$tool.zip"

  printf "│   ├── %b[DOWNLOADING]%b %s v%s\n" "$BLUE" "$NC" "$tool" "$version"
  # Download and install
  if curl -sSL "$download_url" -o "$zip_file" \
    && unzip -q "$zip_file" -d "$tmp_dir" \
    && sudo mv "$tmp_dir/$tool" /usr/local/bin/ \
    && sudo chmod +x "/usr/local/bin/$tool"; then
    printf "│   └── %b[SUCCESS]%b %s v%s installed\n" "$GREEN" "$NC" "$tool" "$version"
    rm -rf "$tmp_dir"
    return 0
  else
    printf "│   └── %b[ERROR]%b Failed to install %s\n" "$RED" "$NC" "$tool"
    rm -rf "$tmp_dir"
    return 1
  fi
}

install_hashicorp_tools() {
  echo -e "\n=== Infrastructure Tools ==="
  install_hashicorp_tool "terraform" "1.12.1" "├──" || printf "├── %b[WARNING]%b Terraform installation skipped\n" "$YELLOW" "$NC"
  install_hashicorp_tool "packer" "1.12.0" "└──" || printf "└── %b[WARNING]%b Packer installation skipped\n" "$YELLOW" "$NC"
}

# MCP Configuration Setup
setup_containerization_and_mcp() {
  echo -e "\n=== MCP Configuration Setup ==="
  local mcp_base_config_dir="${HOME}/.config/mcp"

  # Ensure base MCP config directory exists
  printf "├── %b[CONFIG]%b Ensuring base MCP config directory (%s)\n" "$BLUE" "$NC" "$mcp_base_config_dir"
  if ! ensure_dir "$mcp_base_config_dir"; then
    printf "│   └── %b[ERROR]%b Failed to create base MCP config directory. MCP setup will be incomplete.\n" "$RED" "$NC"
    # Do not return 1 here, let other checks proceed, but this is a critical warning.
    log_warning "Base MCP directory ${mcp_base_config_dir} could not be created."
  else
    printf "│   └── %b[SUCCESS]%b Base MCP config directory ensured.\n" "$GREEN" "$NC"
  fi

  # Environment-aware MCP setup
  if [[ "${CI:-false}" == "true" ]]; then
    printf "├── %b[CI ENVIRONMENT]%b Skipping containerization - MCP config only\n" "$BLUE" "$NC"
    printf "│   └── %b[INFO]%b CI detected - focusing on configuration validation\n" "$BLUE" "$NC"
    return 0
  fi

  # Local environment: prefer OrbStack if available
  printf "├── %b[LOCAL ENVIRONMENT]%b Checking OrbStack status\n" "$BLUE" "$NC"
  if check_command orbctl; then
    if orbctl status > /dev/null 2>&1; then
      printf "│   └── %b[SUCCESS]%b OrbStack is running - MCP servers ready for local testing\n" "$GREEN" "$NC"
      export CONTAINER_RUNTIME=orbstack
    else
      printf "│   └── %b[INFO]%b OrbStack installed but not running - start manually for MCP testing\n" "$YELLOW" "$NC"
    fi
  else
    printf "│   └── %b[INFO]%b OrbStack not found - install for full MCP functionality\n" "$YELLOW" "$NC"
  fi

  # MCP Configuration Setup (directory structure only)
  printf "└── %b[CONFIG]%b Setting up MCP configuration structure\n" "$BLUE" "$NC"

  # Ensure MCP configuration directories exist
  ensure_mcp_server_config "github-mcp-server" "    "
  ensure_mcp_server_config "circleci-mcp-server" "    "

  printf "    └── %b[SUCCESS]%b MCP configuration structure ready\n" "$GREEN" "$NC"

  return 0
}

# Homebrew installation and package management
install_homebrew() {
  echo -e "\n=== System Dependencies ==="
  printf "├── %b[CHECKING]%b Homebrew installation\n" "$BLUE" "$NC"

  if check_command brew; then
    printf "└── %b[SUCCESS]%b Homebrew already installed\n" "$GREEN" "$NC"
    return 0
  fi

  printf "├── %b[INSTALLING]%b Homebrew (this may take a few minutes)\n" "$BLUE" "$NC"

  # Install Homebrew with minimal output
  local brew_install_log="/tmp/homebrew_install.log"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > "$brew_install_log" 2>&1 || {
    printf "└── %b[ERROR]%b Failed to install Homebrew. See %s for details.\n" "$RED" "$NC" "$brew_install_log"
    return 1
  }

  # Configure Homebrew PATH based on architecture
  if [[ "$(uname -m)" == "arm64" ]]; then
    # shellcheck disable=SC2016
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$ZSHRC_PATH"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    # shellcheck disable=SC2016
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$ZSHRC_PATH"
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  printf "└── %b[SUCCESS]%b Homebrew installation complete\n" "$GREEN" "$NC"

  # Ensure .config directory exists for subsequent MCP setup steps
  ensure_dir "${HOME}/.config"

  # Call containerization and MCP setup after brew bundle
  setup_containerization_and_mcp || log_warning "Containerization and MCP setup had issues."

  # Display overall summary
  echo -e "\n${BLUE}=== Setup Summary ===${NC}"
  printf "• Homebrew: Installed\n"
  printf "• Containerization and MCP setup: %b%s%b\n" "$GREEN" "Ready" "$NC"
}

# Container environment setup removed - now using local MCP testing only

install_packages() {
  echo -e "\n=== Installing Packages ==="

  # Check if Brewfile exists
  if [[ ! -f "Brewfile" ]]; then
    printf "└── %b[ERROR]%b Brewfile not found in current directory. Please ensure it exists.\n" "$RED" "$NC"
    return 1
  fi

  # CI environment note
  if [[ "${CI:-false}" == "true" ]]; then
    printf "├── %b[CI ENVIRONMENT]%b No containerization - MCP configuration validation only\n" "$BLUE" "$NC"
  fi

  # Log file for bundle output
  local bundle_log="/tmp/brew_bundle.log"

  # Check bundle status quietly first
  echo "==== brew bundle check ====" > "$bundle_log"
  brew bundle check >> "$bundle_log" 2>&1
  local check_status=$?

  # Always run install in CI, or if check shows missing dependencies
  if [[ $check_status -ne 0 ]] || [[ "${CI:-false}" == "true" ]]; then
    if [[ "${CI:-false}" == "true" ]]; then
      printf "├── %b[INSTALLING]%b Packages (CI mode)\n" "$BLUE" "$NC"
    else
      printf "├── %b[INSTALLING]%b Packages from Brewfile\n" "$BLUE" "$NC"
    fi

    # Capture brew bundle output to extract installed packages
    local bundle_output="/tmp/brew_bundle_output.log"
    echo "==== brew bundle install ====" >> "$bundle_log"
    brew bundle install > "$bundle_output" 2>&1
    local install_status=$?

    # Also append to main log for debugging
    cat "$bundle_output" >> "$bundle_log"

    if [[ $install_status -ne 0 ]]; then
      printf "└── %b[ERROR]%b Failed to install packages (exit code %s). See %s for details.\n" "$RED" "$NC" "$install_status" "$bundle_log"
      return 1
    fi

    # Parse the output to categorize packages
    local installing_packages=""
    local upgrading_packages=""
    local tapping_packages=""
    local using_packages=""
    local install_count=0
    local using_count=0
    local package_name

    while IFS= read -r line; do
      case "$line" in
        Installing*)
          package_name=$(echo "$line" | sed 's/^Installing //' | cut -d' ' -f1)
          installing_packages="${installing_packages}${installing_packages:+, }${package_name}"
          install_count=$((install_count + 1))
          ;;
        Upgrading*)
          package_name=$(echo "$line" | sed 's/^Upgrading //' | cut -d' ' -f1)
          upgrading_packages="${upgrading_packages}${upgrading_packages:+, }${package_name}"
          install_count=$((install_count + 1))
          ;;
        Tapping*)
          package_name=$(echo "$line" | sed 's/^Tapping //' | cut -d' ' -f1)
          tapping_packages="${tapping_packages}${tapping_packages:+, }${package_name}"
          install_count=$((install_count + 1))
          ;;
        Using*)
          package_name="${line#Using }"
          using_packages="${using_packages}${using_packages:+, }${package_name}"
          using_count=$((using_count + 1))
          ;;
      esac
    done < "$bundle_output"

    # Display aggregated packages by category
    if [ -n "$installing_packages" ]; then
      printf "│   ├── %b[INSTALLING]%b %s\n" "$GREEN" "$NC" "$installing_packages"
    fi
    if [ -n "$upgrading_packages" ]; then
      printf "│   ├── %b[UPGRADING]%b %s\n" "$YELLOW" "$NC" "$upgrading_packages"
    fi
    if [ -n "$tapping_packages" ]; then
      printf "│   ├── %b[TAPPING]%b %s\n" "$BLUE" "$NC" "$tapping_packages"
    fi
    if [ -n "$using_packages" ]; then
      printf "│   ├── %b[USING]%b %s\n" "$BLUE" "$NC" "$using_packages"
    fi

    # Show completion summary from brew bundle
    local total_packages=$((install_count + using_count))
    if grep -q "complete!" "$bundle_output"; then
      local total_deps
      total_deps=$(grep "dependencies now installed" "$bundle_output" | grep -o '[0-9]*' | head -1)
      if [ "$install_count" -gt 0 ]; then
        printf "│   └── %b[SUCCESS]%b %s new, %s total dependencies ready\n" "$GREEN" "$NC" "$install_count" "${total_deps:-$total_packages}"
      else
        printf "│   └── %b[SUCCESS]%b All %s dependencies already installed\n" "$GREEN" "$NC" "${total_deps:-$using_count}"
      fi
    else
      if [ "$total_packages" -gt 0 ]; then
        printf "│   └── %b[SUCCESS]%b %s packages processed\n" "$GREEN" "$NC" "$total_packages"
      else
        printf "│   └── %b[SUCCESS]%b Package installation completed\n" "$GREEN" "$NC"
      fi
    fi

    # Clean up temporary file
    rm -f "$bundle_output"
  else
    printf "└── %b[SUCCESS]%b All packages already installed\n" "$GREEN" "$NC"
  fi
}

# Language environment setup
setup_ruby_environment() {
  echo -e "\n=== Setting Up Language Environments ==="
  printf "├── %bRuby Environment%b\n" "$BLUE" "$NC"

  if ! check_command rbenv; then
    printf "│   └── %b[ERROR]%b rbenv not found. Please ensure it's installed.\n" "$RED" "$NC"
    return 1
  fi

  # Initialize rbenv
  eval "$(rbenv init - zsh)"

  # Install latest Ruby version
  local latest_ruby
  latest_ruby=$(rbenv install -l | grep -v - | grep -v dev | tail -1 | tr -d '[:space:]')

  if ! rbenv versions | grep -q "$latest_ruby"; then
    # Start Ruby installation in background
    local ruby_log="/tmp/ruby_install.log"
    (
      RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl) --with-readline-dir=$(brew --prefix readline)" \
        rbenv install "$latest_ruby" > "$ruby_log" 2>&1
    ) &
    local ruby_pid=$!

    # Show progress spinner
    show_progress "│   ├──" "Ruby $latest_ruby" "$ruby_pid"

    # Wait for completion and check result
    wait "$ruby_pid"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      printf "│   ├── %b[SUCCESS]%b Ruby %s installed\n" "$GREEN" "$NC" "$latest_ruby"
    else
      printf "│   └── %b[ERROR]%b Failed to install Ruby %s (see %s)\n" "$RED" "$NC" "$latest_ruby" "$ruby_log"
      return 1
    fi
  else
    printf "│   ├── %b[SUCCESS]%b Ruby %s already installed\n" "$GREEN" "$NC" "$latest_ruby"
  fi

  # Set global Ruby version
  rbenv global "$latest_ruby"
  printf "│   └── %b[SUCCESS]%b Ruby environment ready\n" "$GREEN" "$NC"
}

setup_python_environment() {
  printf "├── %bPython Environment%b\n" "$BLUE" "$NC"

  if ! check_command pyenv; then
    printf "    └── %b[ERROR]%b pyenv not found. Please ensure it's installed.\n" "$RED" "$NC"
    return 1
  fi

  # Initialize pyenv
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"

  # Install latest Python version
  local latest_python
  latest_python=$(pyenv install --list | grep -v - | grep -v a | grep -v b | grep -v rc | grep "^  [0-9]" | tail -1 | tr -d '[:space:]')

  if ! pyenv versions | grep -q "$latest_python"; then
    # Start Python installation in background
    local python_log="/tmp/python_install.log"
    (
      CPPFLAGS="-I$(brew --prefix openssl)/include -I$(brew --prefix sqlite3)/include" \
      LDFLAGS="-L$(brew --prefix openssl)/lib -L$(brew --prefix sqlite3)/lib" \
        pyenv install "$latest_python" > "$python_log" 2>&1
    ) &
    local python_pid=$!

    # Show progress spinner
    show_progress "    ├──" "Python $latest_python" "$python_pid"

    # Wait for completion and check result
    wait "$python_pid"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      printf "    ├── %b[SUCCESS]%b Python %s installed\n" "$GREEN" "$NC" "$latest_python"
    else
      printf "    └── %b[ERROR]%b Failed to install Python %s (see %s)\n" "$RED" "$NC" "$latest_python" "$python_log"
      return 1
    fi
  else
    printf "    ├── %b[SUCCESS]%b Python %s already installed\n" "$GREEN" "$NC" "$latest_python"
  fi

  # Set global Python version
  pyenv global "$latest_python"
  printf "    └── %b[SUCCESS]%b Python environment ready\n" "$GREEN" "$NC"
}

setup_node_environment() {
  printf "└── %bNode.js Environment%b\n" "$BLUE" "$NC"

  # Initialize nvm for this script
  export NVM_DIR="$HOME/.nvm"
  if [[ ! -s "$(brew --prefix)/opt/nvm/nvm.sh" ]]; then
    printf "    └── %b[ERROR]%b nvm not found. Please ensure it's installed.\n" "$RED" "$NC"
    return 1
  fi

  # shellcheck disable=SC1090
  source "$(brew --prefix)/opt/nvm/nvm.sh"

  # Install latest LTS Node.js version
  local latest_node
  latest_node=$(nvm ls-remote --lts | tail -1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')

  if [[ -z "$latest_node" ]]; then
    printf "    └── %b[ERROR]%b Failed to determine latest LTS Node.js version\n" "$RED" "$NC"
    return 1
  fi

  # Check if this version is already installed via nvm (not system)
  if ! nvm list | grep -E "^[[:space:]]*${latest_node// /\\\\ }" > /dev/null 2>&1; then
    # Start Node installation in background
    local node_log="/tmp/node_install.log"
    (
      nvm install "$latest_node" > "$node_log" 2>&1
    ) &
    local node_pid=$!

    # Show progress spinner
    show_progress "    ├──" "Node.js $latest_node" "$node_pid"

    # Wait for completion and check result
    wait "$node_pid"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      printf "    ├── %b[SUCCESS]%b Node.js %s installed\n" "$GREEN" "$NC" "$latest_node"
    else
      printf "    └── %b[ERROR]%b Failed to install Node.js %s (see %s)\n" "$RED" "$NC" "$latest_node" "$node_log"
      return 1
    fi
  else
    printf "    ├── %b[SUCCESS]%b Node.js %s already installed\n" "$GREEN" "$NC" "$latest_node"
  fi

  # Set default Node version and use it
  if nvm alias default "$latest_node" > /dev/null 2>&1 && nvm use default > /dev/null 2>&1; then
    printf "    ├── %b[SUCCESS]%b Node.js %s set as default\n" "$GREEN" "$NC" "$latest_node"
  else
    printf "    ├── %b[WARNING]%b Failed to set Node.js %s as default\n" "$YELLOW" "$NC" "$latest_node"
  fi

  # Update npm to latest version
  if npm install -g npm@latest > /dev/null 2>&1; then
    printf "    ├── %b[SUCCESS]%b npm updated to latest version\n" "$GREEN" "$NC"
  else
    printf "    ├── %b[WARNING]%b Failed to update npm\n" "$YELLOW" "$NC"
  fi

  printf "    └── %b[SUCCESS]%b Node.js environment ready\n" "$GREEN" "$NC"
}

# Shell configuration
setup_antidote() {
  # This function is now called from configure_shell, so suppress its own logging

  # Ensure the directory exists
  local plugins_dir
  plugins_dir=$(dirname "$ANTIDOTE_PLUGINS_FILE")
  ensure_dir "$plugins_dir" > /dev/null 2>&1

  # Create plugins file
  if [[ ! -f "$ANTIDOTE_PLUGINS_FILE" ]]; then
    cat > "$ANTIDOTE_PLUGINS_FILE" << 'EOF'
# Essential ZSH plugins
zsh-users/zsh-syntax-highlighting
zsh-users/zsh-autosuggestions
zsh-users/zsh-completions
zsh-users/zsh-history-substring-search

# z - directory navigation
agkozak/zsh-z

# Git plugins
ohmyzsh/ohmyzsh path:plugins/git

# Kubernetes plugins
ohmyzsh/ohmyzsh path:plugins/kubectl

ohmyzsh/ohmyzsh path:plugins/helm

# Development tools completions
ohmyzsh/ohmyzsh path:plugins/terraform
ohmyzsh/ohmyzsh path:plugins/docker
ohmyzsh/ohmyzsh path:plugins/docker-compose

# Utility plugins
ohmyzsh/ohmyzsh path:plugins/common-aliases
ohmyzsh/ohmyzsh path:plugins/brew
ohmyzsh/ohmyzsh path:plugins/fzf
EOF
  fi

  # Add antidote configuration to .zshrc
  local antidote_config
  antidote_config="# Initialize antidote
[[ -e \$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh ]] && source \$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh
autoload -Uz compinit && compinit
antidote load \${ZDOTDIR:-\$HOME}/.zsh_plugins.txt"

  if ! grep -q "Initialize antidote" "$ZSHRC_PATH"; then
    echo -e "\n$antidote_config" >> "$ZSHRC_PATH"
  fi
}

generate_completion_files() {
  # Ensure completion directory exists
  ensure_completion_dir || return 1

  # Generate completions for development environment tools
  echo "├── Development Tools"
  local dev_tools=(
    "rbenv:rbenv completions zsh"
    "mcp_manager:cp _mcp_manager ${COMPLETION_DIR}/_mcp_manager"
  )

  local i=0
  for tool_config in "${dev_tools[@]}"; do
    local tool="${tool_config%%:*}"
    local completion_cmd="${tool_config#*:}"
    local completion_file="${COMPLETION_DIR}/_${tool}"
    local prefix="│   "
    local connector="├──"
    if [[ $i -eq $((${#dev_tools[@]} - 1)) ]]; then
      connector="└──"
    fi

    if command -v "$tool" > /dev/null 2>&1; then
      if run_with_timeout 10 "$completion_cmd" > "$completion_file" 2> /dev/null; then
        printf "%s%s %b[SUCCESS]%b %s completion generated\n" "$prefix" "$connector" "$GREEN" "$NC" "$tool"
      else
        printf "%s%s %b[WARNING]%b %s completion failed\n" "$prefix" "$connector" "$YELLOW" "$NC" "$tool"
        rm -f "$completion_file"
      fi
    else
      printf "%s%s %b[WARNING]%b %s not found, skipping\n" "$prefix" "$connector" "$YELLOW" "$NC" "$tool"
    fi
    ((i++))
  done

  # Special case for pyenv - copy system completion file
  echo "├── Language Environment Tools"
  if command -v pyenv > /dev/null 2>&1; then
    local pyenv_completion
    pyenv_completion=$(find "$(brew --prefix)" -name "pyenv.zsh" -path "*/completions/*" 2> /dev/null | head -1)
    if [[ -n "$pyenv_completion" && -f "$pyenv_completion" ]]; then
      cp "$pyenv_completion" "${COMPLETION_DIR}/_pyenv" \
        && printf "│   └── %b[SUCCESS]%b pyenv completion generated\n" "$GREEN" "$NC"
    else
      printf "│   └── %b[WARNING]%b pyenv completion file not found\n" "$YELLOW" "$NC"
    fi
  else
    printf "│   └── %b[WARNING]%b pyenv not found, skipping\n" "$YELLOW" "$NC"
  fi
}

setup_shell_completions() {
  # This function is now called from configure_shell, so suppress its own logging

  # Ensure completion directories exist
  ensure_dir "$COMPLETION_DIR"
  ensure_dir "$ZCOMPCACHE_DIR"

  # Generate completion files first
  generate_completion_files

  # Add completion configuration to .zshrc
  # shellcheck disable=SC2124
  local completion_config=(
    "# Initialize completions"
    "# Ensure we're running in zsh"
    "if [ -n \"\$BASH_VERSION\" ]; then"
    "    exec /bin/zsh \"\$0\" \"\$@\""
    "fi"
    ""
    "# Initialize completion system"
    "autoload -Uz compinit"
    "if [[ -f ~/.zcompdump && \$(find ~/.zcompdump -mtime +1) ]]; then"
    "    compinit -i"
    "else"
    "    compinit -C -i"
    "fi"
    ""
    "# Completion settings"
    "zstyle ':completion:*' menu select"
    "zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'"
    "zstyle ':completion::complete:*' use-cache on"
    "zstyle ':completion::complete:*' cache-path \"\$ZCOMPCACHE_DIR\""
    ""
    "# Source fzf completions if available"
    "if [[ -f \"\$(brew --prefix)/opt/fzf/shell/completion.zsh\" ]]; then"
    "    source \"\$(brew --prefix)/opt/fzf/shell/completion.zsh\" 2>/dev/null"
    "fi"
    ""
    "# Additional completion sources"
    "fpath=(\"${COMPLETION_DIR}\" \"\${fpath[@]}\")"
    ""
    "# HashiCorp tool completions (use built-in completion system)"
    "if command -v terraform >/dev/null 2>&1; then"
    "    complete -o nospace -C terraform terraform"
    "fi"
    ""
    "if command -v packer >/dev/null 2>&1; then"
    "    complete -o nospace -C packer packer"
    "fi"
    ""
    "# Pyenv initialization"
    "if command -v pyenv >/dev/null 2>&1; then"
    "    eval \"\$(pyenv init -)\""
    "fi"
    ""
    "# NVM initialization"
    "export NVM_DIR=\"\$HOME/.nvm\""
    "if [ -s \"\$(brew --prefix)/opt/nvm/nvm.sh\" ]; then"
    "    source \"\$(brew --prefix)/opt/nvm/nvm.sh\""
    "fi"
    "if [ -s \"\$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm\" ]; then"
    "    source \"\$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm\""
    "fi"
  )

  if ! grep -q "Initialize completions" "$ZSHRC_PATH"; then
    printf "%s\n" "${completion_config[@]}" >> "$ZSHRC_PATH"
  fi

  # Force regeneration of completion cache (suppress error if no files exist)
  rm -f "${HOME}/.zcompdump"* 2> /dev/null || true
  # Only remove cache files if directory exists and has files
  if [[ -d "$ZCOMPCACHE_DIR" ]] && [[ -n "$(ls -A "$ZCOMPCACHE_DIR" 2> /dev/null)" ]]; then
    rm -f "${ZCOMPCACHE_DIR}/"* 2> /dev/null || true
  fi

  # Set up completions immediately for current session
  if [[ -f "$(brew --prefix)/opt/fzf/shell/completion.zsh" ]]; then
    # shellcheck disable=SC1090
    source "$(brew --prefix)/opt/fzf/shell/completion.zsh" 2> /dev/null || printf "│   │   └── %b[WARNING]%b Failed to source fzf completion\n" "$YELLOW" "$NC"
  fi

  # Initialize completion system for current session
  autoload -Uz compinit
  compinit -C -i

  # Set up HashiCorp completions for current session

  # Terraform uses its own completion system
  if command -v terraform > /dev/null 2>&1; then
    # Terraform handles its own completion via the installed autocomplete
    complete -o nospace -C terraform terraform 2> /dev/null || true
  fi

  # Packer also uses its own completion system
  if command -v packer > /dev/null 2>&1; then
    # Packer handles its own completion via the installed autocomplete
    complete -o nospace -C packer packer 2> /dev/null || true
  fi

  # Initialize pyenv for current session
  if command -v pyenv > /dev/null 2>&1; then
    eval "$(pyenv init -)" 2> /dev/null || true
  fi

  # Initialize nvm for current session
  export NVM_DIR="$HOME/.nvm"
  if [[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ]]; then
    source "$(brew --prefix)/opt/nvm/nvm.sh" 2> /dev/null || true
  fi
  if [[ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ]]; then
    source "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" 2> /dev/null || true
  fi
}

configure_terminal_fonts() {
  echo -e "\n=== Terminal Configuration ==="

  # Skip in CI environments as these are GUI applications
  if [[ "${CI:-false}" == "true" ]]; then
    printf "└── %b[SKIPPED]%b Terminal font configuration (CI environment)\n" "$YELLOW" "$NC"
    return 0
  fi

  # First, verify Nerd Fonts are available
  printf "├── %b[CHECKING]%b Nerd Font availability\n" "$BLUE" "$NC"
  local available_fonts=(
    "FiraCode Nerd Font Mono"
    "JetBrains Mono Nerd Font"
    "Fira Code Nerd Font"
  )

  local nerd_font_found=false
  local recommended_font=""

  for font in "${available_fonts[@]}"; do
    if system_profiler SPFontsDataType 2> /dev/null | grep -q "$font"; then
      printf "│   ├── %b[FOUND]%b %s\n" "$GREEN" "$NC" "$font"
      if [[ -z "$recommended_font" ]]; then
        recommended_font="$font"
      fi
      nerd_font_found=true
    fi
  done

  if [[ "$nerd_font_found" == "false" ]]; then
    printf "│   └── %b[WARNING]%b No Nerd Fonts found - Starship icons may not display properly\n" "$YELLOW" "$NC"
    return 1
  else
    printf "│   └── %b[SUCCESS]%b Nerd Fonts available for Starship\n" "$GREEN" "$NC"
  fi

  # Configure Warp terminal automatically
  printf "├── %b[CONFIGURING]%b Warp terminal fonts\n" "$BLUE" "$NC"
  if [[ -d "/Applications/Warp.app" ]]; then
    local warp_prefs
    warp_prefs="/Users/$(whoami)/Library/Preferences/dev.warp.Warp-Stable.plist"

    if [[ -f "$warp_prefs" ]]; then
      # Get current font settings using PlistBuddy
      local current_font_name
      local current_font_size
      current_font_name=$(/usr/libexec/PlistBuddy -c "Print :FontName" "$warp_prefs" 2> /dev/null || echo "unknown")
      current_font_size=$(/usr/libexec/PlistBuddy -c "Print :FontSize" "$warp_prefs" 2> /dev/null || echo "unknown")

      printf "│   ├── %b[INFO]%b Current: %s %spt\n" "$BLUE" "$NC" "$current_font_name" "$current_font_size"

      local needs_update=false

      # Check if we need to update the font or size
      if [[ "$current_font_name" != "FiraCode Nerd Font Mono" ]] || [[ "$current_font_size" != "14.0" ]]; then
        needs_update=true
      fi

      if [[ "$needs_update" == "true" ]]; then
        printf "│   ├── %b[SETTING]%b Font to: FiraCode Nerd Font Mono 14pt\n" "$BLUE" "$NC"

        # Set optimal font and size for Starship using PlistBuddy
        if /usr/libexec/PlistBuddy -c "Set :FontName \"FiraCode Nerd Font Mono\"" "$warp_prefs" 2> /dev/null \
          && /usr/libexec/PlistBuddy -c "Set :FontSize \"14.0\"" "$warp_prefs" 2> /dev/null; then
          printf "│   ├── %b[SUCCESS]%b Warp font updated - restart Warp for changes\n" "$GREEN" "$NC"
        else
          printf "│   ├── %b[WARNING]%b Failed to update Warp font\n" "$YELLOW" "$NC"
        fi
      else
        printf "│   ├── %b[SUCCESS]%b Font already configured correctly\n" "$GREEN" "$NC"
      fi
    else
      printf "│   └── %b[INFO]%b Warp preferences not found\n" "$BLUE" "$NC"
    fi
  else
    printf "│   └── %b[INFO]%b Warp not installed\n" "$BLUE" "$NC"
  fi

  # Configure iTerm2 terminal
  printf "└── %b[CONFIGURING]%b iTerm2 terminal fonts\n" "$BLUE" "$NC"
  if [[ -d "/Applications/iTerm.app" ]]; then
    local iterm_prefs
    iterm_prefs="/Users/$(whoami)/Library/Preferences/com.googlecode.iterm2.plist"

    if [[ -f "$iterm_prefs" ]]; then
      printf "    ├── %b[SETTING]%b Font to: FiraCodeNFM-Reg 14\n" "$BLUE" "$NC"

      if /usr/libexec/PlistBuddy -c "Set :\"New Bookmarks\":0:\"Normal Font\" \"FiraCodeNFM-Reg 14\"" "$iterm_prefs" 2> /dev/null; then
        printf "    └── %b[SUCCESS]%b iTerm2 font configured - restart iTerm2 to apply\n" "$GREEN" "$NC"
      else
        printf "    └── %b[WARNING]%b Failed to update iTerm2 font\n" "$YELLOW" "$NC"
      fi
    else
      printf "    └── %b[INFO]%b iTerm2 preferences not found\n" "$BLUE" "$NC"
    fi
  else
    printf "    └── %b[INFO]%b iTerm2 not installed\n" "$BLUE" "$NC"
  fi

  printf "\n%b[CONFIGURATION SUMMARY]%b\n" "$BLUE" "$NC"
  printf "• Warp: Font configured - restart Warp to apply changes\n"
  printf "• iTerm2: Font configured - restart iTerm2 to apply changes\n"
  printf "• Font: FiraCode Nerd Font Mono Reg, 14pt for optimal Starship display\n"

  # Test Nerd Font symbols immediately
  printf "\n%b[FONT TEST]%b Testing Nerd Font symbols in current session:\n" "$BLUE" "$NC"
  printf "Expected symbols: "
  if printf "\uE0A0 \uE0B0 \uE0B2 \uf015 \uf07c" 2> /dev/null; then
    printf " ← These should be: git branch, arrows, folder icons\n"
  else
    printf "(test failed)\n"
  fi
  printf "%bIf you see boxes or missing symbols above, the font change will take effect after restarting iTerm2%b\n" "$YELLOW" "$NC"
}

configure_shell() {
  echo -e "\n=== Shell Configuration ==="

  # Create or backup .zshrc
  printf "├── %b[CONFIGURING]%b Shell environment\n" "$BLUE" "$NC"
  if [[ ! -f "$ZSHRC_PATH" ]]; then
    if touch "$ZSHRC_PATH" 2> /dev/null; then
      printf "│   ├── %b[CREATED]%b .zshrc file\n" "$GREEN" "$NC"
    else
      printf "│   ├── %b[ERROR]%b Failed to create .zshrc file\n" "$RED" "$NC"
      return 1
    fi
  else
    backup_file "$ZSHRC_PATH" > /dev/null 2>&1
    printf "│   ├── %b[BACKED UP]%b Existing .zshrc\n" "$BLUE" "$NC"
  fi

  # Ensure .zprofile exists and sources .zshrc
  local zprofile_path="${ZDOTDIR}/.zprofile"
  if [[ ! -f "$zprofile_path" ]]; then
    if echo '[[ -f ~/.zshrc ]] && source ~/.zshrc' > "$zprofile_path" 2> /dev/null; then
      printf "│   ├── %b[CREATED]%b .zprofile to source .zshrc\n" "$GREEN" "$NC"
    else
      printf "│   ├── %b[ERROR]%b Failed to create .zprofile\n" "$RED" "$NC"
      return 1
    fi
  elif ! grep -q "source.*\.zshrc" "$zprofile_path"; then
    if echo '[[ -f ~/.zshrc ]] && source ~/.zshrc' >> "$zprofile_path" 2> /dev/null; then
      printf "│   ├── %b[UPDATED]%b .zprofile to source .zshrc\n" "$GREEN" "$NC"
    else
      printf "│   ├── %b[ERROR]%b Failed to update .zprofile\n" "$RED" "$NC"
      return 1
    fi
  else
    printf "│   ├── %b[EXISTS]%b .zprofile already sources .zshrc\n" "$BLUE" "$NC"
  fi

  # Ensure completion directory exists
  printf "│   ├── %b[CONFIGURING]%b Completion directory\n" "$BLUE" "$NC"
  if ! ensure_completion_dir; then
    printf "│   │   └── %b[ERROR]%b Failed to set up completion directory\n" "$RED" "$NC"
    return 1
  fi
  printf "│   │   └── %b[SUCCESS]%b Completion directory configured\n" "$GREEN" "$NC"

  # Setup Antidote plugin manager
  printf "│   ├── %b[SETTING UP]%b Antidote plugin manager\n" "$BLUE" "$NC"
  if setup_antidote > /dev/null 2>&1; then
    printf "│   │   ├── %b[SUCCESS]%b Plugin configuration created\n" "$GREEN" "$NC"
  else
    printf "│   │   ├── %b[WARNING]%b Plugin setup had issues but continuing\n" "$YELLOW" "$NC"
  fi

  # Install Antidote if needed
  if ! command -v antidote > /dev/null 2>&1; then
    printf "│   │   ├── %b[INSTALLING]%b Antidote\n" "$BLUE" "$NC"
    if brew install antidote > /dev/null 2>&1; then
      printf "│   │   └── %b[SUCCESS]%b Antidote installed\n" "$GREEN" "$NC"
    else
      printf "│   │   └── %b[ERROR]%b Failed to install Antidote\n" "$RED" "$NC"
      return 1
    fi
  else
    printf "│   │   └── %b[SUCCESS]%b Antidote already available\n" "$GREEN" "$NC"
  fi

  # Source Antidote and bundle plugins
  if [[ -e "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh" ]]; then
    printf "│   │   ├── %b[LOADING]%b Antidote plugins\n" "$BLUE" "$NC"
    # Initialize completion system
    autoload -Uz compinit
    if [[ -f ~/.zcompdump && $(find ~/.zcompdump -mtime +1) ]]; then
      compinit -i
    else
      compinit -C -i
    fi

    source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
    # Clear antidote cache to prevent stale plugin loading issues
    antidote purge 2> /dev/null || true

    # Load plugins with error handling
    if antidote load "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" 2> /dev/null; then
      printf "│   │   └── %b[SUCCESS]%b Plugins loaded successfully\n" "$GREEN" "$NC"
    else
      printf "│   │   └── %b[WARNING]%b Some plugins failed to load\n" "$YELLOW" "$NC"
      # Try to update plugins to fix any issues
      antidote update 2> /dev/null || true
    fi
  else
    printf "│   │   └── %b[ERROR]%b Antidote installation not found\n" "$RED" "$NC"
    return 1
  fi

  # Setup shell completions
  printf "│   ├── %b[SETTING UP]%b Shell completions\n" "$BLUE" "$NC"
  if setup_shell_completions > /dev/null 2>&1; then
    printf "│   │   └── %b[SUCCESS]%b Completion system configured\n" "$GREEN" "$NC"
  else
    printf "│   │   └── %b[WARNING]%b Completion setup had issues but continuing\n" "$YELLOW" "$NC"
  fi

  # Add tool-specific configurations
  printf "│   └── %b[CONFIGURING]%b Tool integrations\n" "$BLUE" "$NC"
  local configs=(
    "rbenv:rbenv init - zsh"
    "pyenv:pyenv init --path\npyenv init -"
    "nvm:[ -s \"$(brew --prefix)/opt/nvm/nvm.sh\" ] && source \"$(brew --prefix)/opt/nvm/nvm.sh\""
    "direnv:direnv hook zsh"
    "starship:starship init zsh"
  )

  for config in "${configs[@]}"; do
    local tool="${config%%:*}"
    local init_cmd="${config#*:}"

    if check_command "$tool"; then
      if ! grep -q "$tool" "$ZSHRC_PATH"; then
        if echo -e "\n# Initialize $tool\neval \"\$($init_cmd)\"" >> "$ZSHRC_PATH" 2> /dev/null; then
          printf "│       ├── %b[ADDED]%b %s integration\n" "$GREEN" "$NC" "$tool"
        else
          printf "│       ├── %b[ERROR]%b Failed to add %s integration\n" "$RED" "$NC" "$tool"
          return 1
        fi
      else
        printf "│       ├── %b[EXISTS]%b %s integration\n" "$BLUE" "$NC" "$tool"
      fi
    else
      printf "│       ├── %b[SKIPPED]%b %s (not installed)\n" "$YELLOW" "$NC" "$tool"
    fi
  done

  printf "└── %b[SUCCESS]%b Shell configuration completed\n" "$GREEN" "$NC"
}

# Main execution
main() {
  echo -e "\n=== macOS Development Environment Setup v${SCRIPT_VERSION} ==="

  validate_system || exit 1
  install_homebrew || exit 1
  install_packages || exit 1
  setup_containerization_and_mcp || printf "├── %b[WARNING]%b MCP configuration setup incomplete\n" "$YELLOW" "$NC"
  install_hashicorp_tools || printf "├── %b[WARNING]%b Some HashiCorp tools may not be installed\n" "$YELLOW" "$NC"
  configure_terminal_fonts || printf "├── %b[WARNING]%b Terminal font configuration incomplete\n" "$YELLOW" "$NC"
  configure_shell || exit 1
  setup_ruby_environment || printf "├── %b[WARNING]%b Ruby environment setup incomplete\n" "$YELLOW" "$NC"
  setup_python_environment || printf "├── %b[WARNING]%b Python environment setup incomplete\n" "$YELLOW" "$NC"
  setup_node_environment || printf "├── %b[WARNING]%b Node.js environment setup incomplete\n" "$YELLOW" "$NC"

  # Call the MCP manager script for MCP environment setup
  echo -e "\n=== MCP Environment Setup ==="
  if [[ -f "./mcp_manager.sh" ]]; then
    if [[ "${SKIP_MCP:-false}" == "true" ]]; then
      printf "└── %b[SKIPPED]%b MCP setup (SKIP_MCP=true)\n" "$YELLOW" "$NC"
    else
      printf "├── %b[DELEGATING]%b MCP setup to mcp_manager.sh\n" "$BLUE" "$NC"
      if ./mcp_manager.sh setup; then
        printf "└── %b[SUCCESS]%b MCP environment setup complete via mcp_manager.sh\n" "$GREEN" "$NC"
      else
        printf "└── %b[ERROR]%b MCP environment setup failed via mcp_manager.sh\n" "$RED" "$NC"
      fi
    fi
  else
    printf "└── %b[ERROR]%b mcp_manager.sh not found. Skipping MCP setup.\n" "$RED" "$NC"
  fi

  echo -e "\n=== Setup Complete ==="
  printf "└── %b[SUCCESS]%b All components installed and configured\n" "$GREEN" "$NC"
  # Ensure .zshrc is loaded in login shells by configuring .zprofile
  printf "├── %b[CONFIGURING]%b Shell loading across terminal types\n" "$BLUE" "$NC"
  local zprofile_path="$HOME/.zprofile"

  if [[ ! -f "$zprofile_path" ]] || ! grep -q "source.*\.zshrc" "$zprofile_path"; then
    echo '[[ -f ~/.zshrc ]] && source ~/.zshrc' >> "$zprofile_path"
    printf "│   └── %b[SUCCESS]%b .zprofile configured to load .zshrc\n" "$GREEN" "$NC"
  else
    printf "│   └── %b[EXISTS]%b .zprofile already sources .zshrc\n" "$BLUE" "$NC"
  fi

  printf "\n%bNext steps:%b Please restart your terminal or run: source %s\n" "$YELLOW" "$NC" "$ZSHRC_PATH"
}

# Call ensure_completion_dir early in the script
ensure_completion_dir || log_warning "Failed to set up completion directory"

main "$@"
