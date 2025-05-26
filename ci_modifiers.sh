#!/bin/zsh
set -e

# Simple logging functions with forced flush
log_info() { printf "[INFO] %s\n" "$1" | tee /dev/stderr; }
log_success() { printf "[SUCCESS] %s\n" "$1" | tee /dev/stderr; }
log_error() { printf "[ERROR] %s\n" "$1" | tee /dev/stderr; }
log_debug() { printf "DEBUG: %s\n" "$1" | tee /dev/stderr; }

# Function to generate CI setup script
generate_ci_setup() {
    local setup_file="$1"
    local output_file="$2"

    if [[ ! -f "$setup_file" ]]; then
        log_error "Setup file not found: $setup_file"
        return 1
    fi

    log_info "Creating CI-compatible setup script..."

    cat > "$output_file" << 'EEOF'
#!/bin/zsh
# CI-compatible setup script for macOS

# Essential environment setup
export CI=true
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
setopt +o nomatch

# Simple logging functions with forced flush
log_info() { printf "[INFO] %s\n" "$1" | tee /dev/stderr; }
log_success() { printf "[SUCCESS] %s\n" "$1" | tee /dev/stderr; }
log_error() { printf "[ERROR] %s\n" "$1" | tee /dev/stderr; }
log_debug() { printf "DEBUG: %s\n" "$1" | tee /dev/stderr; }

# Function to patch zinit
patch_zinit_init() {
    log_info "Finding zinit installation..."
    local zinit_path
    
    # Split declaration and assignment for proper error handling
    zinit_path="$(brew --prefix)/opt/zinit/zinit.zsh"
    if [[ ! -f "$zinit_path" ]]; then
        log_error "Zinit not found at: $zinit_path"
        return 1
    fi

    log_success "Found zinit at: $zinit_path"
    
    # Display original content with line numbers
    log_debug "Initial zinit script content:"
    printf "DEBUG: Line %d: %s\n" "$(nl -ba "$zinit_path")" | tee /dev/stderr
    
    # Show typeset patterns with line numbers
    log_debug "Searching for typeset patterns..."
    grep -n 'typeset.*-g' "$zinit_path" | while IFS=':' read -r line content; do
        printf "DEBUG: Found pattern at line %d: %s\n" "$line" "$content" | tee /dev/stderr
    done
    
    # Create backup if it doesn't exist
    if [[ ! -f "${zinit_path}.bak" ]]; then
        cp "$zinit_path" "${zinit_path}.bak" || {
            log_error "Failed to create backup of zinit script"
            return 1
        }
    fi

    # Patch zinit script
    log_info "Patching zinit script..."
    local tmp_file="${zinit_path}.tmp"
    cp "$zinit_path" "$tmp_file" || return 1
    
    # Ensure the temporary file exists
    if [[ ! -f "$tmp_file" ]]; then
        log_error "Failed to create temporary file"
        return 1
    fi
    
    # Check initial content
    log_debug "Temporary file created, size: $(wc -l < "$tmp_file") lines"
    
    # Process patterns
    local pattern_count=0
    local replaced_count=0
    
    # Check each pattern type
    for type in "A" "a" "U" ""; do
        local search="typeset[[:space:]]*-g${type}[[:space:]]"
        local replace="typeset ${type:+ -$type }"
        
        # Count matches
        local matches
        matches=$(grep -c "$search" "$tmp_file" || echo 0)
        ((pattern_count += matches))
        
        if ((matches > 0)); then
            log_debug "Found $matches occurrences of pattern: $search"
            sed -i '' -E "s/$search/$replace/g" "$tmp_file" && ((replaced_count += matches))
        fi
    done
    
    log_debug "Found $pattern_count patterns, replaced $replaced_count"
    
    # Verify patch success
    if grep -q "typeset.*-g" "$tmp_file"; then
        log_error "Patching verification failed"
        log_debug "Remaining patterns:"
        grep -n "typeset.*-g" "$tmp_file" | while IFS=':' read -r line content; do
            printf "DEBUG: Pattern remains at line %d: %s\n" "$line" "$content" | tee /dev/stderr
        done
        rm -f "$tmp_file"
        return 1
    fi
    
    # Show final content
    log_debug "Final content:"
    printf "DEBUG: Line %d: %s\n" "$(nl -ba "$tmp_file")" | tee /dev/stderr
    
    mv "$tmp_file" "$zinit_path"
    log_success "Successfully patched zinit script"
    return 0
}

# Install packages
install_packages() {
    log_info "Installing packages..."
    
    # Install git and zinit first
    brew install git zinit || return 1
    patch_zinit_init || return 1
    
    # Install development tools
    brew install rbenv pyenv direnv starship || return 1

    # Install HashiCorp tools required by verification
    log_info "Installing HashiCorp tools..."
    brew install terraform packer || {
        log_error "Failed to install HashiCorp tools"
        return 1
    }
    
    return 0
}

# Configure shell
configure_shell() {
    log_info "Configuring shell..."
    
    mkdir -p "$HOME/.zcompcache"
    touch "$HOME/.zshrc"
    
    local zinit_path
    # Split declaration and assignment for proper error handling
    zinit_path="$(brew --prefix)/opt/zinit/zinit.zsh"
    echo "source $zinit_path" >> "$HOME/.zshrc"
    
    if command -v rbenv >/dev/null; then
        eval "$(rbenv init -)"
    fi

    if command -v pyenv >/dev/null; then
        eval "$(pyenv init --path)"
        eval "$(pyenv init -)"
    fi
    
    rm -f "$HOME/.zcompdump"* 2>/dev/null || true
    rm -f "$HOME/.zcompcache/"* 2>/dev/null || true
    
    autoload -Uz compinit
    compinit -i
    
    # shellcheck disable=SC1091
    source "$HOME/.zshrc"
    
    return 0
}

# Main function
main() {
    log_info "Starting CI setup..."
    
    # Install Homebrew if needed
    if ! command -v brew >/dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [[ "$(uname -m)" == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
    
    install_packages || exit 1
    configure_shell || exit 1
    
    log_success "CI setup completed"
}

main "$@"
EEOF

    chmod +x "$output_file"
    log_success "Created CI setup script at: $output_file"
}

# Main execution
main() {
    generate_ci_setup "setup.sh" "ci_setup.sh" || {
        log_error "Failed to create CI setup script"
        return 1
    }
    log_success "CI setup script generation complete"
}

main "$@"
