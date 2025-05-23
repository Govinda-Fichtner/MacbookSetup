#!/bin/bash

# Test script for Terraform completion functionality
# This script verifies that Terraform completion is properly set up via zinit plugin

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

log_success() {
    echo -e "${GREEN}[✓] $1${NC}"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[✗] $1${NC}"
}

log_info() {
    echo -e "${YELLOW}[i] $1${NC}"
}

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    ((TESTS_RUN++))
    
    echo -e "\nRunning test: $test_name"
    if eval "$test_command"; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        return 1
    fi
}

# Test 1: Check if zinit is installed
test_zinit_installed() {
    run_test "Check if zinit is installed" '
        command -v zinit >/dev/null 2>&1
    '
}

# Test 2: Check if terraform-zsh plugin is loaded
test_terraform_plugin_loaded() {
    run_test "Check if terraform-zsh plugin is loaded" '
        zinit list 2>/dev/null | grep -q "macunha1/zsh-terraform"
    '
}

# Test 3: Check if Terraform is installed
test_terraform_installed() {
    run_test "Check if Terraform is installed" '
        command -v terraform >/dev/null 2>&1
    '
}

# Test 4: Check if basic Terraform completions are available
test_terraform_completions() {
    run_test "Check if Terraform completions are available" '
        local completions
        completions=$(terraform --help 2>/dev/null | grep -E "^  [a-z]" | cut -d " " -f3)
        [[ -n "$completions" ]] && echo "$completions" | grep -q "init"
    '
}

# Test 5: Verify completion for common Terraform commands
test_terraform_common_commands() {
    run_test "Verify completion for common Terraform commands" '
        local commands=("init" "plan" "apply" "destroy" "fmt" "validate")
        local all_found=true
        local completions
        completions=$(terraform --help 2>/dev/null | grep -E "^  [a-z]" | cut -d " " -f3)
        
        for cmd in "${commands[@]}"; do
            if ! echo "$completions" | grep -q "^$cmd$"; then
                echo "Missing completion for: $cmd"
                all_found=false
            fi
        done
        
        $all_found
    '
}

# Run all tests
main() {
    log_info "Starting Terraform completion tests..."
    
    # Run individual tests
    test_zinit_installed
    test_terraform_plugin_loaded
    test_terraform_installed
    test_terraform_completions
    test_terraform_common_commands
    
    # Print summary
    echo -e "\nTest Summary:"
    echo "Tests run: $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    
    # Return success only if all tests passed
    [[ $TESTS_RUN -eq $TESTS_PASSED ]]
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
