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
  log_info() { echo "::info::$1"; }
  log_success() { echo "::success::$1"; }
  log_warning() { echo "::warning::$1"; }
  log_error() { echo "::error::$1"; }
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
      "PASS") echo "::success::✓ $description${version:+ ($version)}" ;;
      "FAIL") echo "::error::✗ $description" ;;
      *) echo "::info::$result $description${version:+ ($version)}" ;;
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
      command -v docker > /dev/null 2>&1 && docker help completion > /dev/null 2>&1
      ;;
    orb)
      # Skip orb completion check in CI as it's not critical
      [[ "$QUIET_MODE" == "true" ]] && return 0
      command -v orb > /dev/null 2>&1 && orb completion zsh > /dev/null 2>&1
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
  log_info "Starting verification v${SCRIPT_VERSION}"

  local success_count=0
  local total_checks=0
  local failed_items=()

  # Verify shell configuration first
  verify_shell_config || {
    log_error "Shell configuration verification failed"
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
  for tool in docker kubectl helm; do
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
  for tool in docker kubectl helm terraform; do
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
    return 1
  fi

  log_success "All checks passed"
  return 0
}

# Run main function
main "$@"
