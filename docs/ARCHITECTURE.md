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
