#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2296,SC2034,SC2154,SC1091

# macOS Development Environment Setup Script
#
# This script automates the installation and configuration of a development environment on macOS.
# It installs Homebrew, all tools specified in the Brewfile, and configures the shell environment.
#
# Usage: ./setup.sh

# Enable strict error handling
set -e

# Script configuration
readonly SCRIPT_VERSION="1.0.0"
readonly ZSHRC_PATH="${HOME}/.zshrc"
ZDOTDIR="${ZDOTDIR:-$HOME}"
readonly COMPLETION_DIR="${HOME}/.zsh/completions"
readonly ZCOMPCACHE_DIR="${HOME}/.zcompcache"
readonly ANTIDOTE_PLUGINS_FILE="${ZDOTDIR}/.zsh_plugins.txt"
# shellcheck disable=SC2155
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$1" >&2; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1" >&2; }
log_warning() { printf "${YELLOW}[WARNING]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }
log_debug() { printf "DEBUG: %s\n" "$1" >&2; }

# Helper function to extract clean version numbers (shared with verify_setup.sh)
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
    direnv)
      # "2.36.0" -> "2.36.0" (direnv outputs just the version number)
      echo "$version_string" | sed -n 's/^\([0-9][0-9.]*\).*/\1/p'
      ;;
    terraform)
      # "Terraform v1.12.1" -> "1.12.1"
      echo "$version_string" | sed -n 's/.*v\([0-9][0-9.]*\).*/\1/p'
      ;;
    packer)
      # "Packer v1.12.0" -> "1.12.0"
      echo "$version_string" | sed -n 's/.*Packer v\([0-9][0-9.]*\).*/\1/p'
      ;;
    *)
      # For other tools, try to extract the first version-like pattern
      echo "$version_string" | sed -n 's/.*\([0-9][0-9.]*[0-9]\).*/\1/p' | head -1
      ;;
  esac
}

# Utility functions
check_command() {
  command -v "$1" > /dev/null 2>&1
}

ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir" || {
      log_error "Failed to create directory: $dir"
      return 1
    }
  fi
}

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local timestamp
    timestamp=$(date +"%Y%m%d%H%M%S")
    local backup="${file}.backup.${timestamp}"
    cp "$file" "$backup" || {
      log_error "Failed to create backup of $file"
      return 1
    }
    log_info "Created backup: $backup"
  fi
}

# System validation
validate_system() {
  echo -e "\n=== System Validation ==="

  printf "├── %b[CHECKING]%b Operating system\n" "$BLUE" "$NC"
  # Check OS
  if [[ "$(uname)" != "Darwin" ]]; then
    printf "│   └── %b[ERROR]%b This script requires macOS\n" "$RED" "$NC"
    return 1
  fi
  printf "│   └── %b[SUCCESS]%b macOS detected\n" "$GREEN" "$NC"

  printf "└── %b[CHECKING]%b User permissions\n" "$BLUE" "$NC"
  # Check if running as root
  if [[ $EUID -eq 0 ]]; then
    printf "    └── %b[ERROR]%b Do not run as root - use regular user\n" "$RED" "$NC"
    return 1
  fi
  printf "    └── %b[SUCCESS]%b Running as regular user\n" "$GREEN" "$NC"

  return 0
}

# HashiCorp tool installation
install_hashicorp_tool() {
  local tool="$1"
  local version="$2"
  local arch
  local connector="$3"

  printf "%s %b[CHECKING]%b %s\n" "$connector" "$BLUE" "$NC" "$tool"
  if check_command "$tool"; then
    local current_version
    current_version=$("$tool" --version 2> /dev/null | head -1)
    # Extract clean version for display
    local clean_version
    clean_version=$(extract_version "$current_version" "$tool")
    printf "│   └── %b[SUCCESS]%b Already installed (v%s)\n" "$GREEN" "$NC" "$clean_version"
    return 0
  fi

  # Determine architecture
  if [[ "$(uname -m)" == "arm64" ]]; then
    arch="arm64"
  else
    arch="amd64"
  fi

  # Create temporary directory
  local tmp_dir
  tmp_dir=$(mktemp -d) || {
    printf "│   └── %b[ERROR]%b Failed to create temporary directory\n" "$RED" "$NC"
    return 1
  }

  local download_url="https://releases.hashicorp.com/$tool/$version/${tool}_${version}_darwin_${arch}.zip"
  local zip_file="$tmp_dir/$tool.zip"

  printf "│   ├── %b[DOWNLOADING]%b %s v%s\n" "$BLUE" "$NC" "$tool" "$version"
  # Download and install
  if curl -sSL "$download_url" -o "$zip_file" \
    && unzip -q "$zip_file" -d "$tmp_dir" \
    && sudo mv "$tmp_dir/$tool" /usr/local/bin/ \
    && sudo chmod +x "/usr/local/bin/$tool"; then
    printf "│   └── %b[SUCCESS]%b %s v%s installed\n" "$GREEN" "$NC" "$tool" "$version"
    rm -rf "$tmp_dir"
    return 0
  else
    printf "│   └── %b[ERROR]%b Failed to install %s\n" "$RED" "$NC" "$tool"
    rm -rf "$tmp_dir"
    return 1
  fi
}

install_hashicorp_tools() {
  echo -e "\n=== Infrastructure Tools ==="
  install_hashicorp_tool "terraform" "1.12.1" "├──" || printf "├── %b[WARNING]%b Terraform installation skipped\n" "$YELLOW" "$NC"
  install_hashicorp_tool "packer" "1.12.0" "└──" || printf "└── %b[WARNING]%b Packer installation skipped\n" "$YELLOW" "$NC"
}

# Homebrew installation and package management
install_homebrew() {
  echo -e "\n=== System Dependencies ==="
  printf "├── %b[CHECKING]%b Homebrew installation\n" "$BLUE" "$NC"

  if check_command brew; then
    printf "└── %b[SUCCESS]%b Homebrew already installed\n" "$GREEN" "$NC"
    return 0
  fi

  printf "├── %b[INSTALLING]%b Homebrew (this may take a few minutes)\n" "$BLUE" "$NC"

  # Install Homebrew with minimal output
  local brew_install_log="/tmp/homebrew_install.log"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > "$brew_install_log" 2>&1 || {
    log_error "Failed to install Homebrew. See $brew_install_log for details."
    return 1
  }

  # Configure Homebrew PATH based on architecture
  if [[ "$(uname -m)" == "arm64" ]]; then
    # shellcheck disable=SC2016
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$ZSHRC_PATH"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    # shellcheck disable=SC2016
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$ZSHRC_PATH"
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  printf "└── %b[SUCCESS]%b Homebrew installation complete\n" "$GREEN" "$NC"
}

setup_orbstack() {
  echo -e "\n=== Container Environment ==="

  # Skip OrbStack setup if SKIP_ORBSTACK is set to true
  if [[ "${SKIP_ORBSTACK:-false}" == "true" ]]; then
    printf "└── %b[SKIPPED]%b OrbStack setup (SKIP_ORBSTACK=true)\n" "$YELLOW" "$NC"
    return 0
  fi

  printf "├── %b[CHECKING]%b OrbStack installation\n" "$BLUE" "$NC"
  if ! check_command orbctl; then
    if [[ "${CI:-false}" == "true" ]]; then
      printf "└── %b[WARNING]%b OrbStack not installed (expected in CI)\n" "$YELLOW" "$NC"
      return 0
    else
      printf "└── %b[ERROR]%b OrbStack not installed - please install first\n" "$RED" "$NC"
      return 1
    fi
  fi

  # Ensure OrbStack is in PATH
  if [[ -d "/Applications/OrbStack.app" ]]; then
    printf "├── %b[CONFIGURING]%b Adding OrbStack to PATH\n" "$BLUE" "$NC"
    # shellcheck disable=SC2016
    echo 'export PATH="/Applications/OrbStack.app/Contents/MacOS:$PATH"' >> "$ZSHRC_PATH"
    export PATH="/Applications/OrbStack.app/Contents/MacOS:$PATH"
  fi

  # Start OrbStack if it's not running
  printf "├── %b[CHECKING]%b OrbStack status\n" "$BLUE" "$NC"
  if ! orbctl status > /dev/null 2>&1; then
    printf "│   ├── %b[STARTING]%b OrbStack service\n" "$BLUE" "$NC"
    if ! orbctl start; then
      if [[ "${CI:-false}" == "true" ]]; then
        printf "│   └── %b[WARNING]%b Failed to start (expected in CI)\n" "$YELLOW" "$NC"
        return 0
      else
        printf "│   └── %b[ERROR]%b Failed to start OrbStack\n" "$RED" "$NC"
        return 1
      fi
    fi

    # Wait for OrbStack to be fully initialized
    printf "│   └── %b[WAITING]%b Initializing OrbStack\n" "$BLUE" "$NC"
    local retries=30
    while [[ $retries -gt 0 ]]; do
      if orbctl status > /dev/null 2>&1; then
        break
      fi
      sleep 1
      ((retries--))
    done

    if [[ $retries -eq 0 ]]; then
      printf "└── %b[ERROR]%b OrbStack failed to initialize\n" "$RED" "$NC"
      return 1
    fi
  else
    printf "│   └── %b[SUCCESS]%b OrbStack already running\n" "$GREEN" "$NC"
  fi

  printf "└── %b[SUCCESS]%b Container environment ready\n" "$GREEN" "$NC"
}

install_packages() {
  echo -e "\n=== Installing Packages ==="

  # Check if Brewfile exists
  if [[ ! -f "Brewfile" ]]; then
    log_error "Brewfile not found in current directory. Please ensure it exists."
    return 1
  fi

  # Remove Docker from Brewfile if it exists (since it comes with OrbStack)
  if grep -q "docker" "Brewfile"; then
    printf "├── %bRemoving Docker from Brewfile%b (comes with OrbStack)\n" "$YELLOW" "$NC"
    sed -i.bak '/docker/d' "Brewfile"
    rm -f "Brewfile.bak"
  fi

  # Log file for bundle output
  local bundle_log="/tmp/brew_bundle.log"

  # Check bundle status quietly first
  echo "==== brew bundle check ====" > "$bundle_log"
  brew bundle check >> "$bundle_log" 2>&1
  local check_status=$?

  # Always run install in CI, or if check shows missing dependencies
  if [[ $check_status -ne 0 ]] || [[ "${CI:-false}" == "true" ]]; then
    if [[ "${CI:-false}" == "true" ]]; then
      printf "├── %b[INSTALLING]%b Packages (CI mode)\n" "$BLUE" "$NC"
    else
      printf "├── %b[INSTALLING]%b Packages from Brewfile\n" "$BLUE" "$NC"
    fi

    # Capture brew bundle output to extract installed packages
    local bundle_output="/tmp/brew_bundle_output.log"
    echo "==== brew bundle install ====" >> "$bundle_log"
    brew bundle install > "$bundle_output" 2>&1
    local install_status=$?

    # Also append to main log for debugging
    cat "$bundle_output" >> "$bundle_log"

    if [[ $install_status -ne 0 ]]; then
      log_error "Failed to install packages (exit code $install_status). See $bundle_log for details."
      return 1
    fi

    # Parse the output to categorize packages
    local installing_packages=""
    local upgrading_packages=""
    local tapping_packages=""
    local using_packages=""
    local install_count=0
    local using_count=0
    local package_name

    while IFS= read -r line; do
      case "$line" in
        Installing*)
          package_name=$(echo "$line" | sed 's/^Installing //' | cut -d' ' -f1)
          installing_packages="${installing_packages}${installing_packages:+, }${package_name}"
          install_count=$((install_count + 1))
          ;;
        Upgrading*)
          package_name=$(echo "$line" | sed 's/^Upgrading //' | cut -d' ' -f1)
          upgrading_packages="${upgrading_packages}${upgrading_packages:+, }${package_name}"
          install_count=$((install_count + 1))
          ;;
        Tapping*)
          package_name=$(echo "$line" | sed 's/^Tapping //' | cut -d' ' -f1)
          tapping_packages="${tapping_packages}${tapping_packages:+, }${package_name}"
          install_count=$((install_count + 1))
          ;;
        Using*)
          package_name="${line#Using }"
          using_packages="${using_packages}${using_packages:+, }${package_name}"
          using_count=$((using_count + 1))
          ;;
      esac
    done < "$bundle_output"

    # Display aggregated packages by category
    if [ -n "$installing_packages" ]; then
      printf "│   ├── %b[INSTALLING]%b %s\n" "$GREEN" "$NC" "$installing_packages"
    fi
    if [ -n "$upgrading_packages" ]; then
      printf "│   ├── %b[UPGRADING]%b %s\n" "$YELLOW" "$NC" "$upgrading_packages"
    fi
    if [ -n "$tapping_packages" ]; then
      printf "│   ├── %b[TAPPING]%b %s\n" "$BLUE" "$NC" "$tapping_packages"
    fi
    if [ -n "$using_packages" ]; then
      printf "│   ├── %b[USING]%b %s\n" "$BLUE" "$NC" "$using_packages"
    fi

    # Show completion summary from brew bundle
    local total_packages=$((install_count + using_count))
    if grep -q "complete!" "$bundle_output"; then
      local total_deps
      total_deps=$(grep "dependencies now installed" "$bundle_output" | grep -o '[0-9]*' | head -1)
      if [ "$install_count" -gt 0 ]; then
        printf "│   └── %b[SUCCESS]%b %s new, %s total dependencies ready\n" "$GREEN" "$NC" "$install_count" "${total_deps:-$total_packages}"
      else
        printf "│   └── %b[SUCCESS]%b All %s dependencies already installed\n" "$GREEN" "$NC" "${total_deps:-$using_count}"
      fi
    else
      if [ "$total_packages" -gt 0 ]; then
        printf "│   └── %b[SUCCESS]%b %s packages processed\n" "$GREEN" "$NC" "$total_packages"
      else
        printf "│   └── %b[SUCCESS]%b Package installation completed\n" "$GREEN" "$NC"
      fi
    fi

    printf "└── %b[SUCCESS]%b Homebrew bundle complete\n" "$GREEN" "$NC"

    # Clean up temporary file
    rm -f "$bundle_output"
  else
    printf "└── %b[SUCCESS]%b All packages already installed\n" "$GREEN" "$NC"
  fi
}

# Language environment setup
setup_ruby_environment() {
  echo -e "\n=== Setting Up Language Environments ==="
  printf "├── %bRuby Environment%b\n" "$BLUE" "$NC"

  if ! check_command rbenv; then
    log_error "rbenv not found. Please ensure it's installed."
    return 1
  fi

  # Initialize rbenv
  eval "$(rbenv init - zsh)"

  # Install latest Ruby version
  local latest_ruby
  latest_ruby=$(rbenv install -l | grep -v - | grep -v dev | tail -1 | tr -d '[:space:]')

  if ! rbenv versions | grep -q "$latest_ruby"; then
    printf "│   ├── %b[INSTALLING]%b Ruby %s (this may take several minutes)\n" "$BLUE" "$NC" "$latest_ruby"
    # Suppress verbose output by redirecting to log file
    local ruby_log="/tmp/ruby_install.log"
    RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl) --with-readline-dir=$(brew --prefix readline)" \
      rbenv install "$latest_ruby" > "$ruby_log" 2>&1 || {
      printf "│   └── %b[ERROR]%b Failed to install Ruby %s (see %s)\n" "$RED" "$NC" "$latest_ruby" "$ruby_log"
      return 1
    }
    printf "│   ├── %b[SUCCESS]%b Ruby %s installed\n" "$GREEN" "$NC" "$latest_ruby"
  else
    printf "│   ├── %b[SUCCESS]%b Ruby %s already installed\n" "$GREEN" "$NC" "$latest_ruby"
  fi

  # Set global Ruby version
  rbenv global "$latest_ruby"
  printf "│   └── %b[SUCCESS]%b Ruby environment ready\n" "$GREEN" "$NC"
}

setup_python_environment() {
  printf "└── %bPython Environment%b\n" "$BLUE" "$NC"

  if ! check_command pyenv; then
    log_error "pyenv not found. Please ensure it's installed."
    return 1
  fi

  # Initialize pyenv
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"

  # Install latest Python version
  local latest_python
  latest_python=$(pyenv install --list | grep -v - | grep -v a | grep -v b | grep -v rc | grep "^  [0-9]" | tail -1 | tr -d '[:space:]')

  if ! pyenv versions | grep -q "$latest_python"; then
    printf "    ├── %b[INSTALLING]%b Python %s (this may take several minutes)\n" "$BLUE" "$NC" "$latest_python"
    # Suppress verbose output by redirecting to log file
    local python_log="/tmp/python_install.log"
    CPPFLAGS="-I$(brew --prefix openssl)/include -I$(brew --prefix sqlite3)/include" \
    LDFLAGS="-L$(brew --prefix openssl)/lib -L$(brew --prefix sqlite3)/lib" \
      pyenv install "$latest_python" > "$python_log" 2>&1 || {
      printf "    └── %b[ERROR]%b Failed to install Python %s (see %s)\n" "$RED" "$NC" "$latest_python" "$python_log"
      return 1
    }
    printf "    ├── %b[SUCCESS]%b Python %s installed\n" "$GREEN" "$NC" "$latest_python"
  else
    printf "    ├── %b[SUCCESS]%b Python %s already installed\n" "$GREEN" "$NC" "$latest_python"
  fi

  # Set global Python version
  pyenv global "$latest_python"
  printf "    └── %b[SUCCESS]%b Python environment ready\n" "$GREEN" "$NC"
}

# Shell configuration
setup_antidote() {
  # This function is now called from configure_shell, so suppress its own logging

  # Ensure the directory exists
  local plugins_dir
  plugins_dir=$(dirname "$ANTIDOTE_PLUGINS_FILE")
  ensure_dir "$plugins_dir" > /dev/null 2>&1

  # Create plugins file
  if [[ ! -f "$ANTIDOTE_PLUGINS_FILE" ]]; then
    cat > "$ANTIDOTE_PLUGINS_FILE" << 'EOF'
# Essential ZSH plugins
zsh-users/zsh-syntax-highlighting
zsh-users/zsh-autosuggestions
zsh-users/zsh-completions
zsh-users/zsh-history-substring-search

# z - directory navigation
agkozak/zsh-z

# Git plugins
ohmyzsh/ohmyzsh path:plugins/git

# Kubernetes plugins
ohmyzsh/ohmyzsh path:plugins/kubectl

ohmyzsh/ohmyzsh path:plugins/helm

# Development tools completions
ohmyzsh/ohmyzsh path:plugins/terraform
ohmyzsh/ohmyzsh path:plugins/docker
ohmyzsh/ohmyzsh path:plugins/docker-compose

# Utility plugins
ohmyzsh/ohmyzsh path:plugins/common-aliases
ohmyzsh/ohmyzsh path:plugins/brew
ohmyzsh/ohmyzsh path:plugins/fzf
EOF
  fi

  # Add antidote configuration to .zshrc
  local antidote_config
  antidote_config="# Initialize antidote
[[ -e \$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh ]] && source \$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh
autoload -Uz compinit && compinit
antidote load \${ZDOTDIR:-\$HOME}/.zsh_plugins.txt"

  if ! grep -q "Initialize antidote" "$ZSHRC_PATH"; then
    echo -e "\n$antidote_config" >> "$ZSHRC_PATH"
  fi
}

generate_completion_files() {
  echo -e "\n=== Generating Completion Files ==="

  # macOS-compatible timeout function
  run_with_timeout() {
    local timeout_duration=$1
    shift
    local cmd="$*"

    # Try to use gtimeout if available (from brew install coreutils)
    if command -v gtimeout > /dev/null 2>&1; then
      gtimeout "$timeout_duration" bash -c "$cmd"
    # Fallback to using background process with timeout
    else
      (
        eval "$cmd" &
        local pid=$!
        (
          sleep "$timeout_duration"
          kill "$pid" 2> /dev/null
        ) &
        local timeout_pid=$!
        wait "$pid" 2> /dev/null
        local exit_code=$?
        kill "$timeout_pid" 2> /dev/null
        exit "$exit_code"
      )
    fi
  }

  # Generate static completion files for tools that support it
  echo "├── Container Tools"
  local container_tools=(
    "docker:docker completion zsh"
    "kubectl:kubectl completion zsh"
    "helm:helm completion zsh"
    "orb:orb completion zsh"
    "orbctl:orbctl completion zsh"
  )

  local i=0
  for tool_config in "${container_tools[@]}"; do
    local tool="${tool_config%%:*}"
    local completion_cmd="${tool_config#*:}"
    local completion_file="${COMPLETION_DIR}/_${tool}"
    local prefix="│   "
    local connector="├──"
    if [[ $i -eq $((${#container_tools[@]} - 1)) ]]; then
      connector="└──"
    fi

    if command -v "$tool" > /dev/null 2>&1; then
      if run_with_timeout 10 "$completion_cmd" > "$completion_file" 2> /dev/null; then
        printf "%s%s %b[SUCCESS]%b %s completion generated\n" "$prefix" "$connector" "$GREEN" "$NC" "$tool"
      else
        printf "%s%s %b[WARNING]%b %s completion failed (timeout or error)\n" "$prefix" "$connector" "$YELLOW" "$NC" "$tool"
        rm -f "$completion_file"
      fi
    else
      printf "%s%s %b[WARNING]%b %s not found, skipping\n" "$prefix" "$connector" "$YELLOW" "$NC" "$tool"
    fi
    ((i++))
  done

  # Generate completions for development environment tools
  echo "├── Development Tools"
  local dev_tools=(
    "rbenv:rbenv completions zsh"
    "direnv:direnv hook zsh"
  )

  local i=0
  for tool_config in "${dev_tools[@]}"; do
    local tool="${tool_config%%:*}"
    local completion_cmd="${tool_config#*:}"
    local completion_file="${COMPLETION_DIR}/_${tool}"
    local prefix="│   "
    local connector="├──"
    if [[ $i -eq $((${#dev_tools[@]} - 1)) ]]; then
      connector="└──"
    fi

    if command -v "$tool" > /dev/null 2>&1; then
      if run_with_timeout 10 "$completion_cmd" > "$completion_file" 2> /dev/null; then
        printf "%s%s %b[SUCCESS]%b %s completion generated\n" "$prefix" "$connector" "$GREEN" "$NC" "$tool"
      else
        printf "%s%s %b[WARNING]%b %s completion failed\n" "$prefix" "$connector" "$YELLOW" "$NC" "$tool"
        rm -f "$completion_file"
      fi
    else
      printf "%s%s %b[WARNING]%b %s not found, skipping\n" "$prefix" "$connector" "$YELLOW" "$NC" "$tool"
    fi
    ((i++))
  done

  # Special case for pyenv - copy system completion file
  echo "├── Language Environment Tools"
  if command -v pyenv > /dev/null 2>&1; then
    local pyenv_completion
    pyenv_completion=$(find "$(brew --prefix)" -name "pyenv.zsh" -path "*/completions/*" 2> /dev/null | head -1)
    if [[ -n "$pyenv_completion" && -f "$pyenv_completion" ]]; then
      cp "$pyenv_completion" "${COMPLETION_DIR}/_pyenv" \
        && printf "│   └── %b[SUCCESS]%b pyenv completion generated\n" "$GREEN" "$NC"
    else
      printf "│   └── %b[WARNING]%b pyenv completion file not found\n" "$YELLOW" "$NC"
    fi
  else
    printf "│   └── %b[WARNING]%b pyenv not found, skipping\n" "$YELLOW" "$NC"
  fi

  # Set up HashiCorp tool completions (they use different mechanisms)
  echo "└── Infrastructure Tools"
  local infra_tools=("terraform" "packer")
  local i=0
  for tool in "${infra_tools[@]}"; do
    local prefix="    "
    local connector="├──"
    if [[ $i -eq $((${#infra_tools[@]} - 1)) ]]; then
      connector="└──"
    fi

    if command -v "$tool" > /dev/null 2>&1; then
      if [[ "$tool" == "terraform" ]]; then
        if terraform -install-autocomplete 2> /dev/null; then
          printf "%s%s %b[SUCCESS]%b %s autocomplete installed\n" "$prefix" "$connector" "$GREEN" "$NC" "$tool"
        else
          printf "%s%s %b[INFO]%b %s autocomplete already installed\n" "$prefix" "$connector" "$BLUE" "$NC" "$tool"
        fi
      elif [[ "$tool" == "packer" ]]; then
        if packer -autocomplete-install 2> /dev/null; then
          printf "%s%s %b[SUCCESS]%b %s autocomplete installed\n" "$prefix" "$connector" "$GREEN" "$NC" "$tool"
        else
          printf "%s%s %b[INFO]%b %s autocomplete already installed\n" "$prefix" "$connector" "$BLUE" "$NC" "$tool"
        fi
      fi
    else
      printf "%s%s %b[WARNING]%b %s not found, skipping\n" "$prefix" "$connector" "$YELLOW" "$NC" "$tool"
    fi
    ((i++))
  done

  log_success "Completion file generation completed."
}

setup_shell_completions() {
  # This function is now called from configure_shell, so suppress its own logging

  # Ensure completion directories exist
  ensure_dir "$COMPLETION_DIR"
  ensure_dir "$ZCOMPCACHE_DIR"

  # Generate completion files first
  generate_completion_files

  # Add completion configuration to .zshrc
  # shellcheck disable=SC2124
  local completion_config=(
    "# Initialize completions"
    "# Ensure we're running in zsh"
    "if [ -n \"\$BASH_VERSION\" ]; then"
    "    exec /bin/zsh \"\$0\" \"\$@\""
    "fi"
    ""
    "# Initialize completion system"
    "autoload -Uz compinit"
    "if [[ -f ~/.zcompdump && \$(find ~/.zcompdump -mtime +1) ]]; then"
    "    compinit -i"
    "else"
    "    compinit -C -i"
    "fi"
    ""
    "# Completion settings"
    "zstyle ':completion:*' menu select"
    "zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'"
    "zstyle ':completion::complete:*' use-cache on"
    "zstyle ':completion::complete:*' cache-path \"\$ZCOMPCACHE_DIR\""
    ""
    "# Source fzf completions if available"
    "if [[ -f \"\$(brew --prefix)/opt/fzf/shell/completion.zsh\" ]]; then"
    "    source \"\$(brew --prefix)/opt/fzf/shell/completion.zsh\" 2>/dev/null"
    "fi"
    ""
    "# Additional completion sources"
    "fpath=(\"${COMPLETION_DIR}\" \"\${fpath[@]}\")"
    ""
    "# HashiCorp tool completions (use built-in completion system)"
    "if command -v terraform >/dev/null 2>&1; then"
    "    complete -o nospace -C terraform terraform"
    "fi"
    ""
    "if command -v packer >/dev/null 2>&1; then"
    "    complete -o nospace -C packer packer"
    "fi"
    ""
    "# Pyenv initialization"
    "if command -v pyenv >/dev/null 2>&1; then"
    "    eval \"\$(pyenv init -)\""
    "fi"
  )

  if ! grep -q "Initialize completions" "$ZSHRC_PATH"; then
    printf "%s\n" "${completion_config[@]}" >> "$ZSHRC_PATH"
  fi

  # Force regeneration of completion cache (suppress error if no files exist)
  rm -f "${HOME}/.zcompdump"* 2> /dev/null || true
  # Only remove cache files if directory exists and has files
  if [[ -d "$ZCOMPCACHE_DIR" ]] && [[ -n "$(ls -A "$ZCOMPCACHE_DIR" 2> /dev/null)" ]]; then
    rm -f "${ZCOMPCACHE_DIR}/"* 2> /dev/null || true
  fi

  # Set up completions immediately for current session
  if [[ -f "$(brew --prefix)/opt/fzf/shell/completion.zsh" ]]; then
    # shellcheck disable=SC1090
    source "$(brew --prefix)/opt/fzf/shell/completion.zsh" 2> /dev/null || log_warning "Failed to source fzf completion"
  fi

  # Initialize completion system for current session
  autoload -Uz compinit
  compinit -C -i

  # Set up HashiCorp completions for current session

  # Terraform uses its own completion system
  if command -v terraform > /dev/null 2>&1; then
    # Terraform handles its own completion via the installed autocomplete
    complete -o nospace -C terraform terraform 2> /dev/null || true
  fi

  # Packer also uses its own completion system
  if command -v packer > /dev/null 2>&1; then
    # Packer handles its own completion via the installed autocomplete
    complete -o nospace -C packer packer 2> /dev/null || true
  fi

  # Initialize pyenv for current session
  if command -v pyenv > /dev/null 2>&1; then
    eval "$(pyenv init -)" 2> /dev/null || true
  fi
}

configure_shell() {
  echo -e "\n=== Shell Configuration ==="

  # Create or backup .zshrc
  printf "├── %b[CONFIGURING]%b Shell environment\n" "$BLUE" "$NC"
  if [[ ! -f "$ZSHRC_PATH" ]]; then
    touch "$ZSHRC_PATH"
    printf "│   ├── %b[CREATED]%b .zshrc file\n" "$GREEN" "$NC"
  else
    backup_file "$ZSHRC_PATH" > /dev/null 2>&1
    printf "│   ├── %b[BACKED UP]%b Existing .zshrc\n" "$BLUE" "$NC"
  fi

  # Setup Antidote plugin manager
  printf "│   ├── %b[SETTING UP]%b Antidote plugin manager\n" "$BLUE" "$NC"
  if setup_antidote > /dev/null 2>&1; then
    printf "│   │   ├── %b[SUCCESS]%b Plugin configuration created\n" "$GREEN" "$NC"
  else
    printf "│   │   ├── %b[WARNING]%b Plugin setup had issues but continuing\n" "$YELLOW" "$NC"
  fi

  # Install Antidote if needed
  if ! command -v antidote > /dev/null 2>&1; then
    printf "│   │   ├── %b[INSTALLING]%b Antidote\n" "$BLUE" "$NC"
    if brew install antidote > /dev/null 2>&1; then
      printf "│   │   └── %b[SUCCESS]%b Antidote installed\n" "$GREEN" "$NC"
    else
      printf "│   │   └── %b[ERROR]%b Failed to install Antidote\n" "$RED" "$NC"
      return 1
    fi
  else
    printf "│   │   └── %b[SUCCESS]%b Antidote already available\n" "$GREEN" "$NC"
  fi

  # Source Antidote and bundle plugins
  if [[ -e "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh" ]]; then
    printf "│   │   ├── %b[LOADING]%b Antidote plugins\n" "$BLUE" "$NC"
    # Initialize completion system
    autoload -Uz compinit
    if [[ -f ~/.zcompdump && $(find ~/.zcompdump -mtime +1) ]]; then
      compinit -i
    else
      compinit -C -i
    fi

    source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
    # Clear antidote cache to prevent stale plugin loading issues
    antidote purge 2> /dev/null || true

    # Load plugins with error handling
    if antidote load "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" 2> /dev/null; then
      printf "│   │   └── %b[SUCCESS]%b Plugins loaded successfully\n" "$GREEN" "$NC"
    else
      printf "│   │   └── %b[WARNING]%b Some plugins failed to load\n" "$YELLOW" "$NC"
      # Try to update plugins to fix any issues
      antidote update 2> /dev/null || true
    fi
  else
    printf "│   │   └── %b[ERROR]%b Antidote installation not found\n" "$RED" "$NC"
    return 1
  fi

  # Setup shell completions
  printf "│   ├── %b[SETTING UP]%b Shell completions\n" "$BLUE" "$NC"
  if setup_shell_completions > /dev/null 2>&1; then
    printf "│   │   └── %b[SUCCESS]%b Completion system configured\n" "$GREEN" "$NC"
  else
    printf "│   │   └── %b[WARNING]%b Completion setup had issues but continuing\n" "$YELLOW" "$NC"
  fi

  # Add tool-specific configurations
  printf "│   └── %b[CONFIGURING]%b Tool integrations\n" "$BLUE" "$NC"
  local configs=(
    "rbenv:rbenv init - zsh"
    "pyenv:pyenv init --path\npyenv init -"
    "direnv:direnv hook zsh"
    "starship:starship init zsh"
  )

  for config in "${configs[@]}"; do
    local tool="${config%%:*}"
    local init_cmd="${config#*:}"

    if check_command "$tool"; then
      if ! grep -q "$tool" "$ZSHRC_PATH"; then
        echo -e "\n# Initialize $tool\neval \"\$($init_cmd)\"" >> "$ZSHRC_PATH"
        printf "│       ├── %b[ADDED]%b %s integration\n" "$GREEN" "$NC" "$tool"
      else
        printf "│       ├── %b[EXISTS]%b %s integration\n" "$BLUE" "$NC" "$tool"
      fi
    else
      printf "│       ├── %b[SKIPPED]%b %s (not installed)\n" "$YELLOW" "$NC" "$tool"
    fi
  done

  printf "└── %b[SUCCESS]%b Shell configuration completed\n" "$GREEN" "$NC"
}

# Main execution
main() {
  echo -e "\n=== macOS Development Environment Setup v${SCRIPT_VERSION} ==="

  validate_system || exit 1
  install_homebrew || exit 1
  install_packages || exit 1
  setup_orbstack || log_warning "OrbStack setup incomplete"
  install_hashicorp_tools || log_warning "Some HashiCorp tools may not be installed"
  configure_shell || exit 1
  setup_ruby_environment || log_warning "Ruby environment setup incomplete"
  setup_python_environment || log_warning "Python environment setup incomplete"

  echo -e "\n=== Setup Complete ==="
  printf "└── %b[SUCCESS]%b All components installed and configured\n" "$GREEN" "$NC"
  printf "\n%bNext steps:%b Please restart your terminal or run: source %s\n" "$YELLOW" "$NC" "$ZSHRC_PATH"
}

main "$@"
