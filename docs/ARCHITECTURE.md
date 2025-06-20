# MCP Manager Architecture Documentation

## 🏗️ **System Overview**

The MCP Manager is a shell-based tool for configuring and managing Model Context Protocol (MCP) servers. This document details the system architecture discovered during extensive debugging sessions.

## 🔄 **Configuration Generation Pipeline**

### **Dual-Function Architecture (CRITICAL)**

**⚠️ DISCOVERED COMPLEXITY**: The system has TWO separate configuration generation pipelines with **DIFFERENT CODE PATHS**:

```
┌─────────────────────────────────────────────────────────────┐
│                    Configuration Generation                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  🖥️  PREVIEW MODE (./mcp_manager.sh config)                │
│  ├── generate_cursor_config()   → Terminal output only     │
│  └── generate_claude_config()   → Terminal output only     │
│                                                             │
│  💾 WRITE MODE (./mcp_manager.sh config-write)             │
│  ├── write_cursor_config()      → ~/.cursor/mcp.json       │
│  └── write_claude_config()      → Claude config file       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**❌ CRITICAL ISSUE**: These functions have **INCONSISTENT IMPLEMENTATIONS**
- Different server type handling logic
- Different parameter processing
- Different error handling patterns

### **Command Flow**

```bash
./mcp_manager.sh config-write
    ↓
main() function
    ↓
generate_client_configs() with mode="write"
    ↓
write_cursor_config() + write_claude_config()
    ↓
Actual configuration files written
```

## 🎯 **Server Type Classification System**

### **Four Server Types**

| Type | Examples | Configuration Strategy | Special Handling |
|------|----------|----------------------|------------------|
| `api_based` | GitHub, CircleCI, Figma | `--env-file` for tokens | Token validation |
| `mount_based` | Filesystem | Docker mount directories | Path resolution |
| `privileged` | Docker, Kubernetes, Terraform-CLI | Volumes + networks + special access | System integration |
| `standalone` | Inspector, Terraform Registry | No external dependencies | Self-contained |

### **Server Type Detection**

```bash
get_server_type() {
  local server_id="$1"
  parse_server_config "$server_id" "server_type"
}
```

**Source**: `mcp_server_registry.yml` → `server_type` field

## 🔧 **Configuration Generation Logic**

### **Privileged Servers (terraform-cli-controller case)**

```bash
# In write_cursor_config() function:
case "$server_type" in
  "privileged")
    # Get configuration components
    volumes=$(get_server_volumes "$server_id")
    networks=$(get_server_networks "$server_id")
    entrypoint=$(get_server_entrypoint "$server_id")
    cmd_args=$(get_server_cmd "$server_id")

    # Special case handling
    if [[ "$server_id" == "terraform-cli-controller" ]]; then
      cmd_args="mcp"  # Override registry value
    fi

    # Build Docker args string
    docker_args="run, --rm, -i, --env-file, ..."

    # Add volumes
    for volume in $volumes; do
      docker_args+="-v, $volume,"
    done

    # Add networks
    for network in $networks; do
      docker_args+="--network, $network,"
    done

    # Add image and cmd
    if [[ -n "$cmd_args" && "$cmd_args" != "null" ]]; then
      docker_args+="$image, $cmd_args"
    else
      docker_args+="$image"
    fi
    ;;
esac
```

### **Configuration Data Sources**

```
┌─────────────────────────────────────────────────────────────┐
│                    Data Flow Sources                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  📋 Registry (mcp_server_registry.yml)                     │
│  ├── Server metadata (name, description, category)         │
│  ├── Docker configuration (image, entrypoint, cmd)         │
│  ├── Server type classification                            │
│  ├── Environment variables                                 │
│  └── Privileged configuration (volumes, networks)          │
│                                                             │
│  🔧 Environment (.env file)                                │
│  ├── API tokens and credentials                            │
│  ├── Directory paths for mount-based servers               │
│  └── Configuration overrides                               │
│                                                             │
│  🏠 User Paths                                             │
│  ├── ~/.cursor/mcp.json (Cursor configuration)             │
│  ├── ~/Library/Application Support/Claude/... (Claude)     │
│  └── Project .env file (environment variables)             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 🧩 **Function Responsibility Matrix**

| Function | Purpose | Input | Output | Used By |
|----------|---------|-------|--------|---------|
| `generate_client_configs()` | Main orchestrator | target_client, write_mode | Side effects | CLI commands |
| `get_working_servers()` | Filter healthy servers | None | Server list | Config generation |
| `get_server_type()` | Classify server | server_id | Server type | Config dispatching |
| `get_server_cmd()` | Parse cmd arrays | server_id | Command string | Docker args |
| `get_server_volumes()` | Parse volume mounts | server_id | Volume list | Privileged config |
| `get_server_networks()` | Parse networks | server_id | Network list | Privileged config |
| `write_cursor_config()` | Write Cursor JSON | server_ids[] | File written | Config writing |
| `write_claude_config()` | Write Claude JSON | server_ids[] | File written | Config writing |

## 🐛 **Known Issues & Debugging Patterns**

### **terraform-cli-controller Case Study**

**Problem**: `mcp` command not appearing in final configuration despite all logic appearing correct.

**Investigation Pattern**:
1. ✅ Registry parsing: `cmd: ["mcp"]` → parsed correctly
2. ✅ Server type detection: `privileged` → classified correctly
3. ✅ get_server_cmd(): returns `mcp` → working correctly
4. ✅ Special handling: `cmd_args="mcp"` → applied correctly
5. ✅ Conditional logic: `[[ -n "$cmd_args" && "$cmd_args" != "null" ]]` → passes correctly
6. ❌ **Final output**: Missing `mcp` command in JSON → **BUG LOCATION**

**Root Cause**: Code path not being executed despite all logic being correct.

**Debugging Techniques Used**:
- Unit testing individual functions
- Step-by-step logic verification
- JSON output inspection
- Debug output insertion
- Isolated function testing

### **Common Debugging Challenges**

1. **Hidden Complexity**: Dual-function architecture not documented
2. **Debug Output Filtering**: `filter_debug_output()` hides execution traces
3. **Inconsistent Implementations**: Preview vs write functions differ
4. **Complex Conditionals**: Multiple server types with different logic paths

## 📋 **Testing Strategy Requirements**

### **Unit Tests Needed**

```bash
# Individual function tests
test_get_server_cmd_parsing()
test_get_server_type_classification()
test_docker_args_construction()
test_privileged_server_handling()

# Integration tests
test_config_generation_consistency()
test_write_vs_preview_equivalence()
test_server_type_dispatch()

# End-to-end tests
test_actual_file_writing()
test_json_validity()
test_client_compatibility()
```

### **Architecture Validation Tests**

```bash
# Consistency checks
validate_dual_function_equivalence()
validate_server_type_coverage()
validate_registry_schema()
validate_configuration_completeness()
```

## 🔄 **Recommended Improvements**

### **1. Unified Configuration Architecture**

```bash
# Proposed: Single configuration generation with output mode parameter
generate_configuration() {
  local server_ids=("$@")
  local output_mode="$1"  # "json" | "terminal" | "file"

  # Single implementation for all server types
  for server_id in "${server_ids[@]}"; do
    local config=$(build_server_config "$server_id")

    case "$output_mode" in
      "json") echo "$config" ;;
      "terminal") format_for_display "$config" ;;
      "file") write_to_file "$config" "$server_id" ;;
    esac
  done
}
```

### **2. Enhanced Debug Capabilities**

```bash
# Debug mode flag
./mcp_manager.sh config-write --debug terraform-cli-controller

# Should show:
# DEBUG: Processing terraform-cli-controller
# DEBUG: Server type: privileged
# DEBUG: CMD args: mcp
# DEBUG: Volumes: [list]
# DEBUG: Networks: [list]
# DEBUG: Final args: [array]
```

### **3. Configuration Validation**

```bash
# Post-generation validation
validate_generated_config() {
  local config_file="$1"

  # JSON syntax validation
  jq empty "$config_file" || return 1

  # Server-specific validation
  for server_id in $(jq -r '.mcpServers | keys[]' "$config_file"); do
    validate_server_config "$server_id" "$config_file"
  done
}
```

## 📚 **Reference Documentation**

### **Key Files**
- `mcp_manager.sh` - Main script with dual-function architecture
- `mcp_server_registry.yml` - Server configuration database
- `docs/TESTING_ARCHITECTURE.md` - Testing strategy and requirements
- `.cursorrules` - Project-specific development guidelines

### **External Dependencies**
- Docker - Container runtime for MCP servers
- jq - JSON processing and validation
- yq - YAML parsing for registry
- zsh/bash - Shell execution environment

---

**🎯 Key Takeaway**: This system has more architectural complexity than initially apparent. The dual-function design creates maintenance challenges and debugging difficulties. Future improvements should focus on unifying the configuration generation pipeline and adding comprehensive testing at multiple levels.

## MCP Config Generation Architecture (Refactored - June 2025)

### ✅ **Architecture Success: Unified Single-Source Configuration**

After extensive refactoring, we successfully eliminated the **dual-function complexity** and achieved a clean, unified architecture:

### **New Unified Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                 UNIFIED CONFIG GENERATION                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  🔄 get_formatted_config_json()                           │
│  ├── Source .env file (with proper stderr redirect)       │
│  ├── generate_mcp_config_json() → Raw JSON                │
│  └── jq formatting → Clean formatted JSON                 │
│                                                             │
│  📺 ./mcp_manager.sh config (Preview)                     │
│  └── get_formatted_config_json() → stdout                 │
│                                                             │
│  💾 ./mcp_manager.sh config-write (Write)                 │
│  └── get_formatted_config_json() → files                  │
│      ├── ~/.cursor/mcp.json                              │
│      └── ~/Library/Application Support/Claude/...         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### **Key Refactoring Achievements**

1. **✅ Eliminated Code Duplication**
   - Single `get_formatted_config_json()` function used by both commands
   - Identical JSON output for both Claude Desktop and Cursor
   - No diverging code paths

2. **✅ Fixed Debug Output Leakage**
   - Proper stderr redirection with `exec 3>&1 1>&2`
   - Clean config preview without variable assignment output
   - Suppressed zsh debug noise

3. **✅ Unified Template System**
   - Jinja2 templates for all servers in `support/templates/`
   - Post-processing with `jq .` for clean formatting
   - One configuration source, two file destinations

4. **✅ Proper JSON Formatting**
   - Templates focus on logic, jq handles presentation
   - Consistent Docker argument formatting (`"--volume", "/path"`)
   - Professional JSON output matching industry standards

### **Template Architecture**

```
support/templates/
├── mcp_config.tpl              # Global wrapper template
├── github.tpl                  # Per-server templates
├── figma.tpl                   # (one per server type)
├── filesystem.tpl              # Mount-based servers
├── docker.tpl                  # Privileged servers
├── kubernetes.tpl              # with volumes/networks
└── terraform-cli-controller.tpl
```

### **Adding New MCP Servers: Step-by-Step Guide**

#### **1. Update Registry**
Add server entry to `mcp_server_registry.yml`:
```yaml
servers:
  my-new-server:
    name: "My New Server"
    server_type: "api_based"  # or mount_based, privileged, standalone
    source:
      type: registry  # or build
      image: "my-org/my-server:latest"
      entrypoint: "node"  # if needed
      cmd: ["dist/cli.js", "--stdio"]  # if needed
    environment_variables:
      - "MY_API_TOKEN"
```

#### **2. Create Template**
Create `support/templates/my-new-server.tpl`:
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

#### **3. Test Configuration**
```bash
# Test server registry parsing
./mcp_manager.sh parse my-new-server server_type

# Preview configuration
./mcp_manager.sh config | jq '.mcpServers."my-new-server"'

# Write and verify
./mcp_manager.sh config-write
cat ~/.cursor/mcp.json | jq '.mcpServers."my-new-server"'
```

### **Critical Pitfalls to Avoid**

#### **🚨 Debug Output Contamination**
```bash
# ❌ WRONG - causes variable assignments in output
cmd_args=$(yq -r ".servers.$server_id.source.cmd" "$MCP_REGISTRY_FILE")

# ✅ CORRECT - use temp files or proper stderr redirection
local cmd_temp_file=$(mktemp)
yq -o json ".servers.$server_id.source.cmd // null" "$MCP_REGISTRY_FILE" > "$cmd_temp_file"
cmd_args=$(cat "$cmd_temp_file")
rm -f "$cmd_temp_file"
```

#### **🚨 Template Formatting Issues**
```jinja2
{# ❌ WRONG - creates concatenated arguments #}
"--volume={{ volume }}"

{# ✅ CORRECT - separate arguments for Docker CLI #}
"--volume", "{{ volume }}"
```

#### **🚨 Environment Variable Expansion**
```bash
# ✅ CRITICAL - Source .env before config generation
if [[ -f ".env" ]]; then
  set -a  # Automatically export all variables
  source .env 2>/dev/null
  set +a  # Turn off auto-export
fi
```

#### **🚨 JSON Validation**
```bash
# ✅ ALWAYS validate generated JSON
if command -v jq > /dev/null 2>&1 && [[ -n "$raw_json" ]]; then
  formatted_json=$(echo "$raw_json" | jq .)  # This validates AND formats
else
  formatted_json="$raw_json"  # Fallback without validation
fi
```

### **Server Type Specific Templates**

| Server Type | Template Pattern | Special Handling |
|-------------|------------------|------------------|
| `api_based` | Basic docker run + env-file | Token validation via environment |
| `mount_based` | docker run + volumes | Directory path resolution |
| `privileged` | docker run + volumes + networks | System access, host networking |
| `standalone` | docker run only | Self-contained, no external deps |

### **Testing New Servers**

```bash
# Unit test the parsing
./mcp_manager.sh parse my-new-server name
./mcp_manager.sh parse my-new-server server_type
./mcp_manager.sh parse my-new-server source.image

# Integration test the configuration
./mcp_manager.sh config | jq '.mcpServers | keys | contains(["my-new-server"])'

# End-to-end test
./mcp_manager.sh config-write
./mcp_manager.sh test my-new-server  # If health testing is implemented
```

### **Configuration Quality Standards**

1. **JSON Validity**: All output must pass `jq .` validation
2. **Docker Compatibility**: Args must work with Docker CLI exactly as written
3. **Environment Expansion**: All `$VAR` references must resolve to absolute paths
4. **Formatting Consistency**: Use `jq .` post-processing for clean output
5. **Error Handling**: Graceful fallbacks for missing dependencies

### **Migration Complete: Legacy Architecture Removed**

The old dual-function architecture (`generate_cursor_config()` vs `write_cursor_config()`) has been completely eliminated. All configuration generation now flows through the unified `get_formatted_config_json()` function.

## **Complete Command Architecture**

The MCP Manager provides a comprehensive command interface for managing Docker-based MCP servers:

### **Command Structure**

```
mcp_manager.sh <command> [options] [arguments]

Commands:
├── config          → Generate configuration preview
├── config-write    → Write configuration to client files
├── list            → List configured servers with names
├── parse           → Extract configuration values from registry
├── setup           → Set up MCP servers (Docker pull/build)
├── test            → Health check MCP servers
├── inspect         → Debug and validate servers/configuration
└── help            → Show usage information
```

### **Setup Command Architecture**

The setup system provides full Docker lifecycle management:

```
Setup Operations:
├── setup_mcp_server() ← Main orchestrator
├── setup_registry_server() ← Docker registry operations
├── setup_build_server() ← Repository cloning and building
└── apply_docker_patches() ← Custom Dockerfile application
```

**Server Source Types:**
- **Registry**: Pull pre-built images from Docker registries
- **Build**: Clone repository, apply custom Dockerfiles, build locally

**Custom Dockerfile Support:**
- Heroku, CircleCI, Kubernetes, Docker, Rails servers have custom Dockerfiles
- Located in `support/docker/<server-name>/Dockerfile`
- Applied automatically during build process

### **Test Command Architecture**

Two-tier testing approach for comprehensive validation:

```
Test Operations:
├── test_mcp_server_health() ← Main health checker
├── test_mcp_basic_protocol() ← CI-friendly protocol validation
└── test_server_advanced_functionality() ← Real token testing
```

**Testing Modes:**
- **Basic Protocol**: JSON-RPC handshake validation (CI-compatible)
- **Advanced Testing**: Real Docker health checks with token validation
- **Environment Awareness**: Different behavior for CI vs local development

### **Inspect Command Architecture**

Debug and validation functionality with extensive flag support:

**Inspect Modes:**
- `inspect` → Overview of all configured servers
- `inspect <server>` → Detailed server inspection
- `inspect --validate-config` → JSON structure validation
- `inspect --ci-mode` → Containerless validation for CI
- `inspect --ui` → UI launcher (placeholder)
- `inspect --connectivity` → Connection testing (placeholder)

### **Shell Completion System**

**Implementation:**
- **Location**: `support/completions/_mcp_manager`
- **Installation**: Symlinked to `~/.zsh/completions/_mcp_manager`
- **Setup Integration**: Managed by `setup.sh` and verified by `verify_setup.sh`

**Coverage:**
- All commands and subcommands
- Server IDs from registry
- Inspect command flags
- Parse command configuration keys

### **Adding New Commands**

To add new commands while maintaining compatibility:

#### **1. Command Dispatcher**
Add to `main()` function in `mcp_manager.sh`:
```bash
case "$1" in
  # ... existing commands ...
  new-command)
    handle_new_command "$2" "$3" "$4"
    ;;
esac
```

#### **2. Function Implementation**
```bash
handle_new_command() {
  local arg1="$1"
  local arg2="$2"

  # Follow existing patterns:
  # - Use printf with color constants ($RED, $GREEN, $BLUE, $YELLOW, $NC)
  # - Handle CI environment with [[ "${CI:-false}" == "true" ]]
  # - Use parse_server_config() for registry data
  # - Clean up temporary files
}
```

#### **3. Help Documentation**
Update `show_help()` function with new command description.

#### **4. Shell Completion**
Add to `support/completions/_mcp_manager`:
```bash
_mcp_commands() {
  local commands
  commands=(
    # ... existing commands ...
    'new-command:Description of new command'
  )
}
```

#### **5. Testing**
- Add unit tests to `spec/unit/`
- Add integration tests to `spec/integration/`
- Ensure both CI and local environments are tested

### **Server Configuration Extension**

To add new MCP servers:

#### **1. Registry Configuration**
Add to `mcp_server_registry.yml`:
```yaml
servers:
  new-server:
    name: "New Server Name"
    server_type: "registry"  # or "build"
    source:
      type: registry  # or build
      image: "org/server:latest"
      # For build type:
      # repository: "https://github.com/org/repo.git"
      # build_context: "."
    environment_variables:
      - "NEW_SERVER_TOKEN"
```

#### **2. Template Creation**
Create `support/templates/new-server.tpl`:
```jinja2
"{{ server.id }}": {
  "command": "docker",
  "args": [
    "run", "--rm", "-i",
    "--env-file", "{{ server.env_file }}",
    "{{ server.image }}"
    {%- if server.cmd_args and server.cmd_args|length > 0 -%},
    {%- for arg in server.cmd_args -%}"{{ arg }}"{%- if not loop.last -%},{%- endif -%}{%- endfor -%}
    {%- endif -%}
  ]
}
```

#### **3. Custom Dockerfile (if needed)**
For build-type servers requiring custom Docker configuration:
```dockerfile
# support/docker/new-server/Dockerfile
FROM node:18-alpine
# Custom build steps...
```

#### **4. Completion Updates**
Server IDs are automatically discovered from the registry, so no completion updates needed.

### **Critical Compatibility Requirements**

#### **Environment Handling**
- Always check `[[ "${CI:-false}" == "true" ]]` for CI-specific behavior
- Use `command -v docker > /dev/null 2>&1` to check Docker availability
- Provide graceful fallbacks for missing dependencies

#### **Output Standards**
- Use established color coding: `$RED` (errors), `$GREEN` (success), `$BLUE` (info), `$YELLOW` (warnings)
- Follow tree-structure formatting: `├──`, `│   `, `└──`
- Suppress debug output appropriately (stderr redirection)

#### **Registry Integration**
- Use `parse_server_config()` for all registry data access
- Support both `registry` and `build` source types
- Handle `null` values from registry gracefully

#### **Testing Integration**
- All new functionality must have unit tests
- Integration tests should work in both CI and local environments
- Use `tmp/` for all test artifacts

### **See also**
- `mcp_manager.sh` (unified config generation + restored functionality)
- `support/templates/` (Jinja2 templates)
- `mcp_server_registry.yml` (server definitions)
- `CLAUDE.md` (development guidelines and restoration protocols)
