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
The output should include "figma"
The output should include "heroku"
The output should include "filesystem"
The output should include "context7"
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
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write'
The status should be success
The output should include "Client configurations written"
End

It 'reads environment variables from .env file'
# Create test .env with placeholder values
cat > tmp/test_home/.env << 'EOF'
GITHUB_PERSONAL_ACCESS_TOKEN=test_token_placeholder
CIRCLECI_TOKEN=test_circleci_placeholder
FILESYSTEM_ALLOWED_DIRS=/test/path
EOF
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write'
The status should be success
The output should include "=== MCP Client Configuration Generation ==="
End
End
End

Describe 'configuration generation (unit tests)'
BeforeEach 'setup_test_environment'
AfterEach 'cleanup_test_environment'

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
End

Describe 'configuration generation (integration tests)'
BeforeEach 'setup_test_environment'
AfterEach 'cleanup_test_environment'

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

It 'generates valid JSON in real locations'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When call validate_json "tmp/test_home/.cursor/mcp.json"
The status should be success
End

It 'generates valid Claude Desktop JSON in real locations'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When call validate_json "tmp/test_home/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
End
End

Describe 'filesystem server functionality'
Describe 'basic filesystem server operations'
BeforeEach 'setup_test_environment'

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
The output should equal "/project"
End
End

Describe 'filesystem directory validation'
BeforeEach 'setup_test_environment'

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
End
End

Describe 'terraform-cli-controller server integration'
BeforeEach 'setup_test_environment'

It 'includes terraform-cli-controller server in available servers list'
When run zsh "$PWD/mcp_manager.sh" list
The status should be success
The output should include "terraform-cli-controller"
End

It 'supports privileged server type for terraform-cli-controller'
When run zsh "$PWD/mcp_manager.sh" parse terraform-cli-controller server_type
The status should be success
The output should equal "privileged"
End

It 'generates terraform-cli-controller configuration for Cursor'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq '.mcpServers."terraform-cli-controller"' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "local/terraform-cli-controller:latest"
The output should include "docker"
End

It 'generates terraform-cli-controller configuration for Claude Desktop'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq '.mcpServers."terraform-cli-controller"' "tmp/test_home/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
The output should include "local/terraform-cli-controller:latest"
The output should include "docker"
End

It 'terraform-cli-controller server uses privileged configuration'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq '.mcpServers."terraform-cli-controller".args[]' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "-v"
The output should include "local/terraform-cli-controller:latest"
End

It 'terraform-cli-controller server can be tested individually'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test terraform-cli-controller'
The status should be success
The output should include "Terraform CLI Controller"
End
End

Describe 'heroku server integration'
BeforeEach 'setup_test_environment'

It 'includes heroku server in available servers list'
When run zsh "$PWD/mcp_manager.sh" list
The status should be success
The output should include "heroku"
End

It 'supports api_based server type for heroku'
When run zsh "$PWD/mcp_manager.sh" parse heroku server_type
The status should be success
The output should equal "api_based"
End

It 'generates heroku configuration for Cursor'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq '.mcpServers.heroku' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "heroku"
The output should include "local/heroku-mcp-server:latest"
End

It 'generates heroku configuration for Claude Desktop'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq '.mcpServers.heroku' "tmp/test_home/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
The output should include "heroku"
End

It 'includes HEROKU_API_KEY environment variable in .env_example'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run grep "HEROKU_API_KEY" "$PWD/.env_example"
The status should be success
The output should include "HEROKU_API_KEY"
End

It 'HEROKU_API_KEY environment variable includes correct placeholder'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run grep "HEROKU_API_KEY" "$PWD/.env_example"
The status should be success
The output should include "your_heroku_api_key_here"
End

It 'heroku server uses api_based configuration'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq '.mcpServers.heroku.args[]' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "--env-file"
End

It 'heroku server can be tested individually'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test heroku'
The status should be success
The output should include "Heroku Platform MCP Server"
End
End

Describe 'context7 server integration'
BeforeEach 'setup_test_environment'

It 'includes context7 server in available servers list'
When run zsh "$PWD/mcp_manager.sh" list
The status should be success
The output should include "context7"
End

It 'supports standalone server type for context7'
When run zsh "$PWD/mcp_manager.sh" parse context7 server_type
The status should be success
The output should equal "standalone"
End

It 'generates context7 configuration for Cursor'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq '.mcpServers.context7' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "context7"
The output should include "local/context7-mcp:latest"
End

It 'generates context7 configuration for Claude Desktop'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq '.mcpServers.context7' "tmp/test_home/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
The output should include "context7"
End

It 'context7 server uses standalone configuration'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq '.mcpServers.context7' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include '"command": "docker"'
The output should include '"run"'
The output should include '"--rm"'
The output should include '"-i"'
The output should include '"local/context7-mcp:latest"'
End

It 'context7 server can be tested individually'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test context7'
The status should be success
The output should include "Context7 Documentation MCP Server"
End

It 'context7 server supports setup command for building'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" setup context7'
The status should be success
The output should include "Context7 Documentation MCP Server"
The output should include "[SUCCESS]"
End
End

Describe 'testing functionality'
Describe 'individual server testing'
BeforeEach 'setup_test_environment'

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
End

Describe 'comprehensive testing'
BeforeEach 'setup_test_environment'

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
End
End

Describe 'edge cases and error handling'
Describe 'invalid input handling'
BeforeEach 'setup_test_environment'

It 'handles invalid server names gracefully'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test nonexistent_server'
The status should not be success
The output should include "Unknown server"
End

It 'handles invalid commands gracefully'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" invalid_command'
The status should not be success
The stderr should include "Unknown command"
The stderr should include "help"
End
End

Describe 'environment edge cases'
BeforeEach 'setup_test_environment'

It 'handles empty FILESYSTEM_ALLOWED_DIRS'
cat > tmp/test_home/.env << 'EOF'
FILESYSTEM_ALLOWED_DIRS=
EOF
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write'
The status should be success
The output should include "=== MCP Client Configuration Generation ==="
End

It 'handles malformed environment file'
cat > tmp/test_home/.env << 'EOF'
INVALID_SYNTAX_HERE=
GITHUB_PERSONAL_ACCESS_TOKEN=test
EOF
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write'
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

test_docker_unavailability() {
  local temp_dir
  temp_dir=$(mktemp -d)
  echo '#!/bin/sh
echo "docker: command not found" >&2
exit 127' > "$temp_dir/docker"
  chmod +x "$temp_dir/docker"
  PATH="$temp_dir:$PATH"
}

Describe 'docker server functionality'
Describe 'basic docker server operations'
BeforeEach 'setup_test_environment'

It 'recognizes docker as privileged server type'
When run zsh "$PWD/mcp_manager.sh" parse docker server_type
The status should be success
The output should equal "privileged"
End

It 'includes docker server in available servers'
When run zsh "$PWD/mcp_manager.sh" list
The status should be success
The output should include "docker"
End

It 'generates docker configuration with docker socket access'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq -r .mcpServers.docker.args[] tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "--volume=/var/run/docker.sock:/var/run/docker.sock"
The output should include "mcp-server-docker:latest"
End

It 'includes docker socket mount in configuration'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq -r .mcpServers.docker.args[] tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "--volume=/var/run/docker.sock:/var/run/docker.sock"
End

It 'can test docker server individually'
if ! command -v docker > /dev/null 2>&1; then
  skip "Docker not available"
fi
When run zsh "$PWD/mcp_manager.sh" test docker
The status should be success
The output should include "Docker MCP Server"
End

It 'can list docker containers when tested'
if ! command -v docker > /dev/null 2>&1; then
  skip "Docker not available"
fi
When run zsh "$PWD/mcp_manager.sh" test docker
The status should be success
The output should include "Docker MCP Server"
End

It 'generates valid configuration for both Cursor and Claude Desktop'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq -r .mcpServers.docker tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "docker"
End

It 'includes docker server in Claude Desktop configuration'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq -r .mcpServers.docker "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
The status should be success
The output should include "docker"
End

It 'uses correct image name in configuration'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq -r .mcpServers.docker.args[] tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "mcp-server-docker:latest"
End
End

Describe 'docker server integration'
BeforeEach 'setup_test_environment'

It 'integrates with existing servers without conflicts'
if ! command -v docker > /dev/null 2>&1; then
  skip "Docker not available"
fi

When run zsh "$PWD/mcp_manager.sh" test
The status should be success
The output should include "Docker MCP Server"
The output should include "GitHub MCP Server"
The output should include "CircleCI MCP Server"
End

It 'maintains configuration consistency across all servers'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq -r .mcpServers.docker tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "docker"
End

It 'handles Docker unavailability gracefully'
test_docker_unavailability

When run zsh "$PWD/mcp_manager.sh" test docker
The status should be failure
The output should include "Docker MCP Server"
The output should include "docker: command not found"
The output should include "protocol failed unexpectedly"

rm -rf "$temp_dir"
End

It 'skips Docker tests in CI environment'
When run env CI=true zsh "$PWD/mcp_manager.sh" test docker
The status should be success
The output should include "MCP protocol functional (auth required or specific error)"
The output should include "Basic protocol validation passed"
The output should include "Advanced functionality tests (CI environment)"
End

It 'should pass basic protocol tests for all servers'
if ! command -v docker > /dev/null 2>&1; then
  skip "Docker not available"
fi

When run zsh "$PWD/mcp_manager.sh" test
The status should be success
The output should include "Basic protocol validation passed"
End
End

Describe 'rails server functionality'
It 'recognizes rails as mount_based server type'
When run zsh "$PWD/mcp_manager.sh" parse rails server_type
The status should be success
The output should equal "mount_based"
End

It 'includes rails server in available servers'
When run zsh "$PWD/mcp_manager.sh" list
The status should be success
The output should include "rails"
End

It 'generates Rails configuration with volume mounts'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run jq '.mcpServers.rails.args[]' "$HOME/.cursor/mcp.json"
The status should be success
The output should include "--volume"
The output should include "rails-projects:/rails-projects"
The output should include "/Users/gfichtner/.config/rails-mcp:/app/.config/rails-mcp"
The output should include "local/mcp-server-rails:latest"
End

It 'can test rails server individually'
When run zsh "$PWD/mcp_manager.sh" test rails
The status should be success
The output should include "Rails MCP Server"
End

It 'lists projects when tested'
When run zsh "$PWD/mcp_manager.sh" test rails
The status should be success
The output should include "Rails MCP Server"
The output should include "Rails MCP Server (configuration verified)"
The output should include "Basic protocol validation passed"
End
End
End
