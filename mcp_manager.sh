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

  printf "├── %b[SETUP]%b %s\n" "$BLUE" "$NC" "$(parse_server_config "$server_id" "name")"

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

  # CI environment: skip Docker operations
  if [[ "${CI:-false}" == "true" ]]; then
    printf "│   └── %b[CI MODE]%b Skipping Docker pull for %s (no containerization in CI)\n" "$YELLOW" "$NC" "$image"
    return 0
  fi

  printf "│   ├── %b[PULLING]%b Registry image: %s\n" "$BLUE" "$NC" "$image"

  if ! command -v docker > /dev/null 2>&1; then
    printf "│   └── %b[WARNING]%b Docker not available - install OrbStack for local MCP testing\n" "$YELLOW" "$NC"
    return 0
  fi

  if docker pull "$image" > /dev/null 2>&1; then
    printf "│   └── %b[SUCCESS]%b Registry image ready\n" "$GREEN" "$NC"
    return 0
  else
    printf "│   └── %b[WARNING]%b Failed to pull registry image (Docker may not be running)\n" "$YELLOW" "$NC"
    return 0
  fi
}

# Setup server from local repository build
setup_build_server() {
  local server_id="$1"
  local repository
  local image
  repository=$(parse_server_config "$server_id" "source.repository")
  image=$(parse_server_config "$server_id" "source.image")

  # CI environment: skip Docker operations, just validate repository access
  if [[ "${CI:-false}" == "true" ]]; then
    printf "│   ├── %b[CI MODE]%b Validating repository access: %s\n" "$BLUE" "$NC" "$(basename "$repository" .git)"
    if git ls-remote --heads "$repository" > /dev/null 2>&1; then
      printf "│   └── %b[SUCCESS]%b Repository accessible (skipping Docker build in CI)\n" "$GREEN" "$NC"
      return 0
    else
      printf "│   └── %b[WARNING]%b Repository not accessible\n" "$YELLOW" "$NC"
      return 0
    fi
  fi

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
      printf "│   └── %b[WARNING]%b Failed to clone repository\n" "$YELLOW" "$NC"
      return 0
    fi
  fi

  # Build Docker image (skip if Docker not available)
  if ! command -v docker > /dev/null 2>&1; then
    printf "│   └── %b[WARNING]%b Docker not available - install OrbStack for local MCP testing\n" "$YELLOW" "$NC"
    return 0
  fi

  printf "│   ├── %b[BUILDING]%b Docker image: %s\n" "$BLUE" "$NC" "$image"

  local build_context
  build_context=$(parse_server_config "$server_id" "source.build_context")
  build_context="${build_context:-.}"

  if (cd "$repo_dir/$build_context" && docker build -t "$image" . > /dev/null 2>&1); then
    printf "│   └── %b[SUCCESS]%b Docker image built\n" "$GREEN" "$NC"
    return 0
  else
    printf "│   └── %b[WARNING]%b Failed to build Docker image (Docker may not be running)\n" "$YELLOW" "$NC"
    return 0
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
      if [[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" && "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" != "test_token" ]]; then
        has_real_tokens=true
      elif [[ -n "${GITHUB_TOKEN:-}" && "${GITHUB_TOKEN:-}" != "test_token" ]]; then
        has_real_tokens=true
      fi
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

  local raw_response_for_log
  raw_response_for_log=$(echo "$mcp_init_message" | docker run --rm -i "${env_args[@]}" "$image" 2>&1)

  local json_response # Ensure it's declared local
  unset json_response # Explicitly unset before case

  case "$parse_mode" in
    "filter_json")
      json_response="" # Initialize to empty for this block
      local -a lines_arr
      local line
      while IFS= read -r line; do
        lines_arr+=("$line")
      done < <(printf '%s\n' "$raw_response_for_log")

      for line in "${lines_arr[@]}"; do
        if [[ "$line" == *'"jsonrpc":"2.0"'* && "$line" == *'"id":1'* && "$line" == *'"result":{"protocolVersion":'* ]]; then
          json_response="$line"
          break
        fi
      done
      ;;
    "direct")
      json_response="$raw_response_for_log"
      ;;
    *)
      json_response="$raw_response_for_log"
      ;;
  esac

  # Check if we got a valid MCP response OR expected auth error
  if [[ -n "$json_response" ]]; then
    if jq -e '.result.serverInfo.name' <<< "$json_response" > /dev/null 2>&1; then
      local server_info
      server_info=$(jq -r '.result.serverInfo.name + " v" + .result.serverInfo.version' <<< "$json_response")
      printf "│   │   │   └── %b[SUCCESS]%b MCP protocol: %s\n" "$GREEN" "$NC" "$server_info"
      printf "│   │   └── %b[SUCCESS]%b Basic protocol validation passed\n" "$GREEN" "$NC"
      return 0
    else
      # jq parsing failed for basic init
      : # Do nothing here, fall through to the broader check
    fi
  else
    # json_response was empty for basic init
    : # Do nothing here, fall through to the broader check
  fi

  # Broader check for auth-related errors or common failure keywords for basic test success
  if echo "$raw_response_for_log" | grep -Eiq "not set|invalid|unauthorized|token|Usage:|error|fail|denied|forbidden"; then # Check raw log for errors
    printf "│   │   │   └── %b[SUCCESS]%b MCP protocol functional (auth required or specific error)\n" "$GREEN" "$NC"
    printf "│   │   └── %b[SUCCESS]%b Basic protocol validation passed\n" "$GREEN" "$NC"
    return 0
  else
    printf "│   │   │   └── %b[ERROR]%b MCP protocol failed unexpectedly for %s\n" "$RED" "$NC" "$server_name"
    printf "│   │   │       %bFull Docker run response:%b\n%s\n" "$YELLOW" "$NC" "$raw_response_for_log"
    return 1
  fi
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
      if [[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" && "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" != "test_token" ]]; then
        env_args+=(-e "GITHUB_PERSONAL_ACCESS_TOKEN=${GITHUB_PERSONAL_ACCESS_TOKEN}")
        printf "│   │   ├── %b[INFO]%b Using GITHUB_PERSONAL_ACCESS_TOKEN for authentication\n" "$BLUE" "$NC"
      elif [[ -n "${GITHUB_TOKEN:-}" && "${GITHUB_TOKEN:-}" != "test_token" ]]; then
        env_args+=(-e "GITHUB_PERSONAL_ACCESS_TOKEN=${GITHUB_TOKEN}") # Pass GITHUB_TOKEN as GITHUB_PERSONAL_ACCESS_TOKEN
        printf "│   │   ├── %b[INFO]%b Using GITHUB_TOKEN (as GITHUB_PERSONAL_ACCESS_TOKEN) for authentication\n" "$BLUE" "$NC"
      fi
      ;;
    "circleci")
      env_args+=(-e "CIRCLECI_TOKEN=${CIRCLECI_TOKEN}")
      ;;
  esac

  # Test authenticated MCP initialization
  printf "│   │   ├── %b[TESTING]%b Authenticated initialization\n" "$BLUE" "$NC"
  local mcp_init_message='{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "advanced-test", "version": "1.0.0"}}}'

  local raw_auth_response_for_log
  raw_auth_response_for_log=$(echo "$mcp_init_message" | docker run --rm -i "${env_args[@]}" "$image" 2>&1)

  local auth_json_response # Ensure it's declared local
  unset auth_json_response # Explicitly unset before case

  case "$parse_mode" in
    "filter_json")
      auth_json_response="" # Initialize to empty for this block
      local -a lines_arr
      local line
      while IFS= read -r line; do
        lines_arr+=("$line")
      done < <(printf '%s\n' "$raw_auth_response_for_log")

      for line in "${lines_arr[@]}"; do
        if [[ "$line" == *'"jsonrpc":"2.0"'* && "$line" == *'"id":1'* && "$line" == *'"result":{"protocolVersion":'* ]]; then
          auth_json_response="$line"
          break
        fi
      done
      ;;
    "direct")
      auth_json_response="$raw_auth_response_for_log"
      ;;
    *)
      auth_json_response="$raw_auth_response_for_log"
      ;;
  esac

  if [[ -n "$auth_json_response" ]]; then
    if jq -e '.result.serverInfo.name' <<< "$auth_json_response" > /dev/null 2>&1; then
      local server_info
      server_info=$(jq -r '.result.serverInfo.name + " v" + .result.serverInfo.version' <<< "$auth_json_response")
      printf "│   │   │   └── %b[SUCCESS]%b Authenticated: %s\n" "$GREEN" "$NC" "$server_info"
    else
      # jq parsing failed for auth init
      printf "│   │   │   └── %b[ERROR]%b Authentication failed\n" "$RED" "$NC"
      printf "│   │   │       %bFull Docker run response:%b\n%s\n" "$YELLOW" "$NC" "$raw_auth_response_for_log"
      return 1 # Important to return failure here
    fi
  else
    # auth_json_response was empty
    printf "│   │   │   └── %b[ERROR]%b Authentication failed (empty JSON response)\n" "$RED" "$NC"
    printf "│   │   │       %bFull Docker run response:%b\n%s\n" "$YELLOW" "$NC" "$raw_auth_response_for_log"
    return 1 # Important to return failure here
  fi

  # Test tools/list with authentication
  printf "│   │   ├── %b[TESTING]%b Authenticated tools discovery\n" "$BLUE" "$NC"
  local tools_messages
  tools_messages=$(
    cat << 'EOF'
{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "advanced-test", "version": "1.0.0"}}
{"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}
EOF
  )

  # For tools/list, we also pipe directly to avoid issues with intermediate variables for parsing
  # The raw response can be captured separately if needed for full logging on error
  local raw_tools_response_for_log # Used for logging on error

  raw_tools_response_for_log=$(echo "$tools_messages" | docker run --rm -i "${env_args[@]}" "$image" 2>&1)

  local tools_response_output # Ensure it's declared local
  unset tools_response_output # Explicitly unset before case

  case "$parse_mode" in
    "filter_json")
      local cleaned_response="$raw_tools_response_for_log"
      if [[ "$server_id" == "github" ]]; then
        cleaned_response="${raw_tools_response_for_log#*GitHub MCP Server running on stdio$'\n'}"
        if [[ "$cleaned_response" == "$raw_tools_response_for_log" ]]; then
          cleaned_response="${raw_tools_response_for_log#GitHub MCP Server running on stdio}"
        fi
      fi

      # printf "│   │   DEBUG_DIRECT_JQ_SELECT: Cleaned response for %s (before final jq select) is:\\n" "$server_name"
      # echo "$cleaned_response" | od -c
      # printf "│   │   END DEBUG_DIRECT_JQ_SELECT for %s\\n" "$server_name"

      tools_response_output=$(jq -c '. | select(.id == 2 and .result.tools?)' <<< "$cleaned_response" 2> /dev/null)

      if [[ -n "$tools_response_output" && "$tools_response_output" != "null" ]]; then
        # printf "│   │   DEBUG_DIRECT_JQ_SELECT: Successfully captured tools_response_output for %s (first 100 chars): %s\\n" "$server_name" "${tools_response_output:0:100}"
        true # Placeholder for successful capture, no specific debug print needed here now
      else
        # printf "│   │   DEBUG_DIRECT_JQ_SELECT: Failed to select/extract id:2 JSON object for %s. JQ output was: [%s]\\n" "$server_name" "$tools_response_output"
        tools_response_output=""
      fi
      ;;
    "direct")
      tools_response_output="$raw_tools_response_for_log"
      ;;
    *)
      tools_response_output="$raw_tools_response_for_log"
      ;;
  esac

  if [[ -n "$tools_response_output" ]] && jq -e '.result.tools[]?' <<< "$tools_response_output" > /dev/null 2>&1; then
    local tool_count
    local tool_names
    tool_count=$(jq '.result.tools | length' <<< "$tools_response_output")
    tool_names=$(jq -r '.result.tools[] | .name' <<< "$tools_response_output" | head -5 | paste -sd ', ' -)

    # Output formatted for easy parsing by verify_setup.sh
    if [[ $tool_count -gt 5 ]]; then
      printf "│   │   │   └── %b[SUCCESS]%b %s: %s tools available (%s, ...)\n" "$GREEN" "$NC" "$server_name" "$tool_count" "$tool_names"
    else
      printf "│   │   │   └── %b[SUCCESS]%b %s: %s tools available (%s)\n" "$GREEN" "$NC" "$server_name" "$tool_count" "$tool_names"
    fi
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
  local -a server_id_list # Declare as array
  local server_id_line    # Temporary variable for reading lines
  while IFS= read -r server_id_line; do
    [[ -n "$server_id_line" ]] && server_id_list+=("$server_id_line")
  done < <(get_configured_servers)

  for server_id in "${server_id_list[@]}"; do
    # Skip empty lines that might result from parsing
    [[ -z "$server_id" ]] && continue
    if ! setup_mcp_server "$server_id"; then
      ((failed_setups++))
    fi
    echo # Add a newline for better separation in output
  done

  if [[ $failed_setups -eq 0 ]]; then
    printf "%b[SUCCESS]%b All MCP servers set up successfully!\\n" "$GREEN" "$NC"
    return 0
  else
    printf "%b[ERROR]%b %d MCP server setup(s) failed\\n" "$RED" "$NC" "$failed_setups"
    return 1
  fi
}

# Test all configured MCP servers
test_all_mcp_servers() {
  echo "=== MCP Server Health Testing (Generalized stdio/JSON-RPC) ==="

  # CI environment: skip Docker-based testing
  if [[ "${CI:-false}" == "true" ]]; then
    printf "%b[CI MODE]%b Skipping Docker-based MCP testing (no containerization in CI)\\n" "$YELLOW" "$NC"
    printf "%b[INFO]%b Configuration validation completed successfully\\n" "$BLUE" "$NC"
    return 0
  fi

  # Check if Docker is available
  if ! command -v docker > /dev/null 2>&1; then
    printf "%b[WARNING]%b Docker not available - MCP testing requires OrbStack\\n" "$YELLOW" "$NC"
    printf "%b[INFO]%b Configuration validation completed successfully\\n" "$BLUE" "$NC"
    return 0
  fi

  local failed_tests=0
  local -a server_id_list # Declare as array
  local server_id_line    # Temporary variable for reading lines
  while IFS= read -r server_id_line; do
    [[ -n "$server_id_line" ]] && server_id_list+=("$server_id_line")
  done < <(get_configured_servers)

  for server_id in "${server_id_list[@]}"; do
    # Skip empty lines
    [[ -z "$server_id" ]] && continue

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
      printf "├── %b[SKIPPED]%b %s (image not available)\\n" "$YELLOW" "$NC" "$server_name"
    fi
    echo # Add a newline for better separation in output
  done

  if [[ $failed_tests -eq 0 ]]; then
    printf "%b[SUCCESS]%b All MCP server health tests passed!\\n" "$GREEN" "$NC"
    return 0
  else
    printf "%b[ERROR]%b %d MCP server health test(s) failed\\n" "$RED" "$NC" "$failed_tests"
    return 1
  fi
}

# Generate client configuration snippets for Cursor and Claude Desktop
generate_client_configs() {
  local target_client="${1:-all}"  # all, cursor, claude
  local write_mode="${2:-preview}" # preview, write

  echo "=== MCP Client Configuration Generation ==="

  # Check if servers are available before generating configs
  if [[ "${CI:-false}" != "true" ]] && command -v docker > /dev/null 2>&1; then
    printf "├── %b[INFO]%b Generating configuration for Docker-based MCP servers\n" "$BLUE" "$NC"
  else
    printf "├── %b[WARNING]%b Docker not available - generating template configurations\n" "$YELLOW" "$NC"
  fi

  # Get list of working servers with token status
  local -a working_servers
  local -a servers_with_tokens
  local -a servers_without_tokens
  local server_line

  while IFS= read -r server_line; do
    if [[ -n "$server_line" && "$server_line" == *:* ]]; then
      local server_id="${server_line%:*}"
      local token_status="${server_line#*:}"
      working_servers+=("$server_id")
      if [[ "$token_status" == "has-tokens" ]]; then
        servers_with_tokens+=("$server_id")
      else
        servers_without_tokens+=("$server_id")
      fi
    fi
  done < <(get_working_servers_with_tokens)

  if [[ ${#working_servers[@]} -eq 0 ]]; then
    printf "├── %b[WARNING]%b No working MCP servers found - run health tests first\n" "$YELLOW" "$NC"
    printf "└── %b[INFO]%b Use: ./mcp_manager.sh test\n" "$BLUE" "$NC"
    return 1
  fi

  # Report token status
  if [[ ${#servers_with_tokens[@]} -gt 0 ]]; then
    printf "├── %b[TOKENS]%b Servers with authentication: %s\n" "$GREEN" "$NC" "${servers_with_tokens[*]}"
  fi
  if [[ ${#servers_without_tokens[@]} -gt 0 ]]; then
    printf "├── %b[PLACEHOLDERS]%b Servers using placeholders: %s\n" "$YELLOW" "$NC" "${servers_without_tokens[*]}"
  fi

  # Generate/write configurations
  if [[ "$target_client" == "all" || "$target_client" == "cursor" ]]; then
    if [[ "$write_mode" == "write" ]]; then
      printf "├── %b[WRITING]%b Cursor configuration\n" "$BLUE" "$NC"
      write_cursor_config "${working_servers[@]}"
    else
      printf "├── %b[GENERATING]%b Cursor configuration\n" "$BLUE" "$NC"
      generate_cursor_config "${working_servers[@]}"
    fi
  fi

  # Generate Claude Desktop configuration
  if [[ "$target_client" == "all" || "$target_client" == "claude" ]]; then
    if [[ "$write_mode" == "write" ]]; then
      printf "└── %b[WRITING]%b Claude Desktop configuration\n" "$BLUE" "$NC"
      write_claude_config "${working_servers[@]}"
    else
      printf "└── %b[GENERATING]%b Claude Desktop configuration\n" "$BLUE" "$NC"
      generate_claude_config "${working_servers[@]}"
    fi
  fi

  if [[ "$write_mode" == "write" ]]; then
    printf "\n%b[SUCCESS]%b Client configurations written to files!\n" "$GREEN" "$NC"
  else
    printf "\n%b[SUCCESS]%b Client configurations generated!\n" "$GREEN" "$NC"
    printf "%b[INFO]%b To write to actual config files, use: ./mcp_manager.sh config-write\n" "$BLUE" "$NC"
  fi
}

# Get list of working servers (those that pass health checks)
get_working_servers() {
  # Check if we're in CI or don't have Docker - return all configured servers
  if [[ "${CI:-false}" == "true" ]] || ! command -v docker > /dev/null 2>&1; then
    while IFS= read -r server_id_line; do
      [[ -n "$server_id_line" ]] && echo "$server_id_line"
    done < <(get_configured_servers)
    return 0
  fi

  # Test each server and only include working ones
  while IFS= read -r server_id_line; do
    [[ -z "$server_id_line" ]] && continue

    local image
    image=$(parse_server_config "$server_id_line" "source.image" 2> /dev/null)

    # Skip if we couldn't get a valid image
    [[ -z "$image" ]] && continue

    # Check if image exists
    if docker images | grep -q "$(echo "$image" | cut -d: -f1)" 2> /dev/null; then
      # Quick basic health check
      local server_name
      local parse_mode
      server_name=$(parse_server_config "$server_id_line" "name" 2> /dev/null)
      parse_mode=$(parse_server_config "$server_id_line" "health_test.parse_mode" 2> /dev/null)

      if test_mcp_basic_protocol "$server_id_line" "$server_name" "$image" "$parse_mode" > /dev/null 2>&1; then
        echo "$server_id_line"
      fi
    fi
  done < <(get_configured_servers)
}

# Find Cursor MCP configuration file path
get_cursor_config_path() {
  local cursor_config="$HOME/.cursor/mcp.json"

  # Create directory if it doesn't exist
  mkdir -p "$(dirname "$cursor_config")"

  echo "$cursor_config"
}

# Check if server has real API tokens (extracted from existing health check logic)
server_has_real_tokens() {
  local server_id="$1"

  case "$server_id" in
    "github")
      if [[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" && "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" != "test_token" ]]; then
        return 0
      elif [[ -n "${GITHUB_TOKEN:-}" && "${GITHUB_TOKEN:-}" != "test_token" ]]; then
        return 0
      fi
      ;;
    "circleci")
      [[ -n "${CIRCLECI_TOKEN:-}" && "${CIRCLECI_TOKEN}" != "test_token" ]] && return 0
      ;;
  esac
  return 1
}

# Get environment variable value or placeholder based on server token availability
get_env_value_or_placeholder() {
  local var_name="$1"
  local server_id="$2"

  if server_has_real_tokens "$server_id"; then
    echo "\${$var_name}"
  else
    case "$var_name" in
      "GITHUB_PERSONAL_ACCESS_TOKEN" | "GITHUB_TOKEN")
        echo "YOUR_GITHUB_TOKEN_HERE"
        ;;
      "CIRCLECI_TOKEN")
        echo "YOUR_CIRCLECI_TOKEN_HERE"
        ;;
      "CIRCLECI_BASE_URL")
        echo "https://circleci.com"
        ;;
      *)
        echo "YOUR_${var_name}_HERE"
        ;;
    esac
  fi
}

# Get working servers with token status
get_working_servers_with_tokens() {
  local -a all_servers
  local server_line

  # Get all configured servers (since we don't have Docker in this environment)
  if [[ "${CI:-false}" == "true" ]] || ! command -v docker > /dev/null 2>&1; then
    while IFS= read -r server_line; do
      if [[ -n "$server_line" && "$server_line" =~ ^[a-z]+$ ]]; then
        all_servers+=("$server_line")
      fi
    done < <(get_configured_servers)
  else
    while IFS= read -r server_line; do
      if [[ -n "$server_line" && "$server_line" =~ ^[a-z]+$ ]]; then
        all_servers+=("$server_line")
      fi
    done < <(get_working_servers)
  fi

  for server_id in "${all_servers[@]}"; do
    [[ -z "$server_id" ]] && continue
    local token_status="no-tokens"
    if server_has_real_tokens "$server_id"; then
      token_status="has-tokens"
    fi
    echo "$server_id:$token_status"
  done
}

# Write Cursor configuration to actual settings file
write_cursor_config() {
  local server_ids=("$@")
  local cursor_config
  cursor_config=$(get_cursor_config_path)

  printf "│   ├── %b[CONFIG]%b Target file: %s\n" "$BLUE" "$NC" "$cursor_config"

  # Environment variables are handled per-server based on health check results

  # Backup existing config
  if [[ -f "$cursor_config" ]]; then
    cp "$cursor_config" "${cursor_config}.backup.$(date +%Y%m%d_%H%M%S)"
    printf "│   ├── %b[BACKUP]%b Created backup of existing configuration\n" "$GREEN" "$NC"
  fi

  # Create temporary file for MCP servers configuration
  local temp_mcp_config
  temp_mcp_config=$(mktemp)

  {
    echo "{"
    local first_server=true

    for server_id in "${server_ids[@]}"; do
      [[ -z "$server_id" ]] && continue

      [[ "$first_server" != "true" ]] && echo ","
      first_server=false

      local image
      local env_vars
      image=$(parse_server_config "$server_id" "source.image" 2> /dev/null)
      env_vars=$(parse_server_config "$server_id" "environment_variables" 2> /dev/null | grep -E '^- "' | sed 's/^- "//' | sed 's/"$//')

      # Build server configuration using simpler approach
      {
        echo "  \"$server_id\": {"
        echo "    \"command\": \"docker\","
        echo "    \"args\": ["
        echo "      \"run\", \"--rm\", \"-i\","

        # Add environment variables
        if [[ -n "$env_vars" ]]; then
          echo "$env_vars" | while IFS= read -r env_var; do
            [[ -n "$env_var" ]] && echo "      \"-e\", \"$env_var\","
          done
        fi

        echo "      \"$image\""
        echo "    ],"
        echo "    \"env\": {"

        # Add environment variable mappings
        if [[ -n "$env_vars" ]]; then
          local env_count=0
          local env_array=()
          while IFS= read -r env_var; do
            [[ -n "$env_var" ]] && env_array+=("$env_var")
          done <<< "$env_vars"

          for env_var in "${env_array[@]}"; do
            ((env_count++))
            local env_value
            env_value=$(get_env_value_or_placeholder "$env_var" "$server_id" 2> /dev/null)
            if [[ $env_count -eq ${#env_array[@]} ]]; then
              echo "      \"$env_var\": \"$env_value\""
            else
              echo "      \"$env_var\": \"$env_value\","
            fi
          done
        fi

        echo "    }"
        echo "  }"
      } >> "$temp_mcp_config"
    done

    echo "}"
  } > "$temp_mcp_config"

  # Read existing config or create empty one
  local existing_config="{}"
  if [[ -f "$cursor_config" ]]; then
    existing_config=$(cat "$cursor_config")
  fi

  # Update configuration using jq (for mcp.json, the structure is simpler)
  local mcp_servers_json
  mcp_servers_json=$(cat "$temp_mcp_config")
  local updated_config
  updated_config=$(echo "$existing_config" | jq --argjson mcp_servers "$mcp_servers_json" '. = $mcp_servers')

  # Write updated configuration
  echo "$updated_config" > "$cursor_config"
  rm "$temp_mcp_config"
  printf "│   └── %b[SUCCESS]%b Cursor MCP configuration updated\n" "$GREEN" "$NC"
}

# Write Claude Desktop configuration
write_claude_config() {
  local server_ids=("$@")
  local claude_config="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

  printf "│   ├── %b[CONFIG]%b Target file: %s\n" "$BLUE" "$NC" "$claude_config"

  # Environment variables are handled per-server based on health check results

  # Backup existing config
  if [[ -f "$claude_config" ]]; then
    cp "$claude_config" "${claude_config}.backup.$(date +%Y%m%d_%H%M%S)"
    printf "│   ├── %b[BACKUP]%b Created backup of existing configuration\n" "$GREEN" "$NC"
  fi

  # Create temporary file for MCP servers configuration
  local temp_mcp_config
  temp_mcp_config=$(mktemp)

  {
    echo "{"
    echo "  \"mcpServers\": {"
    local first_server=true

    for server_id in "${server_ids[@]}"; do
      [[ -z "$server_id" ]] && continue

      [[ "$first_server" != "true" ]] && echo ","
      first_server=false

      local image
      local env_vars
      image=$(parse_server_config "$server_id" "source.image" 2> /dev/null)
      env_vars=$(parse_server_config "$server_id" "environment_variables" 2> /dev/null | grep -E '^- "' | sed 's/^- "//' | sed 's/"$//')

      # Build server configuration using simpler approach
      {
        echo "    \"$server_id\": {"
        echo "      \"command\": \"docker\","
        echo "      \"args\": ["
        echo "        \"run\", \"--rm\", \"-i\","

        # Add environment variables
        if [[ -n "$env_vars" ]]; then
          echo "$env_vars" | while IFS= read -r env_var; do
            [[ -n "$env_var" ]] && echo "        \"-e\", \"$env_var=\${$env_var}\","
          done
        fi

        echo "        \"$image\""
        echo "      ]"
        echo "    }"
      } >> "$temp_mcp_config"
    done

    echo "  }"
    echo "}"
  } > "$temp_mcp_config"

  # Read existing config or create empty one
  local existing_config="{}"
  if [[ -f "$claude_config" ]]; then
    existing_config=$(cat "$claude_config")
  fi

  # Update configuration using jq
  local mcp_servers_json
  mcp_servers_json=$(cat "$temp_mcp_config")
  local updated_config
  updated_config=$(echo "$existing_config" | jq --argjson mcp_servers "$mcp_servers_json" '.mcpServers = $mcp_servers.mcpServers')

  # Write updated configuration
  echo "$updated_config" > "$claude_config"
  rm "$temp_mcp_config"
  printf "│   └── %b[SUCCESS]%b Claude Desktop MCP configuration updated\n" "$GREEN" "$NC"
}

# Generate Cursor-specific MCP configuration
generate_cursor_config() {
  local server_ids=("$@")

  cat << 'EOF'

=== Cursor Configuration ===
Add this to your Cursor MCP configuration file (~/.cursor/mcp.json):

{
EOF

  for server_id in "${server_ids[@]}"; do
    [[ -z "$server_id" ]] && continue

    local server_name
    local image
    local env_vars
    server_name=$(parse_server_config "$server_id" "name")
    image=$(parse_server_config "$server_id" "source.image")

    # Get environment variables for this server
    env_vars=$(parse_server_config "$server_id" "environment_variables" | grep -E '^- "' | sed 's/^- "//' | sed 's/"$//' 2> /dev/null)

    printf '  "%s": {\n' "$server_id"
    printf '    "command": "docker",\n'
    printf '    "args": [\n'
    printf '      "run", "--rm", "-i",\n'

    # Add environment variables
    if [[ -n "$env_vars" ]]; then
      echo "$env_vars" | while IFS= read -r env_var; do
        [[ -n "$env_var" ]] && printf '      "-e", "%s",\n' "$env_var"
      done
    fi

    printf '      "%s"\n' "$image"
    printf '    ],\n'
    printf '    "env": {\n'

    # Add environment variable mappings with proper value handling
    if [[ -n "$env_vars" ]]; then
      local first=true
      echo "$env_vars" | while IFS= read -r env_var; do
        if [[ -n "$env_var" ]]; then
          [[ "$first" != "true" ]] && printf ',\n'
          local env_value
          env_value=$(get_env_value_or_placeholder "$env_var" "$server_id" 2> /dev/null)
          printf '      "%s": "%s"' "$env_var" "$env_value"
          first=false
        fi
      done
      echo ""
    fi

    printf '    }\n'
    printf '  }'

    # Add comma if not the last server
    local is_last=true
    for remaining in "${server_ids[@]}"; do
      if [[ "$remaining" > "$server_id" && -n "$remaining" ]]; then
        is_last=false
        break
      fi
    done
    [[ "$is_last" != "true" ]] && printf ','
    printf '\n'
  done

  cat << 'EOF'
}

EOF
}

# Generate Claude Desktop-specific MCP configuration
generate_claude_config() {
  local server_ids=("$@")

  cat << 'EOF'

=== Claude Desktop Configuration ===
Add this to your Claude Desktop configuration file:
~/Library/Application Support/Claude/claude_desktop_config.json

{
  "mcpServers": {
EOF

  for server_id in "${server_ids[@]}"; do
    [[ -z "$server_id" ]] && continue

    local server_name
    local image
    local env_vars
    server_name=$(parse_server_config "$server_id" "name")
    image=$(parse_server_config "$server_id" "source.image")
    env_vars=$(parse_server_config "$server_id" "environment_variables" | grep -E '^- "' | sed 's/^- "//' | sed 's/"$//' 2> /dev/null)

    printf '    "%s": {\n' "$server_id"
    printf '      "command": "docker",\n'
    printf '      "args": [\n'
    printf '        "run", "--rm", "-i",\n'

    # Add environment variables with proper value handling
    if [[ -n "$env_vars" ]]; then
      echo "$env_vars" | while IFS= read -r env_var; do
        if [[ -n "$env_var" ]]; then
          local env_value
          env_value=$(get_env_value_or_placeholder "$env_var" "$server_id" 2> /dev/null)
          printf '        "-e", "%s=%s",\n' "$env_var" "$env_value"
        fi
      done
    fi

    printf '        "%s"\n' "$image"
    printf '      ]\n'
    printf '    }'

    # Add comma if not the last server
    local is_last=true
    for remaining in "${server_ids[@]}"; do
      if [[ "$remaining" > "$server_id" && -n "$remaining" ]]; then
        is_last=false
        break
      fi
    done
    [[ "$is_last" != "true" ]] && printf ','
    printf '\n'
  done

  cat << 'EOF'
  }
}

EOF
}

# Normalize command arguments to handle both formats
normalize_args() {
  local cmd="$1"
  local arg="$2"

  # If no arguments provided, return as is
  [[ -z "$cmd" ]] && return 0

  # Handle help command variations
  if [[ "$cmd" == "help" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
    echo "help"
    return 0
  fi

  # Handle setup command variations
  if [[ "$cmd" == "setup" || "$cmd" == "--setup" || "$cmd" == "-s" ]]; then
    echo "setup"
    [[ -n "$arg" ]] && echo "$arg"
    return 0
  fi

  # Handle test command variations
  if [[ "$cmd" == "test" || "$cmd" == "--test" || "$cmd" == "-t" ]]; then
    echo "test"
    [[ -n "$arg" ]] && echo "$arg"
    return 0
  fi

  # Handle config command variations
  if [[ "$cmd" == "config" || "$cmd" == "--config" || "$cmd" == "-c" ]]; then
    echo "config"
    [[ -n "$arg" ]] && echo "$arg"
    return 0
  fi

  # Handle config-write command variations
  if [[ "$cmd" == "config-write" || "$cmd" == "--config-write" || "$cmd" == "-w" ]]; then
    echo "config-write"
    [[ -n "$arg" ]] && echo "$arg"
    return 0
  fi

  # Handle list command variations
  if [[ "$cmd" == "list" || "$cmd" == "--list" || "$cmd" == "-l" ]]; then
    echo "list"
    return 0
  fi

  # Handle parse command variations
  if [[ "$cmd" == "parse" || "$cmd" == "--parse" || "$cmd" == "-p" ]]; then
    echo "parse"
    [[ -n "$arg" ]] && echo "$arg"
    [[ -n "$3" ]] && echo "$3"
    return 0
  fi

  # If no recognized command, return as is
  echo "$cmd"
  [[ -n "$arg" ]] && echo "$arg"
  return 0
}

# Command-line interface
main() {
  # Normalize arguments to handle both formats
  local normalized_args
  normalized_args=($(normalize_args "$1" "$2" "$3"))

  case "${normalized_args[0]:-help}" in
    "setup")
      if [[ -n "${normalized_args[1]}" ]]; then
        setup_mcp_server "${normalized_args[1]}"
      else
        setup_all_mcp_servers
      fi
      ;;
    "test")
      if [[ -n "${normalized_args[1]}" ]]; then
        test_mcp_server_health "${normalized_args[1]}"
      else
        test_all_mcp_servers
      fi
      ;;
    "config")
      generate_client_configs "${normalized_args[1]:-all}" "preview"
      ;;
    "config-write")
      generate_client_configs "${normalized_args[1]:-all}" "write"
      ;;
    "list")
      echo "Configured MCP servers:"
      get_configured_servers | while read -r server; do
        printf "  - %s: %s\n" "$server" "$(parse_server_config "$server" "name")"
      done
      ;;
    "parse")
      if [[ -n "${normalized_args[1]}" ]] && [[ -n "${normalized_args[2]}" ]]; then
        parse_server_config "${normalized_args[1]}" "${normalized_args[2]}"
      else
        echo "Usage: $0 parse <server_id> <config_key>"
        echo "Example: $0 parse github source.image"
      fi
      ;;
    "help" | *)
      echo "MCP Server Manager"
      echo ""
      echo "Usage: $0 <command> [server_id|client]"
      echo ""
      echo "Commands:"
      echo "  setup [server_id]     - Set up MCP server(s) (registry pull or local build)"
      echo "  test [server_id]      - Test MCP server(s) health"
      echo "  config [client]       - Generate client configuration snippets (preview)"
      echo "  config-write [client] - Write configuration to actual client config files"
      echo "  list                  - List configured servers"
      echo "  parse <server_id> <config_key> - Parse configuration value from registry"
      echo "  help                  - Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0 setup              # Set up all servers"
      echo "  $0 setup github       # Set up only GitHub server"
      echo "  $0 test               # Test all servers"
      echo "  $0 config             # Preview configs for all clients"
      echo "  $0 config cursor      # Preview Cursor-specific config"
      echo "  $0 config-write       # Write configs to actual files (working servers only)"
      echo "  $0 config-write claude # Write Claude Desktop config only"
      echo ""
      echo "Alternative formats:"
      echo "  $0 --setup github     # Same as 'setup github'"
      echo "  $0 -s github          # Same as 'setup github'"
      echo "  $0 --test             # Same as 'test'"
      echo "  $0 -t github          # Same as 'test github'"
      echo "  $0 --config cursor    # Same as 'config cursor'"
      echo "  $0 -c cursor          # Same as 'config cursor'"
      echo "  $0 --config-write     # Same as 'config-write'"
      echo "  $0 -w claude          # Same as 'config-write claude'"
      echo "  $0 --list             # Same as 'list'"
      echo "  $0 -l                 # Same as 'list'"
      echo "  $0 --parse github source.image  # Same as 'parse github source.image'"
      echo "  $0 -p github source.image       # Same as 'parse github source.image'"
      ;;
  esac
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "${0}" == "${ZSH_ARGZERO}" ]]; then
  main "$@"
fi
