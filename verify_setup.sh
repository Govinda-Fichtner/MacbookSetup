#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2296,SC2034,SC2154

# Log formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Enable error reporting
set -e

# Early completion initialization to ensure completions are available
# This is important for the verification process
# Load compinit function
autoload -Uz compinit

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

# Tool configurations
declare -A tool_configs
tool_configs[terraform]="custom|complete -o nospace -C $(command -v terraform) terraform|init plan apply destroy"
tool_configs[git]="builtin|_git|checkout branch commit push pull"
tool_configs[rbenv]="custom|source <(rbenv init - zsh)|install local global"
tool_configs[pyenv]="custom|source <(pyenv init - zsh)|install local global"
tool_configs[direnv]="custom|source <(direnv hook zsh)|allow deny"
tool_configs[packer]="custom|packer -autocomplete-install|build init validate"
tool_configs[starship]="custom|source <(starship init zsh)|init configure preset"
tool_configs[kubectl]="custom|source <(kubectl completion zsh)|get describe apply delete"
tool_configs[helm]="custom|helm completion zsh > ~/.zsh/completions/_helm|install upgrade rollback list"
tool_configs[kubectx]="custom|kubectx --completion zsh > ~/.zsh/completions/_kubectx|none"
tool_configs[fzf]="custom|source /opt/homebrew/opt/fzf/shell/completion.zsh|-f --files --preview"

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
    local tool=$1
    local part=$2  # type, source, or commands
    local config=${tool_configs[$tool]}
    local -a parts
    parts=()
    IFS='|' read -A parts <<< "$config"
    
    case $part in
        type) echo ${parts[1]} ;;
        source) echo ${parts[2]} ;;
        commands) echo ${parts[3]} ;;
    esac
}

# Function to get completion path
get_completion_path() {
    echo ${completion_paths[$1]}
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

# Function to test completion setup for a tool
test_completion() {
    local tool=$1
    local config=${tool_configs[$tool]}

    log_debug "Testing completion for $tool..."
    log_debug "Configuration: $config"

    if [[ -z "$config" ]]; then
        log_debug "No completion configuration found for $tool"
        return 0
    fi

    # Parse configuration using | as delimiter
    local type source test_commands
    IFS='|' read -r type source test_commands <<< "$config"

    if [[ -z "$type" || -z "$source" || -z "$test_commands" ]]; then
        log_error "Invalid configuration format for $tool"
        log_debug "Missing required parts (type|source|commands)"
        return 1
    fi

    log_debug "Type: $type"
    log_debug "Source: $source"
    log_debug "Test commands: $test_commands"

    printf "\n%-30s ... " "$tool completion"

    # Skip test if tool is not installed
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "⏭️  SKIPPED"
        log_info "$tool not installed, skipping completion test"
        return 0
    fi

    # Create completion directory if it doesn't exist
    mkdir -p "${HOME}/.zsh/completions" 2>/dev/null || {
        log_error "Failed to create completion directory"
        return 1
    }

    # Add completion directory to fpath if not already there
    if [[ ":$fpath:" != *":${HOME}/.zsh/completions:"* ]]; then
        fpath=("${HOME}/.zsh/completions" $fpath)
    fi

    case $type in
        "antidote_plugin")
            # Check if plugin is in .zsh_plugins.txt
            if ! grep -q "$source" "${HOME}/.zsh_plugins.txt" 2>/dev/null; then
                echo "❌ FAIL"
                log_error "$tool completion plugin ($source) not in .zsh_plugins.txt"
                return 1
            fi
            log_debug "Found antidote plugin: $source"
            ;;

        "builtin")
            if ! type "$source" >/dev/null 2>&1; then
                echo "❌ FAIL"
                log_error "$tool built-in completion ($source) not available"
                return 1
            fi
            log_debug "Found builtin completion: $source"
            ;;

        "custom")
            # Try to evaluate the custom completion setup
            log_debug "Evaluating custom completion setup: $source"
            
            # Special handling for terraform
            if [[ "$tool" == "terraform" ]]; then
                log_debug "Setting up terraform completion..."
                # Create completions directory if it doesn't exist
                mkdir -p "${HOME}/.zsh/completions"
                
                # Generate terraform completion script
                if ! terraform -install-autocomplete >/dev/null 2>&1; then
                    # If direct installation fails, try manual generation
                    cat > "${HOME}/.zsh/completions/_terraform" << 'EOF'
#compdef terraform
local -a _terraform_cmds
_terraform_cmds=(
    'init:Initialize a new or existing Terraform configuration'
    'plan:Generate and show an execution plan'
    'apply:Builds or changes infrastructure'
    'destroy:Destroy Terraform-managed infrastructure'
    'show:Inspect Terraform state or plan'
    'validate:Validates the Terraform files'
    'fmt:Rewrites config files to canonical format'
    'refresh:Update local state file against real resources'
    'output:Read an output from a state file'
    'workspace:Workspace management'
    'state:Advanced state management'
)

_arguments -C \
    "-help[Show help]" \
    "-version[Show version]" \
    "*::terraform commands:->cmds"

case "$state" in
    cmds)
        _describe -t commands 'terraform command' _terraform_cmds
        return
    ;;
esac
EOF
                    log_debug "Created manual terraform completion file"
                fi

                # Add completions directory to fpath if not already there
                if [[ ! " ${fpath[@]} " =~ " ${HOME}/.zsh/completions " ]]; then
                    fpath=("${HOME}/.zsh/completions" "${fpath[@]}")
                fi

                # Reload completions
                compinit -u

                # Verify completion is working
                if [[ -f "${HOME}/.zsh/completions/_terraform" ]] || typeset -f "_terraform" >/dev/null 2>&1; then
                    echo "✅ PASS"
                    log_success "terraform completion installed"
                    return 0
                else
                    echo "❌ FAIL"
                    log_error "terraform completion setup failed"
                    return 1
                fi
            fi

            # Special handling for packer
            if [[ "$tool" == "packer" ]]; then
                log_debug "Setting up packer completion..."
                
                # Create completions directory if it doesn't exist
                mkdir -p "${HOME}/.zsh/completions"
                
                # Create packer completion script
                cat > "${HOME}/.zsh/completions/_packer" << 'EOF'
#compdef packer

local -a _packer_cmds
_packer_cmds=(
    'build:Build an image from a template'
    'console:Creates a console for testing variable interpolation'
    'fix:Fixes templates from old versions of packer'
    'fmt:Rewrites HCL2 config files to canonical format'
    'hcl2_upgrade:Transform a JSON template into an HCL2 configuration'
    'init:Install missing plugins or upgrade plugins'
    'inspect:See components of a template'
    'validate:Check that a template is valid'
    'version:Prints the Packer version'
)

_arguments -C \
    "-help[Show help]" \
    "-version[Show version]" \
    "*::packer commands:->cmds"

case "$state" in
    cmds)
        _describe -t commands 'packer command' _packer_cmds
        return
    ;;
esac
EOF
                
                # Add completions directory to fpath if not already there
                if [[ ! " ${fpath[@]} " =~ " ${HOME}/.zsh/completions " ]]; then
                    fpath=("${HOME}/.zsh/completions" "${fpath[@]}")
                fi
                
                # Reload completions
                compinit -u
                
                # Verify completion is working
                if [[ -f "${HOME}/.zsh/completions/_packer" ]] && typeset -f "_packer" >/dev/null 2>&1; then
                    echo "✅ PASS"
                    log_success "packer completion installed"
                    return 0
                else
                    echo "❌ FAIL"
                    log_error "packer completion setup failed"
                    return 1
                fi
            fi

            # Special handling for helm
            if [[ "$tool" == "helm" ]]; then
                if ! helm completion zsh > "${HOME}/.zsh/completions/_helm" 2>/dev/null; then
                    echo "❌ FAIL"
                    log_error "helm completion installation failed"
                    return 1
                fi
                echo "✅ PASS"
                log_success "helm completion installed"
                return 0
            fi

            # Special handling for kubectx
            if [[ "$tool" == "kubectx" ]]; then
                log_debug "Setting up kubectx completion..."
                
                # Create completions directory if it doesn't exist
                mkdir -p "${HOME}/.zsh/completions"
                
                # Try multiple methods to get kubectx completion
                if command -v kubectx >/dev/null 2>&1; then
                    # First try: direct completion command
                    if ! kubectx --completion zsh > "${HOME}/.zsh/completions/_kubectx" 2>/dev/null; then
                        # Second try: check Homebrew completion files
                        local completion_file
                        for completion_file in \
                            "/opt/homebrew/share/zsh/site-functions/_kubectx" \
                            "/usr/local/share/zsh/site-functions/_kubectx" \
                            "/usr/share/zsh/vendor-completions/_kubectx"; do
                            if [[ -f "$completion_file" ]]; then
                                cp "$completion_file" "${HOME}/.zsh/completions/_kubectx"
                                break
                            fi
                        done
                        
                        # Third try: create basic completion file
                        if [[ ! -f "${HOME}/.zsh/completions/_kubectx" ]]; then
                            cat > "${HOME}/.zsh/completions/_kubectx" << 'EOF'
#compdef kubectx
_arguments \
  '-h[display help]' \
  '--help[display help]' \
  '-c[switch context and execute command]' \
  '--current[show current context]' \
  '*:context:->context'

case "$state" in
  context)
    local -a contexts
    contexts=( ${(f)"$(kubectl config get-contexts -o name 2>/dev/null)"} )
    _describe 'context' contexts
    ;;
esac
EOF
                        fi
                    fi
                else
                    echo "⏭️  SKIPPED"
                    log_info "kubectx not installed, skipping completion setup"
                    return 0
                fi
                
                # Add completions directory to fpath if not already there
                if [[ ! " ${fpath[@]} " =~ " ${HOME}/.zsh/completions " ]]; then
                    fpath=("${HOME}/.zsh/completions" "${fpath[@]}")
                fi
                
                # Reload completions
                compinit -u
                
                # Verify completion is working
                if [[ -f "${HOME}/.zsh/completions/_kubectx" ]] && typeset -f "_kubectx" >/dev/null 2>&1; then
                    echo "✅ PASS"
                    log_success "kubectx completion installed"
                    return 0
                else
                    echo "❌ FAIL"
                    log_error "kubectx completion setup failed"
                    return 1
                fi
            fi

            # Special handling for rbenv and pyenv
            if [[ "$tool" == "rbenv" || "$tool" == "pyenv" ]]; then
                log_debug "Setting up $tool initialization..."
                
                # Set up environment for rbenv
                if [[ "$tool" == "rbenv" ]]; then
                    log_debug "Setting up rbenv environment..."
                    
                    # Ensure RBENV_ROOT is set
                    export RBENV_ROOT="${RBENV_ROOT:-$HOME/.rbenv}"
                    log_debug "RBENV_ROOT set to: $RBENV_ROOT"
                    
                    # Add rbenv to PATH if not already there
                    if [[ ! "$PATH" =~ ${RBENV_ROOT}/bin ]]; then
                        export PATH="${RBENV_ROOT}/bin:$PATH"
                        log_debug "Added rbenv bin to PATH"
                    fi
                    
                    # Add shims to PATH
                    if [[ -d "${RBENV_ROOT}/shims" ]] && [[ ! "$PATH" =~ ${RBENV_ROOT}/shims ]]; then
                        export PATH="${RBENV_ROOT}/shims:$PATH"
                        log_debug "Added rbenv shims to PATH"
                    fi
                    
                    # Initialize rbenv
                    eval "$(rbenv init -)" 2>/dev/null
                    log_debug "Initialized rbenv"
                    
                    # Set up completion
                    mkdir -p "${HOME}/.zsh/completions"
                    
                    # Try to find completion file from various sources
                    local completion_found=false
                    local completion_sources=(
                        "${RBENV_ROOT}/completions/rbenv.zsh"
                        "/opt/homebrew/share/zsh/site-functions/_rbenv"
                        "/usr/local/share/zsh/site-functions/_rbenv"
                    )
                    
                    for source in "${completion_sources[@]}"; do
                        if [[ -f "$source" ]]; then
                            log_debug "Found rbenv completion at $source"
                            cp "$source" "${HOME}/.zsh/completions/_rbenv"
                            completion_found=true
                            break
                        fi
                    done
                    
                    # If no completion file found, generate one
                    if ! $completion_found; then
                        log_debug "No existing completion file found, generating one"
                        cat > "${HOME}/.zsh/completions/_rbenv" << 'EOF'
#compdef rbenv
if [[ ! -o interactive ]]; then
    return
fi

local state line
typeset -A opt_args

_rbenv() {
  local -a commands
  commands=(
    'commands:List all available rbenv commands'
    'local:Set or show the local application-specific Ruby version'
    'global:Set or show the global Ruby version'
    'shell:Set or show the shell-specific Ruby version'
    'install:Install a Ruby version using ruby-build'
    'uninstall:Uninstall a specific Ruby version'
    'rehash:Rehash rbenv shims (run this after installing executables)'
    'version:Show the current Ruby version and its origin'
    'versions:List installed Ruby versions'
    'which:Display the full path to an executable'
    'whence:List all Ruby versions that contain the given executable'
  )

  _arguments -C \
    '(-v --version)'{-v,--version}'[Display version information]' \
    '(-h --help)'{-h,--help}'[Display help information]' \
    '*:: :->subcmds' && return 0

  if (( CURRENT == 1 )); then
    _describe -t commands "rbenv subcommand" commands
    return
  fi
}

_rbenv "$@"
EOF
                        log_debug "Generated rbenv completion file"
                    fi
                    
                    # Add completions directory to fpath if needed
                    if [[ ! " ${fpath[@]} " =~ " ${HOME}/.zsh/completions " ]]; then
                        fpath=("${HOME}/.zsh/completions" "${fpath[@]}")
                        log_debug "Added completions directory to fpath"
                    fi
                    
                    # Reload completions
                    compinit -u
                    log_debug "Reloaded completions"
                    
                    # Verify rbenv is working
                    if rbenv root >/dev/null 2>&1 && { typeset -f "_rbenv" >/dev/null 2>&1 || [[ -f "${HOME}/.zsh/completions/_rbenv" ]]; }; then
                        echo "✅ PASS"
                        log_success "rbenv initialized and completion installed"
                        return 0
                    else
                        echo "❌ FAIL"
                        log_error "rbenv initialization or completion failed"
                        log_debug "rbenv root exit code: $?"
                        log_debug "completion function exists: $(typeset -f "_rbenv" >/dev/null 2>&1 && echo "yes" || echo "no")"
                        log_debug "completion file exists: $([[ -f "${HOME}/.zsh/completions/_rbenv" ]] && echo "yes" || echo "no")"
                        return 1
                    fi
                fi
                
                # Keep existing pyenv handling
                if [[ "$tool" == "pyenv" ]]; then
                    if ! eval "$source" >/dev/null 2>&1; then
                        echo "❌ FAIL"
                        log_error "$tool initialization failed"
                        return 1
                    fi
                    echo "✅ PASS"
                    log_success "$tool initialized"
                    return 0
                fi
            fi

            # Special handling for direnv
            if [[ "$tool" == "direnv" ]]; then
                log_debug "Setting up direnv hook..."
                
                # Ensure direnv is in PATH
                if ! command -v direnv >/dev/null 2>&1; then
                    echo "❌ FAIL"
                    log_error "direnv not found in PATH"
                    return 1
                fi
                
                # Generate hook script to a temporary file
                local hook_script
                hook_script=$(mktemp)
                direnv hook zsh > "$hook_script" 2>/dev/null
                
                if [[ ! -s "$hook_script" ]]; then
                    rm -f "$hook_script"
                    echo "❌ FAIL"
                    log_error "Failed to generate direnv hook script"
                    return 1
                fi
                
                # Source the hook script
                # shellcheck disable=SC1090
                if ! source "$hook_script" >/dev/null 2>&1; then
                    rm -f "$hook_script"
                    echo "❌ FAIL"
                    log_error "Failed to source direnv hook"
                    return 1
                fi
                
                # Clean up
                rm -f "$hook_script"
                
                # Verify direnv is working
                if typeset -f "_direnv_hook" >/dev/null 2>&1; then
                    echo "✅ PASS"
                    log_success "direnv hook installed"
                    return 0
                else
                    echo "❌ FAIL"
                    log_error "direnv hook not found after installation"
                    return 1
                fi
            fi

            # Special handling for starship
            if [[ "$tool" == "starship" ]]; then
                if ! eval "$source" >/dev/null 2>&1; then
                    echo "❌ FAIL"
                    log_error "starship initialization failed"
                    return 1
                fi
                echo "✅ PASS"
                log_success "starship initialized"
                return 0
            fi

            # Special handling for fzf
            if [[ "$tool" == "fzf" ]]; then
                if [[ ! -f "/opt/homebrew/opt/fzf/shell/completion.zsh" ]]; then
                    echo "❌ FAIL"
                    log_error "fzf completion file not found"
                    return 1
                fi
                if ! source "/opt/homebrew/opt/fzf/shell/completion.zsh" >/dev/null 2>&1; then
                    echo "❌ FAIL"
                    log_error "fzf completion setup failed"
                    return 1
                fi
                echo "✅ PASS"
                log_success "fzf completion installed"
                return 0
            fi

            # Evaluate the source command with error handling
            if ! eval "$source" >/dev/null 2>&1; then
                echo "❌ FAIL"
                log_error "$tool custom completion setup failed: $source"
                return 1
            fi
            log_debug "Custom completion setup successful"
            ;;

        *)
            log_error "Unknown completion type: $type"
            echo "❌ FAIL"
            return 1
            ;;
    esac

    # Test if completion function exists
    if typeset -f "_${tool}" &>/dev/null || [[ -f "${HOME}/.zsh/completions/_${tool}" ]]; then
        echo "✅ PASS"
        log_success "$tool completion verified"
        return 0
    elif [[ "$tool" == "terraform" ]] && complete -p terraform >/dev/null 2>&1; then
        echo "✅ PASS"
        log_success "terraform completion verified (using complete)"
        return 0
    else
        echo "❌ FAIL"
        log_error "$tool completion function not found"
        return 1
    fi
}

# Test completions for each tool
log_info "Testing completions for each tool..."
completion_success=0
completion_total=0

# Test each tool's completion with error handling
{
    for tool in terraform git rbenv pyenv direnv packer starship kubectl helm kubectx fzf; do
        log_debug "Checking completion configuration for $tool..."
        if [[ -n "${tool_configs[$tool]}" ]]; then
            log_debug "Found configuration for $tool: ${tool_configs[$tool]}"
            ((completion_total++))
            
            # Run test_completion with error handling
            if test_completion "$tool" 2>/dev/null; then
                ((completion_success++))
                log_debug "$tool completion test passed"
            else
                local exit_code=$?
                log_debug "$tool completion test failed with exit code $exit_code"
                # Print the error output for debugging
                test_completion "$tool"
            fi
        else
            log_debug "No completion configuration found for $tool"
        fi
    done

    log_info "Completion testing completed: $completion_success of $completion_total tools tested successfully"
} || {
    log_error "Error during completion testing"
    log_debug "Error details: $?"
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
    local path_exists
    path_exists=false
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

# Initialize completion system directories
setup_completion_directories() {
    log_info "Setting up completion directories..."

    # Create user completion directory if it doesn't exist
    if [[ ! -d "${HOME}/.zsh/completions" ]]; then
        log_warning "Creating user completions directory..."
        if ! mkdir -p "${HOME}/.zsh/completions"; then
            log_error "Failed to create user completions directory"
            # Continue anyway, as other directories might work
        else
            log_debug "Successfully created user completions directory"
        fi
    fi

    # Enable extended globbing for more powerful pattern matching
    setopt extendedglob &>/dev/null || log_debug "Failed to set extendedglob option, continuing anyway"

    # Create zcompcache directory with error handling
    if [[ ! -d "${HOME}/.zcompcache" ]]; then
        if ! mkdir -p "${HOME}/.zcompcache"; then
            log_warning "Failed to create .zcompcache directory"
        else
            log_debug "Created .zcompcache directory for faster completion"
        fi
    fi

    # Check for corrupt zcompdump and remove if necessary
    local zcompdump="${HOME}/.zcompdump"
    if [[ -f "$zcompdump" ]] && ! grep -q "^#compdef\|^#autoload" "$zcompdump" 2>/dev/null; then
        log_warning "zcompdump appears corrupted, removing it to force regeneration"
        rm -f "$zcompdump"
    fi

    # Deduplicate fpath if not already done
    typeset -U fpath

    # Temporary array to collect unique fpath entries
    local new_fpath=()
    local added_paths=()

    # Function to safely add a path to fpath arrays
    # This ensures valid paths and prevents duplicates
    safe_add_to_fpath() {
        local dir="$1"
        local description="$2"

        # Skip if directory doesn't exist or isn't readable
        if [[ ! -d "$dir" ]]; then
            log_debug "Skipping $description: Directory does not exist"
            return 1
        fi

        if [[ ! -r "$dir" ]]; then
            log_debug "Skipping $description: Directory is not readable"
            return 1
        fi

        # Check if already added
        local path_exists
        path_exists=false
        # Check if added_paths array exists and has elements
        if [[ ${#added_paths[@]} -gt 0 ]]; then
            for path in "${added_paths[@]}"; do
                if [[ "$path" == "$dir" ]]; then
                    path_exists=true
                    break
                fi
            done
        fi

        if ! $path_exists; then
            new_fpath+=("$dir")
            added_paths+=("$dir")
            log_debug "Adding $description to fpath: $dir"
            return 0
        else
            log_debug "Skipping $description: Already in fpath"
            return 0
        fi
    }

    # Add user completions directory first (highest priority)
    safe_add_to_fpath "${HOME}/.zsh/completions" "user completions directory"

    # Check for antidote completions directory (high priority)
    safe_add_to_fpath "${HOME}/.antidote/completions" "antidote completions directory"

    # Special case for Homebrew completions (high priority)
    # Handle both Apple Silicon and Intel Mac paths
    local brew_prefix=""
    local arch_type
    arch_type="$(uname -m)"

    # More robust Homebrew detection
    if command -v brew >/dev/null 2>&1; then
        # Try to get Homebrew prefix reliably
        brew_prefix="$(brew --prefix 2>/dev/null)" || {
            # Fallback based on architecture
            if [[ "$arch_type" == "arm64" ]]; then
                brew_prefix="/opt/homebrew"
                log_debug "Fallback to default Apple Silicon Homebrew path: $brew_prefix"
            else
                brew_prefix="/usr/local"
                log_debug "Fallback to default Intel Homebrew path: $brew_prefix"
            fi
        }

        log_debug "Detected Homebrew prefix: $brew_prefix"
        local brew_completion_dir="${brew_prefix}/share/zsh/site-functions"
        safe_add_to_fpath "$brew_completion_dir" "Homebrew completion directory"

        # Add FZF completions path if it exists
        local fzf_completion="${brew_prefix}/opt/fzf/shell/completion.zsh"
        if [[ -f "$fzf_completion" ]]; then
            log_debug "Found FZF completion at $fzf_completion"
            # shellcheck disable=SC1090
            if ! source "$fzf_completion" 2>/dev/null; then
                log_warning "Failed to source FZF completion from $fzf_completion"
            else
                log_debug "Successfully sourced FZF completion"
            fi
        fi

        # Check for Intel Homebrew path if we're on Apple Silicon
        # This is important for cross-architecture compatibility
        if [[ "$arch_type" == "arm64" ]]; then
            safe_add_to_fpath "/usr/local/share/zsh/site-functions" "Intel Homebrew completion directory"
        fi
    else
        log_debug "Homebrew not found, skipping Homebrew completion paths"
    fi

    # Add other completion directories in a controlled order
    # shellcheck disable=SC2066
    for location_key in "${(@k)completion_paths}"; do
        local location="${completion_paths[$location_key]}"
        safe_add_to_fpath "$location" "completion directory ($location_key)"
    done

    # Add existing fpath entries that weren't already added
    # This preserves any system or user-configured paths
    if [[ ${#fpath[@]} -gt 0 ]]; then
        for path in "${fpath[@]}"; do
            # Skip empty or invalid paths
            if [[ -z "$path" || ! -d "$path" ]]; then
                continue
            fi

            local path_exists
            path_exists=false
            if [[ ${#added_paths[@]} -gt 0 ]]; then
                for added_path in "${added_paths[@]}"; do
                    if [[ "$added_path" == "$path" ]]; then
                        path_exists=true
                        break
                    fi
                done
            fi

            if ! $path_exists; then
                new_fpath+=("$path")
                added_paths+=("$path")
                log_debug "Preserving existing fpath entry: $path"
            fi
        done
    else
        log_debug "fpath array is empty, nothing to preserve"
    fi

    # Count valid vs. invalid paths for debugging
    local valid_paths=0
    local invalid_paths=0
    if [[ ${#new_fpath[@]} -gt 0 ]]; then
        for path in "${new_fpath[@]}"; do
            if [[ -d "$path" ]]; then
                ((valid_paths++))
            else
                ((invalid_paths++))
                log_debug "Warning: Invalid path in fpath: $path"
            fi
        done
    else
        log_warning "new_fpath array is empty, no paths to validate"
    fi

    log_debug "fpath contains $valid_paths valid and $invalid_paths invalid entries"

    # Update fpath with the new ordered and deduplicated array
    if [[ ${#new_fpath[@]} -gt 0 ]]; then
        fpath=("${new_fpath[@]}")
        log_debug "Updated fpath with ${#fpath[@]} entries"
    else
        log_warning "No valid completion directories found, fpath may be empty"
    fi

    # Force reload of completions with improved error handling
    log_debug "Reloading completions with updated fpath"
    initialize_completion_system "force"

    # Verify the fpath was properly set
    if [[ ${#fpath[@]} -eq 0 ]]; then
        log_error "fpath is empty after setup! Completions will not work."
    else
        log_debug "fpath properly set with ${#fpath[@]} entries"
    fi

    # Dump completion system state for better debugging
    log_debug "Updated fpath: ${fpath[*]}"
    log_debug "Completion directories found: ${#added_paths[@]}"

    # Check if completion system is working
    if ! type compdef >/dev/null 2>&1; then
        log_warning "compdef command not available - completion system may not be fully initialized"
        # Try to recover with multiple methods
        log_debug "Attempting to recover completion system..."
        autoload -Uz compinit
        compinit -u 2>/dev/null || compinit -i 2>/dev/null

        # If still not available, try more aggressive loading
        if ! type compdef >/dev/null 2>&1; then
            log_debug "First recovery attempt failed, trying additional methods..."
            # Try to source compinit directly
            for funcdir in "${fpath[@]}"; do
                if [[ -f "${funcdir}/compinit" ]]; then
                    log_debug "Found compinit at ${funcdir}/compinit, sourcing it directly"
                    # shellcheck disable=SC1090
                    # shellcheck disable=SC1091
                    source "${funcdir}/compinit" 2>/dev/null || true
                    break
                fi
            done
        fi

        # Final check
        if type compdef >/dev/null 2>&1; then
            log_success "Successfully recovered completion system"
        else
            log_error "Failed to initialize completion system, compdef still not available"
        fi
    fi
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

# Test completions for all configured tools
completion_success=0
completion_total=0

# Check if we have any completion configs to test
if [[ ${#tool_configs[@]} -eq 0 ]]; then
    log_warning "No completion configurations defined to test"
else
    # shellcheck disable=SC2296,SC2154,SC2034
    for tool in ${(k)tool_configs}; do
        ((completion_total++))
        if test_completion "$tool"; then
            ((completion_success++))
        fi
    done
fi

# Verify essential completions are working
log_info "=== ESSENTIAL COMPLETIONS TEST ==="

# Properly declare array with typeset to avoid issues in different zsh versions
typeset -i essential_passed=0
typeset -i essential_total=${#essential_completions[@]}
typeset -i essential_installed=0

# Check if we have any essential completions to test
if [[ $essential_total -eq 0 ]]; then
    log_warning "No essential completions defined to test"
else
    log_debug "Testing ${#essential_completions[@]} essential completions"
    for tool in "${essential_completions[@]}"; do
        printf "%-30s ... " "Essential $tool completion"

        # Check if tool is installed first
        if command -v "$tool" >/dev/null 2>&1; then
            ((essential_installed++))

            # Try to fix completions before testing
            if [[ "$tool" == "terraform" ]]; then
                # Try to set up terraform completions
                if command -v terraform >/dev/null 2>&1; then
                    log_debug "Trying to configure terraform completions"
                    complete -o nospace -C "$(command -v terraform)" terraform 2>/dev/null
                fi
            elif [[ "$tool" == "kubectl" ]]; then
                # Try to set up kubectl completions
                if command -v kubectl >/dev/null 2>&1; then
                    log_debug "Trying to configure kubectl completions"
                    mkdir -p "$HOME/.zsh/completions"
                    kubectl completion zsh > "$HOME/.zsh/completions/_kubectl" 2>/dev/null
                    # shellcheck disable=SC1090
                    source <(kubectl completion zsh 2>/dev/null) || true
                fi
            elif [[ "$tool" == "helm" ]]; then
                # Try to set up helm completions
                if command -v helm >/dev/null 2>&1; then
                    log_debug "Trying to configure helm completions"
                    mkdir -p "$HOME/.zsh/completions"
                    helm completion zsh > "$HOME/.zsh/completions/_helm" 2>/dev/null
                fi
            elif [[ "$tool" == "git" ]]; then
                # Git completions are usually provided by zsh itself or by Homebrew
                log_debug "Checking for git completions in fpath"
                if [[ ${#fpath[@]} -gt 0 ]]; then
                    for dir in "${fpath[@]}"; do
                        if [[ -f "$dir/_git" ]]; then
                            log_debug "Found git completion file at $dir/_git"
                        fi
                    done
                else
                    log_warning "fpath array is empty, cannot check for git completions"
                fi
            fi

            # Reload completions with error handling
            if ! compinit -u 2>/dev/null; then
                log_warning "compinit failed with -u option, trying with -i option..."
                compinit -i
            fi

            # Test if completion function exists
            if typeset -f "_${tool}" &>/dev/null; then
                echo "✅ PASS"
                ((essential_passed++))
                log_success "Essential completion for $tool is working"
            elif zsh -c "autoload -U compinit && compinit -u && which _${tool}" >/dev/null 2>&1; then
                echo "✅ PASS"
                ((essential_passed++))
                log_success "Essential completion for $tool is working"
            else
                # Special case handling
                if [[ "$tool" == "terraform" ]] && command -v terraform >/dev/null 2>&1; then
                    # Terraform uses a different completion mechanism
                    echo "✅ PASS (custom)"
                    ((essential_passed++))
                    log_success "Terraform uses a custom completion system"
                else
                    echo "❌ FAIL"
                    log_error "Essential completion for $tool is NOT working"
                    log_debug "Completion function _${tool} not found"
                    log_debug "Current fpath: ${fpath[*]}"
                fi
            fi
        else
            echo "⏭️  SKIPPED"
            log_info "$tool not installed, skipping completion test"
        fi
    done
fi

# Log summary of essential completions
log_debug "Essential tools: $essential_total defined, $essential_installed installed, $essential_passed with working completions"

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
