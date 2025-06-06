# MCP Manager Testing Architecture

## 🎯 **Core Testing Philosophy**

Based on extensive debugging sessions (e.g., terraform-cli-controller), this project needs **comprehensive unit and integration testing** to quickly identify root causes and prevent architectural confusion.

## 🏗️ **Architecture Components (Hidden Complexity Discovered)**

### **Configuration Generation Dual-Function System**
```
1. Preview Functions (generate_*_config)
   ├── generate_cursor_config()    # Shows preview in terminal
   └── generate_claude_config()    # Shows preview in terminal

2. Write Functions (write_*_config)
   ├── write_cursor_config()       # Actually writes ~/.cursor/mcp.json
   └── write_claude_config()       # Actually writes Claude config
```

**❌ CRITICAL ISSUE**: These functions have **DIFFERENT CODE PATHS** and **DIFFERENT SERVER TYPE HANDLING**

### **Server Type Classification System**
```
api_based       → GitHub, CircleCI, Figma (--env-file approach)
mount_based     → Filesystem (Docker mount approach)
privileged      → Docker, Kubernetes, Terraform-CLI (volumes + networks)
standalone      → Inspector, Terraform Registry (no dependencies)
```

## 🧪 **Required Unit Tests (Missing)**

### **1. Configuration Generation Function Tests**
```bash
# spec/config_generation_spec.sh
Describe 'Configuration Generation Functions'
  Describe 'write_cursor_config vs generate_cursor_config consistency'
    It 'should produce identical args arrays for same server'
      # Test that both functions generate same Docker args for each server type
    End

    It 'should handle cmd_args consistently across both functions'
      # Specific test for terraform-cli-controller cmd: ["mcp"] handling
    End
  End

  Describe 'Server type handling consistency'
    It 'should handle privileged servers identically in preview and write functions'
    It 'should handle api_based servers identically in preview and write functions'
    It 'should handle mount_based servers identically in preview and write functions'
    It 'should handle standalone servers identically in preview and write functions'
  End
End
```

### **2. Individual Function Unit Tests**
```bash
# spec/function_unit_spec.sh
Describe 'Helper Function Unit Tests'
  Describe 'get_server_cmd function'
    It 'should parse JSON arrays correctly'
    It 'should return "mcp" for terraform-cli-controller'
    It 'should return null for servers without cmd field'
  End

  Describe 'get_server_type function'
    It 'should return correct type for each server'
    # Test every server in registry
  End

  Describe 'Docker args construction'
    It 'should include cmd_args when present for privileged servers'
    It 'should handle entrypoint overrides correctly'
    It 'should construct volume mounts properly'
  End
End
```

### **3. Integration Path Tests**
```bash
# spec/integration_paths_spec.sh
Describe 'Code Path Integration Tests'
  Describe 'config-write command end-to-end'
    It 'should call write_cursor_config not generate_cursor_config'
    It 'should produce valid JSON configuration'
    It 'should include all expected servers'
  End

  Describe 'Server-specific integration'
    It 'terraform-cli-controller should have mcp command in final config'
    It 'kubernetes should have correct entrypoint override'
    It 'filesystem should have correct mount configuration'
  End
End
```

## 📋 **Architecture Documentation (Missing)**

### **System Design Documentation**
```bash
# docs/ARCHITECTURE.md sections needed:
1. Configuration Generation Pipeline
2. Server Type Classification System
3. Function Responsibility Matrix
4. Data Flow Diagrams
5. Error Handling Patterns
6. Testing Strategy per Component
```

### **Function Responsibility Matrix**
| Function | Purpose | Used By | Server Types | Output |
|----------|---------|---------|--------------|--------|
| `generate_cursor_config()` | Preview display | `config` command | All | Terminal output |
| `write_cursor_config()` | Actual file writing | `config-write` command | All | JSON file |
| `get_server_cmd()` | Parse cmd arrays | Both config functions | All | String/array |
| `get_server_type()` | Server classification | Both config functions | All | Type string |

## 🔍 **Debug Visibility Improvements**

### **Debug Mode Enhancement**
```bash
# Add debug mode to see code path execution
./mcp_manager.sh config-write --debug terraform-cli-controller

# Should show:
# DEBUG: Using write_cursor_config() function
# DEBUG: Processing terraform-cli-controller as privileged server
# DEBUG: get_server_cmd returned: 'mcp'
# DEBUG: cmd_args conditional: true (cmd_args='mcp')
# DEBUG: Final args: [..., "local/terraform-cli-controller:latest", "mcp"]
```

### **Configuration Validation Tests**
```bash
# Add post-generation validation
validate_generated_config() {
  local config_file="$1"
  local server_id="$2"

  # Validate JSON structure
  jq empty "$config_file" || { echo "Invalid JSON"; return 1; }

  # Validate server-specific expectations
  case "$server_id" in
    "terraform-cli-controller")
      jq '.mcpServers."terraform-cli-controller".args | .[-1]' "$config_file" | grep -q "mcp" || {
        echo "ERROR: terraform-cli-controller missing 'mcp' command"
        return 1
      }
      ;;
  esac
}
```

## 🚀 **Implementation Priority**

### **Phase 1: Immediate (This Session)**
1. ✅ Fix terraform-cli-controller configuration
2. ✅ Document the dual-function architecture discovery
3. ✅ Add architecture documentation file

### **Phase 2: Core Testing (Next)**
1. Add unit tests for `get_server_cmd()` function
2. Add configuration generation consistency tests
3. Add end-to-end integration tests for each server type
4. Add debug mode for configuration generation

### **Phase 3: Comprehensive (Future)**
1. Add visual documentation (diagrams) of system architecture
2. Add performance tests for configuration generation
3. Add regression tests for all discovered edge cases
4. Add automated architecture validation

## 📖 **Lessons Learned**

### **Root Cause Analysis Pattern**
This debugging session took many iterations because:
1. **Hidden complexity** (dual functions)
2. **Inconsistent implementations** between functions
3. **Poor visibility** into code path execution
4. **Missing unit tests** for individual components

### **Prevention Strategy**
- **Test individual functions** before integration testing
- **Document system architecture** explicitly
- **Add debug output** to show code path execution
- **Validate consistency** between related functions
- **Use TDD** for new features to prevent architectural drift

---

**Philosophy**: *Complex systems require comprehensive testing at multiple levels. Debugging sessions are learning opportunities to improve architecture and testing.*
