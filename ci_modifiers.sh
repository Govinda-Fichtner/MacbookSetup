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

# Function to setup antidote plugins
setup_antidote_plugins() {
    log_info "Setting up antidote plugins..."
    local plugins_file="${HOME}/.zsh_plugins.txt"

    # Create plugins file if it doesn't exist
    if [[ ! -f "${plugins_file}" ]]; then
        log_info "Creating antidote plugins file: ${plugins_file}"

        # Create the plugins file with commonly used plugins
        cat > "${plugins_file}" << 'EOF'
# Core ZSH enhancements
zsh-users/zsh-syntax-highlighting
zsh-users/zsh-autosuggestions
zsh-users/zsh-completions
zsh-users/zsh-history-substring-search

# Git enhancements
wfxr/forgit

# Tool integrations
ohmyzsh/ohmyzsh path:plugins/kubectl
ohmyzsh/ohmyzsh path:plugins/docker
ohmyzsh/ohmyzsh path:plugins/docker-compose

# Utility plugins
supercrabtree/k
b4b4r07/enhancd
EOF
        log_success "Created antidote plugins file"
    else
        log_info "Antidote plugins file already exists"
    fi

    # Verify the plugins file exists
    if [[ ! -f "${plugins_file}" ]]; then
        log_error "Failed to create antidote plugins file"
        return 1
    fi

    log_success "Antidote plugins setup complete"
    return 0
}

# Install packages
install_packages() {
    log_info "Installing packages..."

    # Install git and antidote first
    brew install git antidote || {
        log_error "Failed to install git and antidote"
        return 1
    }

    # Install development tools
    brew install rbenv pyenv direnv starship || {
        log_error "Failed to install development tools"
        return 1
    }

    # Install completion utilities
    brew install zsh-completions fzf || {
        log_error "Failed to install completion tools"
        return 1
    }

    # Install HashiCorp tools required by verification
    log_info "Installing HashiCorp tools..."
    brew install terraform packer || {
        log_error "Failed to install HashiCorp tools"
        return 1
    }

    # Install kubernetes tools (non-critical)
    brew install kubectl kubectx || log_info "Kubernetes tools installation skipped, not critical"

    # Setup antidote plugins
    setup_antidote_plugins || {
        log_error "Failed to setup antidote plugins"
        return 1
    }

    log_success "Package installation complete"
    return 0
}

# Configure shell
configure_shell() {
    log_info "Configuring shell..."

    # Create required directories
    mkdir -p "${HOME}/.zcompcache"
    touch "${HOME}/.zshrc"

    # Create/overwrite .zshrc with proper configuration
    log_info "Writing shell configuration to .zshrc..."

    # Create temporary file first to avoid issues with redirection
    local tmp_zshrc="${HOME}/.zshrc.tmp"
    cat > "${tmp_zshrc}" << 'EOT'
# ZSH Configuration

# Enable extended globbing
setopt extended_glob
# Avoid no match errors
setopt null_glob

# Load antidote plugin manager
source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"

# Initialize antidote with static loading
antidote load "${ZDOTDIR:-$HOME}/.zsh_plugins.txt"

# Initialize completion system
autoload -Uz compinit
compinit -i

# Initialize rbenv if available
if command -v rbenv >/dev/null; then
    eval "$(rbenv init -)"
fi

# Initialize pyenv if available
if command -v pyenv >/dev/null; then
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
fi

# Initialize direnv if available
if command -v direnv >/dev/null; then
    eval "$(direnv hook zsh)"
fi

# Initialize starship prompt if available
if command -v starship >/dev/null; then
    eval "$(starship init zsh)"
fi

# Initialize fzf if available
if [[ -f "$(brew --prefix)/opt/fzf/shell/completion.zsh" ]]; then
    source "$(brew --prefix)/opt/fzf/shell/completion.zsh"
fi

if [[ -f "$(brew --prefix)/opt/fzf/shell/key-bindings.zsh" ]]; then
    source "$(brew --prefix)/opt/fzf/shell/key-bindings.zsh"
fi

# Kubernetes completions
if command -v kubectl >/dev/null; then
    source <(kubectl completion zsh)
fi

# HashiCorp tool completions
if command -v terraform >/dev/null; then
    complete -o nospace -C "$(command -v terraform)" terraform
fi

if command -v packer >/dev/null; then
    complete -o nospace -C "$(command -v packer)" packer
fi

# Kubectx and kubens completions (safe handling)
if command -v kubectx >/dev/null; then
    # Capture completion script output and evaluate it safely
    kubectx_comp="$(kubectx --completion zsh 2>/dev/null)" || true
    if [[ -n "${kubectx_comp}" ]]; then
        eval "${kubectx_comp}"
    fi
fi

if command -v kubens >/dev/null; then
    # Capture completion script output and evaluate it safely
    kubens_comp="$(kubens --completion zsh 2>/dev/null)" || true
    if [[ -n "${kubens_comp}" ]]; then
        eval "${kubens_comp}"
    fi
fi
EOT

    # Move the temporary file to the actual .zshrc
    mv "${tmp_zshrc}" "${HOME}/.zshrc"

    # Clean up completion cache
    rm -f "${HOME}/.zcompdump"* 2>/dev/null || true
    rm -f "${HOME}/.zcompcache/"* 2>/dev/null || true

    # Initialize completion system
    autoload -Uz compinit
    compinit -i

    # shellcheck disable=SC1090,SC1091
    source "${HOME}/.zshrc"

            log_success "Shell configuration completed"
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
