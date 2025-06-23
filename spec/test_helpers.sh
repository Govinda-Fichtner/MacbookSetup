#!/bin/bash
# shellcheck disable=SC2317

# ShellSpec helper function for conditional test skipping
skip() {
  local message="${1:-Skipped}"
  echo 'SKIP:' "$message" >&2
  return 0
}

# Test environment setup
setup_test_environment() {
  export TEST_HOME="$PWD/tmp/test_home"
  export CI=false

  # Create test directory structure
  mkdir -p "$TEST_HOME"/{inspector,rails/{projects,config/rails-mcp}}

  # Set up Rails test environment
  export RAILS_MCP_ROOT_PATH="$TEST_HOME/rails/projects"
  export RAILS_MCP_CONFIG_HOME="$TEST_HOME/rails/config"

  # Create projects.yml with test project (container paths)
  cat > "$TEST_HOME/rails/config/rails-mcp/projects.yml" << 'EOF'
test_project: '/rails-projects/test_project'
blog: '/rails-projects/blog'
EOF

  # Create test project directory
  mkdir -p "$TEST_HOME/rails/projects/test_project"

  # Set up inspector test environment
  mkdir -p "$TEST_HOME/inspector/.cursor"
}

# Test environment cleanup
cleanup_test_environment() {
  rm -rf "$TEST_HOME"
}

# Mock environment variables for testing
mock_env_vars() {
  # Mock .env file for testing
  cat > "$TEST_HOME/.env" << EOF
RAILS_MCP_ROOT_PATH=$TEST_HOME/rails/projects
RAILS_MCP_CONFIG_HOME=$TEST_HOME/rails/config
EOF
}

# Mock Docker commands for testing
mock_docker_commands() {
  # Create mock functions for Docker in test environment
  docker() {
    case "$1" in
      "ps")
        echo "CONTAINER ID   IMAGE                     NAMES"
        echo "123abc         mcp/github:latest        test-github"
        ;;
      "images") echo "mcp/github   latest   123   2 hours ago   100MB" ;;
      "run") echo "{\"status\": \"success\", \"message\": \"Test successful\"}" ;;
      *) return 1 ;;
    esac
  }
}

# Mock yq command for testing
mock_yq_command() {
  yq() {
    case "$*" in
      "eval '.servers | keys | .[]' mcp_server_registry.yml")
        echo "github"
        echo "circleci"
        echo "filesystem"
        echo "docker"
        echo "kubernetes"
        echo "rails"
        echo "inspector"
        ;;
      "eval '.servers.github.name' mcp_server_registry.yml")
        echo "GitHub MCP Server"
        ;;
      "eval '.servers.github.server_type' mcp_server_registry.yml")
        echo "api_based"
        ;;
      "eval '.servers.github.source.type' mcp_server_registry.yml")
        echo "registry"
        ;;
      "eval '.servers.github.source.image' mcp_server_registry.yml")
        echo "mcp/github:latest"
        ;;
      *) return 1 ;;
    esac
  }
}

# Mock jq command for testing
mock_jq_command() {
  jq() {
    case "$*" in
      "'.github' $TEST_HOME/.cursor/mcp.json")
        echo "{\"command\": \"docker\", \"args\": [\"run\", \"--rm\", \"-i\", \"--env-file\", \".env\", \"mcp/github:latest\"]}"
        ;;
      "'.mcpServers.github' $TEST_HOME/Library/Application Support/Claude/claude_desktop_config.json")
        echo "{\"command\": \"docker\", \"args\": [\"run\", \"--rm\", \"-i\", \"--env-file\", \".env\", \"mcp/github:latest\"]}"
        ;;
      *) return 1 ;;
    esac
  }
}

# Mock git command for testing
mock_git_command() {
  git() {
    case "$*" in
      "ls-remote --heads https://github.com/example/repo.git")
        echo "refs/heads/main"
        return 0
        ;;
      *) return 1 ;;
    esac
  }
}

# Mock Docker for server start/stop testing
mock_docker_for_server_control() {
  docker() {
    case "$1" in
      "run")
        if [[ "$*" == *"--name mcp-github"* ]]; then
          echo "123abc"
          return 0
        fi
        return 1
        ;;
      "stop")
        if [[ "$*" == *"mcp-github"* ]]; then
          echo "mcp-github"
          return 0
        fi
        return 1
        ;;
      "rm")
        if [[ "$*" == *"mcp-github"* ]]; then
          echo "mcp-github"
          return 0
        fi
        return 1
        ;;
      *) return 1 ;;
    esac
  }
}

# Mock Docker for privileged server testing
mock_docker_for_privileged() {
  docker() {
    case "$1" in
      "run")
        if [[ "$*" == *"--privileged"* ]]; then
          echo "123abc"
          return 0
        fi
        return 1
        ;;
      *) return 1 ;;
    esac
  }
}

# Mock Docker for network testing
mock_docker_for_network() {
  docker() {
    case "$1" in
      "run")
        if [[ "$*" == *"--network"* ]]; then
          echo "123abc"
          return 0
        fi
        return 1
        ;;
      *) return 1 ;;
    esac
  }
}

# Mock Docker for volume testing
mock_docker_for_volume() {
  docker() {
    case "$1" in
      "run")
        if [[ "$*" == *"-v"* ]]; then
          echo "123abc"
          return 0
        fi
        return 1
        ;;
      *) return 1 ;;
    esac
  }
}

# Setup all mocks for testing
setup_all_mocks() {
  mock_docker_commands
  mock_yq_command
  mock_jq_command
  mock_git_command
  mock_docker_for_server_control
  mock_docker_for_privileged
  mock_docker_for_network
  mock_docker_for_volume
}

# Cleanup all mocks
cleanup_all_mocks() {
  unset -f docker yq jq git 2> /dev/null || true
}

# Setup test environment with all mocks
setup_test_environment_with_mocks() {
  setup_test_environment
  mock_env_vars
  setup_all_mocks

  # Create .env file in TEST directory only - NEVER overwrite real .env
  cat > "$TEST_HOME/.env" << EOF
GITHUB_TOKEN=test_token_here
CIRCLECI_TOKEN=test_token_here
FILESYSTEM_ALLOWED_DIRS=/Users/gfichtner/MacbookSetup,/Users/gfichtner/Desktop
RAILS_MCP_ROOT_PATH=$TEST_HOME/rails/projects
RAILS_MCP_CONFIG_HOME=$TEST_HOME/rails/config
EOF
}

# Cleanup test environment and mocks
cleanup_test_environment_with_mocks() {
  cleanup_test_environment
  cleanup_all_mocks
  # Remove .env file created for testing (in test directory only)
  rm -f "$TEST_HOME/.env"
}

# Start test MCP containers
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

# Mock Docker for CI environment
mock_docker_for_ci() {
  # Mock Docker commands for CI environment where Docker may not be available
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

# Mock Docker with no containers
mock_docker_no_containers() {
  # Mock Docker commands to simulate no containers running
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

# Setup inspector test environment
setup_inspector_test_environment() {
  setup_test_environment
  mock_env_vars
}

# Cleanup inspector test environment
cleanup_inspector_test_environment() {
  cleanup_test_environment
}

start_github_server_for_test() {
  ./mcp_manager.sh start github > /dev/null
}

stop_github_server_for_test() {
  ./mcp_manager.sh stop github > /dev/null
}

# Validate .env file content to prevent corruption issues
validate_env_file() {
  local env_file="$1"

  if [[ ! -f "$env_file" ]]; then
    echo "ERROR: .env file not found: $env_file" >&2
    return 1
  fi

  # Check for shell redirection artifacts that indicate corruption
  if grep -q -E "(EOF|<<|>>|< /dev|> /dev)" "$env_file"; then
    echo "ERROR: .env file contains shell redirection artifacts: $env_file" >&2
    echo "Corrupted content:" >&2
    cat "$env_file" >&2
    return 1
  fi

  # Check for invalid variable format (must be KEY=VALUE)
  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Check if line matches KEY=VALUE format
    if ! [[ "$line" =~ ^[A-Z_][A-Z0-9_]*=.*$ ]]; then
      echo "ERROR: Invalid .env line format: '$line'" >&2
      echo "Expected format: KEY=VALUE" >&2
      return 1
    fi
  done < "$env_file"

  return 0
}

# Create safe .env file using printf instead of heredoc
create_safe_env_file() {
  local env_file="$1"
  shift
  local env_vars=("$@")

  # Remove existing file first
  rm -f "$env_file"

  # Create each line safely using printf
  for env_var in "${env_vars[@]}"; do
    printf '%s\n' "$env_var" >> "$env_file"
  done

  # Validate the created file
  if ! validate_env_file "$env_file"; then
    rm -f "$env_file"
    echo "ERROR: Failed to create valid .env file: $env_file" >&2
    return 1
  fi

  return 0
}
