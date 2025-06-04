#!/bin/zsh
# Shellspec test suite for mcp_manager.sh

# Simple test environment setup
setup() {
  export HOME="$PWD/test_home"
  mkdir -p "$HOME/.cursor"
  mkdir -p "$HOME/Library/Application Support/Claude"
  rm -f "$HOME/.cursor/mcp.json"
  rm -f "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  rm -f "$PWD/.env_example"
  # Ensure we have a clean environment for tests
  unset functrace funcfiletrace funcsourcetrace 2> /dev/null || true
}

BeforeEach 'setup'

# Helper function to validate JSON
validate_json() {
  jq . "$1" > /dev/null 2>&1
}

# Helper function to check if file contains expected servers
has_expected_servers() {
  local file="$1"
  local expected_servers="github circleci filesystem"

  if ! jq . "$file" > /dev/null 2>&1; then
    return 1
  fi

  for server in $expected_servers; do
    if ! jq -e ".[\"$server\"] // .mcpServers[\"$server\"]" "$file" > /dev/null 2>&1; then
      return 1
    fi
  done
  return 0
}

Describe 'mcp_manager.sh configuration generation'
Describe 'basic configuration generation'
It 'creates config files successfully'
When run zsh "$PWD/mcp_manager.sh" config-write
The status should be success
The output should include "Client configurations written"
The file "$HOME/.cursor/mcp.json" should be exist
The file "$HOME/Library/Application Support/Claude/claude_desktop_config.json" should be exist
End

It 'generates valid Cursor JSON'
# First create the config files
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq . "$HOME/.cursor/mcp.json"
The status should be success
The output should include "github"
End

It 'generates valid Claude Desktop JSON'
# First create the config files
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq . "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
The output should include "mcpServers"
End
End

Describe 'JSON validation and regression tests'
It 'generates syntactically valid JSON for Cursor'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When call validate_json "$HOME/.cursor/mcp.json"
The status should be success
End

It 'generates syntactically valid JSON for Claude Desktop'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When call validate_json "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
End

It 'includes expected servers in Cursor configuration'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When call has_expected_servers "$HOME/.cursor/mcp.json"
The status should be success
End

It 'includes expected servers in Claude Desktop configuration'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When call has_expected_servers "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
End
End

Describe 'debug output regression tests'
It 'does not output debug variables during config generation'
When run zsh "$PWD/mcp_manager.sh" config-write
The status should be success
The output should not include "container_value="
The output should not include "image="
The output should not include "env_vars="
End

It 'does not include debug output in generated Cursor JSON'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run cat "$HOME/.cursor/mcp.json"
The status should be success
The output should not include "container_value="
The output should not include "image="
The output should not include "env_vars="
End

It 'does not include debug output in generated Claude Desktop JSON'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run cat "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
The output should not include "container_value="
The output should not include "image="
The output should not include "env_vars="
End

# The problematic test - now with timeouts built into mcp_manager.sh
It 'does not output debug variables during test command'
When run zsh "$PWD/mcp_manager.sh" test
The status should be success
The output should not include "container_value="
The output should not include "image="
The output should not include "env_vars="
End
End

Describe 'configuration format validation'
It 'uses --env-file approach in Cursor configuration'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run cat "$HOME/.cursor/mcp.json"
The status should be success
The output should include "--env-file"
The output should include ".env"
End

It 'uses --env-file approach in Claude Desktop configuration'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run cat "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
The output should include "--env-file"
The output should include ".env"
End

It 'does not use inline environment variables'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run cat "$HOME/.cursor/mcp.json"
The status should be success
The output should not include "GITHUB_TOKEN"
The output should not include "CIRCLECI_TOKEN"
End

It 'includes correct Docker images'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run cat "$HOME/.cursor/mcp.json"
The status should be success
The output should include "mcp/github-mcp-server:latest"
The output should include "local/mcp-server-circleci:latest"
The output should include "mcp/filesystem:latest"
End
End

Describe 'environment file generation'
It 'creates .env_example file'
When run zsh "$PWD/mcp_manager.sh" config-write
The status should be success
The output should include "Environment example file created"
The file "$PWD/.env_example" should be exist
End

It 'includes expected environment variables in .env_example'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run cat "$PWD/.env_example"
The status should be success
The output should include "GITHUB_TOKEN"
The output should include "GITHUB_PERSONAL_ACCESS_TOKEN"
The output should include "CIRCLECI_TOKEN"
The output should include "CIRCLECI_BASE_URL"
The output should include "FILESYSTEM_ALLOWED_DIRS"
End

It 'uses placeholder values in .env_example'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run cat "$PWD/.env_example"
The status should be success
The output should include "your_github_token_here"
The output should include "your_circleci_token_here"
The output should include "MacbookSetup"
The output should include "Desktop"
The output should include "Downloads"
End
End

Describe 'preview mode validation'
It 'generates clean preview output without debug variables'
When run zsh "$PWD/mcp_manager.sh" config cursor
The status should be success
The output should include "Cursor Configuration"
The output should not include "container_value="
The output should not include "image="
The output should not include "env_vars="
End

It 'includes --env-file in preview output'
When run zsh "$PWD/mcp_manager.sh" config cursor
The status should be success
The output should include "--env-file"
End
End

Describe 'JSON structure validation'
It 'has proper JSON structure for Cursor'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq 'type' "$HOME/.cursor/mcp.json"
The status should be success
The output should equal '"object"'
End

It 'has proper JSON structure for Claude Desktop'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq '.mcpServers | type' "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
The output should equal '"object"'
End

It 'has proper server configuration structure'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq '.github.command' "$HOME/.cursor/mcp.json"
The status should be success
The output should equal '"docker"'
End

It 'has proper args array structure'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq '.github.args | type' "$HOME/.cursor/mcp.json"
The status should be success
The output should equal '"array"'
End
End

Describe 'error handling and edge cases'
It 'handles missing Docker gracefully'
# Test with limited PATH
When run env PATH="/usr/bin:/bin" zsh "$PWD/mcp_manager.sh" config-write
The status should be success
The output should include "Client configurations written"
End
End

Describe 'shell completion functionality'
It 'completion file includes inspect command'
When run grep -c "inspect.*Inspect and debug" "support/completions/_mcp_manager"
The status should be success
The output should equal "1"
End

It 'completion file can extract server IDs from registry'
When run awk '/^  [a-z].*:$/ { gsub(/:/, ""); gsub(/^  /, ""); print }' "mcp_server_registry.yml"
The status should be success
The output should include "github"
The output should include "circleci"
The output should include "inspector"
End

It 'completion function exists and is properly defined'
When run grep -c "_mcp_inspect_subcommands" "support/completions/_mcp_manager"
The status should be success
The output should equal "2"
End

It 'inspect subcommand completions include expected options'
When run grep -A20 "_mcp_inspect_subcommands" "support/completions/_mcp_manager"
The status should be success
The output should include "--ui:Launch visual web interface"
The output should include "--stop:Stop Inspector container"
The output should include "--health:Monitor Inspector health"
The output should include "--validate-config:Validate client configurations"
End
End

Describe 'filesystem server integration'
It 'includes filesystem server in available servers list'
When run zsh "$PWD/mcp_manager.sh" list
The status should be success
The output should include "filesystem"
End

It 'generates filesystem server configuration for Cursor'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq '.filesystem' "$HOME/.cursor/mcp.json"
The status should be success
The output should include "docker"
The output should include "mcp/filesystem:latest"
End

It 'generates filesystem server configuration for Claude Desktop'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq '.mcpServers.filesystem' "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
The output should include "docker"
The output should include "mcp/filesystem:latest"
End

It 'includes filesystem environment variables in .env_example'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run grep "FILESYSTEM_ALLOWED_DIRS" "$PWD/.env_example"
The status should be success
The output should include "FILESYSTEM_ALLOWED_DIRS"
End

It 'filesystem environment variables include secure directory paths'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run grep "FILESYSTEM_ALLOWED_DIRS" "$PWD/.env_example"
The status should be success
The output should include "MacbookSetup"
The output should include "Desktop"
The output should include "Downloads"
End

It 'filesystem server uses --env-file approach'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq '.filesystem.args[]' "$HOME/.cursor/mcp.json"
The status should be success
The output should include "--env-file"
End

It 'filesystem server can be tested individually'
When run zsh "$PWD/mcp_manager.sh" test filesystem
The status should be success
The output should include "Filesystem MCP Server"
End
End
End
