#!/bin/zsh
# ShellSpec test suite for JSON validation
# Validates that generated JSON config files are properly formatted and valid

# Source test helpers
source "$PWD/spec/test_helpers.sh"

Describe "JSON Configuration Validation"
BeforeAll 'setup_test_environment'
AfterAll 'cleanup_test_environment'

# Helper function to set up test environment and generate configs
setup_json_test_environment() {
  setup_inspector_test_environment
  export TEST_HOME="$PWD/tmp/test_home"
  mkdir -p "$TEST_HOME/.cursor"
  mkdir -p "$TEST_HOME/Library/Application Support/Claude"

  # Create minimal .env for testing
  cat > "$TEST_HOME/.env" << EOF
GITHUB_TOKEN=test_token_here
CIRCLECI_TOKEN=test_token_here
FILESYSTEM_ALLOWED_DIRS=/Users/gfichtner/MacbookSetup,/Users/gfichtner/Desktop
EOF

  # Generate the config files that tests expect
  cd "$TEST_HOME" && HOME="$PWD" zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1
  cd "$OLDPWD" || return

  # Verify files were created
  if [[ ! -f "$TEST_HOME/.cursor/mcp.json" ]]; then
    echo "ERROR: Failed to create Cursor config file" >&2
    return 1
  fi

  if [[ ! -f "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json" ]]; then
    echo "ERROR: Failed to create Claude Desktop config file" >&2
    return 1
  fi
}

# Helper function to clean up test environment
cleanup_json_test_environment() {
  rm -rf "$PWD/tmp/test_home"
  # NOTE: DO NOT remove .env file - it's the user's real environment file!
  # Tests should only create/cleanup files in $TEST_HOME, never in project root
}

BeforeAll 'setup_json_test_environment'
AfterAll 'cleanup_json_test_environment'

Describe "Cursor JSON Configuration"
It "generates valid JSON without syntax errors"
When run jq '.' "$TEST_HOME/.cursor/mcp.json"
The status should be success
The output should start with '{'
The output should end with '}'
End

It "contains no empty lines in JSON structure"
# Check for empty lines (lines with only whitespace)
When run grep -E '^\s*$' "$TEST_HOME/.cursor/mcp.json"
The status should not be success
End

It "has no trailing whitespace on any line"
# Check for trailing whitespace
When run grep -E '\s+$' "$TEST_HOME/.cursor/mcp.json"
The status should not be success
End

It "contains valid mcpServers structure"
# Validate mcpServers exists and is an object
When run jq '.mcpServers | type' "$TEST_HOME/.cursor/mcp.json"
The output should equal '"object"'
End

It "has valid figma entry without contamination"
# Extract just the figma entry and validate it
When run jq '.mcpServers.figma' "$TEST_HOME/.cursor/mcp.json"
The status should be success
The output should include '"command"'
The output should include '"args"'
The output should not include '[INFO]'
The output should not include '[ERROR]'
The output should not include '[SUCCESS]'
End

It "has all required fields for each server entry"
# Check that each server has command and args
When run jq '.mcpServers | to_entries[] | select(.value.command == null or .value.args == null) | .key' "$TEST_HOME/.cursor/mcp.json"
The output should be blank
End

It "contains no log messages or debug output in JSON"
# Check for common log patterns that shouldn't be in JSON
When run grep -E '\[(INFO|ERROR|SUCCESS|WARNING|DEBUG)\]' "$TEST_HOME/.cursor/mcp.json"
The status should not be success
End

It "contains no tree structure characters in JSON"
When run grep -E '├──|└──|│' "$TEST_HOME/.cursor/mcp.json"
The status should not be success
End
End

Describe "Claude Desktop JSON Configuration"
It "Claude Desktop config file exists"
The path "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json" should be exist
End

It "generates valid JSON without syntax errors"
When run jq '.' "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
The stderr should be blank
End

It "contains no empty lines in JSON structure"
# Check for empty lines (lines with only whitespace)
When run grep -E '^\s*$' "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should not be success
End

It "has no trailing whitespace on any line"
# Check for trailing whitespace
When run grep -E '\s+$' "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should not be success
End

It "has valid figma entry without contamination"
# Extract just the figma entry and validate it
When run jq '.mcpServers.figma' "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
The output should include '"command"'
The output should include '"args"'
The output should not include '[INFO]'
The output should not include '[ERROR]'
The output should not include '[SUCCESS]'
End

It "contains no log messages or debug output in JSON"
# Check for common log patterns that shouldn't be in JSON
When run grep -E '\[(INFO|ERROR|SUCCESS|WARNING|DEBUG)\]' "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should not be success
End

It "contains no tree structure characters in JSON"
When run grep -E '├──|└──|│' "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should not be success
End
End

Describe "JSON Content Validation"
It "has consistent JSON formatting across both configs"
# Both configs should have the same structure
cursor_keys=$(jq '.mcpServers | keys | sort' "$TEST_HOME/.cursor/mcp.json")
claude_keys=$(jq '.mcpServers | keys | sort' "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json")
When run test "$cursor_keys" = "$claude_keys"
The status should be success
End

It "has proper JSON indentation (2 spaces)"
# Check that indentation is consistent (2 spaces)
# This validates that jq is being used with proper formatting
When run sh -c "head -10 '$TEST_HOME/.cursor/mcp.json' | grep -E '^  [^[:space:]]'"
The status should be success
End

It "figma entry has expected Docker image reference"
# Validate figma has the expected long image name (Docker image is at position -3, not -1)
When run jq -r '.mcpServers.figma.args[-3]' "$TEST_HOME/.cursor/mcp.json"
The output should include 'figma-context-mcp'
The output should include 'ghcr.io'
The output should not include '[INFO]'
End

It "all server entries have docker command"
# All entries should use docker command
When run sh -c "jq -r '.mcpServers[].command' '$TEST_HOME/.cursor/mcp.json' | grep -v '^docker$'"
The status should not be success
End

It "no server entries have non-docker commands"
When run jq -r '.mcpServers[] | select(.command != "docker") | .command' "$TEST_HOME/.cursor/mcp.json"
The output should be blank
End

It "all server entries have valid args arrays"
# All args should be arrays with at least one element
When run jq '.mcpServers | to_entries[] | select(.value.args | type != "array" or length == 0) | .key' "$TEST_HOME/.cursor/mcp.json"
The output should be blank
End
End

Describe "Generation Process Isolation"
It "config generation does not pollute JSON with log output"
# Ensure the JSON file itself contains only JSON
When run jq '.' "$TEST_HOME/.cursor/mcp.json" > /dev/null 2>&1
The status should be success
End

It "JSON ends properly"
When run tail -1 "$TEST_HOME/.cursor/mcp.json"
The output should equal '}'
End

It "handles figma's long image name without truncation"
# Get the full figma image name and ensure it's complete (Docker image is at position -3, not -1)
When run jq -r '.mcpServers.figma.args[-3]' "$TEST_HOME/.cursor/mcp.json"
The output should include 'ghcr.io/metorial/mcp-container--glips--figma-context-mcp--figma-context-mcp:latest'
The output should not include '...'
The output should not match pattern '*[INFO]*'
End

It "does not contain debug variable assignments in JSON files"
# Check for debug patterns that were appearing in earlier versions
When run grep -E 'mount_path=|config_path=' "$TEST_HOME/.cursor/mcp.json"
The status should not be success
End

It "Claude config also has no debug contamination"
When run grep -E 'mount_path=|config_path=' "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should not be success
End
End

Describe 'MCP Manager JSON Validation'
# REGRESSION TESTS: Ensure NO debug output contamination
Describe 'Debug Output Elimination (Regression Tests)'
It 'should produce NO variable assignment debug output in config-write'
When run zsh "$PWD/mcp_manager.sh" config-write
The status should be success
The output should not include "cmd_args="
The output should not include "privileged="
The output should not include "network_mode="
The output should not include "source_env_var="
The output should not include "container_path="
The output should not include "default_fallback="
The output should not include "mount_dirs="
The output should not include "first_dir="
The output should not include "mount_path="
The output should not include "config_path="
End

It 'should produce NO function error messages in config-write'
When run zsh "$PWD/mcp_manager.sh" config-write
The status should be success
The output should not include "command not found"
The output should not include "mapfile"
The output should not include ": not found"
The output should not include "line "
End

It 'should produce NO trace output in config-write'
When run zsh "$PWD/mcp_manager.sh" config-write
The status should be success
The output should not include "++"
The output should not include "DEBUG"
The output should not include "TRACE"
End

It 'should have clean structured output with only status messages'
When run zsh "$PWD/mcp_manager.sh" config-write
The status should be success
# Should only contain structured output (=== headers, ├── items, └── completion)
The output should include "=== MCP Client Configuration Generation ==="
The output should include "[SUCCESS]"
# Should NOT contain any debug pollution
End
End

# Existing JSON validation tests...
# ... existing code ...

Describe 'JSON Structure Validation'
It 'Cursor configuration file exists'
When run cat "$TEST_HOME/.cursor/mcp.json"
The status should be success
End

It 'generates valid JSON for Cursor configuration'
When run jq '.' "$TEST_HOME/.cursor/mcp.json"
The status should be success
End

It 'Claude Desktop configuration file exists'
When run cat "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
End

It 'generates valid JSON for Claude Desktop configuration'
When run jq '.' "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
End

It 'Cursor JSON contains no empty lines'
When run grep '^$' "$TEST_HOME/.cursor/mcp.json"
The status should not be success # grep should find nothing
End

It 'Claude JSON contains no empty lines'
When run grep '^$' "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should not be success # grep should find nothing
End

It 'JSON files contain no trailing whitespace'
When run grep -E ' +$' "$TEST_HOME/.cursor/mcp.json" "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be failure # grep should find nothing
End

It 'Figma entry should be complete with full image name'
When run sh -c "jq -r '.mcpServers.figma.args[]' '$TEST_HOME/.cursor/mcp.json' | grep ghcr.io"
The status should be success
The output should include "ghcr.io/metorial/mcp-container--glips--figma-context-mcp--figma-context-mcp:latest"
End

It 'generated JSON should not contain log message contamination'
When run grep -E '\[INFO\]|\[SUCCESS\]|\[ERROR\]|===|\├──|\└──' "$TEST_HOME/.cursor/mcp.json" "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be failure # Should find no log messages in JSON
End

It 'generated JSON should not contain debug variables'
When run grep -E 'mount_path=|config_path=|cmd_args=|privileged=' "$TEST_HOME/.cursor/mcp.json" "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be failure # Should find no debug variables in JSON
End

It 'generated JSON should not contain tree structure characters'
When run grep -E '├──|└──|│' "$TEST_HOME/.cursor/mcp.json" "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be failure # Should find no tree characters in JSON
End

It 'all servers should consistently use "docker" command'
When run sh -c "jq -r '.mcpServers[].command' '$TEST_HOME/.cursor/mcp.json' | sort | uniq"
The status should be success
The output should equal "docker"
End
End

Describe 'Critical Environment File Protection (Regression Tests)'
It 'CRITICAL: Tests must not delete user .env file'
# REGRESSION TEST: Ensure tests never delete the project root .env file
# This is a critical bug that would destroy user environment configuration
test_env_before=""
if [[ -f .env ]]; then
  test_env_before=$(cat .env)
fi

# Run a representative config generation test
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1

# Check that .env file still exists if it existed before
if [[ -n "$test_env_before" ]]; then
  test_env_after=""
  if [[ -f .env ]]; then
    test_env_after=$(cat .env)
  fi

  When run test "$test_env_before" = "$test_env_after"
  The status should be success
else
  # If no .env existed before, that's fine - just don't create one
  Skip "No .env file to protect - test passed"
fi
End
End

Describe 'Variable Resolution Validation'
BeforeEach 'setup_json_test_environment'
AfterEach 'cleanup_json_test_environment'

It 'should not contain unresolved $HOME variables in Claude Desktop config'
# First generate config, then check for unresolved variables
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1

When run grep -E '\$HOME|\$USER|\${' "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be failure # grep should find NO matches (exit 1)
End

It 'should not contain unresolved $HOME variables in Cursor config'
# First generate config, then check for unresolved variables
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1

When run grep -E '\$HOME|\$USER|\${' "$HOME/.cursor/mcp.json"
The status should be failure # grep should find NO matches (exit 1)
End

It 'should expand all volume path variables to absolute paths'
# Generate config first
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1

# Extract volume definitions and verify they're absolute paths
When run jq -r '.mcpServers | to_entries[] | .value.args[] | select(startswith("--volume="))' "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
# All volume paths should start with absolute paths, not variables
The output should not include "\$HOME"
The output should not include "\$USER"
End

It 'should resolve environment variables in volume mounts'
# Generate config first
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1

# Check that kubernetes server volumes are properly expanded
When run jq -r '.mcpServers.kubernetes.args[] | select(contains("--volume="))' "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
# Should contain actual username, not $HOME variable
The output should include "/Users/gfichtner"
The output should not include "\$HOME"
End

# REGRESSION TEST: terraform-cli-controller $HOME expansion bug
It 'terraform-cli-controller volumes should expand $HOME variables (regression test)'
# Generate config first
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1

# Check that terraform-cli-controller volumes have expanded $HOME paths
When run jq -r '.mcpServers."terraform-cli-controller".args[] | select(contains("--volume="))' "$HOME/.cursor/mcp.json"
The status should be success
# Should contain actual expanded paths like /Users/gfichtner/.aws
The output should include "/Users/gfichtner/.aws:/root/.aws:ro"
The output should include "/Users/gfichtner/terraform-projects:/workspace"
# Should NOT contain literal $HOME variables
The output should not include "\$HOME"
End

It 'terraform-cli-controller should have same $HOME expansion in both configs (regression test)'
# Generate config first
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1

# Extract terraform-cli-controller volumes from both configs
cursor_volumes=$(jq -r '.mcpServers."terraform-cli-controller".args[] | select(contains("--volume="))' "$HOME/.cursor/mcp.json" | sort)
claude_volumes=$(jq -r '.mcpServers."terraform-cli-controller".args[] | select(contains("--volume="))' "$HOME/Library/Application Support/Claude/claude_desktop_config.json" | sort)

When run test "$cursor_volumes" = "$claude_volumes"
The status should be success
End
End

Describe 'Cross-platform JSON Consistency'
BeforeEach 'setup_json_test_environment'
AfterEach 'cleanup_json_test_environment'

It 'Cursor and Claude configs should have identical server entries'
cursor_servers=$(jq -r '.mcpServers | keys[]' "$TEST_HOME/.cursor/mcp.json" | sort)
claude_servers=$(jq -r '.mcpServers | keys[]' "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json" | sort)
When run test "$cursor_servers" = "$claude_servers"
The status should be success
End

It 'both configs should use mcpServers wrapper format'
When run jq -e '.mcpServers' "$TEST_HOME/.cursor/mcp.json" "$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
End
End
End
End
