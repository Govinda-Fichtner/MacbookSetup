#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2296,SC2034,SC2154,SC1091
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

# Function to add homebrew-bundle check at the beginning of install_packages function
add_homebrew_bundle_check() {
  local temp_file
  temp_file=$(mktemp)

  log_debug "Adding homebrew-bundle check to install_packages function"

  # Add homebrew-bundle check right after the "install_packages()" function definition
  sed '/^install_packages() {$/a\
  # Ensure homebrew-bundle is available in CI\
  if [[ "$CI" == "true" ]]; then\
    log_info "Verifying homebrew-bundle availability in CI..."\
    if ! brew bundle --help > /dev/null 2>&1; then\
      log_info "Installing homebrew-bundle for CI..."\
      # Update Homebrew first\
      brew update 2>/dev/null || true\
      # Try installing bundle support\
      if ! brew install homebrew/bundle/brew-bundle 2>/dev/null; then\
        # Fallback to tap method for older versions\
        brew tap homebrew/bundle 2>/dev/null || {\
          log_error "Failed to install homebrew-bundle"\
          return 1\
        }\
      fi\
      # Final verification\
      if ! brew bundle --help > /dev/null 2>&1; then\
        log_error "homebrew-bundle installation failed"\
        return 1\
      fi\
      log_success "homebrew-bundle installed successfully"\
    else\
      log_success "homebrew-bundle is already available"\
    fi\
  fi\
\
  # Force brew bundle install in CI environment for reliability\
  if [[ "$CI" == "true" ]]; then\
    log_info "CI environment detected - forcing brew bundle install for reliability"\
    local ci_bundle_log="/tmp/ci_brew_bundle.log"\
    echo "==== CI: brew bundle install ====" >> "$ci_bundle_log"\
    brew bundle install 2>&1 | tee -a "$ci_bundle_log"\
    local ci_install_status=${PIPESTATUS[0]}\
    if [[ $ci_install_status -ne 0 ]]; then\
      log_error "CI brew bundle install failed (exit code $ci_install_status). See $ci_bundle_log for details."\
      return 1\
    fi\
    log_success "CI brew bundle install completed successfully (log: $ci_bundle_log)"\
  fi\
' "$CI_SETUP_SCRIPT" > "$temp_file"

  mv "$temp_file" "$CI_SETUP_SCRIPT" || {
    log_error "Failed to add homebrew-bundle check"
    return 1
  }

  log_success "Added homebrew-bundle check to install_packages function"
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
export HOMEBREW_NO_ENV_HINTS=1

# Ensure we're running in zsh
if [ -n "$BASH_VERSION" ]; then
    exec /bin/zsh "$0" "$@"
fi

# Initialize OrbStack and Docker for CI
if command -v orb > /dev/null 2>&1; then
    # Add OrbStack bin to PATH
    eval "$(orb shell-setup zsh 2>/dev/null)" >/dev/null 2>&1

    # Initialize OrbStack service
    orb start --quiet >/dev/null 2>&1 || true

    # Wait for OrbStack to be ready
    for i in {1..30}; do
        if orb status 2>/dev/null | grep -q "running"; then
            break
        fi
        sleep 1
    done
fi

# Ensure Docker is available and running
if command -v docker > /dev/null 2>&1; then
    # Wait for Docker to be ready
    for i in {1..30}; do
        if docker info >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
fi

# Enhanced completion generation function for CI
generate_ci_completion_files() {
    log_info "Generating completion files for CI environment..."

    # Set up completions directory
    mkdir -p "${HOME}/.zsh/completions"

    # Enhanced completion generation for CI with proper PATH handling
    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

    # macOS/CI-compatible timeout function
    run_with_timeout() {
        local timeout_duration=$1
        shift
        local cmd="$*"

        # Try to use gtimeout if available (from brew install coreutils)
        if command -v gtimeout > /dev/null 2>&1; then
            gtimeout "$timeout_duration" bash -c "$cmd"
        # Try regular timeout on Linux systems
        elif command -v timeout > /dev/null 2>&1; then
            timeout "$timeout_duration" bash -c "$cmd"
        # Fallback to using background process with timeout
        else
            (
                eval "$cmd" &
                local pid=$!
                (
                    sleep "$timeout_duration"
                    kill "$pid" 2>/dev/null
                ) &
                local timeout_pid=$!
                wait "$pid" 2>/dev/null
                local exit_code=$?
                kill "$timeout_pid" 2>/dev/null
                exit "$exit_code"
            )
        fi
    }

    # Generate completions for container tools
for tool_pair in "docker:docker completion zsh" "kubectl:kubectl completion zsh" "helm:helm completion zsh" "orb:orb completion zsh" "orbctl:orbctl completion zsh"; do
    tool="${tool_pair%%:*}"
    cmd="${tool_pair#*:}"
    completion_file="${HOME}/.zsh/completions/_${tool}"

    if command -v "$tool" > /dev/null 2>&1; then
        # For orb/orbctl, try completion generation even if OrbStack isn't fully running
        if [[ "$tool" == "orb" || "$tool" == "orbctl" ]]; then
            # Try completion generation with extended timeout for orb tools
            if run_with_timeout 30 "$cmd" > "$completion_file" 2>/dev/null && [[ -s "$completion_file" ]]; then
                echo "[CI] Generated completion for $tool"
            else
                # Fallback: try to verify the completion subcommand exists
                if "$tool" completion --help > /dev/null 2>&1 || [[ "$("$tool" --help 2>/dev/null)" == *"completion"* ]]; then
                    echo "[CI] $tool completion subcommand verified (generation failed but command exists)"
                    # Create a minimal completion file to indicate the tool supports completion
                    echo "#compdef $tool" > "$completion_file"
                    echo "# $tool completion - generated by CI setup" >> "$completion_file"
                    echo "_${tool}() { _command_names }" >> "$completion_file"
                    echo "compdef _${tool} ${tool}" >> "$completion_file"
                else
                    echo "[CI] Failed to generate completion for $tool - no completion support detected"
                    rm -f "$completion_file"
                fi
            fi
        else
            # Standard completion generation for other tools
            if run_with_timeout 15 "$cmd" > "$completion_file" 2>/dev/null && [[ -s "$completion_file" ]]; then
                echo "[CI] Generated completion for $tool"
            else
                echo "[CI] Failed to generate completion for $tool - timeout or empty output"
                rm -f "$completion_file"
            fi
        fi
    else
        echo "[CI] Tool $tool not found, skipping completion"
    fi
done

# Generate completions for development tools
for tool_pair in "rbenv:rbenv completions zsh" "pyenv:pyenv completions zsh" "direnv:direnv hook zsh"; do
    tool="${tool_pair%%:*}"
    cmd="${tool_pair#*:}"
    completion_file="${HOME}/.zsh/completions/_${tool}"

    if command -v "$tool" > /dev/null 2>&1; then
        if run_with_timeout 15 "$cmd" > "$completion_file" 2>/dev/null && [[ -s "$completion_file" ]]; then
            echo "[CI] Generated completion for $tool"
        else
            echo "[CI] Failed to generate completion for $tool - timeout or empty output"
            rm -f "$completion_file"
        fi
    else
        echo "[CI] Tool $tool not found, skipping completion"
    fi
done

# HashiCorp tools use different completion mechanism
for tool in terraform packer; do
    if command -v "$tool" > /dev/null 2>&1; then
        echo "[CI] Setting up autocomplete for $tool..."
        run_with_timeout 15 "$tool -install-autocomplete zsh" >/dev/null 2>&1 || true
    fi
done

    # Add completion configuration to .zshrc
    cat >> "${ZDOTDIR:-$HOME}/.zshrc" << 'ZSHRC_EOF'
# Initialize completion system
autoload -Uz compinit
if [[ -f ~/.zcompdump && $(find ~/.zcompdump -mtime +1) ]]; then
    compinit -i >/dev/null 2>&1
else
    compinit -C -i >/dev/null 2>&1
fi

# Add completions directory to fpath
fpath=("${HOME}/.zsh/completions" $fpath)

# Completion settings
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path "${HOME}/.zcompcache"
ZSHRC_EOF

    log_success "CI completion generation completed"
}

EOF

  # Call the main setup function at the end
  echo 'main "$@"' >> "$CI_SETUP_SCRIPT"

  log_success "Added CI-specific configurations"
}

# Main execution
main() {
  log_info "Starting CI modifications for setup script..."

  # Ensure setup.sh exists
  if [[ ! -f "$SETUP_SCRIPT" ]]; then
    log_error "$SETUP_SCRIPT not found"
    exit 1
  fi

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
  add_homebrew_bundle_check || exit 1

  # Replace original completion generation function completely with enhanced CI version
  sed -i '' '/^generate_completion_files() {$/,/^}$/c\
# CI: Original function replaced with enhanced version\
# See generate_ci_completion_files function below' "$CI_SETUP_SCRIPT" || log_warning "Could not modify completion generation function"

  # Replace the function call with our enhanced version
  sed -i '' 's/generate_completion_files/generate_ci_completion_files/' "$CI_SETUP_SCRIPT" || log_warning "Could not modify completion generation call"

  # Remove the original main call before adding CI modifications
  sed -i '' '/^main "\$@"$/d' "$CI_SETUP_SCRIPT" || log_warning "Could not remove original main call"

  add_ci_modifications || exit 1

  log_success "CI modifications completed successfully"
  log_info "Created CI-compatible script: $CI_SETUP_SCRIPT"
}

# Execute main function
main "$@"
