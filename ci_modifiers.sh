# shellcheck shell=bash
# shellcheck disable=SC2296,SC2034,SC2154
#!/bin/zsh
#
# CI Modifier Script
# This script modifies setup.sh to create a CI-compatible version

# Enable strict error handling
set -euo pipefail
IFS=$'\n\t'

# Source logging module
# shellcheck source=lib/logging.sh
source "lib/logging.sh"

# Script configuration
readonly SETUP_SCRIPT="setup.sh"
readonly CI_SETUP_SCRIPT="ci_setup.sh"

# Function to add CI-specific environment variables
add_ci_env_vars() {
    local temp_file
    temp_file=$(mktemp)
    
    log_debug "Creating temporary file for modifications: $temp_file"
    
    # Add CI environment variables after set -e line
    sed '/^set -e/a\
# CI-specific environment variables\
export CI=true\
export NONINTERACTIVE=1\
export HOMEBREW_NO_AUTO_UPDATE=1\
export HOMEBREW_NO_INSTALL_CLEANUP=1\
export HOMEBREW_NO_ENV_HINTS=1\
' "$SETUP_SCRIPT" > "$temp_file"

    # Replace original file
    mv "$temp_file" "$CI_SETUP_SCRIPT" || {
        log_error "Failed to create $CI_SETUP_SCRIPT"
        rm -f "$temp_file"
        return 1
    }

    chmod +x "$CI_SETUP_SCRIPT"
    log_success "Created CI-compatible setup script: $CI_SETUP_SCRIPT"
}

# Function to modify interactive prompts
modify_interactive_prompts() {
    local temp_file
    temp_file=$(mktemp)
    
    log_debug "Modifying interactive prompts in $CI_SETUP_SCRIPT"
    
    # Replace read commands with default values
    sed 's/read -p/# read -p/g' "$CI_SETUP_SCRIPT" > "$temp_file"
    mv "$temp_file" "$CI_SETUP_SCRIPT"

    # Replace interactive confirmations with automatic yes
    sed 's/read -r response/response="y"/g' "$CI_SETUP_SCRIPT" > "$temp_file"
    mv "$temp_file" "$CI_SETUP_SCRIPT"

    log_success "Modified interactive prompts for CI environment"
}

# Function to add CI-specific modifications
add_ci_modifications() {
    local temp_file
    temp_file=$(mktemp)
    
    log_debug "Adding CI-specific modifications"
    
    # Add CI-specific configurations
    cat >> "$CI_SETUP_SCRIPT" << 'EOF'

# CI-specific configurations
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export SHELL="/bin/zsh"
export ZDOTDIR="${ZDOTDIR:-$HOME}"

# Ensure non-interactive mode
export DEBIAN_FRONTEND=noninteractive
export HOMEBREW_NO_ANALYTICS=1
EOF

    log_success "Added CI-specific configurations"
}

# Main execution
main() {
    log_info "Starting CI modifications for setup script..."

    # Ensure setup.sh exists
    if [[ ! -f "$SETUP_SCRIPT" ]]; then
        log_error "$SETUP_SCRIPT not found"
        exit 1
    }

    # Create CI setup script
    log_info "Creating CI-compatible version of $SETUP_SCRIPT..."
    
    # Copy setup script
    cp "$SETUP_SCRIPT" "$CI_SETUP_SCRIPT" || {
        log_error "Failed to create $CI_SETUP_SCRIPT"
        exit 1
    }

    # Apply modifications
    add_ci_env_vars || exit 1
    modify_interactive_prompts || exit 1
    add_ci_modifications || exit 1

    log_success "CI modifications completed successfully"
    log_info "Created CI-compatible script: $CI_SETUP_SCRIPT"
}

# Execute main function
main "$@"
