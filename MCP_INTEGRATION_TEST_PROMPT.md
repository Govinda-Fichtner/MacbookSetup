# MCP Integration Test Prompt

**Copy and paste this entire prompt after restarting Cursor to test MCP server integration:**

---

## 🔬 MCP Integration Testing Session

### **Context**
You are Claude running in Cursor with MCP (Model Context Protocol) integration enabled. We've configured multiple MCP servers for this MacbookSetup project and need to validate that you can actually access and use them.

### **Project Background**
This is a MacbookSetup project with an `mcp_manager.sh` script that configures MCP servers including:
- **GitHub MCP Server** (api_based): Access GitHub repositories and data
- **CircleCI MCP Server** (api_based): Access CI/CD pipelines and builds
- **Filesystem MCP Server** (mount_based): Access local file system
- **Docker MCP Server** (privileged): Manage Docker containers and images
- **Kubernetes MCP Server** (privileged): Manage Kubernetes clusters and resources
- **Inspector MCP Server** (standalone): Debug and inspect MCP communications

### **Test Protocol**

#### **Phase 1: Tool Discovery**
Please answer these questions:
1. **What MCP tools do you currently have available?** List all tools and which servers they come from.
2. **Can you see any MCP servers connected?** If so, which ones?
3. **Are there any connection errors or warnings?**

#### **Phase 2: Server-Specific Testing**

For each available server, please test:

**GitHub MCP Server** (if available):
- Can you list repositories in my GitHub account?
- Can you get information about this MacbookSetup repository?
- Can you read any specific files from GitHub?

**CircleCI MCP Server** (if available):
- Can you show my CircleCI projects?
- Can you get build information or pipeline status?

**Filesystem MCP Server** (if available):
- Can you list files in the MacbookSetup directory?
- Can you read the contents of `README.md`?
- Can you access the `mcp_server_registry.yml` file?

**Docker MCP Server** (if available):
- Can you list Docker containers currently running?
- Can you list Docker images available on the system?
- Can you get Docker system information?

**Kubernetes MCP Server** (if available):
- Can you list Kubernetes namespaces?
- Can you get information about Kubernetes nodes?
- Can you list any pods or services?

**Inspector MCP Server** (if available):
- Can you use any MCP inspector or debugging tools?
- Can you inspect the MCP protocol communications?

#### **Phase 3: Advanced Testing**

If basic tests work, please try:
1. **Cross-server operations**: Use data from one server to inform operations on another
2. **Error handling**: Try operations that should fail gracefully (like accessing non-existent resources)
3. **Authentication validation**: Verify that authenticated operations work with real credentials

### **Expected Results Documentation**

Please provide results in this format:

## MCP Integration Test Results

**Date**: [Current Date]
**Cursor Session**: Fresh restart with MCP integration
**Environment**: macOS (darwin 24.5.0)

### **Tool Discovery Results**:
- **Total MCP tools available**: [number]
- **Connected servers**: [list]
- **Connection errors**: [any issues]

### **Individual Server Test Results**:
- [ ] **GitHub MCP Server**: Tools available ✅/❌ | Authentication ✅/❌ | Data retrieval ✅/❌
  - Specific test: [describe what you tried and result]
- [ ] **CircleCI MCP Server**: Tools available ✅/❌ | Authentication ✅/❌ | Data retrieval ✅/❌
  - Specific test: [describe what you tried and result]
- [ ] **Filesystem MCP Server**: Tools available ✅/❌ | Mount access ✅/❌ | File operations ✅/❌
  - Specific test: [describe what you tried and result]
- [ ] **Docker MCP Server**: Tools available ✅/❌ | Socket access ✅/❌ | Container operations ✅/❌
  - Specific test: [describe what you tried and result]
- [ ] **Kubernetes MCP Server**: Tools available ✅/❌ | Cluster access ✅/❌ | Resource operations ✅/❌
  - Specific test: [describe what you tried and result]
- [ ] **Inspector MCP Server**: Tools available ✅/❌ | Protocol access ✅/❌ | Debug operations ✅/❌
  - Specific test: [describe what you tried and result]

### **Notes**:
[Any issues encountered, interesting findings, or observations about the MCP integration]

### **Conclusion**:
✅ **PASSED**: [List what worked] - MCP integration successful
❌ **FAILED**: [List issues] - requires fixes
⚠️ **PARTIAL**: [List mixed results] - some servers working, others need attention

---

**Additional Instructions**:
- Be thorough in your testing
- Note any error messages exactly
- Try to distinguish between "server not available" vs "authentication failure" vs "permission denied"
- Document both successes and failures clearly
- If you can't access certain servers, try to determine why (missing tokens, Docker not running, etc.)

**This test validates our entire MCP server configuration pipeline from registry → configuration generation → Docker deployment → AI integration.**
