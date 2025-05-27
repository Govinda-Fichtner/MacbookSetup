#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2296,SC2034,SC2154

# macOS Development Environment Verification Script
# This script verifies that all tools and configurations are properly installed

# Script configuration
readonly SCRIPT_VERSION="1.0.0"
readonly COMPLETION_DIR="${HOME}/.zsh/completions"

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
log_debug() { printf "[DEBUG] %s\n" "$1" >&2; }

# Utility functions
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Main verification function
main() {
    log_info "Starting macOS development environment verification (v${SCRIPT_VERSION})..."
    
    local success_count=0
    local total_checks=0
    
    # Define tools to verify
    local -A tools=(
        ["brew"]="Homebrew package manager"
        ["git"]="Git version control"
        ["antidote"]="Antidote plugin manager"
        ["rbenv"]="Ruby version manager"
        ["pyenv"]="Python version manager"
        ["direnv"]="Directory environment manager"
        ["starship"]="Starship prompt"
        ["packer"]="HashiCorp Packer"
        ["terraform"]="Terraform infrastructure tool"
        ["kubectl"]="Kubernetes CLI"
        ["helm"]="Kubernetes package manager"
        ["fzf"]="Fuzzy finder"
    )
    
    log_info "=== TOOL INSTALLATION VERIFICATION ==="
    
    # Check each tool
    for tool in ${(k)tools}; do
        local description="${tools[$tool]}"
        ((total_checks++))
        
        printf "%-35s ... " "$description"
        
        if check_command "$tool"; then
            echo "✅ PASS"
            ((success_count++))
            
            # Get version info if possible
            local version=""
            case "$tool" in
                "antidote")
                    # Check if antidote is available as function or via brew
                    if typeset -f antidote >/dev/null 2>&1; then
                        version="$(antidote --version 2>/dev/null || echo "installed as function")"
                    elif brew list antidote >/dev/null 2>&1; then
                        version="installed via Homebrew"
                    else
                        echo "❌ FAIL"
                        log_error "$tool not found in PATH"
                        continue
                    fi
                    echo "✅ PASS"
                    ((success_count++))
                    ;;
                "kubectl")
                    version="$(kubectl version --client --short 2>/dev/null | head -1 || echo "installed")"
                    ;;
                "helm")
                    version="$(helm version --short 2>/dev/null || echo "installed")"
                    ;;
                *)
                    version="$($tool --version 2>/dev/null | head -1 || echo "installed")"
                    ;;
            esac
            log_debug "$tool: $version"
        else
            # Special case for antidote - check if it's available as function or via brew
            if [[ "$tool" == "antidote" ]]; then
                if typeset -f antidote >/dev/null 2>&1; then
                    echo "✅ PASS"
                    ((success_count++))
                    log_debug "$tool: installed as function"
                elif brew list antidote >/dev/null 2>&1; then
                    echo "✅ PASS"
                    ((success_count++))
                    log_debug "$tool: installed via Homebrew"
                else
                    echo "❌ FAIL"
                    log_error "$tool not found in PATH, as function, or via Homebrew"
                fi
            else
                echo "❌ FAIL"
                log_error "$tool not found in PATH"
            fi
        fi
    done
    
    log_info "=== CONFIGURATION FILES VERIFICATION ==="
    
    # Check important configuration files
    local -A config_files=(
        ["${HOME}/.zshrc"]="Zsh configuration file"
        ["${HOME}/.zsh_plugins.txt"]="Antidote plugins file"
        ["Brewfile"]="Homebrew package list"
    )
    
    for file in ${(k)config_files}; do
        local description="${config_files[$file]}"
        ((total_checks++))
        
        printf "%-35s ... " "$description"
        
        if [[ -f "$file" ]]; then
            echo "✅ PASS"
            ((success_count++))
            
            # Additional checks for specific files
            case "$file" in
                "${HOME}/.zsh_plugins.txt")
                    local plugin_count
                    plugin_count=$(grep -cv "^#\|^$" "$file" 2>/dev/null || echo "0")
                    log_debug "Found $plugin_count plugins in .zsh_plugins.txt"
                    ;;
                "${HOME}/.zshrc")
                    if grep -q "compinit" "$file" 2>/dev/null; then
                        log_debug ".zshrc contains completion initialization"
                    else
                        log_warning ".zshrc missing completion initialization"
                    fi
                    ;;
            esac
        else
            echo "❌ FAIL"
            log_error "$file not found"
        fi
    done
    
    log_info "=== COMPLETION DIRECTORIES VERIFICATION ==="
    
    # Check completion directories
    local -A completion_dirs=(
        ["/opt/homebrew/share/zsh/site-functions"]="Homebrew completions"
        ["/usr/share/zsh/site-functions"]="System completions"
        ["${HOME}/.zsh/completions"]="User completions"
        ["/opt/homebrew/opt/fzf/shell"]="FZF completions"
    )
    
    for dir in ${(k)completion_dirs}; do
        local description="${completion_dirs[$dir]}"
        ((total_checks++))
        
        printf "%-35s ... " "$description"
        
        if [[ -d "$dir" ]]; then
            echo "✅ PASS"
            ((success_count++))
            
            local file_count
            file_count=$(find "$dir" -name "_*" 2>/dev/null | wc -l | tr -d '[:space:]')
            log_debug "Found $file_count completion files in $dir"
        else
            echo "⏭️  SKIPPED"
            log_warning "$dir does not exist"
        fi
    done
    
    log_info "=== SUMMARY ==="
    
    local percentage=$((success_count * 100 / total_checks))
    log_info "Verification completed: $success_count of $total_checks checks passed ($percentage%)"
    
    if [[ $success_count -eq $total_checks ]]; then
        log_success "All verifications passed! Your development environment is properly configured."
        return 0
    elif [[ $percentage -ge 80 ]]; then
        log_warning "Most verifications passed, but some issues were found."
        log_info "Your development environment is mostly functional."
        return 0
    else
        log_error "Multiple verification failures detected."
        log_info "Please run the setup script to fix missing components."
        return 1
    fi
}

# Run main function
main "$@"
