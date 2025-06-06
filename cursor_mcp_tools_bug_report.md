# Cursor MCP Tools Accessibility Bug Report

**Date**: 2025-01-03
**Reporter**: GitHub User (gfichtner)
**Environment**: Cursor with MCP Integration
**Issue**: MCP Tools Shown as Available in UI But Not Accessible to AI Assistant

## 🔍 **Issue Summary**

Cursor's MCP settings dialog shows multiple MCP servers as connected and enabled with tools available, but the AI assistant cannot access most of these tools during conversations. There appears to be a disconnect between the UI state and the actual tool availability in the AI context.

## 📱 **Visual Evidence: MCP Servers Shown as Working**

![Cursor MCP Settings](cursor_mcp_settings_screenshot.png)

The screenshot shows the following MCP servers as connected and enabled:
- **circleci**: 11 tools enabled ✅ (Green indicator)
- **filesystem**: 11 tools enabled ✅ (Green indicator)
- **docker**: 4 tools enabled ✅ (Green indicator)
- **kubernetes**: 17 tools enabled ✅ (Green indicator)
- **figma**: 2 tools enabled ✅ (Green indicator)
- **heroku**: 37 tools enabled ✅ (Green indicator)
- **terraform**: 4 tools enabled ✅ (Green indicator)
- **terraform-cli-controller**: 10 tools enabled ✅ (Green indicator)

*All servers show green status indicators suggesting they are successfully connected.*

## 🛠️ **Technical Investigation**

### **Tools Actually Available to AI Assistant**

When I query my available tools programmatically, I can access:

```bash
# Available MCP tool prefixes found:
- mcp_github_*           # GitHub MCP server tools (working)
- mcp_circleci_*         # CircleCI MCP server tools (working)
- mcp_filesystem_*       # Filesystem MCP server tools (working)
- mcp_docker_*           # Docker MCP server tools (working)
- mcp_kubernetes_*       # Kubernetes MCP server tools (working)
```

### **Tools NOT Available Despite UI Showing Them**

Despite the UI showing these as connected with tools enabled:
- ❌ **terraform**: No `mcp_terraform_*` tools accessible
- ❌ **terraform-cli-controller**: No terraform CLI controller tools accessible
- ❌ **figma**: No `mcp_figma_*` tools accessible
- ❌ **heroku**: No `mcp_heroku_*` tools accessible

### **Technical API Calls Made**

I attempted to verify tool availability using these API calls:

1. **List Allowed Directories** (Filesystem MCP):
```bash
mcp_filesystem_list_allowed_directories(random_string="test")
# Result: Success - Shows "/project" as allowed directory
```

2. **Test Directory Access** (trying to access terraform project):
```bash
mcp_filesystem_list_directory(path="/Users/gfichtner/terraform-projects/default")
# Result: "Error: Access denied - path outside allowed directories"
```

3. **Tool Enumeration**: Examined available function names in my tool set
   - Found mcp_github_*, mcp_circleci_*, mcp_filesystem_*, mcp_docker_*, mcp_kubernetes_*
   - Missing: mcp_terraform_*, mcp_figma_*, mcp_heroku_*, and terraform-cli-controller tools

## 🔧 **Configuration Context**

### **MCP Configuration File Location**
```bash
~/.cursor/mcp.json
```

### **Expected vs Actual Behavior**

| MCP Server | UI Status | Tools Shown | AI Access | Expected |
|------------|-----------|-------------|-----------|-----------|
| circleci | ✅ Green | 11 tools | ✅ Working | ✅ Match |
| filesystem | ✅ Green | 11 tools | ✅ Working | ✅ Match |
| docker | ✅ Green | 4 tools | ✅ Working | ✅ Match |
| kubernetes | ✅ Green | 17 tools | ✅ Working | ✅ Match |
| github | Not shown in screenshot | N/A | ✅ Working | ✅ Should work |
| figma | ✅ Green | 2 tools | ❌ **Not accessible** | ❌ **MISMATCH** |
| heroku | ✅ Green | 37 tools | ❌ **Not accessible** | ❌ **MISMATCH** |
| terraform | ✅ Green | 4 tools | ❌ **Not accessible** | ❌ **MISMATCH** |
| terraform-cli-controller | ✅ Green | 10 tools | ❌ **Not accessible** | ❌ **MISMATCH** |

## 🚨 **Bug Impact**

This creates a confusing user experience where:
1. **Users see servers as working** in the settings UI
2. **AI assistant cannot actually use** many of the tools
3. **No error messages** indicate the tools are unavailable
4. **Users expect functionality** that doesn't work in practice

## 🔄 **Steps to Reproduce**

1. Configure multiple MCP servers in `~/.cursor/mcp.json`
2. Verify all servers show green status in Cursor MCP settings
3. Start a conversation with the AI assistant
4. Ask AI to use tools from servers showing as "enabled"
5. Observe that some tools work (circleci, filesystem, docker, kubernetes) while others don't (figma, heroku, terraform, terraform-cli-controller)

## 💡 **Potential Root Causes**

1. **Different MCP Protocol Versions**: Some servers may use different protocol versions
2. **Authentication Issues**: Some servers might fail authentication silently
3. **Container/Environment Isolation**: AI assistant running in restricted environment
4. **Tool Registration**: Tools may be detected but not properly registered for AI use
5. **Async Loading**: Tools might be loading asynchronously and not ready when queried

## 🎯 **Expected Resolution**

1. **Consistent UI State**: MCP settings should accurately reflect actual tool availability
2. **Error Reporting**: Failed/unavailable tools should show error status in UI
3. **Debug Information**: Provide debugging tools to inspect MCP tool registration
4. **Documentation**: Clear guidance on troubleshooting MCP tool availability issues

## 📋 **System Information**

- **Platform**: macOS (darwin 24.5.0)
- **Cursor Version**: [User should add current version]
- **MCP Server Types**: Mix of registry-based and locally-built Docker containers
- **Configuration Method**: Generated via custom mcp_manager.sh script

## 🔗 **Additional Context**

This issue was discovered during testing of a comprehensive MCP server management system. The terraform-cli-controller specifically was configured and tested via command line tools, showing successful protocol handshake and tool availability, but remains inaccessible to the AI assistant despite showing as enabled in the UI.

---

**Cursor Development Team**: Please investigate the disconnect between MCP UI status indicators and actual tool availability in AI assistant contexts. This significantly impacts the user experience and reliability of the MCP integration feature.
