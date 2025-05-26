#!/bin/zsh
set -e

# Color definitions for logging (used colors only)
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$1" | tee -a ci_setup.log; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1" | tee -a ci_setup.log; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" | tee -a ci_setup.log >&2; }
log_debug() { echo ">>> DEBUG: $1" | tee -a ci_setup.log; }

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

# Logging functions
log_info() { echo "[INFO] $1" | tee -a ci_setup.log; }
log_success() { echo "[SUCCESS] $1" | tee -a ci_setup.log; }
log_error() { echo "[ERROR] $1" | tee -a ci_setup.log >&2; }
log_debug() { echo ">>> DEBUG: $1" | tee -a ci_setup.log; }

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
    log_debug "=== Initial zinit script content ==="
    log_debug "$(cat "$zinit_path")"
    log_debug "=== Typeset patterns found ==="
    log_debug "$(grep -n 'typeset.*-g' "$zinit_path" || echo 'No typeset -g patterns found')"
    
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
    
    # Process each pattern separately for better reliability
    sed -i '' \
        -e 's/typeset[[:space:]]*-gA[[:space:]]/typeset -A /g' \
        -e 's/typeset[[:space:]]*-ga[[:space:]]/typeset -a /g' \
        -e 's/typeset[[:space:]]*-gU[[:space:]]/typeset -U /g' \
        -e 's/typeset[[:space:]]*-g[[:space:]]/typeset /g' \
        "$tmp_file" || {
            rm -f "$tmp_file"
            return 1
        }
    
    log_debug "=== Content after patching ==="
    log_debug "$(cat "$tmp_file")"
    
    # Verify patch was successful
    if grep -q "typeset.*-g" "$tmp_file"; then
        log_error "Patching verification failed"
        log_debug "=== Remaining typeset patterns ==="
        log_debug "$(grep -n 'typeset.*-g' "$tmp_file")"
        rm -f "$tmp_file"
        return 1
    fi
    
    mv "$tmp_file" "$zinit_path"
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
    rm -f ci_setup.log
    generate_ci_setup "setup.sh" "ci_setup.sh" || {
        log_error "Failed to create CI setup script"
        return 1
    }
    log_success "CI setup script generation complete"
}

main "$@"
