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

  # 2. Source HashiCorp installation functions directly from file rather than creating a temp file
  if [ -f "hashicorp_install.sh" ]; then
    log_info "Using existing hashicorp_install.sh for function definitions"
    # Read the content of hashicorp_install.sh, but skip the shebang line
    HASHICORP_FUNCTIONS=$(tail -n +2 "hashicorp_install.sh")
    # Create a temporary file with HashiCorp functions
    cat > /tmp/hashicorp_functions.sh << EOF

# HashiCorp installation functions - directly included from hashicorp_install.sh
${HASHICORP_FUNCTIONS}
EOF
  else
    log_error "hashicorp_install.sh not found - creating default implementation"
    cat > /tmp/hashicorp_functions.sh << 'EOF'

# HashiCorp installation functions
# Placed after all logging functions and before other functions
install_hashicorp_tool() {
  local tool=$1
  local version=$2
  local arch
  
  log_info "Checking if $tool is installed..."
  if command -v "$tool" >/dev/null 2>&1; then
    local current_version
    current_version=$("$tool" --version 2>/dev/null)
    log_success "$tool is already installed (version: $current_version)."
    return 0
  fi

  log_info "Installing HashiCorp $tool directly (version $version)..."
  
  # Create a temporary directory for the download
  local tmp_dir
  tmp_dir=$(mktemp -d)
  log_info "Created temporary directory: $tmp_dir"
  
  # Determine the architecture
  if [[ "$(uname -m)" == "arm64" ]]; then
    arch="arm64"
  else
    arch="amd64"
  fi
  
  # Set the download URL
  local download_url="https://releases.hashicorp.com/$tool/$version/${tool}_${version}_darwin_${arch}.zip"
  local zip_file="$tmp_dir/$tool.zip"
  
  # Download the zip file
  log_info "Downloading $tool from: $download_url"
  if ! curl -sSL "$download_url" -o "$zip_file"; then
    log_error "Failed to download $tool from $download_url"
    rm -rf "$tmp_dir"
    return 1
  fi
  
  # Extract the zip file
  log_info "Extracting $tool..."
  if ! unzip -q "$zip_file" -d "$tmp_dir"; then
    log_error "Failed to extract $tool"
    rm -rf "$tmp_dir"
    return 1
  fi
  
  # Move the binary to /usr/local/bin
  log_info "Installing $tool to /usr/local/bin..."
  if ! sudo mv "$tmp_dir/$tool" /usr/local/bin/; then
    log_error "Failed to move $tool binary to /usr/local/bin/"
    rm -rf "$tmp_dir"
    return 1
  fi
  
  # Set appropriate permissions
  sudo chmod +x "/usr/local/bin/$tool"
  
  # Clean up the temporary directory
  rm -rf "$tmp_dir"
  
  # Verify the installation
  if command -v "$tool" >/dev/null 2>&1; then
    local installed_version
    installed_version=$("$tool" --version)
    log_success "$tool $installed_version installed successfully."
    return 0
  else
    log_error "$tool installation failed. Please check the logs."
    return 1
  fi
}

# Install Terraform
install_terraform() {
  install_hashicorp_tool "terraform" "1.6.0"
}

# Install Packer
install_packer() {
  install_hashicorp_tool "packer" "1.11.2"
}
EOF
  fi

  # 3. Find the insertion point after all logging functions (look for the line after log_error function's closing brace)
  LOGGING_END=$(grep -n "^log_error" "$output_file" | head -1 | cut -d':' -f1)
  if [ -n "$LOGGING_END" ]; then
    # Find the next line after the log_error function's completion
    INSERTION_POINT=$((LOGGING_END + 2))
    # Insert the HashiCorp functions after the log_error function is complete
    sed -i.bak "${INSERTION_POINT}r /tmp/hashicorp_functions.sh" "$output_file"
    log_info "Successfully injected HashiCorp functions into $output_file"
    
    # Verify that the functions were actually injected
    if grep -q "install_terraform()" "$output_file"; then
      log_success "install_terraform function successfully injected into $output_file"
    else
      log_error "install_terraform function not found in $output_file after injection"
      return 1
    fi
    
    if grep -q "install_packer()" "$output_file"; then
      log_success "install_packer function successfully injected into $output_file"
    else
      log_error "install_packer function not found in $output_file after injection"
      return 1
    fi
  else
    log_error "Could not find insertion point after logging functions"
    return 1
  fi

  # Clean up the temporary file
  rm -f /tmp/hashicorp_functions.sh

  # 3. Modify the install_packages function to use a subset of packages
  # Find the install_packages function and replace its content using awk
  # Note: Terraform and Packer are installed separately due to BUSL license
  awk '/^install_packages\(\)/{p=1;print;print "  log_info \"Installing essential packages for CI testing...\"\n\n  # Install core packages directly (faster than full Brewfile)\n  brew install git zinit rbenv pyenv direnv starship kubectl helm kubectx\n\n  # Install HashiCorp tools directly (defined earlier in this script)\n  install_terraform || log_error \"Failed to install Terraform\"\n  install_packer || log_error \"Failed to install Packer\"\n\n  # Skip casks in CI to speed up testing\n  log_success \"Essential packages installed successfully.\"";next} p&&/^}/{p=0} !p{print}' "$output_file" > "$output_file.tmp" && mv "$output_file.tmp" "$output_file"

  # 4. Remove any existing install_terraform or install_packer functions from setup.sh
  # (they might conflict with our injected versions)
  sed -i.bak '/^install_terraform()/,/^}/d' "$output_file"
  sed -i.bak '/^install_packer()/,/^}/d' "$output_file"
  
  # 5. Verify function order and check for duplicates
  log_info "Verifying function order in $output_file..."
  if grep -n "^install_packer()" "$output_file" | wc -l | grep -q "1"; then
    log_success "No duplicate install_packer functions found."
  else
    log_error "Duplicate install_packer functions found. Check $output_file manually."
  fi
  
  # 5. Ensure .zshrc exists and completions are properly loaded
  # Create a temporary file with the content to insert
  cat > /tmp/zshrc_config.txt << 'EOZSH'
# Check and create .zshrc if needed
if [[ ! -f "$ZSHRC_PATH" ]]; then
  touch "$ZSHRC_PATH"
fi

# Ensure zsh completions directory is in fpath
if ! grep -q "zsh/site-functions" "$ZSHRC_PATH" 2>/dev/null; then
  echo "fpath=(/opt/homebrew/share/zsh/site-functions \$fpath)" >> "$ZSHRC_PATH"
fi
EOZSH

  # Insert the content after ZSHRC_PATH declaration
  sed -i.bak "/ZSHRC_PATH=.*$/r /tmp/zshrc_config.txt" "$output_file"
  rm /tmp/zshrc_config.txt

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
