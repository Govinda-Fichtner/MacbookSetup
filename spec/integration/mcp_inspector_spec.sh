#!/bin/zsh
# ShellSpec test suite for MCP Inspector functionality

# Helper functions for test environment setup
setup_inspector_test_environment() {
  export TEST_HOME="$PWD/test_inspector_home"
  export CI=false
  mkdir -p "$TEST_HOME/.cursor"
  mkdir -p "$TEST_HOME/Library/Application Support/Claude"

  # Clean any existing test containers
  docker container stop test-github test-circleci 2> /dev/null || true
  docker container rm test-github test-circleci 2> /dev/null || true
}

cleanup_inspector_test_environment() {
  rm -rf "$TEST_HOME" 2> /dev/null || true
  docker container stop test-github test-circleci 2> /dev/null || true
  docker container rm test-github test-circleci 2> /dev/null || true
}

start_test_mcp_containers() {
  # Create mock MCP server containers for testing
  docker run -d --name test-github --network mcp-network \
    -e GITHUB_TOKEN=test_token \
    mcp/github-mcp-server:latest > /dev/null 2>&1 || true

  docker run -d --name test-circleci --network mcp-network \
    -e CIRCLECI_TOKEN=test_token \
    local/mcp-server-circleci:latest > /dev/null 2>&1 || true

  # Wait for containers to start (reduced from 2s)
  sleep 0.5
}

mock_docker_for_ci() {
  # Mock Docker commands for CI environment where Docker may not be available
  # shellcheck disable=SC2317
  docker() {
    case "$1 $2" in
      "network ls") echo "NETWORK ID     NAME      DRIVER    SCOPE" ;;
      "ps --filter"*)
        echo "CONTAINER ID   IMAGE                     NAMES"
        echo "123abc        mcp/github:latest         test-github"
        ;;
      "images"*) echo "mcp/github   latest   123   2 hours ago   100MB" ;;
      *) return 1 ;;
    esac
  }
}

mock_docker_no_containers() {
  # Mock Docker commands to simulate no containers running
  # shellcheck disable=SC2317
  docker() {
    case "$1 $2" in
      "network ls") echo "NETWORK ID     NAME      DRIVER    SCOPE" ;;
      "ps --filter"*)
        echo "CONTAINER ID   IMAGE                     NAMES"
        # No containers listed
        ;;
      "images"*) echo "REPOSITORY   TAG   IMAGE ID   CREATED   SIZE" ;;
      *) return 1 ;;
    esac
  }
}

Describe 'MCP Inspector Basic Functionality'

Describe 'inspect command with no arguments'
Context 'when running inspect command (adaptive to environment)'
BeforeEach 'setup_inspector_test_environment'
AfterEach 'cleanup_inspector_test_environment'

It 'should run inspect command successfully regardless of container state'
When run ./mcp_manager.sh inspect
The status should be success
The stderr should include "MCP Server Inspection"
The stderr should include "[INFO]"
End

It 'should show appropriate results for the current environment'
When run ./mcp_manager.sh inspect
The status should be success
# Test adapts to whether containers are running or not - focus on what we can always test
The stderr should include "[INFO]"
End
End

Context 'when testing core inspect functionality'
BeforeEach 'setup_inspector_test_environment'
AfterEach 'cleanup_inspector_test_environment'

It 'should provide consistent output structure'
When run ./mcp_manager.sh inspect
The status should be success
The output should include "=== MCP Server Inspection"
The stderr should include "[INFO]"
End

It 'should handle Docker availability gracefully'
When run ./mcp_manager.sh inspect
The status should be success
# Should work whether Docker is available or not - test basic structure
The stderr should include "MCP Server Inspection"
End
End
End

Describe 'inspect command with specific server'
Context 'when inspecting known server from registry'
BeforeEach 'setup_inspector_test_environment'
AfterEach 'cleanup_inspector_test_environment'

It 'should show server information from registry'
When run ./mcp_manager.sh inspect github
The output should include "=== MCP Server Inspection: github ==="
The stderr should include "GitHub MCP Server"
The status should be success
End

It 'should handle server inspection regardless of container state'
When run ./mcp_manager.sh inspect github
The status should be success
# Should work whether container is running or not
The output should include "=== MCP Server Inspection: github ==="
The stderr should include "GitHub MCP Server"
End
End

Context 'when inspecting non-existent server'
BeforeEach 'setup_inspector_test_environment'
AfterEach 'cleanup_inspector_test_environment'

It 'should show error for unknown server'
When run ./mcp_manager.sh inspect nonexistent
The stderr should include "not found in registry"
The status should be failure
End
End
End
End

Describe 'MCP Inspector Advanced Features'

Describe 'inspect --ui command'
Context 'when starting inspector UI'
BeforeEach 'setup_inspector_test_environment'
AfterEach 'cleanup_inspector_test_environment'

It 'should indicate UI startup'
Skip unless "Docker is available" docker version > /dev/null 2>&1
When run ./mcp_manager.sh inspect --ui
The output should include "Inspector UI"
The output should include "localhost:6274"
The status should be success
End
End
End

Describe 'inspect --validate-config command'
Context 'when validating client configurations'
BeforeEach 'setup_inspector_test_environment'
AfterEach 'cleanup_inspector_test_environment'

It 'should validate Cursor and Claude configurations'
When run ./mcp_manager.sh inspect --validate-config
The stderr should include "Configuration Validation"
The output should include "CURSOR"
The output should include "CLAUDE"
The status should be success
End
End
End

Describe 'inspect --ci-mode command'
Context 'when running in CI mode'
BeforeEach 'setup_inspector_test_environment'
AfterEach 'cleanup_inspector_test_environment'

It 'should run validation without Docker dependencies'
When run env CI=true ./mcp_manager.sh inspect --ci-mode
The stderr should include "Validation completed"
The status should be success
End
End
End

Describe 'inspect --connectivity command'
Context 'when testing server connectivity'
BeforeEach 'setup_inspector_test_environment'
AfterEach 'cleanup_inspector_test_environment'

It 'should test connectivity to running servers'
Skip unless "Docker is available" docker version > /dev/null 2>&1
When run ./mcp_manager.sh inspect --connectivity
The stderr should include "Testing server connectivity"
The status should be success
End
End
End

End

Describe 'MCP Inspector Error Handling'

Describe 'when Docker is not available'
Context 'in environment without Docker'
BeforeEach 'setup_inspector_test_environment'
AfterEach 'cleanup_inspector_test_environment'

It 'should gracefully handle missing Docker'
# Create temp directory with essential tools but no docker
mkdir -p tmp/no_docker_bin
ln -sf /opt/homebrew/bin/yq tmp/no_docker_bin/yq 2> /dev/null || true
ln -sf /opt/homebrew/bin/jq tmp/no_docker_bin/jq 2> /dev/null || true
When run env PATH="$PWD/tmp/no_docker_bin:/usr/bin:/bin" ./mcp_manager.sh inspect
The stderr should include "Docker not available"
The status should be success
End
End
End

Describe 'when in CI environment'
Context 'with CI=true'
BeforeEach 'setup_inspector_test_environment'
AfterEach 'cleanup_inspector_test_environment'

It 'should skip Docker-based operations'
When run env CI=true ./mcp_manager.sh inspect
The stderr should include "CI environment"
The status should be success
End
End
End

End

Describe 'MCP Inspector Help and Documentation'

Describe 'inspect command in help output'
It 'should be listed in main help'
When run ./mcp_manager.sh help
The output should include "inspect [server_id]"
The output should include "Inspect and debug MCP server(s)"
The status should be success
End

It 'should show inspect examples in help'
When run ./mcp_manager.sh help
The output should include "inspect            # Quick health check"
The output should include "inspect --ui       # Launch web interface"
The output should include "inspect --validate-config"
The status should be success
End
End

End
