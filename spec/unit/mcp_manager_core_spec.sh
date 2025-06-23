#!/bin/zsh
# Unit tests for mcp_manager.sh core functionality
# Fast tests without Docker dependencies - extracted from original mcp_manager_spec.sh

# Test configuration
export DOCKER_SKIP_TESTS=${DOCKER_SKIP_TESTS:-false}
export TEST_TIMEOUT=${TEST_TIMEOUT:-30}

# Setup test environment for unit tests
setup_unit_test_environment() {
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

  # Create a test .env file with placeholders
  cat > "$TEST_HOME/.env" << EOF
GITHUB_PERSONAL_ACCESS_TOKEN=test_github_token_placeholder
CIRCLECI_TOKEN=test_circleci_token_placeholder
FILESYSTEM_ALLOWED_DIRS=$TEST_HOME,/tmp
HEROKU_API_KEY=test_heroku_api_key_placeholder
EOF
}

# Cleanup test environment
cleanup_unit_test_environment() {
  if [ -n "${TEST_HOME:-}" ] && [ -d "$TEST_HOME" ]; then
    rm -rf "$TEST_HOME"
  fi
}

# Helper function to validate JSON without requiring files to exist
validate_json_structure() {
  local json_content="$1"
  echo "$json_content" | jq empty 2> /dev/null
}

Describe 'MCP Manager Core Functionality (Unit Tests)'

Describe 'Basic Command Interface'
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
The output should include "terraform-cli-controller"
End

It 'parses server configuration correctly'
When run zsh "$PWD/mcp_manager.sh" parse github server_type
The status should be success
The output should equal "api_based"
End

It 'parses server names correctly'
When run zsh "$PWD/mcp_manager.sh" parse github name
The status should be success
The output should include "GitHub"
End

It 'handles invalid commands gracefully'
When run zsh "$PWD/mcp_manager.sh" invalid_command
The status should not be success
The stderr should include "Unknown command"
The stderr should include "help"
End
End

Describe 'Server Type Classification'
It 'recognizes GitHub as api_based server type'
When run zsh "$PWD/mcp_manager.sh" parse github server_type
The status should be success
The output should equal "api_based"
End

It 'recognizes filesystem as mount_based server type'
When run zsh "$PWD/mcp_manager.sh" parse filesystem server_type
The status should be success
The output should equal "mount_based"
End

It 'recognizes context7 as standalone server type'
When run zsh "$PWD/mcp_manager.sh" parse context7 server_type
The status should be success
The output should equal "standalone"
End

It 'recognizes terraform-cli-controller as privileged server type'
When run zsh "$PWD/mcp_manager.sh" parse terraform-cli-controller server_type
The status should be success
The output should equal "privileged"
End

It 'recognizes docker as privileged server type'
When run zsh "$PWD/mcp_manager.sh" parse docker server_type
The status should be success
The output should equal "privileged"
End

It 'recognizes heroku as api_based server type'
When run zsh "$PWD/mcp_manager.sh" parse heroku server_type
The status should be success
The output should equal "api_based"
End

It 'recognizes rails as mount_based server type'
When run zsh "$PWD/mcp_manager.sh" parse rails server_type
The status should be success
The output should equal "mount_based"
End
End

Describe 'Environment Variable Handling'
BeforeEach 'setup_unit_test_environment'
AfterEach 'cleanup_unit_test_environment'

It 'handles missing .env file gracefully'
# Remove .env file to test default behavior
rm -f "$TEST_HOME/.env"
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config'
The status should be success
The output should include "=== MCP Client Configuration Preview ==="
The stderr should include "[WARNING] No .env file found - some variables may not expand"
End

It 'reads environment variables from .env file'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config'
The status should be success
The output should include "=== MCP Client Configuration Preview ==="
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'handles empty FILESYSTEM_ALLOWED_DIRS'
cat > "$TEST_HOME/.env" << 'EOF'
FILESYSTEM_ALLOWED_DIRS=
GITHUB_PERSONAL_ACCESS_TOKEN=test_token
EOF
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config'
The status should be success
The output should include "=== MCP Client Configuration Preview ==="
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'handles malformed environment file'
cat > "$TEST_HOME/.env" << 'EOF'
INVALID_SYNTAX_HERE=
GITHUB_PERSONAL_ACCESS_TOKEN=test
EOF
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config'
The status should be success
The output should include "=== MCP Client Configuration Preview ==="
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End
End

Describe 'Configuration Generation Logic (Unit Tests)'
BeforeEach 'setup_unit_test_environment'
AfterEach 'cleanup_unit_test_environment'

It 'generates configuration preview without errors'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config'
The status should be success
The output should include "=== MCP Client Configuration Preview ==="
The output should include "mcpServers"
The output should include "{"
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'includes all expected servers in configuration preview'
When run sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config'
The status should be success
The output should include "github"
The output should include "circleci"
The output should include "figma"
The output should include "heroku"
The output should include "filesystem"
The output should include "terraform-cli-controller"
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'handles CI environment gracefully'
When run env CI=true sh -c 'cd "$PWD/tmp/test_home" && export HOME="$PWD" && zsh "$OLDPWD/mcp_manager.sh" config'
The status should be success
The output should include "=== MCP Client Configuration Preview ==="
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End
End

Describe 'Server-Specific Configuration Logic'
It 'includes expected servers in available list'
When run zsh "$PWD/mcp_manager.sh" list
The status should be success
The output should include "github"
The output should include "circleci"
The output should include "figma"
The output should include "heroku"
The output should include "filesystem"
The output should include "context7"
The output should include "terraform-cli-controller"
The output should include "docker"
The output should include "rails"
End

It 'parses Docker image names correctly'
When run zsh "$PWD/mcp_manager.sh" parse github source.image
The status should be success
The output should include "mcp/github"
End

It 'parses Context7 image name correctly'
When run zsh "$PWD/mcp_manager.sh" parse context7 source.image
The status should be success
The output should include "local/context7-mcp"
End

It 'parses Heroku image name correctly'
When run zsh "$PWD/mcp_manager.sh" parse heroku source.image
The status should be success
The output should include "local/heroku-mcp-server"
End
End

Describe 'Error Handling and Edge Cases'
BeforeEach 'setup_unit_test_environment'
AfterEach 'cleanup_unit_test_environment'

It 'handles invalid server names gracefully'
When run zsh "$PWD/mcp_manager.sh" parse nonexistent_server server_type
The status should be success
The output should equal "null"
End

It 'handles missing parse arguments gracefully'
When run zsh "$PWD/mcp_manager.sh" parse
The status should not be success
The stderr should include "Usage:"
The stderr should include "parse <server_id> <config_key>"
End

It 'handles unknown configuration keys gracefully'
When run zsh "$PWD/mcp_manager.sh" parse github unknown_key
The status should be success
The output should equal "null"
End
End

Describe 'Environment Variable Placeholder Generation'
It 'generates .env_example with correct placeholders'
When run zsh "$PWD/mcp_manager.sh" config-write
The status should be success
The file ".env_example" should be exist
The output should include "=== MCP Client Configuration Generation ==="
The output should include "Client configurations written"
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'includes GitHub token placeholder in .env_example'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run grep "GITHUB_PERSONAL_ACCESS_TOKEN" "$PWD/.env_example"
The status should be success
The output should include "your_github_personal_access_token_here"
End

It 'includes CircleCI token placeholder in .env_example'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run grep "CIRCLECI_TOKEN" "$PWD/.env_example"
The status should be success
The output should include "your_circleci_token_here"
End

It 'includes Heroku API key placeholder in .env_example'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run grep "HEROKU_API_KEY" "$PWD/.env_example"
The status should be success
The output should include "your_heroku_api_key_here"
End

It 'includes filesystem directories placeholder in .env_example'
zsh "$PWD/mcp_manager.sh" config-write > /dev/null 2>&1
When run grep "FILESYSTEM_ALLOWED_DIRS" "$PWD/.env_example"
The status should be success
The output should include "/Users/user/Project,/Users/user/Desktop,/Users/user/Downloads"
End
End

End
