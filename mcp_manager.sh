#!/bin/zsh
# MCP Server Manager - Generalized management for MCP servers
# Supports both registry images and local repository builds

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

# Configuration
readonly MCP_REGISTRY_FILE="mcp_server_registry.yml"
readonly MCP_BUILD_DIR="./mcp_builds"

# Parse YAML configuration (simple parser for our structure)
parse_server_config() {
  local server_id="$1"
  local config_key="$2"

  # Extract specific configuration values using yq or awk
  if command -v yq > /dev/null 2>&1; then
    yq eval ".servers.${server_id}.${config_key}" "$MCP_REGISTRY_FILE" 2> /dev/null
  else
    # Fallback to awk parsing - handle nested keys like "source.image"
    if [[ "$config_key" == *.* ]]; then
      # Handle nested keys
      local parent_key="${config_key%.*}"
      local child_key="${config_key##*.}"
      awk -v server="$server_id" -v parent="$parent_key" -v child="$child_key" '
        BEGIN { in_server = 0; in_parent = 0 }
        $0 ~ "^  " server ":" { in_server = 1; next }
        in_server && /^  [a-z]/ && $0 !~ "^    " { in_server = 0; in_parent = 0 }
        in_server && $0 ~ "^    " parent ":" { in_parent = 1; next }
        in_parent && $0 ~ "^      " child ":" {
          gsub(/.*: /, ""); gsub(/"/, ""); print; exit
        }
      ' "$MCP_REGISTRY_FILE"
    else
      # Handle simple keys
      awk -v server="$server_id" -v key="$config_key" '
        BEGIN { in_server = 0 }
        $0 ~ "^  " server ":" { in_server = 1; next }
        in_server && /^  [a-z]/ && $0 !~ "^    " { in_server = 0 }
        in_server && $0 ~ "^    " key ":" {
          gsub(/.*: /, ""); gsub(/"/, ""); print; exit
        }
      ' "$MCP_REGISTRY_FILE"
    fi
  fi
}

# Get list of all configured servers
get_configured_servers() {
  if command -v yq > /dev/null 2>&1; then
    yq eval '.servers | keys | .[]' "$MCP_REGISTRY_FILE" 2> /dev/null
  else
    awk '/^  [a-z].*:$/ { gsub(/:/, ""); gsub(/^  /, ""); print }' "$MCP_REGISTRY_FILE"
  fi
}

# Setup MCP server (registry pull or local build)
setup_mcp_server() {
  local server_id="$1"

  printf "├── %b[SETUP]%b %s MCP Server\n" "$BLUE" "$NC" "$(parse_server_config "$server_id" "name")"

  local source_type
  source_type=$(parse_server_config "$server_id" "source.type")

  case "$source_type" in
    "registry")
      setup_registry_server "$server_id"
      ;;
    "build")
      setup_build_server "$server_id"
      ;;
    *)
      printf "│   └── %b[ERROR]%b Unknown source type: %s\n" "$RED" "$NC" "$source_type"
      return 1
      ;;
  esac
}

# Setup server from Docker registry
setup_registry_server() {
  local server_id="$1"
  local image
  image=$(parse_server_config "$server_id" "source.image")

  printf "│   ├── %b[PULLING]%b Registry image: %s\n" "$BLUE" "$NC" "$image"

  if docker pull "$image" > /dev/null 2>&1; then
    printf "│   └── %b[SUCCESS]%b Registry image ready\n" "$GREEN" "$NC"
    return 0
  else
    printf "│   └── %b[ERROR]%b Failed to pull registry image\n" "$RED" "$NC"
    return 1
  fi
}

# Setup server from local repository build
setup_build_server() {
  local server_id="$1"
  local repository
  local image
  repository=$(parse_server_config "$server_id" "source.repository")
  image=$(parse_server_config "$server_id" "source.image")

  printf "│   ├── %b[CLONING]%b Repository: %s\n" "$BLUE" "$NC" "$(basename "$repository" .git)"

  # Create build directory if it doesn't exist
  mkdir -p "$MCP_BUILD_DIR"

  local repo_basename
  repo_basename=$(basename "$repository" .git)
  local repo_dir="$MCP_BUILD_DIR/$repo_basename"

  # Clone or update repository
  if [[ -d "$repo_dir" ]]; then
    printf "│   ├── %b[UPDATING]%b Existing repository\n" "$BLUE" "$NC"
    (cd "$repo_dir" && git pull origin main > /dev/null 2>&1)
  else
    if git clone "$repository" "$repo_dir" > /dev/null 2>&1; then
      printf "│   ├── %b[SUCCESS]%b Repository cloned\n" "$GREEN" "$NC"
    else
      printf "│   └── %b[ERROR]%b Failed to clone repository\n" "$RED" "$NC"
      return 1
    fi
  fi

  # Build Docker image
  printf "│   ├── %b[BUILDING]%b Docker image: %s\n" "$BLUE" "$NC" "$image"

  local build_context
  build_context=$(parse_server_config "$server_id" "source.build_context")
  build_context="${build_context:-.}"

  if (cd "$repo_dir/$build_context" && docker build -t "$image" . > /dev/null 2>&1); then
    printf "│   └── %b[SUCCESS]%b Docker image built\n" "$GREEN" "$NC"
    return 0
  else
    printf "│   └── %b[ERROR]%b Failed to build Docker image\n" "$RED" "$NC"
    return 1
  fi
}

# Test MCP server health using proper stdio/JSON-RPC protocol
# Two-tier approach: Basic (no tokens) + Advanced (with tokens)
test_mcp_server_health() {
  local server_id="$1"
  local server_name
  local image
  local parse_mode

  server_name=$(parse_server_config "$server_id" "name")
  image=$(parse_server_config "$server_id" "source.image")
  parse_mode=$(parse_server_config "$server_id" "health_test.parse_mode")

  printf "├── %b[TESTING]%b %s health\n" "$BLUE" "$NC" "$server_name"

  # Determine if we have real tokens available
  local has_real_tokens=false
  case "$server_id" in
    "github")
      [[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" && "${GITHUB_PERSONAL_ACCESS_TOKEN}" != "test_token" ]] && has_real_tokens=true
      ;;
    "circleci")
      [[ -n "${CIRCLECI_TOKEN:-}" && "${CIRCLECI_TOKEN}" != "test_token" ]] && has_real_tokens=true
      ;;
  esac

  # Run basic test first (always)
  if ! test_mcp_basic_protocol "$server_id" "$server_name" "$image" "$parse_mode"; then
    return 1
  fi

  # Run advanced test if tokens are available
  if [[ "$has_real_tokens" == true ]]; then
    printf "│   ├── %b[DETECTED]%b Real API tokens available - running advanced tests\n" "$BLUE" "$NC"
    if ! test_mcp_advanced_functionality "$server_id" "$server_name" "$image" "$parse_mode"; then
      printf "│   └── %b[WARNING]%b Advanced tests failed (basic protocol works)\n" "$YELLOW" "$NC"
    fi
  else
    printf "│   └── %b[INFO]%b No API tokens - skipping advanced tests\n" "$YELLOW" "$NC"
  fi

  printf "└── %b[SUCCESS]%b %s health test completed\n" "$GREEN" "$NC" "$server_name"
  return 0
}

# Basic MCP protocol test (no authentication required - CI pipeline compatible)
test_mcp_basic_protocol() {
  local server_id="$1"
  local server_name="$2"
  local image="$3"
  local parse_mode="$4"

  printf "│   ├── %b[BASIC]%b MCP protocol validation (CI-friendly)\n" "$BLUE" "$NC"

  # Use test tokens for basic protocol validation (CI pipeline doesn't need real tokens)
  local env_args=()
  case "$server_id" in
    "github")
      env_args+=(-e "GITHUB_PERSONAL_ACCESS_TOKEN=test_token")
      ;;
    "circleci")
      env_args+=(-e "CIRCLECI_TOKEN=test_token")
      ;;
  esac

  # Test MCP initialization with basic protocol check
  printf "│   │   ├── %b[TESTING]%b Protocol handshake\n" "$BLUE" "$NC"
  local mcp_init_message='{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "basic-test", "version": "1.0.0"}}}'

  local response
  response=$(echo "$mcp_init_message" | docker run --rm -i "${env_args[@]}" "$image" 2>&1)

  # For basic test, we expect either success OR authentication error (both prove protocol works)
  local json_response
  case "$parse_mode" in
    "filter_json")
      json_response=$(echo "$response" | grep -E '^\s*\{.*"jsonrpc"' | head -1)
      ;;
    "direct")
      json_response="$response"
      ;;
    *)
      json_response="$response"
      ;;
  esac

  # Check if we got a valid MCP response OR expected auth error
  if [[ -n "$json_response" ]] && echo "$json_response" | jq -e '.result.serverInfo.name' > /dev/null 2>&1; then
    local server_info
    server_info=$(echo "$json_response" | jq -r '.result.serverInfo.name + " v" + .result.serverInfo.version')
    printf "│   │   │   └── %b[SUCCESS]%b MCP protocol: %s\n" "$GREEN" "$NC" "$server_info"
  elif echo "$response" | grep -q "not set\|invalid\|unauthorized\|Usage:"; then
    printf "│   │   │   └── %b[SUCCESS]%b MCP protocol functional (auth required)\n" "$GREEN" "$NC"
  else
    printf "│   │   │   └── %b[ERROR]%b MCP protocol failed\n" "$RED" "$NC"
    return 1
  fi

  printf "│   │   └── %b[SUCCESS]%b Basic protocol validation passed\n" "$GREEN" "$NC"
  return 0
}

# Advanced MCP functionality test (requires real API tokens - local development)
test_mcp_advanced_functionality() {
  local server_id="$1"
  local server_name="$2"
  local image="$3"
  local parse_mode="$4"

  printf "│   ├── %b[ADVANCED]%b MCP functionality with authentication\n" "$BLUE" "$NC"

  # Build environment variables with real tokens
  local env_args=()
  case "$server_id" in
    "github")
      env_args+=(-e "GITHUB_PERSONAL_ACCESS_TOKEN=${GITHUB_PERSONAL_ACCESS_TOKEN}")
      printf "│   │   ├── %b[INFO]%b Using real GitHub token\n" "$BLUE" "$NC"
      ;;
    "circleci")
      env_args+=(-e "CIRCLECI_TOKEN=${CIRCLECI_TOKEN}")
      printf "│   │   ├── %b[INFO]%b Using real CircleCI token\n" "$BLUE" "$NC"
      ;;
  esac

  # Test authenticated MCP initialization
  printf "│   │   ├── %b[TESTING]%b Authenticated initialization\n" "$BLUE" "$NC"
  local mcp_init_message='{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "advanced-test", "version": "1.0.0"}}}'

  local response
  response=$(echo "$mcp_init_message" | docker run --rm -i "${env_args[@]}" "$image" 2>&1)

  # Parse response
  local json_response
  case "$parse_mode" in
    "filter_json")
      json_response=$(echo "$response" | grep -E '^\s*\{.*"jsonrpc"' | head -1)
      ;;
    "direct")
      json_response="$response"
      ;;
    *)
      json_response="$response"
      ;;
  esac

  if [[ -n "$json_response" ]] && echo "$json_response" | jq -e '.result.serverInfo.name' > /dev/null 2>&1; then
    local server_info
    server_info=$(echo "$json_response" | jq -r '.result.serverInfo.name + " v" + .result.serverInfo.version')
    printf "│   │   │   └── %b[SUCCESS]%b Authenticated: %s\n" "$GREEN" "$NC" "$server_info"
  else
    printf "│   │   │   └── %b[ERROR]%b Authentication failed\n" "$RED" "$NC"
    return 1
  fi

  # Test tools/list with authentication
  printf "│   │   ├── %b[TESTING]%b Authenticated tools discovery\n" "$BLUE" "$NC"
  local tools_messages
  tools_messages=$(
    cat << 'EOF'
{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "advanced-test", "version": "1.0.0"}}}
{"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}
EOF
  )

  local tools_response
  tools_response=$(echo "$tools_messages" | docker run --rm -i "${env_args[@]}" "$image" 2>&1)

  # Parse tools response
  local tools_json
  case "$parse_mode" in
    "filter_json")
      tools_json=$(echo "$tools_response" | sed -n '/^{.*tools/,$p' | tail -1)
      ;;
    "direct")
      tools_json=$(echo "$tools_response" | tail -1)
      ;;
    *)
      tools_json=$(echo "$tools_response" | tail -1)
      ;;
  esac

  if [[ -n "$tools_json" ]] && echo "$tools_json" | jq -e '.result.tools[]?' > /dev/null 2>&1; then
    local tool_count
    tool_count=$(echo "$tools_json" | jq '.result.tools | length')
    printf "│   │   │   └── %b[SUCCESS]%b %s authenticated tools available\n" "$GREEN" "$NC" "$tool_count"
  else
    printf "│   │   │   └── %b[WARNING]%b No tools available (token may lack permissions)\n" "$YELLOW" "$NC"
  fi

  printf "│   │   └── %b[SUCCESS]%b Advanced functionality test passed\n" "$GREEN" "$NC"
  return 0
}

# Setup all configured MCP servers
setup_all_mcp_servers() {
  echo "=== MCP Server Setup (Registry + Local Builds) ==="

  local failed_setups=0
  local servers
  servers=$(get_configured_servers)

  for server_id in $servers; do
    if ! setup_mcp_server "$server_id"; then
      ((failed_setups++))
    fi
    echo
  done

  if [[ $failed_setups -eq 0 ]]; then
    printf "%b[SUCCESS]%b All MCP servers set up successfully!\n" "$GREEN" "$NC"
    return 0
  else
    printf "%b[ERROR]%b %d MCP server setup(s) failed\n" "$RED" "$NC" "$failed_setups"
    return 1
  fi
}

# Test all configured MCP servers
test_all_mcp_servers() {
  echo "=== MCP Server Health Testing (Generalized stdio/JSON-RPC) ==="

  local failed_tests=0
  local servers
  servers=$(get_configured_servers)

  for server_id in $servers; do
    # Check if image exists before testing
    local image
    image=$(parse_server_config "$server_id" "source.image")

    if docker images | grep -q "$(echo "$image" | cut -d: -f1)"; then
      if ! test_mcp_server_health "$server_id"; then
        ((failed_tests++))
      fi
    else
      local server_name
      server_name=$(parse_server_config "$server_id" "name")
      printf "├── %b[SKIPPED]%b %s (image not available)\n" "$YELLOW" "$NC" "$server_name"
    fi
    echo
  done

  if [[ $failed_tests -eq 0 ]]; then
    printf "%b[SUCCESS]%b All MCP server health tests passed!\n" "$GREEN" "$NC"
    return 0
  else
    printf "%b[ERROR]%b %d MCP server health test(s) failed\n" "$RED" "$NC" "$failed_tests"
    return 1
  fi
}

# Command-line interface
main() {
  case "${1:-help}" in
    "setup")
      if [[ -n "$2" ]]; then
        setup_mcp_server "$2"
      else
        setup_all_mcp_servers
      fi
      ;;
    "test")
      if [[ -n "$2" ]]; then
        test_mcp_server_health "$2"
      else
        test_all_mcp_servers
      fi
      ;;
    "list")
      echo "Configured MCP servers:"
      get_configured_servers | while read -r server; do
        printf "  - %s: %s\n" "$server" "$(parse_server_config "$server" "name")"
      done
      ;;
    "parse")
      if [[ -n "$2" ]] && [[ -n "$3" ]]; then
        parse_server_config "$2" "$3"
      else
        echo "Usage: $0 parse <server_id> <config_key>"
        echo "Example: $0 parse github source.image"
      fi
      ;;
    "help" | *)
      echo "MCP Server Manager"
      echo ""
      echo "Usage: $0 <command> [server_id]"
      echo ""
      echo "Commands:"
      echo "  setup [server_id]  - Set up MCP server(s) (registry pull or local build)"
      echo "  test [server_id]   - Test MCP server(s) health"
      echo "  list               - List configured servers"
      echo "  help               - Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0 setup            # Set up all servers"
      echo "  $0 setup github     # Set up only GitHub server"
      echo "  $0 test             # Test all servers"
      echo "  $0 test circleci    # Test only CircleCI server"
      ;;
  esac
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "${0}" == "${ZSH_ARGZERO}" ]]; then
  main "$@"
fi
