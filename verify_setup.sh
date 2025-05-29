#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2296,SC2034,SC2154,SC2076

# macOS Development Environment Verification Script
# This script verifies that all tools and configurations are properly installed

# Ensure we're running in zsh
if [ -n "$BASH_VERSION" ]; then
  exec /bin/zsh "$0" "$@"
fi

# Initialize completion system early
autoload -Uz compinit
if [[ -f ~/.zcompdump && $(find ~/.zcompdump -mtime +1) ]]; then
  compinit -i > /dev/null 2>&1
else
  compinit -C -i > /dev/null 2>&1
fi

# Add completions directory to fpath
fpath=("${HOME}/.zsh/completions" "${fpath[@]}")

# Initialize Antidote early
if [[ -e "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh" ]]; then
  source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
  antidote load "${ZDOTDIR:-$HOME}/.zsh_plugins.txt"
fi

# Script configuration
readonly SCRIPT_VERSION="1.0.0"
readonly COMPLETION_DIR="${HOME}/.zsh/completions"

# Set up quiet mode based on environment
if [[ -n "$CIRRUS_CI" ]] || [[ -n "$QUIET_MODE" ]]; then
  QUIET_MODE=true
  # Redirect all shell initialization output to /dev/null
  exec 2> /dev/null
  # Disable verbose shell features
  setopt NO_BEEP
  setopt NO_NOTIFY
  # Disable plugin loading messages
  ZSH_AUTOSUGGEST_USE_ASYNC=true
  ZSH_AUTOSUGGEST_MANUAL_REBIND=true
  ZSH_AUTOSUGGEST_STRATEGY=(history)
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
  ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
  ZSH_AUTOSUGGEST_ORIGINAL_WIDGET_PREFIX=autosuggest-orig-
  ZSH_AUTOSUGGEST_CLEAR_WIDGETS=()
  ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=()
  ZSH_AUTOSUGGEST_EXECUTE_WIDGETS=()
  ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS=()
  ZSH_AUTOSUGGEST_IGNORE_WIDGETS=()
  ZSH_AUTOSUGGEST_COMPLETION_IGNORE=()
  ZSH_AUTOSUGGEST_HISTORY_IGNORE=()
  ZSH_AUTOSUGGEST_ADDITIONAL_IGNORE=()
fi

# Save stdout for logging
exec 3>&1

# Define color codes (disabled in quiet mode)
if [[ "$QUIET_MODE" == "true" ]]; then
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  NC=""
else
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
fi

# Logging functions
log_info() {
  if [[ "$QUIET_MODE" == "true" ]]; then
    echo "::info::$1" >&3
  else
    echo -e "${BLUE}INFO:${NC} $1"
  fi
}

log_success() {
  if [[ "$QUIET_MODE" == "true" ]]; then
    echo "::success::$1" >&3
  else
    echo -e "${GREEN}SUCCESS:${NC} $1"
  fi
}

log_warning() {
  if [[ "$QUIET_MODE" == "true" ]]; then
    echo "::warning::$1" >&3
  else
    echo -e "${YELLOW}WARNING:${NC} $1"
  fi
}

log_error() {
  if [[ "$QUIET_MODE" == "true" ]]; then
    echo "::error::$1" >&3
  else
    echo -e "${RED}ERROR:${NC} $1"
  fi
}

# Function to print status in CI-friendly format
print_status() {
  local description="$1"
  local result="$2"
  local version="${3:-}"

  if [[ "$QUIET_MODE" == "true" ]]; then
    case "$result" in
      "PASS") echo "::success::✓ $description${version:+ ($version)}" >&3 ;;
      "FAIL") echo "::error::✗ $description" >&3 ;;
      *) echo "::info::$result $description${version:+ ($version)}" >&3 ;;
    esac
  else
    printf "%-35s ... %s%s\n" "$description" "$result" "${version:+ ($version)}"
  fi
}

# Utility functions
check_command() {
  command -v "$1" > /dev/null 2>&1
}

# Function to verify Antidote setup
verify_antidote() {
  log_info "Verifying Antidote setup"

  # Check if Antidote is installed
  if ! check_command antidote; then
    log_error "Antidote is not installed"
    return 1
  fi

  # Check if Antidote directory exists
  if [[ ! -d "${ZDOTDIR:-$HOME}/.antidote" ]]; then
    log_error "Antidote directory not found"
    return 1
  fi

  # Check if plugins file exists
  if [[ ! -f "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" ]]; then
    log_error "Antidote plugins file not found"
    return 1
  fi

  # Check if Antidote is properly initialized
  if ! typeset -f __antidote_setup > /dev/null; then
    log_error "Antidote is not properly initialized"
    return 1
  fi

  log_success "Antidote setup verified"
  return 0
}

# Helper function to check completion setup
check_completion() {
  local tool="$1"
  case "$tool" in
    docker)
      # Docker completion is handled by OrbStack
      command -v docker > /dev/null 2>&1
      ;;
    orb)
      # Check if orb completion file exists
      [[ -f "${COMPLETION_DIR}/_orb" ]]
      ;;
    orbctl)
      # Check if orbctl completion file exists
      [[ -f "${COMPLETION_DIR}/_orbctl" ]]
      ;;
    kubectl)
      command -v kubectl > /dev/null 2>&1 && kubectl completion zsh > /dev/null 2>&1
      ;;
    helm)
      command -v helm > /dev/null 2>&1 && helm completion zsh > /dev/null 2>&1
      ;;
    terraform)
      command -v terraform > /dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

# Function to verify OrbStack setup
verify_orbstack() {
  log_info "Verifying OrbStack setup"

  # Check if OrbStack is installed
  if ! check_command orbctl; then
    log_error "OrbStack is not installed"
    return 1
  fi

  # Check if OrbStack is running
  if ! orbctl status > /dev/null 2>&1; then
    log_info "Starting OrbStack..."
    orbctl start || {
      log_error "Failed to start OrbStack"
      return 1
    }
  fi

  # Check completion files
  local completion_files=(
    "${COMPLETION_DIR}/_orbctl"
    "${COMPLETION_DIR}/_orb"
  )

  for file in "${completion_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      log_info "Generating completion file: $file"
      case "$file" in
        *_orbctl)
          orbctl completion zsh > "$file" 2> /dev/null || {
            log_error "Failed to generate orbctl completion"
            return 1
          }
          ;;
        *_orb)
          orb completion zsh > "$file" 2> /dev/null || {
            log_error "Failed to generate orb completion"
            return 1
          }
          ;;
      esac
    fi
  done

  return 0
}

# Function to verify shell configuration
verify_shell_config() {
  log_info "Verifying shell configuration"

  # Verify shell is zsh
  if [[ "$SHELL" != *"zsh"* ]]; then
    log_error "Current shell is not zsh: $SHELL"
    return 1
  fi

  # Check for essential shell files without sourcing them
  local essential_files=(
    "${ZDOTDIR:-$HOME}/.zshrc"
    "${ZDOTDIR:-$HOME}/.zsh_plugins.txt"
  )

  for file in "${essential_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      log_error "Missing essential file: $file"
      return 1
    fi
  done

  # Verify Antidote setup
  verify_antidote || {
    log_error "Antidote verification failed"
    return 1
  }

  return 0
}

# Main verification function
main() {
  # In CI mode, redirect all output to a temporary file
  if [[ "$QUIET_MODE" == "true" ]]; then
    local temp_log
    temp_log=$(mktemp)
    exec 3>&1                # Save stdout
    exec 1> "$temp_log" 2>&1 # Redirect stdout and stderr to temp file
  fi

  log_info "Starting verification v${SCRIPT_VERSION}"

  local success_count=0
  local total_checks=0
  local failed_items=()

  # Verify shell configuration first
  verify_shell_config || {
    log_error "Shell configuration verification failed"
    if [[ "$QUIET_MODE" == "true" ]]; then
      exec 1>&3 # Restore stdout
      grep -E '^(::(info|success|error|warning)|Running verification script\.\.\.)' "$temp_log" >&3
      rm -f "$temp_log"
    fi
    return 1
  }

  # Verify OrbStack setup
  verify_orbstack || {
    log_error "OrbStack verification failed"
    if [[ "$QUIET_MODE" == "true" ]]; then
      exec 1>&3 # Restore stdout
      grep -E '^(::(info|success|error|warning)|Running verification script\.\.\.)' "$temp_log" >&3
      rm -f "$temp_log"
    fi
    return 1
  }

  # Verify core tools
  log_info "Core Tools"
  for tool in brew git rbenv pyenv direnv starship; do
    ((total_checks++))
    if check_command "$tool"; then
      ((success_count++))
      version=$("$tool" --version 2> /dev/null | head -1 || echo "")
      print_status "$tool" "PASS" "$version"
    else
      failed_items+=("$tool")
      print_status "$tool" "FAIL"
    fi
  done

  # Verify container tools
  log_info "Container Tools"
  for tool in docker orb orbctl kubectl helm; do
    ((total_checks++))
    if check_command "$tool"; then
      ((success_count++))
      version=$("$tool" version 2> /dev/null | head -1 || echo "")
      print_status "$tool" "PASS" "$version"
    else
      failed_items+=("$tool")
      print_status "$tool" "FAIL"
    fi
  done

  # Verify shell completions
  log_info "Shell Completions"
  for tool in docker orb orbctl kubectl helm terraform; do
    ((total_checks++))
    if check_completion "$tool" > /dev/null 2>&1; then
      ((success_count++))
      print_status "$tool completion" "PASS"
    else
      failed_items+=("${tool}_completion")
      print_status "$tool completion" "FAIL"
    fi
  done

  # Print summary
  local percentage=$((success_count * 100 / total_checks))
  log_info "Summary: $success_count/$total_checks checks passed ($percentage%)"

  if [[ ${#failed_items[@]} -gt 0 ]]; then
    log_error "Failed items: ${failed_items[*]}"
    if [[ "$QUIET_MODE" == "true" ]]; then
      exec 1>&3 # Restore stdout
      grep -E '^(::(info|success|error|warning)|Running verification script\.\.\.)' "$temp_log" >&3
      rm -f "$temp_log"
    fi
    return 1
  fi

  log_success "All checks passed"
  if [[ "$QUIET_MODE" == "true" ]]; then
    exec 1>&3 # Restore stdout
    grep -E '^(::(info|success|error|warning)|Running verification script\.\.\.)' "$temp_log" >&3
    rm -f "$temp_log"
  fi
  return 0
}

# Run main function
main "$@"
