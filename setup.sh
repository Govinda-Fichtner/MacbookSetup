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
  add_to_zshrc "source.*zinit.zsh" "source \$(brew --prefix)/opt/zinit/zinit.zsh

# Load zinit plugins
zinit light zdharma/fast-syntax-highlighting
zinit light zsh-users/zsh-autosuggestions
zinit light macunha1/zsh-terraform" "zinit setup"

  # Add rbenv configuration
  add_to_zshrc "rbenv init" 'eval "$(rbenv init -)"' "rbenv setup"

  # Add pyenv configuration
  add_to_zshrc "pyenv init" 'export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"' "pyenv setup"

  # Add direnv configuration
  add_to_zshrc "direnv hook" 'eval "$(direnv hook zsh)"' "direnv setup"

  # Add Starship prompt configuration
  add_to_zshrc "starship init" 'eval "$(starship init zsh)"' "Starship prompt setup"

  # Add Kubernetes tools completions
  add_to_zshrc "kubectl completion" 'source <(kubectl completion zsh 2>/dev/null)' "kubectl completion"
  add_to_zshrc "helm completion" 'source <(helm completion zsh 2>/dev/null)' "helm completion"
  add_to_zshrc "kubectx completion" 'source <(kubectl completion zsh 2>/dev/null)' "kubectx completion"

  # Terraform completion is now handled by the zinit plugin (macunha1/zsh-terraform)

  log_success "Shell configuration completed."
}
