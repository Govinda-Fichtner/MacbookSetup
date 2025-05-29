#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2296,SC2034,SC2154,SC2076

# macOS Development Environment Verification Script
# This script verifies that all tools and configurations are properly installed

# Ensure we're running in zsh
if [ -n "$BASH_VERSION" ]; then
  exec /bin/zsh "$0" "$@"
fi

# Script configuration
readonly SCRIPT_VERSION="1.0.0"
readonly COMPLETION_DIR="${HOME}/.zsh/completions"

# Check if running in CI or quiet mode
QUIET_MODE="${CI:-false}"
if [[ "${MACBOOK_SETUP_QUIET:-}" == "true" ]]; then
  QUIET_MODE="true"
fi

# In CI mode, suppress all shell initialization output
if [[ "$QUIET_MODE" == "true" ]]; then
  # Redirect all shell initialization output to /dev/null
  exec 2> /dev/null
  # Disable shell features that produce output
  setopt NO_NOTIFY
  setopt NO_AUTO_CD
  setopt NO_BEEP
  # Disable plugin loading output
  ZSH_AUTOSUGGEST_USE_ASYNC=true
  ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# Color definitions (disabled in quiet mode)
if [[ "$QUIET_MODE" == "true" ]]; then
  readonly RED=''
  readonly GREEN=''
  readonly BLUE=''
  readonly YELLOW=''
  readonly NC=''
else
  readonly RED='\033[0;31m'
  readonly GREEN='\033[0;32m'
  readonly BLUE='\033[0;34m'
  readonly YELLOW='\033[0;33m'
  readonly NC='\033[0m' # No Color
fi

# Logging functions for CI environment
if [[ "$QUIET_MODE" == "true" ]]; then
  log_info() { echo "::info::$1" >&3; }
  log_success() { echo "::success::$1" >&3; }
  log_warning() { echo "::warning::$1" >&3; }
  log_error() { echo "::error::$1" >&3; }
  log_debug() { :; } # No-op in CI
else
  # Keep existing logging functions for local use
  log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$1" >&2; }
  log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1" >&2; }
  log_warning() { printf "${YELLOW}[WARNING]${NC} %s\n" "$1" >&2; }
  log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }
  log_debug() { printf "[DEBUG] %s\n" "$1" >&2; }
fi

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
