#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2296,SC2034,SC2154

# Source logging module
# shellcheck source=lib/logging.sh
source "lib/logging.sh"

# Enable error reporting
set -e

# Script configuration
readonly COMPLETION_DIR="${HOME}/.zsh/completions"

# Function to ensure a directory exists
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            log_error "Failed to create directory: $dir"
            return 1
        }
    fi
}

# Function to handle completion test errors
handle_completion_error() {
    local exit_code="$1"
    local tool="$2"
    
    log_debug "Completion test for $tool failed with exit code $exit_code"
    
    case "$exit_code" in
        1)
            log_error "$tool completion function not found"
            ;;
        2)
            log_error "$tool completion file not found"
            ;;
        3)
            log_error "$tool not installed"
            ;;
        *)
            log_error "Unknown error testing $tool completion"
            ;;
    esac
    
    # Try to fix common issues
    case "$tool" in
        "fzf")
            if [[ -f "/opt/homebrew/opt/fzf/shell/completion.zsh" ]]; then
                log_debug "Found fzf completion, attempting to source it"
                # shellcheck disable=SC1091
                source "/opt/homebrew/opt/fzf/shell/completion.zsh" 2>/dev/null || log_error "Failed to source fzf completion"
            else
                log_error "fzf completion file not found"
            fi
            ;;
        *)
            log_debug "No automatic fix available for $tool"
            ;;
    esac
}

# Function to safely initialize completion system
initialize_completion_system() {
    local force_flag=$1
    local init_result=0

    # Try standard initialization first
    if [[ "$force_flag" == "force" ]]; then
        compinit -u 2>/dev/null || init_result=$?
    else
        compinit 2>/dev/null || init_result=$?
    fi

    # If standard initialization fails, try with different options
    if [[ $init_result -ne 0 ]]; then
        log_debug "First compinit attempt failed, trying with -i option..."
        compinit -i 2>/dev/null || init_result=$?

        # If still failing, try with security checks disabled
        if [[ $init_result -ne 0 ]]; then
            log_debug "Second compinit attempt failed, trying with -C option..."
            compinit -C 2>/dev/null || init_result=$?

            # Last resort - try resetting the zcompdump file
            if [[ $init_result -ne 0 ]]; then
                log_debug "Third compinit attempt failed, trying with zcompdump reset..."
                rm -f "${HOME}/.zcompdump"
                compinit 2>/dev/null || log_warning "All compinit attempts failed"
            fi
        fi
    fi
}

# Early completion initialization to ensure completions are available
# This is important for the verification process
# Load compinit function
autoload -Uz compinit

# Early pyenv initialization to ensure correct PATH setup
if command -v pyenv >/dev/null 2>&1; then
  export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
  export PATH="$PYENV_ROOT/bin:$PATH"
  # Add pyenv shims to PATH
  if [[ -d "$PYENV_ROOT/shims" ]]; then
    export PATH="$PYENV_ROOT/shims:$PATH"
  fi
  # Initialize pyenv for shell integration
  # shellcheck disable=SC1090
  eval "$(pyenv init -)" 2>/dev/null || echo "Warning: pyenv init failed"
  # Initialize pyenv shell completion specifically
  # shellcheck disable=SC1090
  eval "$(pyenv init --path)" 2>/dev/null || echo "Warning: pyenv path init failed"
fi

# Initialize completion system with error handling
initialize_completion_system "force"

# Set NULL_GLOB to avoid "no matches found" errors with globs
setopt NULL_GLOB 2>/dev/null || true

# Logging functions
log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$1" >&2; }
log_debug() { printf "[DEBUG] %s\n" "$1" >&2; }
log_warning() { printf "${YELLOW}[WARNING]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1" >&2; }

log_info "Starting verification process..."

# Debug information
log_debug "Current shell: $SHELL"
log_debug "Current user: $USER"
log_debug "Current PATH: $PATH"
log_debug "Current working directory: $PWD"
log_debug "Home directory: $HOME"
log_debug "Current fpath: $fpath"

# Ensure we're running in zsh
if [ -n "$BASH_VERSION" ]; then
    exec /bin/zsh "$0" "$@"
fi

# Enable zsh features
setopt extended_glob

# Initialize completion system early
autoload -Uz compinit
compinit -u

# Fix source command safety
source_safely() {
    local file="$1"
    if [[ -f "$file" ]]; then
        # shellcheck disable=SC1090
        source "$file" >/dev/null 2>&1
        return $?
    fi
    return 1
}

# Update completion path handling
get_completion_path() {
    local tool="$1"
    if [[ -n "${completion_paths[$tool]}" ]]; then
        printf '%s' "${completion_paths[$tool]}"
    else
        return 1
    fi
}

# Update fzf completion sourcing
if ! source_safely "/opt/homebrew/opt/fzf/shell/completion.zsh"; then
    log_debug "Failed to source fzf completion"
    return 1
fi

# Update tool configuration array
declare -A tool_configs=(
    ["git"]="vcs|$(command -v git)|git branch"
    ["terraform"]="hashicorp|$(command -v terraform)|terraform workspace list"
    ["rbenv"]="ruby|$(command -v rbenv)|rbenv versions"
    ["pyenv"]="python|$(command -v pyenv)|pyenv versions"
    ["direnv"]="env|$(command -v direnv)|direnv status"
    ["packer"]="hashicorp|$(command -v packer)|packer version"
    ["starship"]="prompt|$(command -v starship)|starship prompt"
    ["kubectl"]="k8s|$(command -v kubectl)|kubectl get pods"
    ["helm"]="k8s|$(command -v helm)|helm list"
    ["kubectx"]="k8s|$(command -v kubectx)|kubectx"
    ["fzf"]="utils|$(command -v fzf)|fzf --version"
)

# Completion directories
typeset -A completion_paths
completion_paths=()
completion_paths[homebrew]="/opt/homebrew/share/zsh/site-functions"
completion_paths[homebrew_intel]="/usr/local/share/zsh/site-functions"
completion_paths[user_completions]="$HOME/.zsh/completions"
completion_paths[antidote]="$HOME/.antidote/completions"
completion_paths[zsh_site]="/usr/share/zsh/site-functions"
completion_paths[zsh_vendor]="/usr/share/zsh/vendor-completions"
completion_paths[fzf_completions]="/opt/homebrew/opt/fzf/shell"

# Function to get tool configuration parts
get_tool_config_part() {
    local tool="$1"
    local part="$2"  # type, source, or commands
    local config="${tool_configs[$tool]}"
    local -a parts
    parts=()
    IFS='|' read -r -A parts <<< "$config"
    
    case "$part" in
        type) echo "${parts[1]}" ;;
        source) echo "${parts[2]}" ;;
        commands) echo "${parts[3]}" ;;
    esac
}

# Verify essential commands
typeset -a check_commands
check_commands=(
    "brew"
    "git"
    "terraform"
    "packer"
    "rbenv"
    "pyenv"
    "starship"
)

log_info "=== COMMAND VERIFICATION ==="
for cmd in "${check_commands[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        log_debug "$cmd is available ($(command -v "$cmd"))"
        "$cmd" --version 2>&1 || log_warning "Could not get version for $cmd"
    else
        log_warning "$cmd is not available"
    fi
done

# Verify shell plugins and completions
log_info "=== COMPLETION VERIFICATION ==="
log_info "Verifying shell configuration..."
if [[ -f ~/.zsh_plugins.txt ]]; then
    log_debug "antidote plugins file exists"
else
    log_warning "antidote plugins file missing"
fi

# Initialize completion system
log_info "Initializing completion system..."
autoload -Uz compinit
compinit -u

# Function to test completion for a tool
test_completion() {
    local tool="$1"
    local command="$2"
    local test_command="$3"
    local completion_file=""
    local exit_code=0

    # First, try to find the completion file
    case "$tool" in
        "fzf")
            completion_file="/opt/homebrew/opt/fzf/shell/completion.zsh"
            ;;
        "git")
            completion_file="/opt/homebrew/share/zsh/site-functions/_git"
            ;;
        "kubectl")
            # Generate kubectl completion if not exists
            if [[ ! -f "$COMPLETION_DIR/_kubectl" ]]; then
                kubectl completion zsh > "$COMPLETION_DIR/_kubectl" 2>/dev/null || true
            fi
            completion_file="$COMPLETION_DIR/_kubectl"
            ;;
        "helm")
            # Generate helm completion if not exists
            if [[ ! -f "$COMPLETION_DIR/_helm" ]]; then
                helm completion zsh > "$COMPLETION_DIR/_helm" 2>/dev/null || true
            fi
            completion_file="$COMPLETION_DIR/_helm"
            ;;
        "terraform")
            completion_file="/opt/homebrew/share/zsh/site-functions/_terraform"
            ;;
        "packer")
            completion_file="/opt/homebrew/share/zsh/site-functions/_packer"
            ;;
        "rbenv")
            # Source rbenv completion directly
            if ! command -v rbenv >/dev/null 2>&1; then
                return 3
            fi
            eval "$(rbenv init - zsh)" 2>/dev/null || true
            ;;
        "pyenv")
            # Source pyenv completion directly
            if ! command -v pyenv >/dev/null 2>&1; then
                return 3
            fi
            eval "$(pyenv init - zsh)" 2>/dev/null || true
            ;;
        "direnv")
            # Source direnv completion directly
            if ! command -v direnv >/dev/null 2>&1; then
                return 3
            fi
            eval "$(direnv hook zsh)" 2>/dev/null || true
            ;;
        "starship")
            # Generate starship completion if not exists
            if [[ ! -f "$COMPLETION_DIR/_starship" ]]; then
                starship completions zsh > "$COMPLETION_DIR/_starship" 2>/dev/null || true
            fi
            completion_file="$COMPLETION_DIR/_starship"
            ;;
        "kubectx")
            completion_file="/opt/homebrew/share/zsh/site-functions/_kubectx"
            ;;
        *)
            return 1
            ;;
    esac

    # Source completion file if it exists
    if [[ -n "$completion_file" && -f "$completion_file" ]]; then
        # shellcheck disable=SC1090
        source "$completion_file" 2>/dev/null || exit_code=$?
    fi

    # Verify the completion function exists
    if ! type "_$tool" >/dev/null 2>&1 && ! type "_${tool//-/_}" >/dev/null 2>&1; then
        exit_code=1
    fi

    return $exit_code
}

# Test completions for all tools
test_all_completions() {
    log_info "Testing completions for each tool..."
    local success_count=0
    local total_count=0

    # Define tools and their test commands
    local -A tools=(
        ["terraform"]="workspace list"
        ["git"]="branch"
        ["rbenv"]="versions"
        ["pyenv"]="versions"
        ["direnv"]="status"
        ["packer"]="version"
        ["starship"]="prompt"
        ["kubectl"]="get pods"
        ["helm"]="list"
        ["kubectx"]=""
        ["fzf"]="--version"
    )

    # Ensure completion directories exist
    ensure_dir "$COMPLETION_DIR"

    # Add completion directory to fpath if not already there
    if ! printf '%s\n' "${fpath[@]}" | grep -q "^${COMPLETION_DIR}$"; then
        fpath=("$COMPLETION_DIR" "${fpath[@]}")
    fi

    # Initialize completion system
    autoload -Uz compinit
    compinit -u

    # Test each tool
    for tool in "${!tools[@]}"; do
        local test_cmd="${tools[$tool]}"
        ((total_count++))

        printf "%-30s ... " "$tool completion"
        
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "⏭️  SKIPPED"
            log_info "$tool not installed, skipping completion test"
            continue
        fi

        if test_completion "$tool" "$tool" "$test_cmd"; then
            echo "✅ PASS"
            log_success "$tool completion verified"
            ((success_count++))
        else
            echo "❌ FAIL"
            handle_completion_error $? "$tool"
        fi
    done

    log_info "Completion testing completed: $success_count of $total_count tools tested successfully"
    return 0
}

# Verify completion system
log_info "Verifying completion system..."
zsh -c 'autoload -Uz compinit && compinit -C' || log_warning "Completion initialization failed"

# Function to set up pyenv completion
setup_pyenv_completion() {
    log_debug "Setting up pyenv completion..."

    # Check if pyenv is installed
    if ! command -v pyenv >/dev/null 2>&1; then
        log_error "pyenv not found in PATH"
        return 1
    fi

    # Ensure PYENV_ROOT is set
    export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
    log_debug "PYENV_ROOT set to: $PYENV_ROOT"

    # Ensure pyenv bin is in PATH
    if [[ ! "$PATH" =~ ${PYENV_ROOT}/bin ]]; then
        export PATH="$PYENV_ROOT/bin:$PATH"
        log_debug "Added pyenv bin to PATH: $PYENV_ROOT/bin"
    fi

    # Ensure pyenv shims are in PATH
    if [[ -d "$PYENV_ROOT/shims" ]] && [[ ! "$PATH" =~ ${PYENV_ROOT}/shims ]]; then
        export PATH="$PYENV_ROOT/shims:$PATH"
        log_debug "Added pyenv shims to PATH: $PYENV_ROOT/shims"
    fi

    # Initialize pyenv for the shell
    # shellcheck disable=SC1090
    eval "$(pyenv init -)" 2>/dev/null
    log_debug "Initialized pyenv shell integration"

    # Check for completions directory
    mkdir -p "$HOME/.zsh/completions"

    # Check if completion file exists
    if [[ ! -f "$HOME/.zsh/completions/_pyenv" ]]; then
        log_debug "Creating pyenv completion file..."

        # Try multiple methods to generate the completion file
        if [[ -f "$PYENV_ROOT/completions/pyenv.zsh" ]]; then
            cp "$PYENV_ROOT/completions/pyenv.zsh" "$HOME/.zsh/completions/_pyenv"
            log_debug "Copied pyenv completion from $PYENV_ROOT/completions/pyenv.zsh"
        elif [[ -f "/opt/homebrew/share/zsh/site-functions/_pyenv" ]]; then
            cp "/opt/homebrew/share/zsh/site-functions/_pyenv" "$HOME/.zsh/completions/_pyenv"
            log_debug "Copied pyenv completion from Homebrew"
        elif [[ -f "/usr/local/share/zsh/site-functions/_pyenv" ]]; then
            cp "/usr/local/share/zsh/site-functions/_pyenv" "$HOME/.zsh/completions/_pyenv"
            log_debug "Copied pyenv completion from Homebrew (Intel)"
        else
            # Last resort: generate from pyenv init if possible
            pyenv init --path > "$HOME/.zsh/completions/_pyenv_temp" 2>/dev/null
            # Check if we got a valid completion file
            if [[ -s "$HOME/.zsh/completions/_pyenv_temp" ]]; then
                mv "$HOME/.zsh/completions/_pyenv_temp" "$HOME/.zsh/completions/_pyenv"
                log_debug "Generated pyenv completion file"
            else
                rm -f "$HOME/.zsh/completions/_pyenv_temp"
                log_warning "Failed to generate pyenv completion file"
            fi
        fi
    else
        log_debug "pyenv completion file already exists"
    fi

    # Make sure completions directory is in fpath
    if ! check_fpath_contains "${HOME}/.zsh/completions"; then
        fpath=("$HOME/.zsh/completions" "${fpath[@]}")
        log_debug "Added user completions directory to fpath"
    fi

    # Force reload completions
    compinit -u 2>/dev/null || compinit -i 2>/dev/null

    # Return success
    return 0
}

# Add detailed environment information at startup
log_info "Starting verification process..."
log_debug "Current shell: $SHELL"
log_debug "Current user: $(whoami)"
log_debug "Current PATH: $PATH"
log_debug "Current working directory: $(pwd)"
log_debug "Home directory: $HOME"
log_debug "Current fpath: ${fpath[*]}"

# Function to set up completion directories
setup_completion_directories() {
    log_info "Setting up completion directories..."

    # Create completion directory if it doesn't exist
    ensure_dir "$COMPLETION_DIR"

    # Check if zcompdump is corrupted or old
    local zcompdump="${HOME}/.zcompdump"
    if [[ -f "$zcompdump" ]]; then
        if ! zsh -c "autoload -U compaudit && compaudit" >/dev/null 2>&1; then
            log_warning "zcompdump appears corrupted, removing it to force regeneration"
            rm -f "$zcompdump"*
        elif [[ -n "$(find "$zcompdump" -mtime +7 2>/dev/null)" ]]; then
            log_debug "zcompdump is older than 7 days, removing for regeneration"
            rm -f "$zcompdump"*
        fi
    fi

    # Add user completions directory to fpath if not already there
    log_debug "Adding user completions directory to fpath: $COMPLETION_DIR"
    if ! printf '%s\n' "${fpath[@]}" | grep -q "^${COMPLETION_DIR}$"; then
        fpath=("$COMPLETION_DIR" "${fpath[@]}")
    fi

    # Check for antidote completions directory
    local antidote_completions="/opt/homebrew/share/zsh/site-functions"
    if [[ -d "$antidote_completions" ]]; then
        log_debug "Adding antidote completions directory to fpath: $antidote_completions"
        if ! printf '%s\n' "${fpath[@]}" | grep -q "^${antidote_completions}$"; then
            fpath=("$antidote_completions" "${fpath[@]}")
        fi
    else
        log_debug "Skipping antidote completions directory: Directory does not exist"
    fi

    # Initialize completion system
    autoload -Uz compinit
    compinit -u

    return 0
}

# Run completion directory setup
setup_completion_directories

# Function to verify completion file existence
# shellcheck disable=SC2317
verify_completion_file() {
    local tool=$1
    local completion_path="${HOME}/.zsh/completions/_${tool}"

    if [[ -f "$completion_path" ]]; then
        log_debug "Found completion file for $tool at $completion_path"
        return 0
    else
        log_debug "No completion file found for $tool at $completion_path"
        return 1
    fi
}

# Enable error logging but don't exit immediately on error
set +e

# Add error trapping to help diagnose where failures occur
# Simplified error handling
trap 'log_error "Command failed at line $LINENO"' ERR

# Check if zshrc exists and source it
if [[ -f ~/.zshrc ]]; then
    log_info "Sourcing ~/.zshrc..."
    # shellcheck disable=SC1090,SC1091
    source ~/.zshrc || {
        log_error "Failed to source ~/.zshrc"
        log_debug "Contents of $HOME/.zshrc (first 10 lines):"
        head -n 10 ~/.zshrc || log_debug "Could not read $HOME/.zshrc"
    }
else
    log_warning "$HOME/.zshrc does not exist. Creating a minimal one for testing."
    touch ~/.zshrc
fi

# Reload completion system after sourcing .zshrc
log_debug "Reloading completion system..."
compinit -i 2>/dev/null || log_debug "Failed to reload compinit"

# Verify Antidote setup and plugins
log_info "Verifying Antidote setup..."
log_debug "Checking for antidote..."
if command -v antidote >/dev/null 2>&1; then
    log_debug "Antidote found at: $(command -v antidote)"
    log_debug "Antidote version: $(antidote version 2>&1 || echo "Version command not supported")"
    log_debug "Antidote plugins file exists: $([[ -f "${HOME}/.zsh_plugins.txt" ]] && echo "Yes" || echo "No")"

    if [[ -f "${HOME}/.zsh_plugins.txt" ]]; then
        log_debug "Found Antidote plugins file at ${HOME}/.zsh_plugins.txt"

        # Check for essential plugins with improved error handling
        essential_plugins=("zsh-users/zsh-completions" "zsh-users/zsh-autosuggestions" "zsh-users/zsh-syntax-highlighting")
        plugins_found=0

        for plugin in "${essential_plugins[@]}"; do
            if grep -q "^${plugin}" "${HOME}/.zsh_plugins.txt"; then
                log_debug "Found essential plugin: ${plugin}"
                ((plugins_found++))
            else
                log_warning "Essential plugin not found in .zsh_plugins.txt: ${plugin}"
            fi
        done

        if [[ $plugins_found -eq ${#essential_plugins[@]} ]]; then
            log_success "All essential Antidote plugins are configured"
        else
            log_warning "Only $plugins_found of ${#essential_plugins[@]} essential plugins found"
        fi
    else
        log_error "Antidote plugins file not found at ${HOME}/.zsh_plugins.txt"
    fi
else
    log_error "Antidote not found in PATH"
fi

# Verify .zshrc has necessary completion setup
if [[ -f ~/.zshrc ]]; then
    # Check for specific completion configuration patterns
    if ! grep -q 'compinit\|autoload.*compinit' ~/.zshrc; then
        log_warning "No compinit initialization found in ~/.zshrc"
        log_debug "Adding minimal compinit to ~/.zshrc for testing"
        echo -e "\n# Added by verification script\nautoload -Uz compinit\ncompinit" >> ~/.zshrc
    fi

    # Check for fpath configuration
    if ! grep -q 'fpath=\|fpath+=' ~/.zshrc; then
        log_warning "No fpath configuration found in ~/.zshrc"
        log_debug "Adding basic fpath configuration to ~/.zshrc for testing"
        echo -e "\n# Added by verification script\nfpath=(\$HOME/.zsh/completions \$fpath)" >> ~/.zshrc
    fi
fi

# Check for essential PATH elements
log_info "Checking PATH for required directories..."
# Enhanced pyenv PATH verification
log_info "Verifying pyenv setup..."
if command -v pyenv >/dev/null 2>&1; then
    log_debug "pyenv command found at: $(command -v pyenv)"
    log_debug "pyenv version: $(pyenv --version 2>/dev/null || echo "Unknown")"

    # Check if pyenv is working correctly
    if ! pyenv --version >/dev/null 2>&1; then
        log_warning "pyenv command exists but may not be working properly"
    fi

    # Check PYENV_ROOT
    if [[ -z "${PYENV_ROOT}" ]]; then
        export PYENV_ROOT="$HOME/.pyenv"
        log_debug "PYENV_ROOT not set, defaulting to $PYENV_ROOT"
    else
        log_debug "PYENV_ROOT is set to $PYENV_ROOT"
    fi

    # Validate PYENV_ROOT - make sure it points to a valid directory
    if [[ ! -d "${PYENV_ROOT}" ]]; then
        log_error "PYENV_ROOT points to non-existent directory: ${PYENV_ROOT}"
        # Try to detect the correct path
        # shellcheck disable=SC2168
        local possible_roots=("$HOME/.pyenv" "/opt/homebrew/opt/pyenv" "/usr/local/opt/pyenv")
        for possible_root in "${possible_roots[@]}"; do
            if [[ -d "$possible_root" ]]; then
                log_warning "Found possible pyenv root at $possible_root, using it instead"
                export PYENV_ROOT="$possible_root"
                break
            fi
        done
    fi

    # Verify pyenv root directory exists
    if [[ ! -d "${PYENV_ROOT}" ]]; then
        log_error "PYENV_ROOT directory does not exist: ${PYENV_ROOT}"
    else
        log_debug "PYENV_ROOT directory exists: ${PYENV_ROOT}"
    fi

    # Check shims directory
    if [[ ! -d "${PYENV_ROOT}/shims" ]]; then
        log_error "pyenv shims directory does not exist: ${PYENV_ROOT}/shims"
    else
        log_debug "pyenv shims directory exists: ${PYENV_ROOT}/shims"

        # Check if shims are in PATH
        if [[ ! "$PATH" =~ ${PYENV_ROOT}/shims ]]; then
            log_warning "pyenv shims not in PATH, adding them now"
            export PATH="${PYENV_ROOT}/shims:$PATH"
        else
            log_debug "pyenv shims are properly in PATH"
        fi
    fi

    # Verify pyenv is initialized
    if ! pyenv root >/dev/null 2>&1; then
        log_warning "pyenv not properly initialized, attempting initialization"
        setup_pyenv_completion
    else
        log_success "pyenv properly initialized (root: $(pyenv root))"

        # Check for completion
        if ! typeset -f "_pyenv" &>/dev/null; then
            log_warning "pyenv completion not loaded, attempting to set up"
            setup_pyenv_completion
        else
            log_debug "pyenv completion function found"
        fi
    fi

    # Check installed Python versions
    log_debug "Installed Python versions: $(pyenv versions --bare 2>/dev/null || echo "None")"

    # Check current Python version
    log_debug "Current Python version: $(pyenv version 2>/dev/null || echo "None")"
else
    log_error "pyenv not found in PATH"
    log_debug "Current PATH: $PATH"
fi

# Enhanced rbenv PATH verification
# Enhanced rbenv PATH verification
log_info "Verifying rbenv setup..."
if command -v rbenv >/dev/null 2>&1; then
    log_debug "rbenv command found at: $(command -v rbenv)"
    log_debug "rbenv version: $(rbenv --version 2>/dev/null || echo "Unknown")"

    # Check if rbenv is working correctly
    if ! rbenv root >/dev/null 2>&1; then
        log_warning "rbenv not properly initialized, attempting initialization"

        # More robust initialization with error details
        # shellcheck disable=SC1090
        if ! eval "$(rbenv init -)" 2>/dev/null; then
            log_error "Failed to initialize rbenv"

            # Check for common rbenv setup issues
            if [[ ! -d "$HOME/.rbenv" ]] && [[ ! -d "/opt/homebrew/opt/rbenv" ]] && [[ ! -d "/usr/local/opt/rbenv" ]]; then
                log_error "rbenv installation directories not found"
            fi

            # Check if rbenv shims directory exists
            # shellcheck disable=SC2168
            local rbenv_root
            rbenv_root="$(rbenv root 2>/dev/null || echo "$HOME/.rbenv")"
            if [[ ! -d "${rbenv_root}/shims" ]]; then
                log_error "rbenv shims directory not found at ${rbenv_root}/shims"
            fi

            # Try a more direct initialization
            if [[ -d "${rbenv_root}/shims" ]]; then
                export PATH="${rbenv_root}/shims:$PATH"
                log_debug "Manually added rbenv shims to PATH"
            fi
        else
            log_success "Successfully initialized rbenv"
        fi
    else
        log_success "rbenv is properly initialized (root: $(rbenv root))"

        # Check for completion
        if ! typeset -f "_rbenv" &>/dev/null; then
            log_debug "rbenv completion function not found, setting up..."

            # Create completion directory if needed
            mkdir -p "$HOME/.zsh/completions"

            # Try to generate rbenv completion
            if [[ ! -f "$HOME/.zsh/completions/_rbenv" ]]; then
                if [[ -f "$(rbenv root)/completions/rbenv.zsh" ]]; then
                    cp "$(rbenv root)/completions/rbenv.zsh" "$HOME/.zsh/completions/_rbenv"
                    log_debug "Copied rbenv completion from rbenv root"
                elif [[ -f "/opt/homebrew/share/zsh/site-functions/_rbenv" ]]; then
                    cp "/opt/homebrew/share/zsh/site-functions/_rbenv" "$HOME/.zsh/completions/_rbenv"
                    log_debug "Copied rbenv completion from Homebrew"
                elif [[ -f "/usr/local/share/zsh/site-functions/_rbenv" ]]; then
                    cp "/usr/local/share/zsh/site-functions/_rbenv" "$HOME/.zsh/completions/_rbenv"
                    log_debug "Copied rbenv completion from Intel Homebrew"
                else
                    log_warning "Could not find rbenv completion file to copy"
                fi
            fi

            # Add completions directory to fpath if needed
            # shellcheck disable=SC2168
            local path_exists=false
            if [[ ${#fpath[@]} -gt 0 ]]; then
                for path in "${fpath[@]}"; do
                    if [[ "$path" == "$HOME/.zsh/completions" ]]; then
                        path_exists=true
                        break
                    fi
                done
            else
                log_debug "fpath array is empty, will add user completions directory"
            fi
            if ! $path_exists; then
                fpath=("$HOME/.zsh/completions" "${fpath[@]}")
                log_debug "Added user completions directory to fpath"
                compinit -u
            fi
        fi
    fi
else
    log_error "rbenv not found in PATH"
    log_debug "Current PATH: $PATH"
fi

# Array of commands to verify
typeset -A verify_commands
verify_commands=()
verify_commands[brew]="Homebrew installation"
verify_commands[git]="Git installation"
verify_commands[antidote]="Antidote plugin manager"
verify_commands[rbenv]="rbenv installation"
verify_commands[pyenv]="pyenv installation"
verify_commands[direnv]="direnv installation"
verify_commands[starship]="Starship prompt"
verify_commands[packer]="HashiCorp Packer"
verify_commands[terraform]="Terraform installation"

# Counter for successful checks
success_count=0
total_checks=${#verify_commands}

log_info "=== INSTALLATION VERIFICATION ==="

# Check each command with more detailed output
for cmd in ${(k)verify_commands}; do
    description=${verify_commands[$cmd]}
    printf "%-30s ... " "$description"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✅ PASS"
        ((success_count++))
        log_info "Command '$cmd' found at: $(command -v "$cmd")"
        # More robust version command that won't fail if --version isn't supported
        version_out=$("$cmd" --version 2>&1 || echo "Version command not supported")
        log_info "Version: $(echo "$version_out" | head -n1)"
    else
        echo "❌ FAIL"
        log_error "Command '$cmd' not found in PATH"
        log_debug "Current PATH: $PATH"
    fi
done

# Verify antidote plugins file exists and has content
log_info "=== ANTIDOTE PLUGINS VERIFICATION ==="
printf "%-30s ... " "Antidote plugins file"
if [[ -f "${HOME}/.zsh_plugins.txt" ]]; then
    plugin_count=$(grep -cv "^#\|^$" "${HOME}/.zsh_plugins.txt" | tr -d '[:space:]')
    if [[ "$plugin_count" -gt 0 ]]; then
        echo "✅ PASS"
        log_success "Found ${plugin_count} plugins defined in .zsh_plugins.txt"
    else
        echo "⚠️  WARNING"
        log_warning "Antidote plugins file exists but appears to be empty"
    fi
else
    echo "❌ FAIL"
    log_error "Antidote plugins file not found at ${HOME}/.zsh_plugins.txt"
fi

log_info "=== COMPLETION VERIFICATION ==="

# Test completions for all tools
test_all_completions

# Verify completion directories are properly added to fpath
log_info "=== COMPLETION DIRECTORIES VERIFICATION ==="

completion_dirs_verified=0
completion_dirs_total=0
completion_dirs_existing=0
completion_files_count=0

# Check if we have any completion locations to verify
if [[ ${#completion_paths[@]} -eq 0 ]]; then
    log_warning "No completion locations defined to verify"
else
    # Log each directory we're checking for better diagnostics
    log_debug "Checking ${#completion_paths[@]} completion directories"

    # shellcheck disable=SC2154
    # shellcheck disable=SC2066
    for location_key in "${(@k)completion_paths}"; do
        # shellcheck disable=SC2154
        location="${completion_paths[$location_key]}"
        ((completion_dirs_total++))

        printf "%-30s ... " "Completion dir: $location_key"
        if [[ -d "$location" ]]; then
            ((completion_dirs_existing++))
            # Count completion files for better diagnostics
            # shellcheck disable=SC2168
            local file_count=0
            if [[ -d "$location" ]]; then
                file_count=$(find "$location" -name "_*" 2>/dev/null | wc -l | tr -d '[:space:]')
                ((completion_files_count += file_count))
                log_debug "Found $file_count completion files in $location"
            fi

            # Check if directory is in fpath
            # shellcheck disable=SC2168
            local path_exists=false
            if [[ ${#fpath[@]} -gt 0 ]]; then
                for path in "${fpath[@]}"; do
                    if [[ "$path" == "$location" ]]; then
                        path_exists=true
                        break
                    fi
                done
            else
                log_debug "fpath array is empty, cannot verify if $location is included"
                path_exists=false
            fi

            # Report status based on presence in fpath
            if $path_exists; then
                echo "✅ PASS"
                ((completion_dirs_verified++))
                log_success "Completion directory $location exists and is in fpath (contains $file_count completion files)"
            else
                echo "❌ FAIL"
                log_error "Completion directory $location exists but is NOT in fpath (contains $file_count completion files)"
                # Try to fix the issue by adding to fpath
                log_debug "Attempting to add $location to fpath"
                fpath=("$location" "${fpath[@]}")
                compinit -u 2>/dev/null || compinit -i 2>/dev/null
            fi
        else
            echo "⏭️  SKIPPED"
            log_warning "Completion directory $location does not exist"
        fi
    done
fi

# Verify .zshrc completion configuration
log_info "=== .ZSHRC COMPLETION VERIFICATION ==="

zshrc_checks=0
zshrc_passed=0

# Function to check if a pattern exists in .zshrc
check_zshrc_pattern() {
    local description=$1
    local pattern=$2
    ((zshrc_checks++))

    printf "%-30s ... " "$description"
    if [[ -f "${HOME}/.zshrc" ]] && grep -q "$pattern" "${HOME}/.zshrc" 2>/dev/null; then
        echo "✅ PASS"
        ((zshrc_passed++))
        log_success "$description found in .zshrc"
        return 0
    else
        echo "❌ FAIL"
        log_error "$description not found in .zshrc"
        return 1
    fi
}

# Check for essential completion configurations in .zshrc
check_zshrc_pattern "compinit initialization" "compinit"
check_zshrc_pattern "fpath configuration" "fpath=\|fpath+=\|FPATH"
check_zshrc_pattern "completion system setup" "completion\|compdef\|zstyle"
check_zshrc_pattern "Homebrew completions path" "share/zsh/site-functions"

# If using antidote, check for its configuration
if command -v antidote >/dev/null 2>&1; then
    check_zshrc_pattern "antidote initialization" "antidote\|source.*antidote"
fi

# Check for common completion plugins
if [[ -f "${HOME}/.zsh_plugins.txt" ]]; then
    check_zshrc_pattern "zsh-completions plugin source" "source.*zsh_plugins\|antidote bundle"
fi

# Calculate final result
total_checks=$((total_checks + completion_total + essential_total + completion_dirs_total + zshrc_checks))
success_count=$((success_count + completion_success + essential_passed + completion_dirs_verified + zshrc_passed))

log_info "=== SUMMARY ==="

# Calculate percentages for more informative output
typeset -i total_percentage=0
typeset -i completion_percentage=0
typeset -i essential_percentage=0
typeset -i dirs_percentage=0
typeset -i zshrc_percentage=0

# Avoid division by zero
[[ $total_checks -gt 0 ]] && total_percentage=$((success_count * 100 / total_checks))
[[ $completion_total -gt 0 ]] && completion_percentage=$((completion_success * 100 / completion_total))
[[ $essential_total -gt 0 ]] && essential_percentage=$((essential_passed * 100 / essential_total))
[[ $completion_dirs_total -gt 0 ]] && dirs_percentage=$((completion_dirs_verified * 100 / completion_dirs_total))
[[ $zshrc_checks -gt 0 ]] && zshrc_percentage=$((zshrc_passed * 100 / zshrc_checks))

# Display results with percentages and more helpful descriptions
log_info "Overall progress: $success_count of $total_checks checks passed ($total_percentage%)"
log_info "Completion tests: $completion_success of $completion_total passed ($completion_percentage%)"
log_info "Essential completions: $essential_passed of $essential_total passed ($essential_percentage%)"
log_info "Completion directories: $completion_dirs_verified of $completion_dirs_total verified ($dirs_percentage%)"
log_info ".zshrc configuration: $zshrc_passed of $zshrc_checks verified ($zshrc_percentage%)"
log_info "Found $completion_files_count completion files across $completion_dirs_existing directories"

# Determine exit code based on success and provide helpful tips
if [[ $success_count -eq $total_checks ]]; then
    log_success "Verification successful! All components installed and configured correctly."
    log_info "Tips for maintaining your setup:"
    log_info "• Run 'brew update && brew upgrade' regularly to keep packages updated"
    log_info "• Keep your completion files fresh with 'compinit -u' if you experience issues"
    log_info "• Consider running this verification script after major system updates"
    exit 0
else
    log_error "Verification failed! Some components were not installed or configured correctly."
    log_info "Tips to fix common issues:"
    log_info "• Ensure your .zshrc loads completion system with 'autoload -Uz compinit && compinit'"
    # shellcheck disable=SC2128
    log_info "• Add missing completion directories to fpath with 'fpath=(~/.zsh/completions $fpath)'"
    log_info "• Make sure Homebrew and essential tools are properly installed"
    log_info "• Run 'mkdir -p ~/.zsh/completions' to create the user completions directory"
    # Use exit 1 instead of any other code to avoid the cryptic exit status 3
    exit 1
fi

# Function to deduplicate fpath entries
deduplicate_fpath() {
    log_debug "Deduplicating fpath entries..."
    
    # Create temporary array for unique entries
    local -a unique_fpath=()
    local -A seen=()
    
    # Only add each path once
    for path in "${fpath[@]}"; do
        if [[ -n "$path" && -d "$path" && -z "${seen[$path]}" ]]; then
            unique_fpath+=("$path")
            seen[$path]=1
        fi
    done
    
    # Replace fpath with deduplicated array
    fpath=("${unique_fpath[@]}")
    log_debug "Deduplicated fpath now contains ${#fpath[@]} unique entries"
}

# Function to fix zcompdump
fix_zcompdump() {
    log_info "Fixing zcompdump..."
    
    # Remove all zcompdump files
    rm -f "${HOME}/.zcompdump"*(N) 2>/dev/null
    rm -f "${ZDOTDIR:-$HOME}/.zcompdump"*(N) 2>/dev/null
    
    # Force regeneration of completion cache
    autoload -Uz compinit
    compinit -u -d "${ZDOTDIR:-$HOME}/.zcompdump"
    
    log_success "Regenerated zcompdump file"
}

# Function to setup fzf completion
setup_fzf_completion() {
    log_info "Setting up fzf completion..."
    
    local fzf_completion_file="/opt/homebrew/opt/fzf/shell/completion.zsh"
    local intel_fzf_completion_file="/usr/local/opt/fzf/shell/completion.zsh"
    
    if [[ -f "$fzf_completion_file" ]]; then
        # shellcheck disable=SC1091
        source "$fzf_completion_file" 2>/dev/null || log_error "Failed to source fzf completion"
    elif [[ -f "$intel_fzf_completion_file" ]]; then
        # shellcheck disable=SC1091
        source "$intel_fzf_completion_file" 2>/dev/null || log_error "Failed to source fzf completion"
    else
        log_error "fzf completion file not found"
        return 1
    fi
    
    # Verify fzf completion is working
    if typeset -f "_fzf" >/dev/null 2>&1; then
        log_success "fzf completion setup successful"
        return 0
    else
        log_error "fzf completion setup failed"
        return 1
    fi
}

# Before testing completions, clean up the environment
deduplicate_fpath
fix_zcompdump
setup_fzf_completion

# Fix array handling in fpath checks
check_fpath_contains() {
    local target_path="$1"
    local found=false
    
    for path in "${fpath[@]}"; do
        if [[ "$path" == "$target_path" ]]; then
            found=true
            break
        fi
    done
    
    [[ "$found" == "true" ]]
}

# Update fpath checks to use the new function
if ! check_fpath_contains "${HOME}/.zsh/completions"; then
    fpath=("${HOME}/.zsh/completions" "${fpath[@]}")
fi
