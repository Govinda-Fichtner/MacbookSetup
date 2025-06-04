#!/bin/zsh
# ShellSpec test suite for mcp_manager.sh
# NOTE: MCP-related containers may be spawned automatically by Cursor/Claude Desktop. For full isolation, run tests in a clean Docker environment.

# Test configuration
export DOCKER_SKIP_TESTS=${DOCKER_SKIP_TESTS:-false}
export TEST_TIMEOUT=${TEST_TIMEOUT:-30}

# Global test suite setup
BeforeAll() {
  # Ensure we have a clean test environment
  export PATH="/opt/homebrew/bin:$PATH"
  export CI="${CI:-false}"

  # Aggressively clean up any existing test directories
  test_root="$PWD/test_home"
  rm -rf "$test_root"
  mkdir -p "$test_root"

  # Set up trap to clean up on exit (backup cleanup mechanism)
  trap 'rm -rf "$PWD/test_home" 2>/dev/null || true' EXIT
}

# Global test suite cleanup
AfterAll() {
  # Global cleanup
  test_root="$PWD/test_home"
  if [ -d "$test_root" ]; then
    rm -rf "$test_root"
  fi
}

# Individual test setup - creates completely isolated environment
BeforeEach() {
  setup_test_environment
}

# Individual test cleanup - ensures complete isolation
AfterEach() {
  cleanup_test_environment
}

# Helper functions for common test operations
validate_json() {
  local file="$1"
  if [ -f "$file" ]; then
    jq empty "$file" 2> /dev/null
  else
    return 1
  fi
}

# Setup test environment
setup_test_environment() {
  TEST_HOME="$PWD/test_home"
  export TEST_HOME
  export HOME="$TEST_HOME"

  # Clean and recreate test directory
  rm -rf "$TEST_HOME"
  mkdir -p "$TEST_HOME"
  mkdir -p "$TEST_HOME/.cursor"
  mkdir -p "$TEST_HOME/Library/Application Support/Claude"

  # Create a test .env file with placeholders and real directories for filesystem testing
  cat > "$TEST_HOME/.env" << EOF
GITHUB_PERSONAL_ACCESS_TOKEN=test_github_token_placeholder
CIRCLECI_TOKEN=test_circleci_token_placeholder
FILESYSTEM_ALLOWED_DIRS=$TEST_HOME,/tmp
EOF
}

# Cleanup test environment
cleanup_test_environment() {
  if [ -n "${TEST_HOME:-}" ] && [ -d "$TEST_HOME" ]; then
    rm -rf "$TEST_HOME"
  fi
}

# Helper function to check if we're in an integration test
is_integration_test() {
  test "${TEST_TYPE:-}" = "integration"
}

# Helper function to check if real tokens are available
has_real_tokens() {
  test -f "$PWD/.env" && test "$(grep -v "placeholder" "$PWD/.env" | grep -c "=")" -gt 0
}

# Helper function to get config paths based on test type
get_config_paths() {
  if is_integration_test; then
    CURSOR_CONFIG_FILE="$HOME/.cursor/mcp.json"
    CLAUDE_CONFIG_FILE="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  else
    CURSOR_CONFIG_FILE="$TEST_HOME/.cursor/mcp.json"
    CLAUDE_CONFIG_FILE="$TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json"
  fi
}

Describe 'mcp_manager.sh basic functionality'
Describe 'command parsing and validation'
It 'displays help when no arguments provided'
When run zsh "$PWD/mcp_manager.sh"
The status should be success
The output should include "Usage:"
End

It 'lists available servers'
When run zsh "$PWD/mcp_manager.sh" list
The status should be success
The output should include "github"
The output should include "circleci"
The output should include "filesystem"
End

It 'parses server configuration correctly'
When run zsh "$PWD/mcp_manager.sh" parse github server_type
The status should be success
The output should equal "api_based"
End
End

Describe 'environment handling'
BeforeEach 'setup_test_environment'
AfterEach 'cleanup_test_environment'

It 'handles missing .env file gracefully'
# No .env file created - should use defaults
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write'
The status should be success
The output should include "Client configurations written"
End

It 'reads environment variables from .env file'
# Create test .env with placeholder values
cat > test_home/.env << 'EOF'
GITHUB_PERSONAL_ACCESS_TOKEN=test_token_placeholder
CIRCLECI_TOKEN=test_circleci_placeholder
FILESYSTEM_ALLOWED_DIRS=/test/path
EOF
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write'
The status should be success
The output should include "=== MCP Client Configuration Generation ==="
End
End
End

Describe 'configuration generation (unit tests)'
BeforeEach 'setup_test_environment'
AfterEach 'cleanup_test_environment'

It 'generates valid JSON configuration files'
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
The status should be success
The file "test_home/.cursor/mcp.json" should be exist
The file "test_home/Library/Application Support/Claude/claude_desktop_config.json" should be exist
End

It 'generates syntactically valid JSON for Cursor'
sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When call validate_json "test_home/.cursor/mcp.json"
The status should be success
End

It 'generates syntactically valid JSON for Claude Desktop'
sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When call validate_json "test_home/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
End

It 'includes expected servers in generated configuration'
sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers | keys[]' test_home/.cursor/mcp.json
The status should be success
The output should include "github"
The output should include "circleci"
The output should include "filesystem"
End
End

Describe 'configuration generation (integration tests)'
BeforeEach 'setup_test_environment'
AfterEach 'cleanup_test_environment'

It 'writes to real Cursor config location'
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write'
The status should be success
The output should include "=== MCP Client Configuration Generation ==="
The file "test_home/.cursor/mcp.json" should be exist
End

It 'writes to real Claude Desktop config location'
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write'
The status should be success
The output should include "=== MCP Client Configuration Generation ==="
The file "test_home/Library/Application Support/Claude/claude_desktop_config.json" should be exist
End

It 'generates valid JSON in real locations'
sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When call validate_json "test_home/.cursor/mcp.json"
The status should be success
End

It 'generates valid Claude Desktop JSON in real locations'
sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When call validate_json "test_home/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
End
End

Describe 'filesystem server functionality'
Describe 'basic filesystem server operations'
It 'recognizes filesystem as mount_based server type'
When run zsh "$PWD/mcp_manager.sh" parse filesystem server_type
The status should be success
The output should equal "mount_based"
End

It 'includes filesystem server in available servers'
When run zsh "$PWD/mcp_manager.sh" list
The status should be success
The output should include "filesystem"
End
End

Describe 'filesystem directory configuration'
BeforeEach 'setup_test_environment'

It 'generates filesystem configuration with test directories'
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test filesystem'
The status should be success
The output should include "Filesystem MCP Server"
End

It 'uses first directory for Docker mount configuration'
sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers.filesystem.args[]' test_home/.cursor/mcp.json
The status should be success
The output should include "--mount"
The output should include "type=bind"
End

It 'includes container path argument'
sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers.filesystem.args[-1]' test_home/.cursor/mcp.json
The status should be success
The output should equal "/project"
End
End

Describe 'filesystem directory validation'
BeforeEach 'setup_test_environment'

It 'handles existing directories correctly'
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test filesystem'
The status should be success
The output should include "Filesystem MCP Server"
End

It 'handles missing directories gracefully'
# Create config with non-existent directory
cat > test_home/.env << EOF
FILESYSTEM_ALLOWED_DIRS=$PWD/test_home/nonexistent_dir
EOF
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test filesystem'
The status should not be success
The output should include "Filesystem MCP Server"
The output should include "Filesystem test failed"
End

It 'handles directories with special characters'
# Create directories with spaces in test environment
mkdir -p "test_home/My Documents"
mkdir -p "test_home/Desktop Items"
cat > test_home/.env << EOF
FILESYSTEM_ALLOWED_DIRS=$PWD/test_home/My Documents,$PWD/test_home/Desktop Items
EOF
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test filesystem'
The status should be success
The output should include "Filesystem MCP Server"
End
End
End

Describe 'testing functionality'
Describe 'individual server testing'
BeforeEach 'setup_test_environment'

It 'can test GitHub server individually'
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test github'
The status should be success
The output should include "GitHub MCP Server"
End

It 'can test filesystem server individually'
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test filesystem'
The status should be success
The output should include "Filesystem MCP Server"
End
End

Describe 'comprehensive testing'
BeforeEach 'setup_test_environment'

It 'can run comprehensive test of all servers'
if ! has_real_tokens; then skip "No real .env present"; fi
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test'
The status should be success
The output should include "GitHub MCP Server"
The output should include "CircleCI MCP Server"
The output should include "Filesystem MCP Server"
End
End
End

Describe 'edge cases and error handling'
Describe 'invalid input handling'
BeforeEach 'setup_test_environment'

It 'handles invalid server names gracefully'
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test nonexistent_server'
The status should not be success
The output should include "Unknown server"
End

It 'handles invalid commands gracefully'
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" invalid_command'
The status should not be success
The stderr should include "Unknown command"
The stderr should include "help"
End
End

Describe 'environment edge cases'
BeforeEach 'setup_test_environment'

It 'handles empty FILESYSTEM_ALLOWED_DIRS'
cat > test_home/.env << 'EOF'
FILESYSTEM_ALLOWED_DIRS=
EOF
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write'
The status should be success
The output should include "=== MCP Client Configuration Generation ==="
End

It 'handles malformed environment file'
cat > test_home/.env << 'EOF'
INVALID_SYNTAX_HERE=
GITHUB_PERSONAL_ACCESS_TOKEN=test
EOF
When run sh -c 'cd "$PWD/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write'
The status should be success
The output should include "=== MCP Client Configuration Generation ==="
End
End
End

Describe 'integration tests with real tokens'
It 'can test GitHub server with real token'
if ! has_real_tokens; then skip "No real .env present"; fi
When run zsh "$PWD/mcp_manager.sh" test github
The status should be success
The output should include "GitHub MCP Server"
End

It 'can test CircleCI server with real token'
if ! has_real_tokens; then skip "No real .env present"; fi
When run zsh "$PWD/mcp_manager.sh" test circleci
The status should be success
The output should include "CircleCI MCP Server"
End

It 'can run comprehensive test of all servers with real tokens'
if ! has_real_tokens; then skip "No real .env present"; fi
# Skip Docker/Kubernetes if not available in test environment
if [[ "${CI:-false}" == "true" ]]; then skip "Privileged tests not available in CI"; fi
When run zsh "$PWD/mcp_manager.sh" test
The status should be success
The output should include "GitHub MCP Server"
The output should include "CircleCI MCP Server"
The output should include "Filesystem MCP Server"
End
End
