#!/bin/bash
# CI-specific modifications to be applied to setup.sh
# This file contains only the differences needed for CI environments

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

# Source HashiCorp installation functions
source ./hashicorp_install.sh

# Function to patch the setup.sh script for CI use
patch_for_ci() {
  local setup_file="$1"
  local output_file="$2"

  # Create a copy of the original script
  cp "$setup_file" "$output_file"
  
  # Apply CI-specific modifications
  
  # 1. Add CI environment marker near the top
  # Note: Using single quotes intentionally for literal string in sed pattern
  sed -i.bak '4i\
# Modified for CI environment\
export CI=true\
' "$output_file"

  # 2. Modify the install_packages function to use a subset of packages
  # Find the install_packages function and replace its content using awk
  # Note: Terraform and Packer are installed separately due to BUSL license
  awk '/^install_packages\(\)/{p=1;print;print "  log_info \"Installing essential packages for CI testing...\"\n\n  # Install core packages directly (faster than full Brewfile)\n  brew install git zinit rbenv pyenv direnv starship kubectl helm kubectx\n\n  # Install HashiCorp tools directly\n  install_terraform || log_error \"Failed to install Terraform\"\n  install_packer || log_error \"Failed to install Packer\"\n\n  # Skip casks in CI to speed up testing\n  log_success \"Essential packages installed successfully.\"";next} p&&/^}/{p=0} !p{print}' "$output_file" > "$output_file.tmp" && mv "$output_file.tmp" "$output_file"

  # 3. Ensure .zshrc exists and completions are properly loaded
  sed -i.bak '/ZSHRC_PATH=.*$/a\
if [[ ! -f "$ZSHRC_PATH" ]]; then\
  touch "$ZSHRC_PATH"\
fi\n\
# Ensure zsh completions directory is in fpath\
echo "fpath=(/opt/homebrew/share/zsh/site-functions $fpath)" >> "$ZSHRC_PATH"\
' "$output_file"

  # 4. Remove any interactive prompts
  sed -i.bak 's/read -p/echo "CI mode: skipping prompt" #read -p/g' "$output_file"
  
  # 5. Add CI-specific logging at the start
  sed -i.bak '/^log_info "Starting setup process/a\
log_info "Running in CI environment - some operations will be modified"' "$output_file"

  # 6. Ensure the script is executable
  chmod +x "$output_file"

  # Clean up backup files
  rm -f "$output_file.bak"

  log_info "CI-optimized script created at $output_file with execute permissions"
}
