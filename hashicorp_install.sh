#!/bin/zsh
#
# HashiCorp Tools Installation Script
# This script provides functions for installing HashiCorp tools directly from releases

# Enable strict error handling
set -euo pipefail
IFS=$'\n\t'

# Source logging module
# shellcheck source=lib/logging.sh
source "lib/logging.sh"

# Script configuration
readonly INSTALL_DIR="/usr/local/bin"
readonly TMP_BASE="/tmp/hashicorp_install"

# Function to clean up temporary files
cleanup() {
    local tmp_dir="$1"
    if [[ -d "$tmp_dir" ]]; then
        rm -rf "$tmp_dir"
        log_debug "Cleaned up temporary directory: $tmp_dir"
    fi
}

# Function to verify tool installation
verify_installation() {
    local tool="$1"
    local version="$2"
    
    if ! command -v "$tool" >/dev/null 2>&1; then
        log_error "$tool not found in PATH after installation"
        return 1
    fi
    
    local installed_version
    installed_version=$("$tool" version | head -n1)
    log_debug "$tool version after installation: $installed_version"
    
    if [[ "$installed_version" != *"$version"* ]]; then
        log_warning "Installed version ($installed_version) may not match requested version ($version)"
    }
    
    return 0
}

# Function to install HashiCorp tools
install_hashicorp_tool() {
    local tool="$1"
    local version="$2"
    local arch
    
    log_info "Checking if $tool is installed..."
    if command -v "$tool" >/dev/null 2>&1; then
        local current_version
        current_version=$("$tool" --version 2>/dev/null)
        log_success "$tool is already installed (version: $current_version)"
        return 0
    fi
    
    log_info "Installing HashiCorp $tool version $version..."
    
    # Create a unique temporary directory
    local tmp_dir
    tmp_dir="${TMP_BASE}/${tool}_${version}_$(date +%s)"
    mkdir -p "$tmp_dir" || {
        log_error "Failed to create temporary directory"
        return 1
    }
    
    # Set up cleanup trap
    trap 'cleanup "$tmp_dir"' EXIT
    
    # Determine architecture
    if [[ "$(uname -m)" == "arm64" ]]; then
        arch="arm64"
    else
        arch="amd64"
    fi
    
    # Construct download URL and paths
    local download_url="https://releases.hashicorp.com/$tool/$version/${tool}_${version}_darwin_${arch}.zip"
    local zip_file="$tmp_dir/$tool.zip"
    
    # Download the tool
    log_info "Downloading $tool from: $download_url"
    if ! curl -sSL "$download_url" -o "$zip_file"; then
        log_error "Failed to download $tool"
        return 1
    fi
    
    # Verify download
    if [[ ! -s "$zip_file" ]]; then
        log_error "Downloaded file is empty"
        return 1
    fi
    
    # Extract the archive
    log_info "Extracting $tool..."
    if ! unzip -q "$zip_file" -d "$tmp_dir"; then
        log_error "Failed to extract $tool archive"
        return 1
    fi
    
    # Install the binary
    log_info "Installing $tool to $INSTALL_DIR..."
    if ! sudo mv "$tmp_dir/$tool" "$INSTALL_DIR/"; then
        log_error "Failed to install $tool binary"
        return 1
    fi
    
    # Set permissions
    if ! sudo chmod +x "$INSTALL_DIR/$tool"; then
        log_error "Failed to set executable permissions for $tool"
        return 1
    fi
    
    # Verify installation
    if verify_installation "$tool" "$version"; then
        log_success "$tool $version installed successfully"
        return 0
    else
        log_error "Failed to verify $tool installation"
        return 1
    fi
}

# Function to install multiple HashiCorp tools
install_hashicorp_tools() {
    local -A tools=(
        ["terraform"]="1.12.1"
        ["packer"]="1.12.0"
        ["vault"]="1.15.0"
        ["consul"]="1.17.0"
        ["nomad"]="1.7.0"
    )
    
    local success_count=0
    local total_tools=${#tools[@]}
    
    for tool version in ${(kv)tools}; do
        if install_hashicorp_tool "$tool" "$version"; then
            ((success_count++))
        else
            log_warning "Failed to install $tool $version"
        fi
    done
    
    log_info "Installation complete: $success_count of $total_tools tools installed successfully"
    return $((total_tools - success_count))
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -eq 2 ]]; then
        install_hashicorp_tool "$1" "$2"
    else
        install_hashicorp_tools
    fi
fi
