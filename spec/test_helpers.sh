#!/usr/bin/env shellspec

# Mock functions for testing
mock_parse_server_config() {
  local server_id="$1"
  local config_key="$2"

  case "$server_id" in
    "github")
      case "$config_key" in
        "name") echo "GitHub MCP Server" ;;
        "source.image") echo "mcp/github-mcp-server:latest" ;;
        "source.type") echo "registry" ;;
        "environment_variables") echo "- \"GITHUB_TOKEN\"" ;;
        "health_test.parse_mode") echo "filter_json" ;;
      esac
      ;;
    "circleci")
      case "$config_key" in
        "name") echo "CircleCI MCP Server" ;;
        "source.image") echo "local/mcp-server-circleci:latest" ;;
        "source.type") echo "build" ;;
        "environment_variables") echo "- \"CIRCLECI_TOKEN\"" ;;
        "health_test.parse_mode") echo "direct" ;;
      esac
      ;;
  esac
}

mock_get_configured_servers() {
  echo "github"
  echo "circleci"
}

mock_docker_images() {
  echo "mcp/github-mcp-server latest"
  echo "local/mcp-server-circleci latest"
}

# Test fixtures
create_test_registry_file() {
  cat > "$MCP_REGISTRY_FILE" << 'EOF'
servers:
  github:
    name: "GitHub MCP Server"
    source:
      type: "registry"
      image: "mcp/github-mcp-server:latest"
    environment_variables:
      - "GITHUB_TOKEN"
    health_test:
      parse_mode: "filter_json"
  circleci:
    name: "CircleCI MCP Server"
    source:
      type: "build"
      image: "local/mcp-server-circleci:latest"
    environment_variables:
      - "CIRCLECI_TOKEN"
    health_test:
      parse_mode: "direct"
EOF
}

# Cleanup function
cleanup_test_files() {
  rm -f "$MCP_REGISTRY_FILE"
  rm -f ~/.cursor/mcp.json
  rm -f ~/Library/Application\ Support/Claude/claude_desktop_config.json
}

# Setup function
setup_test_environment() {
  # Create test registry file
  create_test_registry_file

  # Set up test tokens
  export GITHUB_PERSONAL_ACCESS_TOKEN="test_token"
  export CIRCLECI_TOKEN="test_token"
}

# Teardown function
teardown_test_environment() {
  # Clean up test files
  cleanup_test_files

  # Unset test tokens
  unset GITHUB_PERSONAL_ACCESS_TOKEN
  unset CIRCLECI_TOKEN
}
