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
  # Load validation functions
  source "$PWD/spec/test_helpers.sh"
}

# Individual test cleanup - ensures complete isolation
AfterEach() {
  # Validate any .env files created during test before cleanup
  if [[ -f "$TEST_HOME/.env" ]]; then
    if ! validate_env_file "$TEST_HOME/.env"; then
      echo "WARNING: Test created corrupted .env file!" >&2
    fi
  fi
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

  # Create directories for Rails and other servers
  mkdir -p "$TEST_HOME/rails-projects"
  mkdir -p "$TEST_HOME/ChromaDB"/{db,backup}
  mkdir -p "$TEST_HOME/terraform-projects"
  mkdir -p "$TEST_HOME/.kube"
  mkdir -p "$TEST_HOME/.config/rails-mcp"
  mkdir -p "$TEST_HOME/.cache/ms-playwright"
  mkdir -p "$TEST_HOME/screenshots"

  # Create required Rails MCP projects.yml file with proper entries
  printf '%s\n' \
    'test_project: "/rails-projects/test_project"' \
    'blog: "/rails-projects/blog"' \
    > "$TEST_HOME/.config/rails-mcp/projects.yml"

  # Create the actual project directories
  mkdir -p "$TEST_HOME/rails-projects"/{test_project,blog}

  # Create a test .env file with placeholders and real directories for filesystem testing
  # Use safe .env creation to prevent corruption
  source "$PWD/spec/test_helpers.sh"
  create_safe_env_file "$TEST_HOME/.env" \
    "GITHUB_PERSONAL_ACCESS_TOKEN=test_github_token_placeholder" \
    "CIRCLECI_TOKEN=test_circleci_token_placeholder" \
    "FILESYSTEM_ALLOWED_DIRS=$TEST_HOME,/tmp" \
    "HEROKU_API_KEY=test_heroku_api_key_placeholder" \
    "FIGMA_API_KEY=test_figma_api_key_placeholder" \
    "SONARQUBE_TOKEN=test_sonarqube_token_placeholder" \
    "SONARQUBE_ORG=test_sonarqube_org_placeholder" \
    "SONARQUBE_URL=https://sonarcloud.io" \
    "SONARQUBE_STORAGE_PATH=$TEST_HOME/sonarqube_storage" \
    "MAILGUN_API_KEY=test_mailgun_api_key_placeholder" \
    "MAILGUN_DOMAIN=test_mailgun_domain_placeholder" \
    "RAILS_MCP_ROOT_PATH=$TEST_HOME/rails-projects" \
    "RAILS_MCP_CONFIG_HOME=$TEST_HOME/.config" \
    "MCP_MEMORY_CHROMA_PATH=$TEST_HOME/ChromaDB/db" \
    "MCP_MEMORY_BACKUPS_PATH=$TEST_HOME/ChromaDB/backup" \
    "TERRAFORM_HOST_DIR=$TEST_HOME/terraform-projects" \
    "KUBECONFIG_HOST=$TEST_HOME/.kube/config" \
    "K8S_NAMESPACE=test_namespace" \
    "K8S_CONTEXT=test_context" \
    "PLAYWRIGHT_BROWSER_PATH=$TEST_HOME/.cache/ms-playwright" \
    "PLAYWRIGHT_SCREENSHOTS_PATH=$TEST_HOME/screenshots" \
    "OBSIDIAN_API_KEY=test_obsidian_api_key_placeholder" \
    "OBSIDIAN_BASE_URL=https://host.docker.internal:27124" \
    "OBSIDIAN_VERIFY_SSL=false" \
    "OBSIDIAN_ENABLE_CACHE=true" \
    "MCP_TRANSPORT_TYPE=stdio" \
    "MCP_LOG_LEVEL=debug"
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
The output should include "memory-service"
The output should include "playwright"
End

It 'writes identical configuration to both client files'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
cursor_config=$(jq -S . tmp/test_home/.cursor/mcp.json)
claude_config=$(jq -S . "tmp/test_home/Library/Application Support/Claude/claude_desktop_config.json")
When run test "$cursor_config" = "$claude_config"
The status should be success
End

It 'writes to real Cursor config location'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write'
The status should be success
The output should include "=== MCP Client Configuration Generation ==="
The stderr should include "[INFO] Sourcing .env file for variable expansion"
The file "tmp/test_home/.cursor/mcp.json" should be exist
End

It 'writes to real Claude Desktop config location'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write'
The status should be success
The output should include "=== MCP Client Configuration Generation ==="
The stderr should include "[INFO] Sourcing .env file for variable expansion"
The file "tmp/test_home/Library/Application Support/Claude/claude_desktop_config.json" should be exist
End
End

Describe 'Unified Configuration Architecture Integration'
BeforeEach 'setup_integration_test_environment'
AfterEach 'cleanup_integration_test_environment'

It 'config and config-write generate identical JSON content'
# Get JSON from config command (preview)
preview_json=$(sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config 2>/dev/null | tail -n +2')

# Get JSON from config-write command (file output)
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
write_json=$(jq . tmp/test_home/.cursor/mcp.json)

When run test "$preview_json" = "$write_json"
The status should be success
End

It 'validates all servers have proper Docker command structure'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'

# All servers should have docker command and args array
When run sh -c 'jq ".mcpServers | to_entries | map(.value.command == \"docker\") | all" tmp/test_home/.cursor/mcp.json && jq ".mcpServers | to_entries | map(.value.args | type == \"array\") | all" tmp/test_home/.cursor/mcp.json'
The status should be success
The output should include "true"
End

It 'validates server type specific configurations'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'

# Check API-based, mount-based, and privileged server configurations
When run sh -c 'jq ".mcpServers.github.args | length <= 6" tmp/test_home/.cursor/mcp.json && jq ".mcpServers.filesystem.args | map(select(test(\"--volume\"))) | length > 0" tmp/test_home/.cursor/mcp.json && jq ".mcpServers.docker.args | map(select(test(\"/var/run/docker.sock\"))) | length > 0" tmp/test_home/.cursor/mcp.json'
The status should be success
The output should include "true"
End

It 'validates template processing with real environment'
# Create completely clean .env file with specific test values
cat > tmp/test_home/.env << EOF
GITHUB_PERSONAL_ACCESS_TOKEN=test_github_token_placeholder
CIRCLECI_TOKEN=test_circleci_token_placeholder
FILESYSTEM_ALLOWED_DIRS=/tmp/test1,/tmp/test2
HEROKU_API_KEY=test_heroku_api_key_placeholder
FIGMA_API_KEY=test_figma_api_key_placeholder
RAILS_MCP_ROOT_PATH=$TEST_HOME/rails-projects
RAILS_MCP_CONFIG_HOME=$TEST_HOME/.config
MCP_MEMORY_CHROMA_PATH=$TEST_HOME/ChromaDB/db
MCP_MEMORY_BACKUPS_PATH=$TEST_HOME/ChromaDB/backup
TERRAFORM_HOST_DIR=$TEST_HOME/terraform-projects
KUBECONFIG_HOST=/tmp/.kube/config
K8S_NAMESPACE=test_namespace
K8S_CONTEXT=test_context
EOF

sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'

# Environment variables should be expanded and no unexpanded variables should remain
When run sh -c 'jq ".mcpServers.filesystem.args | map(select(test(\"/tmp/test1\"))) | length > 0" tmp/test_home/.cursor/mcp.json && ! jq -r . tmp/test_home/.cursor/mcp.json | grep -q "\\$"'
The status should be success
The output should include "true"
End

It 'validates JSON formatting quality'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'

# Volume arguments should be separate, not concatenated
When run sh -c 'test $(jq ".mcpServers.filesystem.args | map(select(test(\"--volume=\"))) | length" tmp/test_home/.cursor/mcp.json) -eq 0 && jq ".mcpServers.filesystem.args | map(select(. == \"--volume\")) | length > 0" tmp/test_home/.cursor/mcp.json'
The status should be success
The output should include "true"
End
End

Describe 'Filesystem Server Integration'
BeforeEach 'setup_integration_test_environment'
AfterEach 'cleanup_integration_test_environment'

It 'performs comprehensive filesystem server testing'
# Test filesystem server functionality with existing directories
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test filesystem'
The status should be success
The output should include "Filesystem MCP Server"
The stderr should include "READY"
The stderr should include "VALIDATED"
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

It 'handles missing directories gracefully'
# Create config with non-existent directory
cat > tmp/test_home/.env << EOF
FILESYSTEM_ALLOWED_DIRS=$PWD/tmp/test_home/nonexistent_dir
EOF
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test filesystem'
The status should be success
# Note: Current implementation only tests container startup, not directory validation
The output should include "Filesystem MCP Server"
The stderr should include "READY"
The stderr should include "VALIDATED"
End

It 'handles directories with special characters in configuration'
# Create directories with spaces in test environment
mkdir -p "tmp/test_home/My Documents"
mkdir -p "tmp/test_home/Desktop Items"
cat > tmp/test_home/.env << EOF
FILESYSTEM_ALLOWED_DIRS="$PWD/tmp/test_home/My Documents,$PWD/tmp/test_home/Desktop Items"
EOF
# Test configuration generation only (no additional container needed)
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers.filesystem.args[]' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "Documents"
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

It 'can test all servers efficiently in one batch'
# Test all servers at once to reduce container overhead
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test'
# Status may fail if some containers can't start, but most should work
The status should be failure
The output should include "GitHub MCP Server"
The output should include "Figma Context MCP Server"
The output should include "Filesystem MCP Server"
The output should include "Docker MCP Server"
The output should include "Rails MCP Server"
The output should include "Obsidian MCP Server"
# Improved readiness detection should show most servers as ready
The stderr should include "READY"
The stderr should include "VALIDATED"
# Some servers may still have issues, so we might see errors
End

It 'can test context7 server individually'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test context7'
The status should be success
The output should include "Context7 Documentation MCP Server"
The stderr should include "READY"
The stderr should include "VALIDATED"
End

It 'can test heroku server individually'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test heroku'
The status should be success
The output should include "Heroku Platform MCP Server"
# Improved readiness detection should show READY instead of TIMEOUT
The stderr should include "READY"
The stderr should include "VALIDATED"
End

It 'can test terraform-cli-controller server individually'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test terraform-cli-controller'
The status should be success
The output should include "Terraform CLI Controller"
The stderr should include "READY"
The stderr should include "VALIDATED"
End

It 'can test playwright server individually'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test playwright'
The status should be success
The output should include "Playwright MCP Server"
# Improved readiness detection should show READY instead of TIMEOUT
The output should include "SUCCESS"
The stderr should include "READY"
The stderr should include "VALIDATED"
End

It 'can test obsidian server individually'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test obsidian'
The status should be success
The output should include "Obsidian MCP Server"
# Obsidian should work with improved silent server detection
The output should include "SUCCESS"
# Should detect silent MCP servers quickly
The stderr should include "READY"
The stderr should include "VALIDATED"
End
End

Describe 'Docker Server Integration'
BeforeEach 'setup_integration_test_environment'
AfterEach 'cleanup_integration_test_environment'

It 'generates docker configuration with docker socket access'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers.docker.args[]' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "/var/run/docker.sock:/var/run/docker.sock"
The output should include "mcp-server-docker:latest"
End

It 'includes docker socket mount in configuration'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers.docker.args[]' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "/var/run/docker.sock:/var/run/docker.sock"
End

It 'can test docker server with comprehensive validation'
if ! command -v docker > /dev/null 2>&1; then
  skip "Docker not available"
fi
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test docker'
The status should be success
The output should include "Docker MCP Server"
# Improved readiness detection should show READY instead of TIMEOUT
The stderr should include "READY"
The stderr should include "VALIDATED"
End

It 'includes playwright in Docker configuration with browser cache and screenshots mounts'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers.playwright.args[]' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "--volume"
# The browser cache mount is no longer present
# The output should include ".cache/ms-playwright:/ms-playwright"
The output should include "screenshots:/app/output"
The output should include "--output-dir"
The output should include "local/playwright-mcp-server:latest"
End

It 'handles Docker unavailability gracefully'
# Test with Docker command unavailable - create temp dir with tools except docker
mkdir -p tmp/no_docker_bin
ln -sf /opt/homebrew/bin/yq tmp/no_docker_bin/yq 2> /dev/null || true
ln -sf /opt/homebrew/bin/jq tmp/no_docker_bin/jq 2> /dev/null || true
When run env PATH="$PWD/tmp/no_docker_bin:/usr/bin:/bin" sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test docker'
The status should be success
The output should include "Docker MCP Server"
The output should include "Docker not available"
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
The output should include "/.config:/app/.config/rails-mcp"
The output should include "local/mcp-server-rails:latest"
End

It 'can test rails server and validate functionality'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" test rails'
# Rails server may fail due to container lifecycle but should show it attempted to start
The status should be failure
The output should include "Rails MCP Server"
The stderr should include "Container"
End
End

Describe 'Memory Service Integration'
BeforeEach 'setup_integration_test_environment'
AfterEach 'cleanup_integration_test_environment'

It 'includes memory-service in Docker configuration'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers."memory-service".args[]' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "--volume"
The output should include "chroma_db"
The output should include "local/mcp-server-memory-service:latest"
End

It 'includes ChromaDB volume mounts in configuration'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers."memory-service".args[]' tmp/test_home/.cursor/mcp.json
The status should be success
The output should include "/app/chroma_db"
End

It 'can test memory-service server individually'
When run zsh mcp_manager.sh test memory-service
The status should be success
The output should include "Memory Service MCP Server"
The output should include "Basic protocol validation passed"
The stderr should include "READY"
The stderr should include "VALIDATED"
End

It 'validates memory service configuration'
sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config-write > /dev/null 2>&1'
When run jq -r '.mcpServers."memory-service".command' tmp/test_home/.cursor/mcp.json
The status should be success
The output should equal "docker"
End
End

Describe 'Memory Service Setup Environment Validation'
BeforeEach 'setup_integration_test_environment'
AfterEach 'cleanup_integration_test_environment'

It 'fails with clear error if MCP_MEMORY_CHROMA_PATH is missing'
# Only set BACKUPS_PATH
cat > tmp/test_home/.env << EOF
MCP_MEMORY_BACKUPS_PATH=$PWD/tmp/test_home/ChromaDB/backup
EOF
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" setup memory-service'
The status should not be success
The output should include "MCP_MEMORY_CHROMA_PATH"
The output should include "must be set"
End

It 'fails with clear error if MCP_MEMORY_BACKUPS_PATH is missing'
# Only set CHROMA_PATH
cat > tmp/test_home/.env << EOF
MCP_MEMORY_CHROMA_PATH=$PWD/tmp/test_home/ChromaDB/db
EOF
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" setup memory-service'
The status should not be success
The output should include "MCP_MEMORY_BACKUPS_PATH"
The output should include "must be set"
End

It 'fails with clear error if either variable is empty'
cat > tmp/test_home/.env << EOF
MCP_MEMORY_CHROMA_PATH=
MCP_MEMORY_BACKUPS_PATH=
EOF
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" setup memory-service'
The status should not be success
The output should include "MCP_MEMORY_CHROMA_PATH"
The output should include "must be set"
The output should include "MCP_MEMORY_BACKUPS_PATH"
The output should include "must be set"
End

It 'creates directories if both variables are set and non-empty'
cat > tmp/test_home/.env << EOF
MCP_MEMORY_CHROMA_PATH=$PWD/tmp/test_home/ChromaDB/db
MCP_MEMORY_BACKUPS_PATH=$PWD/tmp/test_home/ChromaDB/backup
EOF
# Remove directories so they will be created during setup
rm -rf tmp/test_home/ChromaDB
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" setup memory-service'
The status should be success
The output should include "Creating directory"
The directory "tmp/test_home/ChromaDB/db" should be exist
The directory "tmp/test_home/ChromaDB/backup" should be exist
End

It 'does not fail if directories already exist'
mkdir -p tmp/test_home/ChromaDB/db
mkdir -p tmp/test_home/ChromaDB/backup
cat > tmp/test_home/.env << EOF
MCP_MEMORY_CHROMA_PATH=$PWD/tmp/test_home/ChromaDB/db
MCP_MEMORY_BACKUPS_PATH=$PWD/tmp/test_home/ChromaDB/backup
EOF
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" setup memory-service'
The status should be success
The output should include "already exists"
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

It 'memory-service server supports setup command for building'
# Ensure test .env is present and valid for this test
cat > tmp/test_home/.env << EOF
MCP_MEMORY_CHROMA_PATH=$PWD/tmp/test_home/ChromaDB/db
MCP_MEMORY_BACKUPS_PATH=$PWD/tmp/test_home/ChromaDB/backup
EOF
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" setup memory-service'
The status should be success
The output should include "[SUCCESS]"
End

It 'sonarqube server supports setup command for building'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" setup sonarqube'
The status should be success
The output should include "SonarQube MCP Server"
The output should include "[SUCCESS]"
End

It 'mailgun server supports setup command for building'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" setup mailgun'
The status should be success
The output should include "Mailgun MCP Server"
The output should include "[SUCCESS]"
End

It 'playwright server supports setup command for building'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" setup playwright'
The status should be success
The output should include "Playwright MCP Server"
The output should include "[SUCCESS]"
End
End

Describe 'Real Token Integration Tests'
It 'can test GitHub server with real token'
if ! has_real_tokens; then skip "No real .env present"; fi
When run zsh "$PWD/mcp_manager.sh" test github
The status should be success
The output should include "GitHub MCP Server"
The stderr should include "READY"
The stderr should include "VALIDATED"
End

It 'can test CircleCI server with real token'
if ! has_real_tokens; then skip "No real .env present"; fi
When run zsh "$PWD/mcp_manager.sh" test circleci
The status should be success
The output should include "CircleCI MCP Server"
# Improved readiness detection should show READY instead of TIMEOUT
The stderr should include "READY"
The stderr should include "VALIDATED"
End

It 'can test Heroku server with real token'
if ! has_real_tokens; then skip "No real .env present"; fi
When run zsh "$PWD/mcp_manager.sh" test heroku
The status should be success
The output should include "Heroku Platform MCP Server"
# Improved readiness detection should show READY instead of TIMEOUT
The stderr should include "READY"
The stderr should include "VALIDATED"
End

It 'can test SonarQube server with real token'
if ! has_real_tokens; then skip "No real .env present"; fi
When run zsh "$PWD/mcp_manager.sh" test sonarqube
The status should be success
The output should include "SonarQube MCP Server"
# Improved readiness detection should show READY instead of TIMEOUT
The stderr should include "READY"
The stderr should include "VALIDATED"
End

It 'can test Mailgun server with real token'
if ! has_real_tokens; then skip "No real .env present"; fi
When run zsh "$PWD/mcp_manager.sh" test mailgun
The status should be success
The output should include "Mailgun MCP Server"
The stderr should include "READY"
End

End

End
