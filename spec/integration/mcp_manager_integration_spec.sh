#!/bin/zsh
# Integration tests for mcp_manager.sh
# Slower tests that require Docker and real file operations - extracted from original mcp_manager_spec.sh

# Test configuration
export DOCKER_SKIP_TESTS=${DOCKER_SKIP_TESTS:-false}
export TEST_TIMEOUT=${TEST_TIMEOUT:-30}

# Global test suite setup
BeforeAll() {
  # Ensure we have a clean test environment
  export PATH="/opt/homebrew/bin:$PATH"
  export CI="${CI:-false}"

  # Aggressively clean up any existing test directories
  test_root="$PWD/tmp/test_home"
  rm -rf "$test_root"
  mkdir -p "$test_root"

  # Set up trap to clean up on exit (backup cleanup mechanism)
  trap 'rm -rf "$PWD/tmp/test_home" 2>/dev/null || true' EXIT
}

# Global test suite cleanup
AfterAll() {
  # Global cleanup
  test_root="$PWD/tmp/test_home"
  if [ -d "$test_root" ]; then
    rm -rf "$test_root"
  fi
}

# Individual test setup - creates completely isolated environment
BeforeEach() {
  setup_integration_test_environment
}

# Individual test cleanup - ensures complete isolation
AfterEach() {
  cleanup_integration_test_environment
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

# Setup test environment for integration tests
setup_integration_test_environment() {
  TEST_HOME="$PWD/tmp/test_home"
  export TEST_HOME
  export HOME="$TEST_HOME"

  # Clean and recreate test directory
  rm -rf "$TEST_HOME"
  mkdir -p "$TEST_HOME"
  mkdir -p "$TEST_HOME/.cursor"
  mkdir -p "$TEST_HOME/Library/Application Support/Claude"

  # Create .cargo/env to prevent zsh warnings in test environment
  mkdir -p "$TEST_HOME/.cargo"
  touch "$TEST_HOME/.cargo/env"

  # Create a test .env file with placeholders and real directories for filesystem testing
  cat > "$TEST_HOME/.env" << EOF
GITHUB_PERSONAL_ACCESS_TOKEN=test_github_token_placeholder
CIRCLECI_TOKEN=test_circleci_token_placeholder
FILESYSTEM_ALLOWED_DIRS=$TEST_HOME,/tmp
HEROKU_API_KEY=test_heroku_api_key_placeholder
EOF
}

# Cleanup test environment
cleanup_integration_test_environment() {
  if [ -n "${TEST_HOME:-}" ] && [ -d "$TEST_HOME" ]; then
    rm -rf "$TEST_HOME"
  fi
}

# Helper function to check if real tokens are available
has_real_tokens() {
  test -f "$PWD/.env" && test "$(grep -v "placeholder" "$PWD/.env" | grep -c "=")" -gt 0
}

Describe 'MCP Manager Integration Tests'

Describe 'Configuration File Generation (Integration)'
BeforeEach 'setup_integration_test_environment'
AfterEach 'cleanup_integration_test_environment'

It 'generates valid JSON configuration files'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
The status should be success
The file "tmp/test_home/.cursor/mcp.json" should be exist
The file "tmp/test_home/Library/Application Support/Claude/claude_desktop_config.json" should be exist
End

It 'generates syntactically valid JSON for Cursor'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When call validate_json "tmp/test_home/.cursor/mcp.json"
The status should be success
End

It 'generates syntactically valid JSON for Claude Desktop'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When call validate_json "tmp/test_home/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
End

It 'includes expected servers in generated configuration'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers | keys[]' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "github"
The output should include "circleci"
The output should include "figma"
The output should include "heroku"
The output should include "filesystem"
The output should include "context7"
End

It 'writes to real Cursor config location'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write'
The status should be success
The output should include "=== MCP Client Configuration Generation ==="
The file "tmp/test_home/.cursor/mcp.json" should be exist
End

It 'writes to real Claude Desktop config location'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write'
The status should be success
The output should include "=== MCP Client Configuration Generation ==="
The file "tmp/test_home/Library/Application Support/Claude/claude_desktop_config.json" should be exist
End
End

Describe 'Filesystem Server Integration'
BeforeEach 'setup_integration_test_environment'
AfterEach 'cleanup_integration_test_environment'

It 'generates filesystem configuration with test directories'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test filesystem'
The status should be success
The output should include "Filesystem MCP Server"
End

It 'uses first directory for Docker mount configuration'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers.filesystem.args[]' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "--volume"
The output should include "/project"
End

It 'includes container path argument'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers.filesystem.args[-1]' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "/projects/"
End

It 'handles existing directories correctly'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test filesystem'
The status should be success
The output should include "Filesystem MCP Server"
End

It 'handles missing directories gracefully'
# Create config with non-existent directory
cat > tmp/test_home/.env << EOF
FILESYSTEM_ALLOWED_DIRS=$PWD/tmp/test_home/nonexistent_dir
EOF
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test filesystem'
The status should not be success
The output should include "Filesystem MCP Server"
The output should include "Directory not found"
End

It 'handles directories with special characters'
# Create directories with spaces in test environment
mkdir -p "tmp/test_home/My Documents"
mkdir -p "tmp/test_home/Desktop Items"
cat > tmp/test_home/.env << EOF
FILESYSTEM_ALLOWED_DIRS=$PWD/tmp/test_home/My Documents,$PWD/tmp/test_home/Desktop Items
EOF
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test filesystem'
The status should be success
The output should include "Filesystem MCP Server"
End

It 'supports multiple directories in FILESYSTEM_ALLOWED_DIRS for configuration generation'
# Create multiple test directories
mkdir -p "tmp/test_home/MacbookSetup"
mkdir -p "tmp/test_home/Desktop"
mkdir -p "tmp/test_home/Downloads"
mkdir -p "tmp/test_home/rails-projects"
cat > tmp/test_home/.env << EOF
FILESYSTEM_ALLOWED_DIRS=$PWD/tmp/test_home/MacbookSetup,$PWD/tmp/test_home/Desktop,$PWD/tmp/test_home/Downloads,$PWD/tmp/test_home/rails-projects
EOF
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers.filesystem.args[]' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "--volume"
The output should include "MacbookSetup:/projects/MacbookSetup"
The output should include "Desktop:/projects/Desktop"
The output should include "Downloads:/projects/Downloads"
The output should include "rails-projects:/projects/rails-projects"
End

It 'maps each directory to individual /projects/<dirname> paths in Cursor config'
# Create multiple test directories
mkdir -p "tmp/test_home/MacbookSetup"
mkdir -p "tmp/test_home/Desktop"
mkdir -p "tmp/test_home/Downloads"
cat > tmp/test_home/.env << EOF
FILESYSTEM_ALLOWED_DIRS=$PWD/tmp/test_home/MacbookSetup,$PWD/tmp/test_home/Desktop,$PWD/tmp/test_home/Downloads
EOF
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers.filesystem.args | map(select(contains("/projects/"))) | join(" ")' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "MacbookSetup:/projects/MacbookSetup"
The output should include "Desktop:/projects/Desktop"
The output should include "Downloads:/projects/Downloads"
End

It 'maps each directory to individual /projects/<dirname> paths in Claude Desktop config'
# Create multiple test directories
mkdir -p "tmp/test_home/MacbookSetup"
mkdir -p "tmp/test_home/Desktop"
mkdir -p "tmp/test_home/Downloads"
cat > tmp/test_home/.env << EOF
FILESYSTEM_ALLOWED_DIRS=$PWD/tmp/test_home/MacbookSetup,$PWD/tmp/test_home/Desktop,$PWD/tmp/test_home/Downloads
EOF
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers.filesystem.args | map(select(contains("/projects/"))) | join(" ")' "tmp/test_home/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
The output should include "MacbookSetup:/projects/MacbookSetup"
The output should include "Desktop:/projects/Desktop"
The output should include "Downloads:/projects/Downloads"
End

It 'includes all directories as volume arguments, not just first one'
# Create multiple test directories
mkdir -p "tmp/test_home/Project1"
mkdir -p "tmp/test_home/Project2"
mkdir -p "tmp/test_home/Project3"
cat > tmp/test_home/.env << EOF
FILESYSTEM_ALLOWED_DIRS=$PWD/tmp/test_home/Project1,$PWD/tmp/test_home/Project2,$PWD/tmp/test_home/Project3
EOF
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers.filesystem.args | map(select(test(".*:/projects/.*"))) | length' tmp/test_home/.cursor/mcp.json
The status should be success
The output should equal "3"
End
End

Describe 'Individual Server Testing (Integration)'
BeforeEach 'setup_integration_test_environment'
AfterEach 'cleanup_integration_test_environment'

It 'can test GitHub server individually'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test github'
The status should be success
The output should include "GitHub MCP Server"
End

It 'can test Figma server individually'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test figma'
The status should be success
The output should include "Figma Context MCP Server"
End

It 'can test filesystem server individually'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test filesystem'
The status should be success
The output should include "Filesystem MCP Server"
End

It 'can test context7 server individually'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test context7'
The status should be success
The output should include "Context7 Documentation MCP Server"
End

It 'can test heroku server individually'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test heroku'
The status should be success
The output should include "Heroku Platform MCP Server"
End

It 'can test terraform-cli-controller server individually'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test terraform-cli-controller'
The status should be success
The output should include "Terraform CLI Controller"
End
End

Describe 'Docker Server Integration'
BeforeEach 'setup_integration_test_environment'
AfterEach 'cleanup_integration_test_environment'

It 'generates docker configuration with docker socket access'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r .mcpServers.docker.args[] tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "--volume=/var/run/docker.sock:/var/run/docker.sock"
The output should include "mcp-server-docker:latest"
End

It 'includes docker socket mount in configuration'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r .mcpServers.docker.args[] tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "--volume=/var/run/docker.sock:/var/run/docker.sock"
End

It 'can test docker server individually'
if ! command -v docker > /dev/null 2>&1; then
  skip "Docker not available"
fi
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test docker'
The status should be success
The output should include "Docker MCP Server"
End

It 'handles Docker unavailability gracefully'
# Test with Docker command unavailable
When run env PATH="/usr/bin:/bin" sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test docker'
The status should be failure
The output should include "Docker MCP Server"
The output should include "protocol failed unexpectedly"
End

It 'skips Docker tests in CI environment'
When run env CI=true sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test docker'
The status should be success
The output should include "MCP protocol functional (auth required or specific error)"
The output should include "Basic protocol validation passed"
The output should include "Advanced functionality tests (CI environment)"
End
End

Describe 'Rails Server Integration'
BeforeEach 'setup_integration_test_environment'
AfterEach 'cleanup_integration_test_environment'

It 'generates Rails configuration with volume mounts'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq '.mcpServers.rails.args[]' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "--volume"
The output should include "rails-projects:/rails-projects"
The output should include "/Users/user/.config:/app/.config/rails-mcp"
The output should include "local/mcp-server-rails:latest"
End

It 'can test rails server individually'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test rails'
The status should be success
The output should include "Rails MCP Server"
End

It 'lists projects when tested'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test rails'
The status should be success
The output should include "Rails MCP Server"
The output should include "Rails MCP Server (configuration verified)"
The output should include "Basic protocol validation passed"
End
End

Describe 'Setup Command Integration'
BeforeEach 'setup_integration_test_environment'
AfterEach 'cleanup_integration_test_environment'

It 'context7 server supports setup command for building'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" setup context7'
The status should be success
The output should include "Context7 Documentation MCP Server"
The output should include "[SUCCESS]"
End
End

Describe 'Comprehensive Testing (Integration)'
BeforeEach 'setup_integration_test_environment'
AfterEach 'cleanup_integration_test_environment'

It 'can run comprehensive test of all servers'
if ! has_real_tokens; then skip "No real .env present"; fi
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test'
The status should be success
The output should include "GitHub MCP Server"
The output should include "CircleCI MCP Server"
The output should include "Figma Context MCP Server"
The output should include "Heroku Platform MCP Server"
The output should include "Filesystem MCP Server"
The output should include "Terraform CLI Controller"
End

It 'integrates with existing servers without conflicts'
if ! command -v docker > /dev/null 2>&1; then
  skip "Docker not available"
fi

When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test'
The status should be success
The output should include "Docker MCP Server"
The output should include "GitHub MCP Server"
The output should include "CircleCI MCP Server"
End

It 'should pass basic protocol tests for all servers'
if ! command -v docker > /dev/null 2>&1; then
  skip "Docker not available"
fi

When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test'
The status should be success
The output should include "Basic protocol validation passed"
End
End

Describe 'Real Token Integration Tests'
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

It 'can test Heroku server with real token'
if ! has_real_tokens; then skip "No real .env present"; fi
When run zsh "$PWD/mcp_manager.sh" test heroku
The status should be success
The output should include "Heroku Platform MCP Server"
End

It 'can run comprehensive test of all servers with real tokens'
if ! has_real_tokens; then skip "No real .env present"; fi
# Skip Docker/Kubernetes if not available in test environment
if [[ "${CI:-false}" == "true" ]]; then skip "Privileged tests not available in CI"; fi
When run zsh "$PWD/mcp_manager.sh" test
The status should be success
The output should include "GitHub MCP Server"
The output should include "CircleCI MCP Server"
The output should include "Figma Context MCP Server"
The output should include "Heroku Platform MCP Server"
The output should include "Filesystem MCP Server"
The output should include "Terraform CLI Controller"
End
End

End
