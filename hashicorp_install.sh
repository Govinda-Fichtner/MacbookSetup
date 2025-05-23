#!/bin/bash
# Function to install HashiCorp tools directly from releases

# Function to install HashiCorp tools directly from releases
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
  install_hashicorp_tool "packer" "1.10.0"
}
