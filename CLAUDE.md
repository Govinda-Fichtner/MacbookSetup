# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Essential Commands

### Building and Testing
```bash
# Run all tests (MANDATORY before any commit)
shellspec spec/

# Run specific test suite
shellspec spec/unit/mcp_manager_unit_spec.sh
shellspec spec/integration/mcp_manager_integration_spec.sh

# Quick syntax validation
zsh -n setup.sh && zsh -n verify_setup.sh && zsh -n mcp_manager.sh

# Integration test
./verify_setup.sh > /dev/null

# Pre-commit checks (NEVER skip with --no-verify)
pre-commit run --all-files

# Clean temporary files
support/scripts/clean_tmp.sh
```

### MCP Server Management
```bash
# List all configured MCP servers
./mcp_manager.sh list

# Test server health (basic protocol + advanced functionality)
./mcp_manager.sh test                    # Test all servers
./mcp_manager.sh test github              # Test specific server
./mcp_manager.sh test filesystem          # Test filesystem server

# Build/setup servers (for build-type servers)
./mcp_manager.sh setup circleci           # Build from source
./mcp_manager.sh setup heroku             # Build custom Docker image

# Configuration generation
./mcp_manager.sh config-write             # Write both Cursor and Claude configs
./mcp_manager.sh config cursor            # Preview Cursor config
./mcp_manager.sh config claude            # Preview Claude Desktop config

# Launch MCP Inspector
./mcp_manager.sh inspect --ui             # Visual debugging interface
./mcp_manager.sh inspect --health         # Monitor health with auto-healing
./mcp_manager.sh inspect --stop           # Stop inspector
```

### Development Workflow Commands (Simple Continuous Testing - SCT)
```bash
# Fast tests (<10 seconds) - run frequently
sct-fast() {
  echo "⚡ Fast tests..."
  zsh -n setup.sh && zsh -n verify_setup.sh && zsh -n mcp_manager.sh
  shellspec spec/unit/mcp_manager_unit_spec.sh --format progress
}

# Full tests (30+ seconds) - run periodically
sct-full() {
  echo "🔍 Full test suite..."
  shellspec spec/ --format documentation
  ./verify_setup.sh > /dev/null
  pre-commit run --all-files
}

# Commit with fast tests (use for most changes)
sct-commit() {
  sct-fast || { echo "❌ Fast tests failed"; return 1; }
  git add .
  git commit -m "${1:-feat: incremental change}"
  # Tracks changes and runs full tests every 5 commits
}
```

## High-Level Architecture

### MCP Manager System
The MCP Manager (`mcp_manager.sh`) is the central tool for configuring Model Context Protocol servers. Key architectural insights:

1. **Dual-Function Configuration System**:
   - Preview functions (`generate_cursor_config`, `generate_claude_config`) for terminal display
   - Write functions (`write_cursor_config`, `write_claude_config`) for actual file generation
   - These have DIFFERENT implementations - a source of complexity

2. **Server Type Classification**:
   - `api_based`: GitHub, CircleCI, Figma, Slack (use `--env-file` for tokens)
   - `mount_based`: Filesystem (use `--mount` for directory access)
   - `privileged`: Docker, Kubernetes, Terraform-CLI (need special volumes/networks)
   - `standalone`: Inspector, Terraform Registry (no external dependencies)

3. **Configuration Data Flow**:
   - Source: `mcp_server_registry.yml` (server metadata, Docker configs, environment variables)
   - Environment: `.env` file (API tokens, never committed)
   - Output: `~/.cursor/mcp.json` and `~/Library/Application Support/Claude/claude_desktop_config.json`

4. **Template-Based Generation** (New Architecture):
   - Jinja2 templates in `support/templates/` for each server
   - Shell script generates `data.json`, Jinja2 renders final configs
   - Single source of truth for formatting

### Testing Architecture
Comprehensive ShellSpec-based testing with multiple levels:

1. **Unit Tests** (`spec/unit/`): Test individual functions (115+ fast tests)
2. **Integration Tests** (`spec/integration/`): Test full workflows
3. **Test Helpers** (`spec/spec_helper.sh`, `spec/test_helpers.sh`): Shared utilities
4. **Temporary Test Environments**: Use `./tmp/test_home/` for isolated testing

### Directory Structure
```
MacbookSetup/
├── mcp_manager.sh              # Main MCP server management tool
├── setup.sh                    # Main setup script for Mac environment
├── verify_setup.sh             # Verification script
├── mcp_server_registry.yml     # Central MCP server configuration
├── spec/                       # ShellSpec tests
│   ├── unit/                   # Fast unit tests
│   ├── integration/            # Slower integration tests
│   └── *.sh                    # Test helpers
├── support/                    # Supporting files
│   ├── completions/            # Shell completions
│   ├── docker/                 # Custom Dockerfiles for MCP servers
│   ├── scripts/                # Utility scripts
│   └── templates/              # Jinja2 templates for configs
└── tmp/                        # Temporary files (gitignored)
    ├── repositories/           # Cloned repos during builds
    └── test_home/              # Test environments
```

### Critical Implementation Details

1. **Function Order Matters**: Helper functions must be defined BEFORE use in shell scripts
2. **Debug Output Prevention**: NEVER use command substitution `$()` without proper stderr redirection
3. **Environment File Safety**: Never overwrite `.env`, only generate `.env_example`
4. **Container Path Mapping**: Host paths must map to container paths (e.g., KUBECONFIG)
5. **Build-Type Servers**: Use custom Dockerfiles from `support/docker/*/Dockerfile`
6. **Cleanup Protocol**: Always clean cloned repositories after Docker builds

### 🚨 **Critical Refactoring Lessons (June 2025)**

**ELIMINATED COMPLEXITY**: The dual-function architecture has been completely removed. Key lessons:

1. **✅ Unified Configuration**: Single `get_formatted_config_json()` function eliminates code duplication
2. **✅ Debug Output Control**: Use `exec 3>&1 1>&2` pattern to prevent variable assignment leakage
3. **✅ JSON Formatting**: Let Jinja2 handle logic, `jq .` handle presentation
4. **✅ Template Consistency**: Separate Docker arguments (`"--volume", "/path"`) not concatenated (`"--volume=/path"`)

### **Adding New MCP Servers: Checklist**

When adding a new MCP server, follow this exact process:

#### **1. Registry Entry** (`mcp_server_registry.yml`)
```yaml
my-new-server:
  name: "My New Server"
  server_type: "api_based"  # Choose: api_based, mount_based, privileged, standalone
  source:
    type: registry  # or "build" for custom Dockerfiles
    image: "my-org/my-server:latest"
    entrypoint: "node"  # Optional: if needed
    cmd: ["dist/cli.js", "--stdio"]  # Optional: if needed
  environment_variables:
    - "MY_API_TOKEN"
```

#### **2. Template Creation** (`support/templates/my-new-server.tpl`)
```jinja2
"{{ server.id }}": {
  "command": "docker",
  "args": [
    "run", "--rm", "-i",
    "--env-file", "{{ server.env_file }}",
    {%- if server.entrypoint != "null" %}
    "--entrypoint", "{{ server.entrypoint }}",
    {%- endif %}
    "{{ server.image }}"
    {%- if server.cmd_args and server.cmd_args|length > 0 -%},
    {%- for arg in server.cmd_args -%}"{{ arg }}"{%- if not loop.last -%},{%- endif -%}{%- endfor -%}
    {%- endif -%}
  ]
}
```

#### **3. Verification Commands**
```bash
# Parse registry data
./mcp_manager.sh parse my-new-server server_type

# Preview configuration
./mcp_manager.sh config | jq '.mcpServers."my-new-server"'

# Write and test
./mcp_manager.sh config-write
```

### **🚨 Critical: Preventing Output Pollution/Corruption**

**THE PROBLEM**: Shell commands, especially in zsh, can leak debug output, variable assignments, and error messages into STDOUT, corrupting JSON or other structured outputs.

#### **🔥 Zsh-Specific Variable Assignment Leakage**
**Root Cause**: Zsh outputs variable assignments to STDOUT during command substitution, contaminating clean output.

```bash
# ❌ DEADLY PATTERN - Will output "server_type=api_based" to stdout in zsh
server_type=$(yq -r ".servers.$server_id.server_type" "$registry_file")

# ✅ SOLUTION 1: File Descriptor Redirection (Recommended)
get_server_type() {
  local server_id="$1"
  local registry_file="$2"

  # Isolate stdout from stderr during function execution
  exec 3>&1 1>&2

  # All debug output goes to stderr (fd 2)
  local server_type=$(yq -r ".servers.$server_id.server_type" "$registry_file")

  # Restore stdout and return clean result
  exec 1>&3 3>&-
  echo "$server_type"
}

# ✅ SOLUTION 2: Temporary Files (Alternative)
get_server_type_safe() {
  local server_id="$1"
  local registry_file="$2"
  local temp_file=$(mktemp)

  yq -o json ".servers.$server_id.server_type // null" "$registry_file" > "$temp_file" 2>/dev/null
  local result=$(cat "$temp_file")
  rm -f "$temp_file"
  echo "$result"
}
```

#### **🔥 Environment Sourcing Contamination**
**Root Cause**: Sourcing `.env` files can output variable assignments and sourcing messages to STDOUT.

```bash
# ❌ DEADLY PATTERN - May output sourcing messages to stdout
source .env

# ✅ SOLUTION: Proper Redirection with Auto-Export
if [[ -f ".env" ]]; then
  set -a                    # Auto-export all variables
  source .env 2>/dev/null   # Suppress ALL sourcing output to stderr
  set +a                    # Turn off auto-export
fi
```

#### **🔥 Command Substitution Debug Leakage**
**Root Cause**: Commands inside `$()` can output debug info, progress messages, or errors to STDOUT.

```bash
# ❌ DEADLY PATTERN - Debug output contaminates result
result=$(complex_command_with_debug_output)

# ✅ SOLUTION: Separate Command Execution
temp_file=$(mktemp)
complex_command_with_debug_output > "$temp_file" 2>&1
result=$(cat "$temp_file")
rm -f "$temp_file"

# ✅ ALTERNATIVE: Explicit Redirection
result=$(complex_command_with_debug_output 2>/dev/null)
```

#### **🔥 Function Return Value Contamination**
**Root Cause**: Functions that mix debug output with return values via echo.

```bash
# ❌ DEADLY PATTERN - Debug messages mixed with return values
generate_config() {
  echo "Processing server..."  # Goes to stdout!
  echo '{"server": "config"}'  # Also goes to stdout!
}

# ✅ SOLUTION: Separate Debug and Return Channels
generate_config() {
  echo "Processing server..." >&2  # Debug to stderr
  echo '{"server": "config"}'      # Clean return to stdout
}

# ✅ ALTERNATIVE: File Descriptor Isolation
generate_config() {
  exec 3>&1 1>&2  # Redirect stdout to stderr

  echo "Processing server..."  # Now goes to stderr
  local config='{"server": "config"}'

  exec 1>&3 3>&-  # Restore stdout
  echo "$config"  # Clean return
}
```

#### **🔥 Jinja2/External Tool Output Contamination**
**Root Cause**: External tools may output progress, warnings, or debug info to STDOUT.

```bash
# ❌ DEADLY PATTERN - Tool warnings contaminate JSON
json_config=$(jinja2 template.j2 data.json)

# ✅ SOLUTION: Capture and Validate
temp_output=$(mktemp)
jinja2 template.j2 data.json > "$temp_output" 2>/dev/null

# Validate it's clean JSON
if jq empty "$temp_output" 2>/dev/null; then
  json_config=$(cat "$temp_output")
else
  echo "ERROR: Invalid JSON generated" >&2
  exit 1
fi
rm -f "$temp_output"
```

#### **🛡️ Universal Clean Output Pattern**
**The GOLDEN RULE**: For any function that must return clean output:

```bash
generate_clean_output() {
  local input="$1"

  # Step 1: Isolate stdout
  exec 3>&1 1>&2

  # Step 2: All debug/progress output goes to stderr (fd 2)
  echo "[DEBUG] Processing $input"
  local result=$(some_command "$input")
  echo "[DEBUG] Processing complete"

  # Step 3: Restore stdout and return ONLY clean result
  exec 1>&3 3>&-
  echo "$result"
}

# Usage: Clean output only
clean_result=$(generate_clean_output "input")
```

#### **🔍 Debugging Output Pollution**
**Detection Commands:**
```bash
# Check for variable assignments in output
./mcp_manager.sh config | grep -E '^[A-Z_]+=.*$'

# Check for debug messages in JSON
./mcp_manager.sh config | jq . 2>&1 | grep -v "parse error"

# Verify stderr vs stdout separation
./mcp_manager.sh config 2>debug.log 1>clean.json
cat debug.log    # Should contain debug info
cat clean.json   # Should be clean JSON
```

#### **🚨 Testing for Output Pollution**
**Unit Test Pattern:**
```bash
It "produces clean output without debug contamination"
  When run ./mcp_manager.sh config
  The status should be success
  The output should not include "server_type="
  The output should not include "[DEBUG]"
  The output should not include "Processing"
  # JSON should be valid
  The output should match pattern '^\{.*\}$'
End
```

#### **📋 Output Pollution Checklist**
Before any function that generates structured output:

- [ ] **File Descriptor Isolation**: Use `exec 3>&1 1>&2` pattern
- [ ] **Environment Sourcing**: Redirect `.env` sourcing to stderr with `2>/dev/null`
- [ ] **Command Substitution**: Verify no debug output in `$(...)` commands
- [ ] **External Tools**: Capture tool output in temp files, validate before use
- [ ] **Function Returns**: Separate debug (stderr) from return values (stdout)
- [ ] **Testing**: Add unit tests that verify clean output without pollution

#### **⚡ Quick Fix Template**
When you discover output pollution:

```bash
# Before (polluted)
generate_config() {
  echo "Starting..."
  result=$(yq -r ".config" file.yml)
  echo "$result"
}

# After (clean)
generate_config() {
  exec 3>&1 1>&2
  echo "Starting..."
  local result=$(yq -r ".config" file.yml)
  exec 1>&3 3>&-
  echo "$result"
}
```

**Remember**: In shell scripting, especially with zsh, STDOUT pollution is a constant threat. Always isolate debug output from return values using proper file descriptor management.

### **Template Formatting Rules**

1. **Separate Docker Arguments**: Use `"--volume", "/path"` not `"--volume=/path"`
2. **JSON Validation**: Always pipe through `jq .` for final output
3. **Conditional Handling**: Use `{%- if condition -%}` for clean whitespace control
4. **Environment Variables**: Reference as `{{ server.env_file }}` in templates

### **Functionality Restoration from Git History**

When integration tests fail due to missing functionality, **ALWAYS restore from git history rather than reimplementing**:

#### **🔍 Investigation Protocol**
```bash
# 1. Find relevant commits
git log --oneline --grep="setup\|inspect\|test" -10

# 2. Check function existence in recent history
git show HEAD~5:mcp_manager.sh | grep -A 50 "function_name()"

# 3. Extract complete function implementation
git show HEAD~5:mcp_manager.sh | grep -A 200 "setup_mcp_server() {" | head -100
```

#### **✅ Restoration Best Practices**
- **Extract complete functions** - don't modify during extraction
- **Preserve original behavior** - maintain exact functionality
- **Test immediately** after restoration to verify compatibility
- **Check dependencies** - ensure all called functions are also restored

#### **🚨 Integration Test Failure Pattern**
If integration tests fail with "command not found" or "unknown command":
1. **Check git history** for missing command implementation
2. **Restore complete function set** (main function + all helpers)
3. **Verify command dispatch** in main() case statement
4. **Test with actual usage** before running full test suite

**Example Restoration:**
```bash
# Found missing setup functionality
git show HEAD~5:mcp_manager.sh | grep -A 200 "setup_mcp_server" > /tmp/setup_funcs.sh
# Review, then integrate into current mcp_manager.sh
```

### Test-Driven Development (TDD) Requirements

- **NEVER commit with failing tests** - all tests must pass
- **ALWAYS write tests first** for new features (Red-Green-Refactor)
- **ALWAYS add regression tests** for bugs before fixing them
- **Run full test suite** before any commit: `shellspec spec/`
- **Restore from git history** when integration tests fail due to missing functionality

### **Shell Completion System**

The MCP Manager has comprehensive zsh completion support managed by the setup system:

#### **✅ Verification Commands**
```bash
# Check completion installation
ls -la "${ZDOTDIR:-$HOME}/.zsh/completions/" | grep mcp

# Test completion functionality (in new zsh session)
./mcp_manager.sh <TAB><TAB>  # Should show all commands
./mcp_manager.sh setup <TAB><TAB>  # Should show server IDs
./mcp_manager.sh inspect <TAB><TAB>  # Should show flags and server IDs
```

#### **🔧 Setup Integration**
- **Installation**: Handled by `setup.sh` in `generate_completion_files()`
- **Verification**: Checked by `verify_setup.sh`
- **Location**: `support/completions/_mcp_manager` → `~/.zsh/completions/_mcp_manager`
- **Coverage**: All commands, server IDs, inspect flags, parse keys

#### **🚨 Completion Update Protocol**
When adding new commands or flags:
1. **Update completion file**: Modify `support/completions/_mcp_manager`
2. **Test locally**: Source completion and test with `<TAB>`
3. **Verify in tests**: Ensure `verify_setup.sh` validates new completions

### **🔍 MCP Server Troubleshooting**

When MCP servers fail to work in Claude Desktop, follow this systematic debugging approach:

#### **📋 Log File Analysis**
**Primary Investigation Tool**: Claude Desktop maintains detailed logs for each MCP server:

```bash
# Check MCP server logs (most important debugging tool)
~/Library/Logs/Claude/mcp-server-<server-name>.log

# Examples of common failing servers:
~/Library/Logs/Claude/mcp-server-rails.log
~/Library/Logs/Claude/mcp-server-memory-service.log

# View recent log entries
tail -f ~/Library/Logs/Claude/mcp-server-rails.log
tail -50 ~/Library/Logs/Claude/mcp-server-memory-service.log
```

#### **🔍 Configuration Comparison**
**Golden Source**: Compare current configs with last known working versions:

```bash
# Last known good configurations
~/.mcp_backups/last_working/

# Compare current vs working
diff ~/.cursor/mcp.json ~/.mcp_backups/last_working/cursor_mcp.json
diff "~/Library/Application Support/Claude/claude_desktop_config.json" \
     "~/.mcp_backups/last_working/claude_desktop_config.json"

# Focus on specific failing servers
jq '.mcpServers.rails' ~/.cursor/mcp.json
jq '.mcpServers.rails' ~/.mcp_backups/last_working/cursor_mcp.json
```

#### **🚨 Common Failure Patterns**
Based on log analysis, look for these typical issues:

**Docker Connection Issues:**
```
Error: Cannot connect to the Docker daemon
Error: docker: command not found
Error: permission denied while trying to connect to Docker daemon
```

**Environment Variable Problems:**
```
Error: RAILS_PROJECT_DIR not set
Error: No such file or directory: /path/to/project
Error: environment variable expansion failed
```

**Image/Build Problems:**
```
Error: Unable to find image 'custom/rails:latest' locally
Error: pull access denied for custom/rails
Error: build failed with exit code 1
```

**MCP Protocol Issues:**
```
Error: Failed to initialize MCP server
Error: JSON-RPC communication failed
Error: Server did not respond to initialize request
```

#### **⚡ Systematic Debugging Workflow**

1. **📊 Check Server Status**
   ```bash
   ./mcp_manager.sh test rails
   ./mcp_manager.sh test memory-service
   ```

2. **📋 Analyze Logs**
   ```bash
   # Look for error patterns
   grep -i "error\|failed\|exception" ~/Library/Logs/Claude/mcp-server-rails.log

   # Check recent activity
   tail -20 ~/Library/Logs/Claude/mcp-server-rails.log
   ```

3. **🔧 Compare Configurations**
   ```bash
   # Extract current config for failing server
   jq '.mcpServers.rails' ~/.cursor/mcp.json > /tmp/current_rails.json

   # Extract working config
   jq '.mcpServers.rails' ~/.mcp_backups/last_working/cursor_mcp.json > /tmp/working_rails.json

   # Compare
   diff /tmp/current_rails.json /tmp/working_rails.json
   ```

4. **🛠️ Manual Docker Testing**
   ```bash
   # Test Docker command manually
   docker run --rm -i \
     --env-file /Users/gfichtner/MacbookSetup/.env \
     --volume "$HOME/rails-projects:/workspace" \
     custom/rails:latest
   ```

5. **📝 Registry Validation**
   ```bash
   # Check registry entry
   ./mcp_manager.sh parse rails source.image
   ./mcp_manager.sh parse rails server_type

   # Verify template exists
   ls -la support/templates/rails.tpl
   ```

#### **🔧 Common Fixes**

**Environment Variable Issues:**
```bash
# Check .env file has required variables
grep RAILS_PROJECT_DIR .env
grep MEMORY_SERVICE_DIR .env

# Verify paths exist and are accessible
ls -la "$RAILS_PROJECT_DIR"
ls -la "$MEMORY_SERVICE_DIR"
```

**Docker Image Issues:**
```bash
# Rebuild custom images
./mcp_manager.sh setup rails
./mcp_manager.sh setup memory-service

# Verify images exist
docker images | grep rails
docker images | grep memory-service
```

**Configuration Regeneration:**
```bash
# Regenerate clean configs
./mcp_manager.sh config-write

# Restart Claude Desktop to pick up changes
killall Claude
open -a Claude
```

#### **📊 Validation Commands**
After fixing issues:

```bash
# Test server health
./mcp_manager.sh test rails
./mcp_manager.sh test memory-service

# Check logs for successful startup
tail -10 ~/Library/Logs/Claude/mcp-server-rails.log
tail -10 ~/Library/Logs/Claude/mcp-server-memory-service.log

# Verify in Claude Desktop (manual test)
# - Open Claude Desktop
# - Check MCP server status in settings
# - Test server functionality with a simple query
```

#### **📋 Debugging Checklist**
For each failing MCP server:

- [ ] **Check log file** for specific error messages
- [ ] **Compare config** with last known working version
- [ ] **Verify Docker image** exists and is accessible
- [ ] **Test environment variables** are set and paths exist
- [ ] **Manual Docker test** of exact command from config
- [ ] **Registry validation** of server definition
- [ ] **Template validation** exists and renders correctly
- [ ] **Regenerate config** and restart Claude Desktop
- [ ] **Verify fix** with health test and log check

### **Critical Testing Guidelines**

#### **Test Artifact Management**
- **ALL test artifacts MUST be in `tmp/`** - Never create files in project root during tests
- **Use proper ShellSpec lifecycle**: `BeforeEach`/`AfterEach` for setup/cleanup
- **Complete isolation**: Each test must clean up completely to avoid affecting other tests

**Example Pattern:**
```bash
BeforeEach() {
  test_home="$PWD/tmp/test_home_$$"
  mkdir -p "$test_home"
  export TEST_HOME="$test_home"
}

AfterEach() {
  rm -rf "$test_home"
  unset TEST_HOME
}
```

#### **Unit vs Integration Test Separation**

**Unit Tests (`spec/unit/`):**
- **FAST execution** - Should complete in seconds
- **No external dependencies** - No Docker, no real files
- **Isolated functionality** - Test individual functions/commands
- **Mock/stub heavy** - Use temporary files in `tmp/` for testing
- **No .env dependency** - Should work without environment variables

**Integration Tests (`spec/integration/`):**
- **Real dependencies OK** - Can use Docker, actual file system
- **Environment dependent** - May require `.env` file values
- **End-to-end validation** - Test complete workflows
- **Real file generation** - Can write to actual config locations (in test environment)
- **Longer execution** - May take minutes for Docker operations

#### **Test Environment Setup Examples**

**Unit Test Pattern:**
```bash
# spec/unit/my_unit_spec.sh
Describe "Unit Test"
  BeforeEach() {
    test_dir="$PWD/tmp/unit_test_$$"
    mkdir -p "$test_dir"
  }

  AfterEach() {
    rm -rf "$test_dir"
  }

  It "tests isolated functionality"
    # Use test_dir for any temporary files
    echo "test data" > "$test_dir/test.json"
    When run some_function "$test_dir/test.json"
    The status should be success
  End
End
```

**Integration Test Pattern:**
```bash
# spec/integration/my_integration_spec.sh
Describe "Integration Test"
  BeforeEach() {
    test_home="$PWD/tmp/integration_test_$$"
    mkdir -p "$test_home/.cursor"
    mkdir -p "$test_home/Library/Application Support/Claude"
    export HOME="$test_home"
  }

  AfterEach() {
    rm -rf "$test_home"
    unset HOME
  }

  It "tests end-to-end functionality"
    # Can use real environment variables and files
    When run ./mcp_manager.sh config-write
    The status should be success
    The file "$test_home/.cursor/mcp.json" should be exist
  End
End
```

#### **Common Test Artifacts Patterns**

1. **Temporary JSON files**: `tmp/test_context_$$.json`
2. **Mock registry files**: `tmp/mock_registry_$$.yml`
3. **Test home directories**: `tmp/test_home_$$`
4. **Generated configs**: `tmp/test_config_$$.json`

#### **Test Cleanup Verification**
- Always use `$$` (process ID) in temp file names for uniqueness
- Verify cleanup with: `find tmp/ -name "*test*" -mtime -1`
- Global cleanup in CI: `rm -rf tmp/test_*`

### Commit Standards

Use Conventional Commits format:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation only
- `test:` Test additions/changes
- `refactor:` Code restructuring
- `chore:` Maintenance tasks

Subject line: 50 chars max, imperative mood, no period

**IMPORTANT**: Never add Co-Authored-By statements or any AI attribution to commit messages.

### Development Philosophy

**Minimal Complexity Principle**: Always seek the least amount of code and complexity to achieve the goal. This project values simplicity, comprehensive testing, and clear documentation over clever solutions.
