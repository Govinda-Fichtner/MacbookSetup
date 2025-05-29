#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2296,SC2034,SC2154,SC1091

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
readonly COMPLETION_DIR="${HOME}/.zsh/completions"
readonly ZCOMPCACHE_DIR="${HOME}/.zcompcache"
readonly ANTIDOTE_PLUGINS_FILE="${ZDOTDIR}/.zsh_plugins.txt"
# shellcheck disable=SC2155
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging module
# shellcheck source=lib/logging.sh
source "${SCRIPT_DIR}/lib/logging.sh"

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

# Utility functions
check_command() {
  command -v "$1" > /dev/null 2>&1
}

ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir" || {
      log_error "Failed to create directory: $dir"
      return 1
    }
  fi
}

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local timestamp
    timestamp=$(date +"%Y%m%d%H%M%S")
    local backup="${file}.backup.${timestamp}"
    cp "$file" "$backup" || {
      log_error "Failed to create backup of $file"
      return 1
    }
    log_info "Created backup: $backup"
  fi
}

# System validation
validate_system() {
  log_info "Validating system requirements..."

  # Check OS
  if [[ "$(uname)" != "Darwin" ]]; then
    log_error "This script is intended for macOS only."
    return 1
  fi

  # Check if running as root
  if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root. Please run without sudo."
    return 1
  fi

  log_success "System validation passed."
  return 0
}

# HashiCorp tool installation
install_hashicorp_tool() {
  local tool="$1"
  local version="$2"
  local arch

  log_info "Checking if $tool is installed..."
  if check_command "$tool"; then
    local current_version
    current_version=$("$tool" --version 2> /dev/null)
    log_success "$tool is already installed (version: $current_version)."
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
    log_error "Failed to create temporary directory"
    return 1
  }

  local download_url="https://releases.hashicorp.com/$tool/$version/${tool}_${version}_darwin_${arch}.zip"
  local zip_file="$tmp_dir/$tool.zip"

  # Download and install
  if curl -sSL "$download_url" -o "$zip_file" \
    && unzip -q "$zip_file" -d "$tmp_dir" \
    && sudo mv "$tmp_dir/$tool" /usr/local/bin/ \
    && sudo chmod +x "/usr/local/bin/$tool"; then
    log_success "$tool installed successfully."
    rm -rf "$tmp_dir"
    return 0
  else
    log_error "Failed to install $tool"
    rm -rf "$tmp_dir"
    return 1
  fi
}

install_hashicorp_tools() {
  log_info "Installing HashiCorp tools..."
  install_hashicorp_tool "terraform" "1.12.1" || log_warning "Terraform installation skipped"
  install_hashicorp_tool "packer" "1.12.0" || log_warning "Packer installation skipped"
}

# Homebrew installation and package management
install_homebrew() {
  log_info "Checking for Homebrew installation..."
  if check_command brew; then
    log_success "Homebrew is already installed."
    return 0
  fi

  log_info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
    log_error "Failed to install Homebrew"
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

  log_success "Homebrew installed successfully."
}

setup_orbstack() {
  log_info "Setting up OrbStack..."
  if ! check_command orbctl; then
    log_error "OrbStack is not installed. Please install it first."
    exit 1
  fi
  log_success "OrbStack setup completed"
}

install_packages() {
  log_info "Installing packages from Brewfile..."

  # Check if Brewfile exists
  if [[ ! -f "Brewfile" ]]; then
    log_error "Brewfile not found in current directory. Please ensure it exists."
    return 1
  fi

  # Remove Docker from Brewfile if it exists (since it comes with OrbStack)
  if grep -q "docker" "Brewfile"; then
    log_info "Removing Docker from Brewfile as it comes with OrbStack..."
    sed -i.bak '/docker/d' "Brewfile"
    rm -f "Brewfile.bak"
  fi

  # Install packages
  if ! brew bundle check > /dev/null 2>&1; then
    log_info "Installing missing packages from Brewfile..."
    brew bundle install || {
      log_error "Failed to install packages"
      return 1
    }
  else
    log_success "All packages from Brewfile are already installed."
  fi

  # Setup OrbStack
  setup_orbstack || log_warning "OrbStack setup incomplete"

  log_success "Package installation completed."
}

# Language environment setup
setup_ruby_environment() {
  log_info "Setting up Ruby environment..."

  if ! check_command rbenv; then
    log_error "rbenv not found. Please ensure it's installed."
    return 1
  fi

  # Initialize rbenv
  eval "$(rbenv init - zsh)"

  # Install latest Ruby version
  local latest_ruby
  latest_ruby=$(rbenv install -l | grep -v - | grep -v dev | tail -1 | tr -d '[:space:]')

  if ! rbenv versions | grep -q "$latest_ruby"; then
    log_info "Installing Ruby $latest_ruby..."
    RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl) --with-readline-dir=$(brew --prefix readline)" \
      rbenv install "$latest_ruby" || {
      log_error "Failed to install Ruby $latest_ruby"
      return 1
    }
  fi

  # Set global Ruby version
  rbenv global "$latest_ruby"
  log_success "Ruby environment setup completed."
}

setup_python_environment() {
  log_info "Setting up Python environment..."

  if ! check_command pyenv; then
    log_error "pyenv not found. Please ensure it's installed."
    return 1
  fi

  # Initialize pyenv
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"

  # Install latest Python version
  local latest_python
  latest_python=$(pyenv install --list | grep -v - | grep -v a | grep -v b | grep -v rc | grep "^  [0-9]" | tail -1 | tr -d '[:space:]')

  if ! pyenv versions | grep -q "$latest_python"; then
    log_info "Installing Python $latest_python..."
    CPPFLAGS="-I$(brew --prefix openssl)/include -I$(brew --prefix sqlite3)/include" \
    LDFLAGS="-L$(brew --prefix openssl)/lib -L$(brew --prefix sqlite3)/lib" \
      pyenv install "$latest_python" || {
      log_error "Failed to install Python $latest_python"
      return 1
    }
  fi

  # Set global Python version
  pyenv global "$latest_python"
  log_success "Python environment setup completed."
}

# Shell configuration
setup_antidote() {
  log_info "Setting up antidote plugin manager..."

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

  log_success "Antidote setup completed."
}

setup_shell_completions() {
  log_info "Setting up shell completions..."

  # Ensure completion directories exist
  ensure_dir "$COMPLETION_DIR"
  ensure_dir "$ZCOMPCACHE_DIR"

  # OrbStack completions: generate orbctl and install custom orb completion
  if command -v orbctl > /dev/null 2>&1; then
    log_info "Setting up OrbStack completions..."
    orbctl completion zsh > "${COMPLETION_DIR}/_orbctl" 2> /dev/null || log_warning "Failed to generate orbctl completion"

    if [[ -f "${SCRIPT_DIR}/completions/_orb" ]]; then
      cp "${SCRIPT_DIR}/completions/_orb" "${COMPLETION_DIR}/_orb" 2> /dev/null || log_warning "Failed to install custom orb completion"
    fi
  else
    log_warning "OrbStack not found, skipping completion setup"
  fi

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
    "# Docker completion (comes with OrbStack)"
    "if command -v docker >/dev/null 2>&1; then"
    "    source <(docker completion zsh)"
    "fi"
    ""
    "# Terraform completion"
    "if command -v terraform >/dev/null 2>&1; then"
    "    complete -o nospace -C terraform terraform"
    "fi"
    ""
    "# Kubectl completion"
    "if command -v kubectl >/dev/null 2>&1; then"
    "    source <(kubectl completion zsh)"
    "fi"
    ""
    "# Helm completion"
    "if command -v helm >/dev/null 2>&1; then"
    "    source <(helm completion zsh)"
    "fi"
  )

  if ! grep -q "Initialize completions" "$ZSHRC_PATH"; then
    printf "%s\n" "${completion_config[@]}" >> "$ZSHRC_PATH"
  fi

  # Force regeneration of completion cache
  rm -f "${HOME}/.zcompdump"*
  rm -f "${ZCOMPCACHE_DIR}/"*

  # Set up fzf completion immediately for current session
  if [[ -f "$(brew --prefix)/opt/fzf/shell/completion.zsh" ]]; then
    # shellcheck disable=SC1090
    source "$(brew --prefix)/opt/fzf/shell/completion.zsh" 2> /dev/null || log_warning "Failed to source fzf completion"
  fi

  log_success "Shell completions setup completed."
}

configure_shell() {
  log_info "Configuring shell environment..."

  # Create or backup .zshrc
  if [[ ! -f "$ZSHRC_PATH" ]]; then
    touch "$ZSHRC_PATH"
  else
    backup_file "$ZSHRC_PATH"
  fi

  # Setup components
  setup_antidote
  setup_shell_completions

  # Add tool-specific configurations
  local configs=(
    "rbenv:rbenv init - zsh"
    "pyenv:pyenv init --path\npyenv init -"
    "direnv:direnv hook zsh"
    "starship:starship init zsh"
  )

  for config in "${configs[@]}"; do
    local tool="${config%%:*}"
    local init_cmd="${config#*:}"

    if check_command "$tool"; then
      if ! grep -q "$tool" "$ZSHRC_PATH"; then
        echo -e "\n# Initialize $tool\neval \"\$($init_cmd)\"" >> "$ZSHRC_PATH"
      fi
    fi
  done

  log_success "Shell configuration completed."
}

# Main execution
main() {
  log_info "Starting macOS development environment setup (v${SCRIPT_VERSION})..."

  validate_system || exit 1
  install_homebrew || exit 1
  install_packages || exit 1
  install_hashicorp_tools || log_warning "Some HashiCorp tools may not be installed"
  configure_shell || exit 1
  setup_ruby_environment || log_warning "Ruby environment setup incomplete"
  setup_python_environment || log_warning "Python environment setup incomplete"

  # Install Antidote
  if ! command -v antidote > /dev/null 2>&1; then
    log_info "Installing Antidote..."
    brew install antidote || {
      log_error "Failed to install Antidote"
      return 1
    }
  fi

  # Source Antidote and bundle plugins
  if [[ -e "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh" ]]; then
    # Initialize completion system
    autoload -Uz compinit
    if [[ -f ~/.zcompdump && $(find ~/.zcompdump -mtime +1) ]]; then
      compinit -i
    else
      compinit -C -i
    fi

    source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
    log_info "Loading Antidote plugins..."
    antidote load "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" || {
      log_error "Failed to load Antidote plugins"
      return 1
    }
    log_success "Antidote plugins loaded successfully"
  else
    log_error "Antidote installation not found"
    return 1
  fi

  log_success "Antidote setup completed"

  log_success "Setup completed successfully!"
  log_info "Please restart your terminal or run: source $ZSHRC_PATH"
}

main "$@"
