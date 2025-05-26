#!/bin/zsh
set -e

# Simple logging functions
log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

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

# Simple logging functions
log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Function to patch zinit
patch_zinit_init() {
    log_info "Finding zinit installation..."
    local zinit_path
    zinit_path="$(brew --prefix)/opt/zinit/zinit.zsh"

    if [[ ! -f "$zinit_path" ]]; then
        log_error "Zinit not found at: $zinit_path"
        return 1
    fi

    log_success "Found zinit at: $zinit_path"
    
    # Create backup if it doesn't exist
    if [[ ! -f "${zinit_path}.bak" ]]; then
        cp "$zinit_path" "${zinit_path}.bak" || {
            log_error "Failed to create backup of zinit script"
            return 1
        }
    fi

    # Patch zinit script - carefully handle different typeset variants
    log_info "Patching zinit script..."
    local tmp_file="${zinit_path}.tmp"
    
    # Process the file line by line to handle all typeset patterns
    while IFS= read -r line; do
        # Handle different typeset patterns with careful replacements
        line=${line/typeset[[:space:]]-gA[[:space:]]/typeset -A }
        line=${line/typeset[[:space:]]-ga[[:space:]]/typeset -a }
        line=${line/typeset[[:space:]]-gU[[:space:]]/typeset -U }
        line=${line/typeset[[:space:]]-g[[:space:]]/typeset }
        echo "$line"
    done < "$zinit_path" > "$tmp_file"
    
    # Verify no typeset -g patterns remain
    if ! grep -q "typeset[[:space:]]*-g" "$tmp_file"; then
        mv "$tmp_file" "$zinit_path"
        log_success "Successfully patched zinit script"
        return 0
    else
        log_error "Patching verification failed"
        rm -f "$tmp_file"
        cp "${zinit_path}.bak" "$zinit_path"
        return 1
    fi
}

# Install packages
install_packages() {
    log_info "Installing packages..."
    
    # Ensure Homebrew is in PATH
    if [[ "$(uname -m)" == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    # Install git and zinit first
    brew install git zinit || return 1
    
    # Patch zinit
    patch_zinit_init || return 1
    
    # Install remaining packages
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
    
    # Create necessary directories
    mkdir -p "$HOME/.zcompcache"
    mkdir -p "$HOME/.zsh/completions"
    
    # Set up .zshrc with proper completions to pass verification
    cat > "$HOME/.zshrc" << 'EOF'
# Enable extended globbing and other zsh options
setopt EXTENDED_GLOB
setopt NO_CASE_GLOB
setopt COMPLETE_ALIASES

# Set up fpath before compinit
FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"

# Initialize completion system
autoload -Uz compinit
compinit -i

# Initialize bash completions for tools that need it
autoload -Uz bashcompinit
bashcompinit

# Source zinit
source "$(brew --prefix)/opt/zinit/zinit.zsh"

# rbenv initialization (checked by verify_setup.sh)
if command -v rbenv > /dev/null; then
    eval "$(rbenv init -)"
fi

# pyenv initialization (checked by verify_setup.sh)
if command -v pyenv > /dev/null; then
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
fi

# direnv hook (checked by verify_setup.sh)
if command -v direnv > /dev/null; then
    eval "$(direnv hook zsh)"
fi

# starship initialization (checked by verify_setup.sh)
if command -v starship > /dev/null; then
    eval "$(starship init zsh)"
fi

# HashiCorp tools completions (terraform and packer)
if command -v terraform > /dev/null; then
    complete -o nospace -C $(which terraform) terraform
fi

if command -v packer > /dev/null; then
    complete -o nospace -C $(which packer) packer
fi

# Set up specific completions to match verify_setup.sh checks
# For git
if command -v git > /dev/null; then
    zstyle ':completion:*:*:git:*' script "$(brew --prefix)/share/zsh/site-functions/_git"
fi

# Force rebuild completions to ensure everything is available
compinit -i
EOF

    # Source the new configuration
    # shellcheck disable=SC1091
    source "$HOME/.zshrc"
    
    # Clean completion caches
    rm -f "$HOME/.zcompdump"* 2>/dev/null || true
    rm -f "$HOME/.zcompcache/"* 2>/dev/null || true
    
    # Load completions explicitly to ensure verify_setup.sh finds them
    log_info "Setting up completions for verification..."
    
    # Force completion initialization
    autoload -Uz compinit
    compinit -i
    
    # Load bash completions to ensure HashiCorp tools work
    autoload -Uz bashcompinit
    bashcompinit
    
    log_success "Shell environment configured"
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
