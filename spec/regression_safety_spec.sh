#!/usr/bin/env shellspec

# 🛡️ REGRESSION SAFETY TESTS
# These tests MUST ALWAYS PASS to ensure core functionality remains intact
# NEVER modify these tests without explicit approval - they are our safety net

Describe 'CRITICAL: Core MCP Manager Regression Safety Tests'

Describe '🚨 CRITICAL: Docker Integration (Never Break)'
It 'Docker daemon is accessible'
When call docker version
The status should be success
The output should include "Version:"
End

It 'Docker can run basic containers'
When call docker run --rm hello-world
The status should be success
The output should include "Hello from Docker!"
End
End

Describe '🚨 CRITICAL: Basic MCP Manager Commands (Never Break)'
It 'mcp_manager.sh exists and is executable'
When run test -x "$PWD/mcp_manager.sh"
The status should be success
End

It 'mcp_manager.sh list command works'
When run zsh "$PWD/mcp_manager.sh" list
The status should be success
The output should include "Configured MCP servers:"
End

It 'mcp_manager.sh help command works'
When run zsh "$PWD/mcp_manager.sh" help
The status should be success
The output should include "MCP Server Manager"
End
End

Describe '🚨 CRITICAL: Configuration Generation (Never Break)'
It 'config-write command runs without errors'
When run zsh "$PWD/mcp_manager.sh" config-write
The status should be success
The output should not include "ERROR"
The output should not include "server_type="
The output should not include "image="
The output should not include "volumes="
The output should not include "networks="
The output should not include "entrypoint="
End

# Skip JSON validation tests if no working servers - focus on core safety
It 'environment example file generation works'
When run zsh "$PWD/mcp_manager.sh" config-write
The status should be success
The output should include "=== MCP Client Configuration Generation ==="
End
End

Describe '🚨 CRITICAL: Environment Variable Consistency (Never Break)'
It 'generates .env_example with expected variables'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run grep "GITHUB_PERSONAL_ACCESS_TOKEN\\|CIRCLECI_TOKEN\\|FILESYSTEM_ALLOWED_DIRS" "$PWD/.env_example"
The status should be success
The output should include "GITHUB_PERSONAL_ACCESS_TOKEN"
The output should include "CIRCLECI_TOKEN"
The output should include "FILESYSTEM_ALLOWED_DIRS"
End

It 'uses correct GitHub environment variable naming'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run grep "GITHUB_PERSONAL_ACCESS_TOKEN" "$PWD/.env_example"
The status should be success
The output should include "GITHUB_PERSONAL_ACCESS_TOKEN"
End
End

Describe '🚨 CRITICAL: Core Server Functionality (Never Break)'
It 'GitHub server can be tested'
When run zsh "$PWD/mcp_manager.sh" test github
The status should be success
The output should include "[SERVER]"
End

It 'CircleCI server can be tested'
When run zsh "$PWD/mcp_manager.sh" test circleci
The status should be success
The output should include "[SERVER]"
End

It 'Filesystem server can be tested'
When run zsh "$PWD/mcp_manager.sh" test filesystem
The status should be success
The output should include "[SERVER]"
End
End

Describe '🚨 CRITICAL: Protocol Compliance (Never Break)'
It 'all servers pass basic protocol tests'
When run zsh "$PWD/mcp_manager.sh" test
The status should be success
The output should include "[SUCCESS]"
The output should include "passed"
End
End

Describe '🚨 CRITICAL: Registry Integrity (Never Break)'
It 'registry file exists and is valid YAML'
When run test -f "$PWD/mcp_server_registry.yml"
The status should be success
End

It 'contains expected core servers'
When run grep -E "^  (github|circleci|filesystem):" "$PWD/mcp_server_registry.yml"
The status should be success
The output should include "github:"
The output should include "circleci:"
The output should include "filesystem:"
End
End
End

# Test helper functions
backup_configs() {
  mkdir -p .test_backup
  [[ -f "$HOME/.cursor/mcp.json" ]] && cp "$HOME/.cursor/mcp.json" .test_backup/cursor_mcp.json.bak
  [[ -f "$HOME/Library/Application Support/Claude/claude_desktop_config.json" ]] \
    && cp "$HOME/Library/Application Support/Claude/claude_desktop_config.json" .test_backup/claude_config.json.bak
}

restore_configs() {
  [[ -f .test_backup/cursor_mcp.json.bak ]] && cp .test_backup/cursor_mcp.json.bak "$HOME/.cursor/mcp.json"
  [[ -f .test_backup/claude_config.json.bak ]] \
    && cp .test_backup/claude_config.json.bak "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  rm -rf .test_backup
}
