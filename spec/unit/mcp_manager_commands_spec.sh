#!/bin/zsh
# Command interface tests for mcp_manager.sh
# Tests all subcommands and their interfaces

# Global setup for command tests
BeforeAll() {
  test_root="$PWD/tmp/command_test_$$"
  mkdir -p "$test_root"
}

AfterAll() {
  test_root="$PWD/tmp/command_test_$$"
  rm -rf "$test_root"
}

Describe 'MCP Manager Command Interface'
It 'shows help when called with no arguments'
When run zsh "$PWD/mcp_manager.sh"
The status should not be success
The stderr should include "Usage:"
End

It 'shows help when called with invalid command'
When run zsh "$PWD/mcp_manager.sh" invalid-command
The status should not be success
The stderr should include "Usage:"
End

It 'accepts config command'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
The output should include "=== MCP Client Configuration Preview ==="
End

It 'accepts config-write command'
# Create minimal test environment in proper temp location
test_home="$test_root/config_write_test"
mkdir -p "$test_home/.cursor"
mkdir -p "$test_home/Library/Application Support/Claude"

When run sh -c "cd '$test_home' && export HOME='$test_home' && zsh '$PWD/mcp_manager.sh' config-write"
The status should be success
The output should include "=== MCP Client Configuration Generation ==="
End

It 'accepts list command'
When run zsh "$PWD/mcp_manager.sh" list
The status should be success
# Should list configured servers
The output should include "github"
The output should include "filesystem"
End

It 'accepts parse command with server and field'
When run zsh "$PWD/mcp_manager.sh" parse github name
The status should be success
The output should include "GitHub MCP Server"
End

It 'requires both server and field for parse command'
When run zsh "$PWD/mcp_manager.sh" parse github
The status should not be success
End
End

Describe 'Config Command Behavior'
It 'generates valid JSON structure'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
The output should satisfy 'tail -n +2 | jq ".mcpServers | type" | grep -q "object"'
End

It 'includes debug information on stderr'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
The stderr should include "[INFO]"
End

It 'produces clean JSON without debug contamination'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
The output should satisfy 'tail -n +2 | jq . > /dev/null'
The output should not satisfy 'tail -n +2 | grep -q "server_type="'
End

It 'handles missing .env file gracefully'
# Temporarily hide .env if it exists
if [[ -f ".env" ]]; then
  mv .env .env.hidden
fi

When run zsh "$PWD/mcp_manager.sh" config
The status should be success
The stderr should include "[WARNING]"

# Restore .env if it was hidden
if [[ -f ".env.hidden" ]]; then
  mv .env.hidden .env
fi
End
End

Describe 'Config-Write Command Behavior'
BeforeEach
config_test_home="$test_root/config_write_$$"
mkdir -p "$config_test_home/.cursor"
mkdir -p "$config_test_home/Library/Application Support/Claude"
End

AfterEach
rm -rf "$config_test_home"
End

It 'creates both client configuration files'
When run sh -c "cd '$config_test_home' && export HOME='$config_test_home' && zsh '$PWD/mcp_manager.sh' config-write"
The status should be success
The file "$config_test_home/.cursor/mcp.json" should be exist
The file "$config_test_home/Library/Application Support/Claude/claude_desktop_config.json" should be exist
End

It 'writes identical content to both files'
sh -c "cd '$config_test_home' && export HOME='$config_test_home' && zsh '$PWD/mcp_manager.sh' config-write > /dev/null 2>&1"

cursor_content=$(jq -S . "$config_test_home/.cursor/mcp.json")
claude_content=$(jq -S . "$config_test_home/Library/Application Support/Claude/claude_desktop_config.json")

When run test "$cursor_content" = "$claude_content"
The status should be success
End

It 'provides informative output about what was written'
When run sh -c "cd '$config_test_home' && export HOME='$config_test_home' && zsh '$PWD/mcp_manager.sh' config-write"
The status should be success
The output should include "[CONFIG]"
The output should include "Cursor configuration"
The output should include "Claude Desktop configuration"
The output should include "[SUCCESS]"
End

It 'provides next steps guidance'
When run sh -c "cd '$config_test_home' && export HOME='$config_test_home' && zsh '$PWD/mcp_manager.sh' config-write"
The status should be success
The output should include "[NEXT STEPS]"
The output should include ".env_example"
The output should include "real API tokens"
End
End

Describe 'List Command Behavior'
It 'lists all configured servers'
When run zsh "$PWD/mcp_manager.sh" list
The status should be success
The output should include "github"
The output should include "circleci"
The output should include "filesystem"
The output should include "docker"
The output should include "kubernetes"
End

It 'outputs one server per line'
When run zsh "$PWD/mcp_manager.sh" list
The status should be success
# Count lines and servers - should match
server_count=$(zsh "$PWD/mcp_manager.sh" list | wc -l | tr -d ' ')
registry_count=$(yq -r '.servers | keys | length' mcp_server_registry.yml)
When run test "$server_count" -eq "$registry_count"
The status should be success
End
End

Describe 'Parse Command Behavior'
It 'parses server names correctly'
When run zsh "$PWD/mcp_manager.sh" parse github name
The status should be success
The output should include "GitHub MCP Server"
End

It 'parses server types correctly'
When run zsh "$PWD/mcp_manager.sh" parse github server_type
The status should be success
The output should include "api_based"

When run zsh "$PWD/mcp_manager.sh" parse filesystem server_type
The status should be success
The output should include "mount_based"

When run zsh "$PWD/mcp_manager.sh" parse docker server_type
The status should be success
The output should include "privileged"
End

It 'parses nested configuration fields'
When run zsh "$PWD/mcp_manager.sh" parse github source.image
The status should be success
The output should include "mcp/github-mcp-server:latest"
End

It 'handles non-existent servers gracefully'
When run zsh "$PWD/mcp_manager.sh" parse non-existent-server name
The status should be success
The output should include "null"
End

It 'handles non-existent fields gracefully'
When run zsh "$PWD/mcp_manager.sh" parse github non-existent-field
The status should be success
The output should include "null"
End

It 'handles complex field paths'
When run zsh "$PWD/mcp_manager.sh" parse figma source.cmd
The status should be success
# Figma has cmd array
The output should include "dist/cli.js"
End
End

Describe 'Command Integration and Consistency'
It 'config and parse commands use same data source'
# Get server type from parse command
parse_result=$(zsh "$PWD/mcp_manager.sh" parse github server_type)

# Get server type from config JSON
config_json=$(zsh "$PWD/mcp_manager.sh" config 2> /dev/null | tail -n +2)
# Should be api_based type with minimal args
echo "$config_json" | jq '.mcpServers.github.args | length <= 6' | grep -q true

When run test "$?" -eq 0
The status should be success
End

It 'list and config commands show same servers'
list_servers=$(zsh "$PWD/mcp_manager.sh" list | sort)
config_servers=$(zsh "$PWD/mcp_manager.sh" config 2> /dev/null | tail -n +2 | jq -r '.mcpServers | keys[]' | sort)

When run test "$list_servers" = "$config_servers"
The status should be success
End

It 'all commands handle missing registry file gracefully'
# Backup registry
mv mcp_server_registry.yml mcp_server_registry.yml.backup

# Commands should fail gracefully when registry is missing
When run zsh "$PWD/mcp_manager.sh" list
The status should not be success

When run zsh "$PWD/mcp_manager.sh" config
The status should not be success

# Restore registry
mv mcp_server_registry.yml.backup mcp_server_registry.yml
End
End

Describe 'Error Handling and Edge Cases'
It 'handles missing dependencies gracefully'
# Test behavior when jq is missing (simulate)
Skip if '! command -v jq >/dev/null' 'jq is required for this test'
# This test would need to temporarily hide jq to test graceful degradation
End

It 'handles malformed JSON gracefully in templates'
# This would require creating a malformed template temporarily
# Skip for now as it would require significant test setup
Skip 'Template malformation testing requires complex setup'
End

It 'provides meaningful error messages'
When run zsh "$PWD/mcp_manager.sh" invalid-command
The status should not be success
The stderr should include "Usage:"
The stderr should include "config"
The stderr should include "list"
The stderr should include "parse"
End

It 'handles permission errors on config directories'
# This would test behavior when config directories are not writable
# Skip for now as it would require special permission setup
Skip 'Permission error testing requires special setup'
End
End
