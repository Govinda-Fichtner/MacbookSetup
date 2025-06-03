#!/usr/bin/env shellspec

Describe "MCP Manager Core Functions"
Include ./mcp_manager.sh

Describe "parse_server_config"
It "extracts simple configuration values"
When call parse_server_config "github" "name"
The output should eq "GitHub MCP Server"
End

It "extracts nested configuration values"
When call parse_server_config "github" "source.image"
The output should eq "mcp/github-mcp-server:latest"
End

It "handles missing values gracefully"
When call parse_server_config "nonexistent" "name"
The output should be empty
End
End

Describe "server_has_real_tokens"
It "detects real GitHub token"
GITHUB_PERSONAL_ACCESS_TOKEN="real_token"
When call server_has_real_tokens "github"
The status should be success
End

It "detects test token as invalid"
GITHUB_PERSONAL_ACCESS_TOKEN="test_token"
When call server_has_real_tokens "github"
The status should be failure
End

It "handles missing tokens"
unset GITHUB_PERSONAL_ACCESS_TOKEN
When call server_has_real_tokens "github"
The status should be failure
End
End

Describe "get_env_value_or_placeholder"
It "returns shell variable for real tokens"
GITHUB_PERSONAL_ACCESS_TOKEN="real_token"
When call get_env_value_or_placeholder "GITHUB_PERSONAL_ACCESS_TOKEN" "github"
The output should eq "\${GITHUB_PERSONAL_ACCESS_TOKEN}"
End

It "returns placeholder for missing tokens"
unset GITHUB_PERSONAL_ACCESS_TOKEN
When call get_env_value_or_placeholder "GITHUB_PERSONAL_ACCESS_TOKEN" "github"
The output should eq "YOUR_GITHUB_TOKEN_HERE"
End
End

Describe "get_working_servers_with_tokens"
It "filters server IDs correctly"
# Mock get_configured_servers to return test data
get_configured_servers() {
  echo "github"
  echo "circleci"
  echo "invalid_server"
}

When call get_working_servers_with_tokens
The output should include "github:"
The output should include "circleci:"
The output should not include "invalid_server"
End
End

Describe "write_cursor_config"
It "generates valid JSON structure"
# Mock server data
local test_servers=("github")
local temp_file
temp_file=$(mktemp)

# Mock parse_server_config for github
parse_server_config() {
  case "$2" in
    "source.image") echo "mcp/github-mcp-server:latest" ;;
    "environment_variables") echo "- \"GITHUB_TOKEN\"" ;;
  esac
}

# Mock get_env_value_or_placeholder
get_env_value_or_placeholder() {
  echo "\${$1}"
}

When call write_cursor_config "${test_servers[@]}"
The status should be success
The output should include "[SUCCESS] Cursor MCP configuration updated"
End
End

Describe "write_claude_config"
It "generates valid JSON structure"
# Mock server data
local test_servers=("github")
local temp_file
temp_file=$(mktemp)

# Mock parse_server_config for github
parse_server_config() {
  case "$2" in
    "source.image") echo "mcp/github-mcp-server:latest" ;;
    "environment_variables") echo "- \"GITHUB_TOKEN\"" ;;
  esac
}

# Mock get_env_value_or_placeholder
get_env_value_or_placeholder() {
  echo "\${$1}"
}

When call write_claude_config "${test_servers[@]}"
The status should be success
The output should include "[SUCCESS] Claude Desktop MCP configuration updated"
End
End
End
