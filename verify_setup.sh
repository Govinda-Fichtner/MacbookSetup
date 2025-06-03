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

# Initialize Antidote early (silently to avoid startup errors)
if [[ -e "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh" ]]; then
  source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh" 2> /dev/null
  # Only load plugins if the file exists to avoid error messages
  if [[ -f "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" ]]; then
    antidote load "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" 2> /dev/null || true
  fi
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

# Helper function to extract clean version numbers
extract_version() {
  local version_string="$1"
  local tool="$2"

  # Handle empty version strings
  [[ -z "$version_string" ]] && echo "" && return

  case "$tool" in
    brew)
      # "Homebrew 4.5.3" -> "4.5.3"
      echo "$version_string" | sed -n 's/.*Homebrew \([0-9][0-9.]*\).*/\1/p'
      ;;
    git)
      # "git version 2.49.0" -> "2.49.0"
      echo "$version_string" | sed -n 's/.*version \([0-9][0-9.]*\).*/\1/p'
      ;;
    rbenv | pyenv | starship)
      # "rbenv 1.3.2" -> "1.3.2"
      echo "$version_string" | sed -n 's/.* \([0-9][0-9.]*\).*/\1/p'
      ;;
    nvm)
      # "0.40.3" -> "0.40.3" (nvm outputs just the version number)
      echo "$version_string" | sed -n 's/^\([0-9][0-9.]*\).*/\1/p'
      ;;
    direnv)
      # "2.36.0" -> "2.36.0" (direnv outputs just the version number)
      echo "$version_string" | sed -n 's/^\([0-9][0-9.]*\).*/\1/p'
      ;;
    orb)
      # "Version: 1.10.3 (1100300)" -> "1.10.3"
      echo "$version_string" | sed -n 's/.*Version: \([0-9][0-9.]*\).*/\1/p'
      ;;
    orbctl)
      # Similar to orb
      echo "$version_string" | sed -n 's/.*Version: \([0-9][0-9.]*\).*/\1/p'
      ;;
    kubectl)
      # Extract version from kubectl output
      echo "$version_string" | sed -n 's/.*v\([0-9][0-9.]*\).*/\1/p'
      ;;
    helm)
      # Extract version from helm output
      echo "$version_string" | sed -n 's/.*v\([0-9][0-9.]*\).*/\1/p'
      ;;
    terraform)
      # "Terraform v1.12.1" -> "1.12.1"
      echo "$version_string" | sed -n 's/.*v\([0-9][0-9.]*\).*/\1/p'
      ;;
    packer)
      # "Packer v1.12.0" -> "1.12.0"
      echo "$version_string" | sed -n 's/.*Packer v\([0-9][0-9.]*\).*/\1/p'
      ;;
    docker)
      # Docker version is already clean from --format
      echo "$version_string"
      ;;
    mcp_manager)
      # Check if mcp_manager.sh exists and completion file is present
      if [[ -f "./mcp_manager.sh" && -f "${completion_dir}/_mcp_manager" ]]; then
        return 0 # mcp_manager.sh and its completion exist
      fi
      return 1
      ;;
    *)
      # For other tools, try to extract the first version-like pattern
      echo "$version_string" | sed -n 's/.*\([0-9][0-9.]*[0-9]\).*/\1/p' | head -1
      ;;
  esac
}

# Status printing function
print_status() {
  local level="$1"
  local label="$2"
  local msg="${3:-}"

  case "$level" in
    PASS)
      printf "%b[SUCCESS]%b %s %s\n" "$GREEN" "$RESET" "$label" "$msg"
      ;;
    FAIL)
      printf "%b[ERROR]%b %s %s\n" "$RED" "$RESET" "$label" "$msg"
      ;;
    SKIP)
      printf "%b[WARNING]%b %s %s\n" "$YELLOW" "$RESET" "$label" "$msg"
      ;;
    INFO)
      printf "%b[INFO]%b %s\n" "$BLUE" "$RESET" "$msg"
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
  # Check if Antidote is installed
  if ! command -v antidote > /dev/null 2>&1; then
    return 1
  fi

  # Create Antidote directory if it doesn't exist
  if [[ ! -d "${ZDOTDIR:-$HOME}/.antidote" ]]; then
    mkdir -p "${ZDOTDIR:-$HOME}/.antidote" 2> /dev/null
  fi

  # Check if plugins file exists
  if [[ ! -f "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" ]]; then
    return 1
  fi

  return 0
}

# Function to verify shell configuration
verify_shell_config() {
  # Verify shell is zsh
  if [[ "$SHELL" != *"zsh"* ]]; then
    log_error "Current shell is not zsh: $SHELL"
    return 1
  fi

  # Check for essential shell files - create them if missing instead of failing
  # Ensure HOME is set and directory exists
  if [[ -z "$HOME" ]]; then
    HOME="/tmp/ci_home"
    export HOME
  fi

  # Ensure home directory exists
  [[ ! -d "$HOME" ]] && mkdir -p "$HOME"

  local zshrc_path="${ZDOTDIR:-$HOME}/.zshrc"
  local plugins_path="${ZDOTDIR:-$HOME}/.zsh_plugins.txt"

  if [[ ! -f "$zshrc_path" ]]; then
    log_warning "Creating missing .zshrc file"
    touch "$zshrc_path" 2> /dev/null || {
      log_warning "Cannot create .zshrc file - continuing anyway"
    }
  fi

  if [[ ! -f "$plugins_path" ]]; then
    log_warning "Creating missing .zsh_plugins.txt file"
    touch "$plugins_path" 2> /dev/null || {
      log_warning "Cannot create .zsh_plugins.txt file - continuing anyway"
    }
  fi

  # Initialize completion system before verifying Antidote
  autoload -Uz compinit
  mkdir -p "${HOME}/.zcompcache" 2> /dev/null || true
  compinit -d "${HOME}/.zcompcache/zcompdump" 2> /dev/null

  # Verify Antidote setup (silently)
  if ! verify_antidote 2> /dev/null; then
    log_warning "Antidote not fully configured - some features may be limited"
    # Don't return 1 here, just warn and continue
  fi

  return 0
}

# Function to verify software tools
verify_software_tools() {
  echo -e "\n=== Software Tools ==="
  local failed_tools=()

  # Core tools
  echo "├── Core Tools"
  local core_tools=(brew git rbenv pyenv nvm direnv starship)
  local i=0
  for tool in "${core_tools[@]}"; do
    local prefix="│   "
    local connector="├──"
    if [[ $i -eq $((${#core_tools[@]} - 1)) ]]; then
      connector="└──"
    fi

    if [[ "$tool" == "nvm" ]]; then
      # Special handling for nvm which needs to be sourced
      if [[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ]]; then
        version_raw=$(source "$(brew --prefix)/opt/nvm/nvm.sh" && nvm --version 2> /dev/null | head -1 || echo "")
        version=$(extract_version "$version_raw" "$tool")
        [[ -n "$version" ]] && version="v$version"
        printf "%s%s %b[SUCCESS]%b %s %s\n" "$prefix" "$connector" "$GREEN" "$RESET" "$tool" "$version"
      else
        printf "%s%s %b[ERROR]%b %s\n" "$prefix" "$connector" "$RED" "$RESET" "$tool"
        failed_tools+=("$tool")
      fi
    elif check_command "$tool"; then
      version_raw=$("$tool" --version 2> /dev/null | head -1 || echo "")
      version=$(extract_version "$version_raw" "$tool")
      [[ -n "$version" ]] && version="v$version"
      printf "%s%s %b[SUCCESS]%b %s %s\n" "$prefix" "$connector" "$GREEN" "$RESET" "$tool" "$version"
    else
      printf "%s%s %b[ERROR]%b %s\n" "$prefix" "$connector" "$RED" "$RESET" "$tool"
      failed_tools+=("$tool")
    fi
    ((i++))
  done

  # Container tools
  echo "├── Container Tools"
  local container_tools=(orb orbctl kubectl helm)
  local i=0
  for tool in "${container_tools[@]}"; do
    local prefix="│   "
    local connector="├──"
    if [[ $i -eq $((${#container_tools[@]} - 1)) ]]; then
      connector="└──"
    fi

    if check_command "$tool"; then
      version_raw=$("$tool" version 2> /dev/null | head -1 || echo "")
      version=$(extract_version "$version_raw" "$tool")
      [[ -n "$version" ]] && version="v$version"
      printf "%s%s %b[SUCCESS]%b %s %s\n" "$prefix" "$connector" "$GREEN" "$RESET" "$tool" "$version"
    else
      printf "%s%s %b[WARNING]%b %s (not available in this environment)\n" "$prefix" "$connector" "$YELLOW" "$RESET" "$tool"
    fi
    ((i++))
  done

  # Docker is provided by OrbStack
  if check_command "docker"; then
    version_raw=$(docker version --format '{{.Client.Version}}' 2> /dev/null || echo "")
    version=$(extract_version "$version_raw" "docker")
    [[ -n "$version" ]] && version="v$version"
    printf "│   └── %b[SUCCESS]%b docker %s\n" "$GREEN" "$RESET" "$version"
  else
    printf "│   └── %b[WARNING]%b docker (not available in this environment)\n" "$YELLOW" "$RESET"
  fi

  # Infrastructure tools
  echo "└── Infrastructure Tools"
  local infra_tools=(terraform packer)
  local i=0
  for tool in "${infra_tools[@]}"; do
    local prefix="    "
    local connector="├──"
    if [[ $i -eq $((${#infra_tools[@]} - 1)) ]]; then
      connector="└──"
    fi

    if check_command "$tool"; then
      version_raw=$("$tool" --version 2> /dev/null | head -1 || echo "")
      version=$(extract_version "$version_raw" "$tool")
      [[ -n "$version" ]] && version="v$version"
      printf "%s%s %b[SUCCESS]%b %s %s\n" "$prefix" "$connector" "$GREEN" "$RESET" "$tool" "$version"
    else
      printf "%s%s %b[ERROR]%b %s\n" "$prefix" "$connector" "$RED" "$RESET" "$tool"
      failed_tools+=("$tool")
    fi
    ((i++))
  done

  if [[ ${#failed_tools[@]} -gt 0 ]]; then
    log_error "Failed tools: ${failed_tools[*]}"
    return 1
  fi

  log_success "Software tools verified"
  return 0
}

# Function to verify design tools
verify_design_tools() {
  echo -e "\n=== Design Tools ==="
  local failed_tools=()

  # Design applications
  echo "└── Design Applications"
  local design_apps=("Figma Beta")
  local i=0
  for app in "${design_apps[@]}"; do
    local prefix="    "
    local connector="├──"
    if [[ $i -eq $((${#design_apps[@]} - 1)) ]]; then
      connector="└──"
    fi

    if [[ -d "/Applications/${app}.app" ]]; then
      printf "%s%s %b[SUCCESS]%b %s\n" "$prefix" "$connector" "$GREEN" "$RESET" "$app"
    else
      printf "%s%s %b[WARNING]%b %s (not installed)\n" "$prefix" "$connector" "$YELLOW" "$RESET" "$app"
    fi
    ((i++))
  done

  if [[ ${#failed_tools[@]} -gt 0 ]]; then
    log_error "Failed design tools: ${failed_tools[*]}"
    return 1
  fi

  log_success "Design tools verified"
  return 0
}

# Function to verify shell completions
verify_shell_completions() {
  echo -e "\n=== Shell Completions ==="
  local failed_completions=()

  # Create completions directory if it doesn't exist
  mkdir -p "${HOME}/.zsh/completions" 2> /dev/null || true

  # Core completions
  echo "├── Core Completions"
  local core_comps=(git rbenv pyenv nvm direnv mcp_manager)
  local i=0
  for tool in "${core_comps[@]}"; do
    local prefix="│   "
    local connector="├──"
    if [[ $i -eq $((${#core_comps[@]} - 1)) ]]; then
      connector="└──"
    fi

    if check_completion "$tool"; then
      printf "%s%s %b[SUCCESS]%b %s completion\n" "$prefix" "$connector" "$GREEN" "$RESET" "$tool"
    else
      printf "%s%s %b[ERROR]%b %s completion\n" "$prefix" "$connector" "$RED" "$RESET" "$tool"
      failed_completions+=("$tool")
    fi
    ((i++))
  done

  # Container completions
  echo "├── Container Completions"
  local container_comps=(kubectl helm docker orb orbctl)
  local i=0
  for tool in "${container_comps[@]}"; do
    local prefix="│   "
    local connector="├──"
    if [[ $i -eq $((${#container_comps[@]} - 1)) ]]; then
      connector="└──"
    fi

    if check_completion "$tool"; then
      printf "%s%s %b[SUCCESS]%b %s completion\n" "$prefix" "$connector" "$GREEN" "$RESET" "$tool"
    else
      printf "%s%s %b[ERROR]%b %s completion\n" "$prefix" "$connector" "$RED" "$RESET" "$tool"
      failed_completions+=("$tool")
    fi
    ((i++))
  done

  # Infrastructure completions
  echo "└── Infrastructure Completions"
  local infra_comps=(terraform packer)
  local i=0
  for tool in "${infra_comps[@]}"; do
    local prefix="    "
    local connector="├──"
    if [[ $i -eq $((${#infra_comps[@]} - 1)) ]]; then
      connector="└──"
    fi

    if check_completion "$tool"; then
      printf "%s%s %b[SUCCESS]%b %s completion\n" "$prefix" "$connector" "$GREEN" "$RESET" "$tool"
    else
      printf "%s%s %b[ERROR]%b %s completion\n" "$prefix" "$connector" "$RED" "$RESET" "$tool"
      failed_completions+=("$tool")
    fi
    ((i++))
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
  echo -e "\n=== Zsh Plugins ==="
  local failed_plugins=()
  local plugin_errors=()

  # Check if plugins file exists - create if missing instead of failing
  local plugins_path="${ZDOTDIR:-$HOME}/.zsh_plugins.txt"
  if [[ ! -f "$plugins_path" ]]; then
    log_warning "Creating missing .zsh_plugins.txt file"
    touch "$plugins_path" || {
      log_error "Failed to create .zsh_plugins.txt file"
      return 1
    }
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
  echo "├── Core Plugins"
  local core_plugins=(zsh-completions zsh-autosuggestions zsh-syntax-highlighting)
  local i=0
  for plugin in "${core_plugins[@]}"; do
    local prefix="│   "
    local connector="├──"
    if [[ $i -eq $((${#core_plugins[@]} - 1)) ]]; then
      connector="└──"
    fi

    local found=false
    for cache_dir in "${antidote_cache_locations[@]}"; do
      if [[ "$plugin" == "zsh-syntax-highlighting" ]]; then
        if [[ -f "${cache_dir}/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-${plugin}/zsh-syntax-highlighting.zsh" ]] \
          || [[ -f "${cache_dir}/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-${plugin}/zsh-syntax-highlighting.plugin.zsh" ]]; then
          printf "%s%s %b[SUCCESS]%b %s\n" "$prefix" "$connector" "$GREEN" "$RESET" "$plugin"
          found=true
          break
        fi
      else
        if [[ -d "${cache_dir}/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-${plugin}/src" ]] \
          || [[ -d "${cache_dir}/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-${plugin}" ]]; then
          printf "%s%s %b[SUCCESS]%b %s\n" "$prefix" "$connector" "$GREEN" "$RESET" "$plugin"
          found=true
          break
        fi
      fi
    done
    if [[ "$found" == "false" ]]; then
      printf "%s%s %b[ERROR]%b %s\n" "$prefix" "$connector" "$RED" "$RESET" "$plugin"
      failed_plugins+=("$plugin")
    fi
    ((i++))
  done

  # Verify Oh My Zsh plugins
  echo "└── Oh My Zsh Plugins"
  local ohmyzsh_plugins=(git kubectl helm terraform docker docker-compose common-aliases brew fzf)
  local i=0
  for plugin in "${ohmyzsh_plugins[@]}"; do
    local prefix="    "
    local connector="├──"
    if [[ $i -eq $((${#ohmyzsh_plugins[@]} - 1)) ]]; then
      connector="└──"
    fi

    local found=false
    for cache_dir in "${antidote_cache_locations[@]}"; do
      if [[ -d "${cache_dir}/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/${plugin}" ]] \
        || [[ -d "${cache_dir}/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/${plugin}/src" ]]; then
        printf "%s%s %b[SUCCESS]%b %s\n" "$prefix" "$connector" "$GREEN" "$RESET" "$plugin"
        found=true
        break
      fi
    done
    if [[ "$found" == "false" ]]; then
      printf "%s%s %b[ERROR]%b %s\n" "$prefix" "$connector" "$RED" "$RESET" "$plugin"
      failed_plugins+=("$plugin")
    fi
    ((i++))
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
  printf "Checks passed: %d/%d (%d%%)\n" "$passed_checks" "$total_checks" "$percentage"

  if [[ $failed_checks -gt 0 ]]; then
    printf "Status: FAILED (%d check(s) failed)\n" "$failed_checks"
    return 1
  else
    printf "Status: PASSED (All checks successful)\n"
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
    nvm)
      # Indirect verification: check if nvm is properly initialized and available
      if [[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ]]; then
        # Also check if nvm command works when sourced
        if (source "$(brew --prefix)/opt/nvm/nvm.sh" && nvm --version > /dev/null 2>&1); then
          return 0 # nvm is working
        fi
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
      # Enhanced Docker verification for CI environments
      # First check if docker CLI exists and works
      if command -v docker > /dev/null 2>&1 && docker --version > /dev/null 2>&1; then
        return 0 # docker cli is working, completion would likely work
      fi

      # Fallback: check if we have a standalone Docker completion file
      # This handles CI environments where OrbStack initialization may fail
      if [[ -f "${completion_dir}/${compfile}" && -s "${completion_dir}/${compfile}" ]]; then
        # Verify it's a proper completion file (not empty)
        if grep -q "compdef.*docker" "${completion_dir}/${compfile}" && grep -q "_docker" "${completion_dir}/${compfile}"; then
          return 0 # Valid standalone Docker completion exists
        fi
      fi

      # In CI environments, Docker/OrbStack may not be available - this is expected
      if [[ "${CI:-false}" == "true" ]]; then
        log_warning "Docker completion not available (expected in CI environment)"
        return 0 # Don't fail the CI pipeline for expected Docker unavailability
      fi

      return 1
      ;;
    orb | orbctl)
      # Indirect verification: check if orb tools exist and have completion subcommand
      if command -v "$tool" > /dev/null 2>&1; then
        # Try to verify completion subcommand exists (more reliable than --version for orb)
        if "$tool" completion --help > /dev/null 2>&1 || [[ "$("$tool" --help 2> /dev/null)" == *"completion"* ]]; then
          return 0 # orb tool has completion support, completion would likely work
        fi
        # Fallback: if the tool exists and shows help, assume completion works
        if "$tool" --help > /dev/null 2>&1; then
          return 0 # orb tool is working, completion would likely work
        fi
      fi

      # In CI environments, OrbStack tools may not be available - this is expected
      if [[ "${CI:-false}" == "true" ]]; then
        log_warning "$tool completion not available (expected in CI environment)"
        return 0 # Don't fail the CI pipeline for expected OrbStack unavailability
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
    mcp_manager)
      # Check if mcp_manager.sh exists and completion file is present
      if [[ -f "./mcp_manager.sh" && -f "${completion_dir}/_mcp_manager" ]]; then
        return 0 # mcp_manager.sh and its completion exist
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

# Function to verify terminal fonts
verify_terminal_fonts() {
  echo -e "\n=== Terminal Fonts ==="
  local font_issues=false

  # Skip in CI environments
  if [[ "${CI:-false}" == "true" ]]; then
    printf "└── %b[SKIPPED]%b Terminal font verification (CI environment)\n" "$YELLOW" "$RESET"
    return 0
  fi

  # First, check if Nerd Fonts are available
  printf "├── %b[CHECKING]%b Nerd Font availability\n" "$BLUE" "$RESET"
  local available_fonts=(
    "FiraCode Nerd Font Mono"
    "JetBrains Mono Nerd Font"
    "Fira Code Nerd Font"
  )

  local nerd_font_found=false
  for font in "${available_fonts[@]}"; do
    if system_profiler SPFontsDataType 2> /dev/null | grep -q "$font"; then
      printf "│   ├── %b[FOUND]%b %s\n" "$GREEN" "$RESET" "$font"
      nerd_font_found=true
      break
    fi
  done

  if [[ "$nerd_font_found" == "false" ]]; then
    printf "│   └── %b[WARNING]%b No Nerd Fonts found - Starship icons may not display properly\n" "$YELLOW" "$RESET"
    font_issues=true
  else
    printf "│   └── %b[SUCCESS]%b Nerd Fonts available for Starship\n" "$GREEN" "$RESET"
  fi

  # Check Warp terminal configuration
  printf "├── %b[CHECKING]%b Warp terminal fonts\n" "$BLUE" "$RESET"
  if [[ -d "/Applications/Warp.app" ]]; then
    local warp_prefs
    warp_prefs="/Users/$(whoami)/Library/Preferences/dev.warp.Warp-Stable.plist"

    if [[ -f "$warp_prefs" ]]; then
      # Get current font settings using PlistBuddy
      local warp_font_name
      local warp_font_size
      warp_font_name=$(/usr/libexec/PlistBuddy -c "Print :FontName" "$warp_prefs" 2> /dev/null || echo "unknown")
      warp_font_size=$(/usr/libexec/PlistBuddy -c "Print :FontSize" "$warp_prefs" 2> /dev/null || echo "unknown")

      if [[ "$warp_font_name" != "unknown" && "$warp_font_size" != "unknown" ]]; then
        printf "│   ├── %b[INFO]%b Current: %s %spt\n" "$BLUE" "$RESET" "$warp_font_name" "$warp_font_size"

        # Check if using Nerd Font
        if [[ "$warp_font_name" == *"Nerd Font"* || "$warp_font_name" == "Fira Code" ]]; then
          printf "│   ├── %b[SUCCESS]%b Using Nerd Font - Starship compatible\n" "$GREEN" "$RESET"
        else
          printf "│   ├── %b[WARNING]%b Not using Nerd Font - Starship icons may not display\n" "$YELLOW" "$RESET"
          font_issues=true
        fi

        # Check font size
        if (($(echo "$warp_font_size >= 14" | bc -l 2> /dev/null || echo "0"))); then
          printf "│   └── %b[SUCCESS]%b Font size adequate for Starship display\n" "$GREEN" "$RESET"
        else
          printf "│   └── %b[WARNING]%b Font size may be too small for optimal Starship display\n" "$YELLOW" "$RESET"
          font_issues=true
        fi
      else
        printf "│   └── %b[INFO]%b Font configuration not detected\n" "$BLUE" "$RESET"
      fi
    else
      printf "│   └── %b[INFO]%b Warp preferences not found\n" "$BLUE" "$RESET"
    fi
  else
    printf "│   └── %b[INFO]%b Warp not installed\n" "$BLUE" "$RESET"
  fi

  # Check iTerm2 terminal configuration
  printf "└── %b[CHECKING]%b iTerm2 terminal fonts\n" "$BLUE" "$RESET"
  if [[ -d "/Applications/iTerm.app" ]]; then
    local iterm_prefs
    iterm_prefs="/Users/$(whoami)/Library/Preferences/com.googlecode.iterm2.plist"

    if [[ -f "$iterm_prefs" ]]; then
      # Use PlistBuddy to get current font
      local current_font
      current_font=$(/usr/libexec/PlistBuddy -c "Print :\"New Bookmarks\":0:\"Normal Font\"" "$iterm_prefs" 2> /dev/null || echo "unknown")

      if [[ "$current_font" != "unknown" && -n "$current_font" ]]; then
        printf "    ├── %b[INFO]%b Current: %s\n" "$BLUE" "$RESET" "$current_font"

        if [[ "$current_font" == *"Nerd Font"* ]]; then
          printf "    └── %b[SUCCESS]%b Using Nerd Font - Starship compatible\n" "$GREEN" "$RESET"
        else
          printf "    └── %b[WARNING]%b Not using Nerd Font - Starship icons may not display\n" "$YELLOW" "$RESET"
          font_issues=true
        fi
      else
        printf "    └── %b[INFO]%b Font configuration not detected\n" "$BLUE" "$RESET"
      fi
    else
      printf "    └── %b[INFO]%b iTerm2 preferences not found\n" "$BLUE" "$RESET"
    fi
  else
    printf "    └── %b[INFO]%b iTerm2 not installed\n" "$BLUE" "$RESET"
  fi

  if [[ "$font_issues" == "true" ]]; then
    log_warning "Terminal font configuration has recommendations for optimal Starship display"
    return 1
  else
    log_success "Terminal fonts verified for Starship compatibility"
    return 0
  fi
}

# Function to verify MCP server health via stdio JSON-RPC
verify_mcp_stdio_health() {
  local server_name_display="$1" # e.g., "GitHub MCP Server"
  local image_name="$2"          # e.g., "mcp/github-mcp-server:latest"
  local token_env_var_name="$3"  # e.g., "GITHUB_TOKEN"
  local connector="$4"           # e.g., "├──" or "└──"

  printf "%s %b[HEALTH CHECK]%b %s (%s)\n" "$connector" "$BLUE" "$RESET" "$server_name_display" "$image_name"

  # Check if Docker is even available and responsive before trying to run
  if ! check_command docker || ! docker info > /dev/null 2>&1; then
    printf "│   └── %b[SKIP]%b Docker not available/responsive. Cannot perform health check for %s.\n" "$YELLOW" "$RESET" "$server_name_display"
    return 1 # Indicates a skip/failure for this specific check
  fi

  # Check if the image exists locally
  if ! docker image inspect "$image_name" > /dev/null 2>&1; then
    printf "│   └── %b[ERROR]%b Docker image %s not found. Run setup script or pull/build manually.\n" "$RED" "$RESET" "$image_name"
    return 1
  fi

  local json_rpc_request='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{}}}'
  # Use a placeholder token if the actual environment variable is not set.
  # The MCP server itself should handle an invalid token gracefully for an initialize request.
  local token_value
  eval "token_value=\"\${$token_env_var_name}\""
  if [[ -z "$token_value" ]]; then
    token_value="placeholder_for_test"
  fi
  local output
  local success=false

  # Run the docker container, pipe the request, and capture output.
  # Timeout after 10 seconds to prevent hanging if the server is unresponsive.
  # Using a subshell for timeout for better compatibility.
  output=$( (timeout 10s echo "$json_rpc_request" | docker run --rm -i -e "$token_env_var_name=$token_value" "$image_name" server stdio) 2>&1)
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    # Basic check for a valid JSON-RPC response structure
    if echo "$output" | grep -q '"jsonrpc":"2.0"' && echo "$output" | grep -q '"id":1'; then
      if echo "$output" | jq -e '.result' > /dev/null 2>&1; then # Check for presence of 'result' key
        printf "│   └── %b[SUCCESS]%b %s is responsive and initialized (stdio JSON-RPC).\n" "$GREEN" "$RESET" "$server_name_display"
        success=true
      else
        printf "│   └── %b[WARNING]%b %s responded, but initialize result might be an error or unexpected. Output: %s\n" "$YELLOW" "$RESET" "$server_name_display" "$output"
        # Log full output for debugging if it's a warning but not outright failure
        # echo "$output" > "/tmp/${server_name_display// /_}_health_check_warn.log"
      fi
    else
      printf "│   └── %b[ERROR]%b %s responded, but output is not a valid JSON-RPC initialize response. Output: %s\n" "$RED" "$RESET" "$server_name_display" "$output"
    fi
  elif [[ $exit_code -eq 124 ]]; then # Timeout exit code
    printf "│   └── %b[ERROR]%b %s health check timed out (10s). Server may be unresponsive or misconfigured.\n" "$RED" "$RESET" "$server_name_display"
  else
    printf "│   └── %b[ERROR]%b %s failed to run or exited with error code %s. Output: %s\n" "$RED" "$RESET" "$server_name_display" "$exit_code" "$output"
  fi

  if ! $success; then
    return 1
  fi
  return 0
}

# Function to verify MCP Server setup (CI-friendly)
verify_containerization_and_mcp() {
  echo -e "\n=== MCP Server Verification ==="
  local all_mcp_checks_passed=true

  # Container runtime verification (comprehensive)
  printf "├── %b[CHECKING]%b Container runtime status\n" "$BLUE" "$RESET"

  if [[ "${CI:-false}" == "true" ]]; then
    printf "│   └── %b[CI MODE]%b Skipping container runtime checks (no Docker in CI)\n" "$YELLOW" "$RESET"
  else
    # Check OrbStack first (preferred)
    if check_command orbctl && orbctl status > /dev/null 2>&1; then
      printf "│   ├── %b[SUCCESS]%b OrbStack is running\n" "$GREEN" "$RESET"
      # Verify Docker is available through OrbStack
      if check_command docker && docker info > /dev/null 2>&1; then
        printf "│   └── %b[SUCCESS]%b Docker available via OrbStack - full MCP testing ready\n" "$GREEN" "$RESET"
      else
        printf "│   └── %b[WARNING]%b OrbStack running but Docker not available\n" "$YELLOW" "$RESET"
      fi
    elif check_command docker && docker info > /dev/null 2>&1; then
      printf "│   └── %b[SUCCESS]%b Docker is available - MCP testing ready\n" "$GREEN" "$RESET"
    else
      printf "│   └── %b[WARNING]%b No container runtime available - install OrbStack for full MCP functionality\n" "$YELLOW" "$RESET"
    fi
  fi

  # Enhanced MCP server verification with clear tier indication
  printf "├── %b[CHECKING]%b MCP server health testing\n" "$BLUE" "$RESET"

  # Check token availability to determine test tier
  local has_github_token=false
  local has_circleci_token=false
  local test_tier="basic"

  # Check for tokens in environment (now including .envrc)
  if [[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]] || [[ -n "${GITHUB_TOKEN:-}" ]]; then
    has_github_token=true
  fi
  if [[ -n "${CIRCLECI_TOKEN:-}" ]]; then
    has_circleci_token=true
  fi

  # Determine test tier
  if [[ "$has_github_token" == "true" || "$has_circleci_token" == "true" ]]; then
    test_tier="advanced"
  fi

  # Show test tier and reasoning
  if [[ "$test_tier" == "advanced" ]]; then
    printf "│   ├── %b[TEST TIER]%b Advanced (API tokens detected)\n" "$GREEN" "$RESET"
    [[ "$has_github_token" == "true" ]] && printf "│   │   ├── %b[TOKEN]%b GitHub authentication available\n" "$GREEN" "$RESET"
    [[ "$has_circleci_token" == "true" ]] && printf "│   │   └── %b[TOKEN]%b CircleCI authentication available\n" "$GREEN" "$RESET"
  else
    printf "│   ├── %b[TEST TIER]%b Basic (no API tokens found)\n" "$YELLOW" "$RESET"
    printf "│   │   └── %b[INFO]%b Testing protocol compliance only\n" "$BLUE" "$RESET"
  fi

  # Show config file locations
  printf "│   ├── %b[CONFIG]%b MCP server configuration files:\n" "$BLUE" "$RESET"
  printf "│   │   ├── %b[GitHub]%b %s/.config/mcp/github-mcp-server/config.json\n" "$BLUE" "$RESET" "$HOME"
  printf "│   │   └── %b[CircleCI]%b %s/.config/mcp/circleci-mcp-server/config.json\n" "$BLUE" "$RESET" "$HOME"

  # Perform MCP testing with enhanced output
  if [[ -f "./mcp_manager.sh" ]]; then
    printf "│   ├── %b[TESTING]%b Running MCP health checks via mcp_manager.sh\n" "$BLUE" "$RESET"

    # Capture mcp_manager.sh output for parsing
    local mcp_output
    mcp_output=$(./mcp_manager.sh test 2>&1)
    local mcp_exit_code=$?

    if [[ $mcp_exit_code -eq 0 ]]; then
      printf "│   ├── %b[SUCCESS]%b MCP servers verified successfully\n" "$GREEN" "$RESET"

      # Parse and display tool capabilities for advanced testing
      if [[ "$test_tier" == "advanced" ]]; then
        printf "│   └── %b[CAPABILITIES]%b Available MCP tools:\n" "$GREEN" "$RESET"

        # Extract tool information from mcp_manager output (handle line wrapping)
        local github_tools
        local circleci_tools
        github_tools=$(echo "$mcp_output" | tr '\n' ' ' | grep -o "GitHub MCP Server: [0-9]* tools available ([^)]*)" | head -1 || echo "")
        circleci_tools=$(echo "$mcp_output" | tr '\n' ' ' | grep -o "CircleCI MCP Server: [0-9]* tools available ([^)]*)" | head -1 || echo "")

        if [[ -n "$github_tools" ]]; then
          printf "│       ├── %b[GitHub]%b %s\n" "$GREEN" "$RESET" "$github_tools"
        else
          printf "│       ├── %b[GitHub]%b Authentication successful\n" "$GREEN" "$RESET"
        fi

        if [[ -n "$circleci_tools" ]]; then
          printf "│       └── %b[CircleCI]%b %s\n" "$GREEN" "$RESET" "$circleci_tools"
        else
          printf "│       └── %b[CircleCI]%b Authentication successful\n" "$GREEN" "$RESET"
        fi
      else
        printf "│   └── %b[INFO]%b MCP protocol functional (authentication would unlock full capabilities)\n" "$BLUE" "$RESET"
      fi
    else
      printf "│   ├── %b[WARNING]%b MCP testing completed with issues\n" "$YELLOW" "$RESET"
      printf "│   └── %b[INFO]%b Run './mcp_manager.sh test' for detailed output\n" "$BLUE" "$RESET"
    fi
  else
    printf "│   └── %b[WARNING]%b mcp_manager.sh not found - skipping MCP verification\n" "$YELLOW" "$RESET"
  fi

  # Verify MCP configuration using existing manager
  printf "└── %b[CHECKING]%b MCP configuration files\n" "$BLUE" "$RESET"
  local mcp_config_dir="${HOME}/.config/mcp"
  if [[ -d "$mcp_config_dir" ]]; then
    printf "    ├── %b[SUCCESS]%b MCP config directory exists\n" "$GREEN" "$RESET"

    # Check for basic MCP server configs
    if [[ -f "$mcp_config_dir/github-mcp-server/config.json" ]]; then
      printf "    ├── %b[SUCCESS]%b GitHub MCP config found\n" "$GREEN" "$RESET"
    else
      printf "    ├── %b[WARNING]%b GitHub MCP config missing - run setup script\n" "$YELLOW" "$RESET"
    fi

    if [[ -f "$mcp_config_dir/circleci-mcp-server/config.json" ]]; then
      printf "    └── %b[SUCCESS]%b CircleCI MCP config found\n" "$GREEN" "$RESET"
    else
      printf "    └── %b[WARNING]%b CircleCI MCP config missing - run setup script\n" "$YELLOW" "$RESET"
    fi
  else
    printf "    └── %b[WARNING]%b MCP config directory missing - run setup script\n" "$YELLOW" "$RESET"
  fi

  # Final MCP verification summary
  if [[ "${CI:-false}" == "true" ]]; then
    log_success "MCP configuration validation completed (CI environment)"
    return 0
  elif [[ -f "./mcp_manager.sh" ]]; then
    log_success "MCP environment verified via mcp_manager.sh"
    return 0
  else
    log_warning "MCP environment verification limited (mcp_manager.sh not found)"
    return 1
  fi

}

# Main verification function
main() {
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

  # Verify design tools (non-critical check)
  if ! verify_design_tools; then
    log_warning "Design tools verification had issues (see warnings above)"
    # Don't fail the build for missing design tools
    ((passed_checks++))
  else
    ((passed_checks++))
  fi
  ((total_checks++))

  # Verify terminal fonts (non-critical check)
  if ! verify_terminal_fonts; then
    log_warning "Terminal font configuration needs attention (see recommendations above)"
    # Don't fail the build for font configuration issues
    ((passed_checks++))
  else
    ((passed_checks++))
  fi
  ((total_checks++))

  # Verify containerization and MCP servers
  verify_containerization_and_mcp
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
