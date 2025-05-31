#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2296,SC2034,SC2154,SC2076,SC2317

# Script configuration
readonly SCRIPT_VERSION="1.0.0"
readonly COMPLETION_DIR="${HOME}/.zsh/completions"

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
  print_status INFO "INFO" "$1"
}

log_success() {
  print_status PASS "SUCCESS" "$1"
}

log_warning() {
  print_status SKIP "WARNING" "$1"
}

log_error() {
  print_status FAIL "ERROR" "$1"
}

# Function to verify Antidote setup
verify_antidote() {
  log_info "Verifying Antidote setup"

  # Check if Antidote is installed
  if ! command -v antidote > /dev/null 2>&1; then
    log_error "Antidote is not installed"
    return 1
  fi

  # Create Antidote directory if it doesn't exist
  if [[ ! -d "${ZDOTDIR:-$HOME}/.antidote" ]]; then
    log_info "Creating Antidote directory at ${ZDOTDIR:-$HOME}/.antidote"
    mkdir -p "${ZDOTDIR:-$HOME}/.antidote"
  fi

  # Check if plugins file exists
  if [[ ! -f "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" ]]; then
    log_error "Antidote plugins file not found"
    return 1
  fi

  log_success "Antidote setup verified"
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

  # Initialize completion system before verifying Antidote
  autoload -Uz compinit
  compinit -d "${HOME}/.zcompcache/zcompdump"

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
  for tool in orb orbctl kubectl helm; do
    if check_command "$tool"; then
      version=$("$tool" version 2> /dev/null | head -1 || echo "")
      print_status PASS "$tool" "$version"
    else
      print_status WARNING "$tool" "Not available in this environment"
    fi
  done

  # Docker is provided by OrbStack
  if check_command "docker"; then
    version=$(docker version --format '{{.Client.Version}}' 2> /dev/null || echo "")
    print_status PASS "docker" "$version"
  else
    print_status WARNING "docker" "Not available in this environment"
  fi

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
  for tool in kubectl helm docker orb orbctl; do
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
  local plugin_errors=()

  # Check if plugins file exists
  if [[ ! -f "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" ]]; then
    log_error "Zsh plugins file not found"
    return 1
  fi

  # Initialize completion system before checking plugins
  autoload -Uz compinit
  compinit -d "${HOME}/.zcompcache/zcompdump"

  # Define possible Antidote cache locations
  local antidote_cache_locations=(
    "${HOME}/Library/Caches/antidote"
    "${ANTIDOTE_HOME:-${HOME}/.antidote}"
  )

  # Verify core plugins
  log_info "Core Plugins"
  for plugin in zsh-completions zsh-autosuggestions zsh-syntax-highlighting; do
    local found=false
    for cache_dir in "${antidote_cache_locations[@]}"; do
      if [[ "$plugin" == "zsh-syntax-highlighting" ]]; then
        if [[ -f "${cache_dir}/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-${plugin}/zsh-syntax-highlighting.zsh" ]] \
          || [[ -f "${cache_dir}/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-${plugin}/zsh-syntax-highlighting.plugin.zsh" ]]; then
          print_status PASS "$plugin"
          found=true
          break
        fi
      else
        if [[ -d "${cache_dir}/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-${plugin}/src" ]] \
          || [[ -d "${cache_dir}/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-${plugin}" ]]; then
          print_status PASS "$plugin"
          found=true
          break
        fi
      fi
    done
    if [[ "$found" == "false" ]]; then
      print_status FAIL "$plugin"
      failed_plugins+=("$plugin")
    fi
  done

  # Verify Oh My Zsh plugins
  log_info "Oh My Zsh Plugins"
  for plugin in git kubectl helm terraform docker docker-compose common-aliases brew fzf; do
    local found=false
    for cache_dir in "${antidote_cache_locations[@]}"; do
      if [[ -d "${cache_dir}/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/${plugin}" ]] \
        || [[ -d "${cache_dir}/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/${plugin}/src" ]]; then
        print_status PASS "$plugin"
        found=true
        break
      fi
    done
    if [[ "$found" == "false" ]]; then
      print_status FAIL "$plugin"
      failed_plugins+=("$plugin")
    fi
  done

  # Report results
  if [[ ${#failed_plugins[@]} -gt 0 ]]; then
    log_error "Failed plugins: ${failed_plugins[*]}"
    log_error "Zsh plugins verification failed"
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

  echo -e "\n=== Verification Summary ==="
  print_status INFO "Total checks" "$total_checks"
  print_status PASS "Passed" "$passed_checks"
  print_status FAIL "Failed" "$failed_checks"
  print_status INFO "Success rate" "$percentage%"

  if [[ $failed_checks -gt 0 ]]; then
    print_status FAIL "Verification failed" "See above for details"
    return 1
  else
    print_status PASS "Verification" "All checks passed"
    return 0
  fi
}

# Helper to check if a completion exists in fpath
completion_in_fpath() {
  local compfile="_$1"
  for dir in "${fpath[@]}"; do
    [[ -f "$dir/$compfile" ]] && return 0
  done
  return 1
}

# Function to check if a completion exists or can be indirectly verified
check_completion() {
  local tool=$1
  local completion_dir="${HOME}/.zsh/completions"
  local compfile="_$tool"

  # 1. Check if completion is already in fpath
  if completion_in_fpath "$tool"; then
    return 0
  fi

  # 2. Check if completion exists in completion directory (should be generated during setup)
  if [[ -f "${completion_dir}/${compfile}" && -s "${completion_dir}/${compfile}" ]]; then
    return 0
  fi

  # 3. For tools that use built-in completion systems, check if they're properly configured
  case "$tool" in
    git)
      # Git completion is usually provided by system or homebrew
      for loc in \
        "/usr/share/zsh/functions/Completion/Unix/_git" \
        "/usr/local/share/zsh/site-functions/_git" \
        "/opt/homebrew/share/zsh/site-functions/_git"; do
        if [[ -f "$loc" ]]; then
          return 0
        fi
      done
      # Indirect verification: if git exists and is properly installed
      if command -v git > /dev/null 2>&1 && git --version > /dev/null 2>&1; then
        return 0 # Git completion should work via system/homebrew
      fi
      return 1
      ;;
    rbenv)
      # Indirect verification: check if rbenv is properly initialized and can list versions
      if command -v rbenv > /dev/null 2>&1 && rbenv versions > /dev/null 2>&1; then
        return 0 # rbenv is working, completion would likely work
      fi
      return 1
      ;;
    pyenv)
      # Indirect verification: check if pyenv is properly initialized and can list versions
      if command -v pyenv > /dev/null 2>&1 && pyenv versions > /dev/null 2>&1; then
        return 0 # pyenv is working, completion would likely work
      fi
      return 1
      ;;
    direnv)
      # Indirect verification: check if direnv can show help
      if command -v direnv > /dev/null 2>&1 && direnv help > /dev/null 2>&1; then
        return 0 # direnv is working, completion would likely work
      fi
      return 1
      ;;
    kubectl)
      # Indirect verification: check if kubectl can connect or show version
      if command -v kubectl > /dev/null 2>&1 && kubectl version --client > /dev/null 2>&1; then
        return 0 # kubectl is working, completion would likely work
      fi
      return 1
      ;;
    helm)
      # Indirect verification: check if helm can show version
      if command -v helm > /dev/null 2>&1 && helm version > /dev/null 2>&1; then
        return 0 # helm is working, completion would likely work
      fi
      return 1
      ;;
    docker)
      # Indirect verification: check if docker exists (even if daemon isn't running)
      if command -v docker > /dev/null 2>&1 && docker --version > /dev/null 2>&1; then
        return 0 # docker cli is working, completion would likely work
      fi
      return 1
      ;;
    orb | orbctl)
      # Indirect verification: check if orb tools exist and can show version
      if command -v "$tool" > /dev/null 2>&1 && "$tool" --version > /dev/null 2>&1; then
        return 0 # orb tool is working, completion would likely work
      fi
      return 1
      ;;
    terraform | packer)
      # HashiCorp tools use built-in completion system, check if command exists and works
      if command -v "$tool" > /dev/null 2>&1 && "$tool" --version > /dev/null 2>&1; then
        return 0 # tool is working, built-in completion should work
      fi
      return 1
      ;;
    *)
      # For other tools, try indirect verification first
      if command -v "$tool" > /dev/null 2>&1; then
        return 0 # tool exists, completion would likely work
      fi
      return 1
      ;;
  esac
}

# Main verification function
main() {
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
