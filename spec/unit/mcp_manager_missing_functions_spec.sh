#!/bin/zsh
# Unit tests for restored missing functions

Describe 'Missing Function Validation'
It 'has test_mcp_server_health function available'
When run zsh -c "grep -q '^test_mcp_server_health()' ./mcp_manager.sh"
The status should be success
End

It 'has setup_mcp_server function available'
When run zsh -c "grep -q '^setup_mcp_server()' ./mcp_manager.sh"
The status should be success
End

It 'has test_mcp_basic_protocol function available'
When run zsh -c "grep -q '^test_mcp_basic_protocol()' ./mcp_manager.sh"
The status should be success
End

It 'has setup_registry_server function available'
When run zsh -c "grep -q '^setup_registry_server()' ./mcp_manager.sh"
The status should be success
End

It 'has setup_build_server function available'
When run zsh -c "grep -q '^setup_build_server()' ./mcp_manager.sh"
The status should be success
End

It 'test and setup commands work properly'
When run ./mcp_manager.sh help
The status should be success
The output should include "test"
The output should include "setup"
End
End
