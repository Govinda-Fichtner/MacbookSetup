#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2296,SC2034,SC2154,SC2076,SC2317

# macOS Development Environment Verification Script
# This script verifies that all tools and configurations are properly installed

# Create completions directory if it doesn't exist
mkdir -p "${HOME}/.zsh/completions"

# Initialize completion system
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

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Add the missing check_command function
check_command() {
  command -v "$1" > /dev/null 2>&1
}

# Fix print_status to use a local variable for status
print_status() {
  local pstatus=$1
  local label=$2
  local msg=$3
  case "$pstatus" in
    PASS)
      printf "%b[✓]%b %-30s %s\n" "$GREEN" "$RESET" "$label" "$msg"
      ;;
    FAIL)
      printf "%b[✗]%b %-30s %s\n" "$RED" "$RESET" "$label" "$msg"
      ;;
    SKIP)
      printf "%b[⚠]%b %-30s %s\n" "$YELLOW" "$RESET" "$label" "$msg"
      ;;
    INFO)
      printf "%b[ℹ]%b %-30s %s\n" "$BLUE" "$RESET" "$label" "$msg"
      ;;
  esac
}

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

# Function to verify Antidote setup
verify_antidote() {
  log_info "Verifying Antidote setup"

  # Check if Antidote is installed
  if ! command -v antidote > /dev/null 2>&1; then
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

  log_success "Antidote setup verified"
  return 0
}

# Helper function to check completion setup
check_completion() {
  local tool="$1"
  case "$tool" in
    git)
      # Git completion is built into zsh
      [[ -f "/usr/share/zsh/functions/Completion/Unix/_git" ]] \
        || [[ -f "/usr/local/share/zsh/site-functions/_git" ]] \
        || [[ -f "${HOME}/.zsh/completions/_git" ]]
      ;;
    rbenv)
      # rbenv completion is built into the tool
      command -v rbenv > /dev/null 2>&1 && rbenv completions > /dev/null 2>&1
      ;;
    pyenv)
      # pyenv completion is built into the tool
      command -v pyenv > /dev/null 2>&1 && pyenv completions > /dev/null 2>&1
      ;;
    direnv)
      # direnv completion is built into the tool
      command -v direnv > /dev/null 2>&1 && direnv hook zsh > /dev/null 2>&1
      ;;
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
      # Generate helm completion if not exists
      if command -v helm > /dev/null 2>&1; then
        if [[ ! -f "${COMPLETION_DIR}/_helm" ]]; then
          helm completion zsh > "${COMPLETION_DIR}/_helm" 2> /dev/null || return 1
        fi
        [[ -f "${COMPLETION_DIR}/_helm" ]]
      else
        return 1
      fi
      ;;
    terraform)
      command -v terraform > /dev/null 2>&1
      ;;
    packer)
      command -v packer > /dev/null 2>&1
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
  if ! verify_antidote; then
    log_error "Antidote verification failed"
    log_warning "Skipping completions and plugins checks due to missing Antidote"
    return 1
  fi

  return 0
}

# Function to verify software tools
verify_software_tools() {
  log_info "Verifying software tools"
  local failed_tools=()

  # Core tools
  log_info "Core Tools"
  for tool in brew git rbenv pyenv direnv starship; do
    if check_command "$tool"; then
      version=$("$tool" --version 2> /dev/null | head -1 || echo "")
      print_status PASS "$tool" "$version"
    else
      print_status FAIL "$tool"
      failed_tools+=("$tool")
    fi
  done

  # Container tools
  log_info "Container Tools"
  for tool in docker orb orbctl kubectl helm; do
    if check_command "$tool"; then
      version=$("$tool" version 2> /dev/null | head -1 || echo "")
      print_status PASS "$tool" "$version"
    else
      print_status FAIL "$tool"
      failed_tools+=("$tool")
    fi
  done

  # Infrastructure tools
  log_info "Infrastructure Tools"
  for tool in terraform packer; do
    if check_command "$tool"; then
      version=$("$tool" --version 2> /dev/null | head -1 || echo "")
      print_status PASS "$tool" "$version"
    else
      print_status FAIL "$tool"
      failed_tools+=("$tool")
    fi
  done

  if [[ ${#failed_tools[@]} -gt 0 ]]; then
    log_error "Failed tools: ${failed_tools[*]}"
    return 1
  fi

  log_success "Software tools verified"
  return 0
}

# Function to verify shell completions
verify_shell_completions() {
  log_info "Verifying shell completions"
  local failed_completions=()

  # Create completions directory if it doesn't exist
  mkdir -p "${HOME}/.zsh/completions"

  # Core completions
  log_info "Core Completions"
  for tool in git rbenv pyenv direnv; do
    if check_completion "$tool"; then
      print_status PASS "$tool completion"
    else
      print_status FAIL "$tool completion"
      failed_completions+=("$tool")
    fi
  done

  # Container completions
  log_info "Container Completions"
  for tool in docker orb orbctl kubectl helm; do
    if check_completion "$tool"; then
      print_status PASS "$tool completion"
    else
      print_status FAIL "$tool completion"
      failed_completions+=("$tool")
    fi
  done

  # Infrastructure completions
  log_info "Infrastructure Completions"
  for tool in terraform packer; do
    if check_completion "$tool"; then
      print_status PASS "$tool completion"
    else
      print_status FAIL "$tool completion"
      failed_completions+=("$tool")
    fi
  done

  if [[ ${#failed_completions[@]} -gt 0 ]]; then
    log_error "Failed completions: ${failed_completions[*]}"
    return 1
  fi

  log_success "Shell completions verified"
  return 0
}

# Function to verify zsh plugins
verify_zsh_plugins() {
  log_info "Verifying zsh plugins"
  local failed_plugins=()

  # Check if plugins file exists
  if [[ ! -f "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" ]]; then
    log_error "Zsh plugins file not found"
    return 1
  fi

  # Verify core plugins
  log_info "Core Plugins"
  for plugin in zsh-completions zsh-autosuggestions zsh-syntax-highlighting; do
    if [[ -d "${ZDOTDIR:-$HOME}/.antidote/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-${plugin}" ]]; then
      print_status PASS "$plugin"
    else
      print_status FAIL "$plugin"
      failed_plugins+=("$plugin")
    fi
  done

  # Verify Oh My Zsh plugins
  log_info "Oh My Zsh Plugins"
  for plugin in git kubectl helm terraform docker docker-compose common-aliases brew fzf; do
    if [[ -d "${ZDOTDIR:-$HOME}/.antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/${plugin}" ]]; then
      print_status PASS "$plugin"
    else
      print_status FAIL "$plugin"
      failed_plugins+=("$plugin")
    fi
  done

  if [[ ${#failed_plugins[@]} -gt 0 ]]; then
    log_error "Failed plugins: ${failed_plugins[*]}"
    return 1
  fi

  log_success "Zsh plugins verified"
  return 0
}

# Function to print verification summary
print_verification_summary() {
  local total_checks=$1
  local passed_checks=$2
  local failed_checks=$3
  local percentage=$((passed_checks * 100 / total_checks))

  log_info "=== Verification Summary ==="
  log_info "Total checks: $total_checks"
  log_success "Passed: $passed_checks"
  log_error "Failed: $failed_checks"
  log_info "Success rate: $percentage%"

  if [[ $failed_checks -gt 0 ]]; then
    log_error "Verification failed - see above for details"
    return 1
  else
    log_success "All checks passed"
    return 0
  fi
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
  local verification_failed=false
  local total_checks=0
  local passed_checks=0
  local failed_checks=0

  # Verify shell configuration first
  if ! verify_shell_config; then
    log_error "Shell configuration verification failed"
    verification_failed=true
    ((failed_checks++))
  else
    ((passed_checks++))
  fi
  ((total_checks++))

  # Verify software tools
  if ! verify_software_tools; then
    log_error "Software tools verification failed"
    verification_failed=true
    ((failed_checks++))
  else
    ((passed_checks++))
  fi
  ((total_checks++))

  # Verify shell completions
  if ! verify_shell_completions; then
    log_error "Shell completions verification failed"
    verification_failed=true
    ((failed_checks++))
  else
    ((passed_checks++))
  fi
  ((total_checks++))

  # Verify zsh plugins
  if ! verify_zsh_plugins; then
    log_error "Zsh plugins verification failed"
    verification_failed=true
    ((failed_checks++))
  else
    ((passed_checks++))
  fi
  ((total_checks++))

  # Verify OrbStack setup
  if ! verify_orbstack; then
    log_error "OrbStack verification failed"
    verification_failed=true
    ((failed_checks++))
  else
    ((passed_checks++))
  fi
  ((total_checks++))

  if [[ "$QUIET_MODE" == "true" ]]; then
    exec 1>&3 # Restore stdout
    grep -E '^(::(info|success|error|warning)|Running verification script\.\.\.)' "$temp_log" >&3
    rm -f "$temp_log"
  fi

  # Print verification summary
  print_verification_summary "$total_checks" "$passed_checks" "$failed_checks"

  # Ensure we exit with the correct status
  if [[ "$verification_failed" == "true" ]]; then
    exit 1
  fi
  exit 0
}

# Run main function
main "$@"
