#!/bin/bash
#
# macOS Development Environment Setup Script
# 
# This script automates the installation and configuration of a development environment on macOS.
# It installs Homebrew, all tools specified in the Brewfile, and configures the shell environment.
#
# Usage: ./setup.sh

# Enable strict error handling
set -e

# Log formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Ensure script is being run with appropriate permissions
if [[ $EUID -eq 0 ]]; then
  log_error "This script should not be run as root. Please run without sudo."
  exit 1
fi

log_info "Starting setup process..."

# Check if we're on macOS
if [[ "$(uname)" != "Darwin" ]]; then
  log_error "This script is intended for macOS only."
  exit 1
fi

# Create a backup of .zshrc if it exists
ZSHRC_PATH="$HOME/.zshrc"
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
if [[ -f "$ZSHRC_PATH" ]]; then
  log_info "Creating backup of .zshrc as .zshrc.backup.$TIMESTAMP"
  cp "$ZSHRC_PATH" "$ZSHRC_PATH.backup.$TIMESTAMP"
fi

# Check if Homebrew is installed, install if needed
install_homebrew() {
  log_info "Checking for Homebrew installation..."
  if command -v brew >/dev/null 2>&1; then
    log_success "Homebrew is already installed."
  else
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH based on architecture
    if [[ "$(uname -m)" == "arm64" ]]; then
      # For Apple Silicon
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$ZSHRC_PATH"
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      # For Intel Mac
      echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$ZSHRC_PATH"
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    log_success "Homebrew installed successfully."
  fi
}

# Install all packages from Brewfile
install_packages() {
  local brewfile_path="$HOME/Brewfile"
  
  if [[ ! -f "$brewfile_path" ]]; then
    log_error "Brewfile not found at $brewfile_path. Creating a new one."
    
    # Create a new Brewfile with the tools we've been using
    cat > "$brewfile_path" << EOF
# Brewfile
# This file documents all Homebrew installations and can be used to set up a new machine.
# To use this file for installation, run: brew bundle

# Taps (Third-party repositories)
tap "getantibody/antibody"

# Formulae (Command-line packages)
brew "git"
brew "zinit"
brew "rbenv"
brew "pyenv"
brew "direnv"

# Casks (GUI applications)
cask "iterm2"
cask "warp"
cask "signal"
cask "whatsapp"
EOF
    log_info "Created new Brewfile at $brewfile_path"
  fi
  
  log_info "Installing packages from Brewfile..."
  if brew bundle check --file="$brewfile_path" >/dev/null 2>&1; then
    log_success "All packages in Brewfile are already installed."
  else
    brew bundle install --file="$brewfile_path"
    log_success "Packages installed successfully."
  fi
}

# Configure shell with required tool integrations
configure_shell() {
  log_info "Configuring shell environment in .zshrc..."
  
  # Function to add configuration if it doesn't exist
  add_to_zshrc() {
    local search_pattern="$1"
    local config_block="$2"
    local comment="$3"
    
    if ! grep -q "$search_pattern" "$ZSHRC_PATH" 2>/dev/null; then
      log_info "Adding $comment configuration to .zshrc"
      echo -e "\n# $comment\n$config_block" >> "$ZSHRC_PATH"
    else
      log_info "$comment configuration already exists in .zshrc"
    fi
  }
  
  # Add zinit configuration
  add_to_zshrc "source.*zinit.zsh" "source \$(brew --prefix)/opt/zinit/zinit.zsh" "zinit setup"
  
  # Add rbenv configuration
  add_to_zshrc "rbenv init" 'eval "$(rbenv init -)"' "rbenv setup"
  
  # Add pyenv configuration
  add_to_zshrc "pyenv init" 'export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"' "pyenv setup"
  
  # Add direnv configuration
  add_to_zshrc "direnv hook" 'eval "$(direnv hook zsh)"' "direnv setup"
  
  log_success "Shell configuration completed."
}

# Install Ruby build dependencies required for compiling Ruby
install_ruby_build_dependencies() {
  log_info "Checking and installing Ruby build dependencies..."
  
  # Check if Homebrew is installed
  if ! command -v brew >/dev/null 2>&1; then
    log_error "Homebrew is not installed. Cannot install Ruby build dependencies."
    return 1
  fi
  
  # List of common Ruby build dependencies
  # These are required for various Ruby features:
  # - openssl: Required for SSL/TLS support in Ruby
  # - readline: Provides line-editing and history features in Ruby shell
  # - zlib: Required for compression support
  # - libyaml: Required for YAML parsing (used by many Ruby gems)
  # - libffi: Required for Foreign Function Interface (calling functions in other languages)
  # - autoconf: Build system tool required for compiling Ruby
  local dependencies=("openssl" "readline" "zlib" "libyaml" "libffi" "autoconf")
  
  for dep in "${dependencies[@]}"; do
    if ! brew list --formula | grep -q "^$dep$"; then
      log_info "Installing $dep..."
      brew install "$dep"
      log_success "$dep installed successfully."
    else
      log_info "$dep is already installed."
    fi
  done
  
  log_success "All Ruby build dependencies are installed."
  return 0
}

# Install the latest stable Ruby version using rbenv
install_latest_ruby() {
  log_info "Checking if rbenv is installed..."
  if ! command -v rbenv >/dev/null 2>&1; then
    log_warning "rbenv is not installed. Skipping Ruby installation."
    return
  fi

  log_info "Installing latest stable Ruby version..."
  # Get the latest stable Ruby version (excluding preview/beta)
  latest_ruby=$(rbenv install -l | grep -v - | grep -v dev | tail -1 | tr -d '[:space:]')
  
  if [[ -z "$latest_ruby" ]]; then
    log_error "Failed to determine the latest stable Ruby version."
    return
  fi

  log_info "Latest stable Ruby version: $latest_ruby"
  
  # Install required build dependencies before proceeding
  log_info "Ensuring all Ruby build dependencies are installed..."
  install_ruby_build_dependencies
  
  # Check if this version is already installed
  if rbenv versions | grep -q "$latest_ruby"; then
    log_info "Ruby $latest_ruby is already installed."
  else
    log_info "Installing Ruby $latest_ruby..."
    
    # Set environment variables to help rbenv find the installed dependencies
    export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl) --with-readline-dir=$(brew --prefix readline) --with-libyaml-dir=$(brew --prefix libyaml) --with-zlib-dir=$(brew --prefix zlib)"
    
    # Install Ruby with rbenv
    rbenv install "$latest_ruby"
    log_success "Ruby $latest_ruby installed successfully."
  fi
  
  # Set as global version
  log_info "Setting Ruby $latest_ruby as the global version..."
  rbenv global "$latest_ruby"
  log_success "Ruby $latest_ruby is now the global version."
  
  # Verify installation
  ruby_version=$(ruby -v)
  log_info "Installed Ruby version: $ruby_version"
}

# Install Python build dependencies required for compiling Python
install_python_build_dependencies() {
  log_info "Checking and installing Python build dependencies..."
  
  # Check if Homebrew is installed
  if ! command -v brew >/dev/null 2>&1; then
    log_error "Homebrew is not installed. Cannot install Python build dependencies."
    return 1
  fi
  
  # List of common Python build dependencies
  # These are required for various Python features:
  # - xz: Required for LZMA compression support (needed for many packages including Python itself)
  # - openssl: Required for SSL/TLS support in Python
  # - readline: Provides line-editing and history features in Python shell
  # - sqlite3: Required for SQLite database support in Python
  # - zlib: Required for compression features
  # - bzip2: Required for bzip2 compression support
  local dependencies=("xz" "openssl" "readline" "sqlite3" "zlib" "bzip2")
  
  for dep in "${dependencies[@]}"; do
    if ! brew list --formula | grep -q "^$dep$"; then
      log_info "Installing $dep..."
      brew install "$dep"
      log_success "$dep installed successfully."
    else
      log_info "$dep is already installed."
    fi
  done
  
  log_success "All Python build dependencies are installed."
  return 0
}

# Install the latest stable Python version using pyenv
install_latest_python() {
  log_info "Checking if pyenv is installed..."
  if ! command -v pyenv >/dev/null 2>&1; then
    log_warning "pyenv is not installed. Skipping Python installation."
    return
  fi

  log_info "Installing latest stable Python version..."
  # Get the latest stable Python version (excluding alpha/beta/rc)
  latest_python=$(pyenv install --list | grep -v - | grep -v a | grep -v b | grep -v rc | grep "^  [0-9]" | tail -1 | tr -d '[:space:]')
  
  if [[ -z "$latest_python" ]]; then
    log_error "Failed to determine the latest stable Python version."
    return
  fi

  log_info "Latest stable Python version: $latest_python"
  
  # Install required build dependencies before proceeding
  log_info "Ensuring all Python build dependencies are installed..."
  install_python_build_dependencies
  
  # Check if this version is already installed
  if pyenv versions | grep -q "$latest_python"; then
    log_info "Python $latest_python is already installed."
  else
    log_info "Installing Python $latest_python..."
    # Set CPPFLAGS and LDFLAGS to ensure the build can find the dependencies
    # These environment variables help pyenv find the installed dependencies
    export CPPFLAGS="-I$(brew --prefix openssl)/include -I$(brew --prefix bzip2)/include -I$(brew --prefix readline)/include -I$(brew --prefix sqlite3)/include -I$(brew --prefix zlib)/include -I$(brew --prefix xz)/include"
    export LDFLAGS="-L$(brew --prefix openssl)/lib -L$(brew --prefix readline)/lib -L$(brew --prefix sqlite3)/lib -L$(brew --prefix zlib)/lib -L$(brew --prefix bzip2)/lib -L$(brew --prefix xz)/lib"
    
    # Install Python with pyenv
    pyenv install "$latest_python"
    log_success "Python $latest_python installed successfully."
  fi
  
  # Set as global version
  log_info "Setting Python $latest_python as the global version..."
  pyenv global "$latest_python"
  log_success "Python $latest_python is now the global version."
  
  # Verify installation
  python_version=$(python --version)
  log_info "Installed Python version: $python_version"
}

# Main execution
main() {
  install_homebrew
  install_packages
  configure_shell
  install_latest_ruby
  install_latest_python
  
  log_success "Setup completed successfully!"
  log_info "To apply the changes to your current terminal session, run: source $ZSHRC_PATH"
  log_info "Or restart your terminal."
}

main "$@"

