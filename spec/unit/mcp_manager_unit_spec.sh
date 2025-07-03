#!/bin/zsh
# Unit tests for mcp_manager.sh unified configuration architecture
# Tests the new single-source template-based configuration system

Describe 'Unified Configuration Generation'
It 'generates valid JSON with mcpServers structure'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
The stderr should include "=== MCP Client Configuration Preview ==="
The output should include '"mcpServers"'
The output should include '"command": "docker"'
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'generates identical JSON for repeated calls'
# Test architectural guarantee of deterministic output
run1=$(zsh "$PWD/mcp_manager.sh" config 2> /dev/null)
run2=$(zsh "$PWD/mcp_manager.sh" config 2> /dev/null)
When run test "$run1" = "$run2"
The status should be success
End

It 'includes all expected core servers'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
The output should include '"github"'
The output should include '"filesystem"'
The output should include '"docker"'
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'produces clean JSON output without debug contamination'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Debug info should be in header, not JSON
The stderr should include "=== MCP Client Configuration Preview ==="
The output should not include "server_type="
The output should not include "image="
The stderr should include "[INFO]"
End
End

Describe 'Template System Integration'
It 'checks if jinja2 is available'
When run bash -c 'command -v jinja2'
The status should be success
The output should include "jinja2"
End

It 'validates mcp_config template exists'
When run test -f support/templates/mcp_config.tpl
The status should be success
End

It 'validates github template exists'
When run test -f support/templates/github.tpl
The status should be success
End

It 'validates filesystem template exists'
When run test -f support/templates/filesystem.tpl
The status should be success
End

It 'processes server-specific templates correctly'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Verify standard docker command structure
The output should include '"command": "docker"'
The output should include '"args"'
The output should include '"run"'
The output should include '"--rm"'
The output should include '"-i"'
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'handles server entrypoints and cmd args correctly'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Figma should have entrypoint and cmd args
The output should include '"figma"'
The output should include '"--entrypoint"'
The output should include '"node"'
The output should include '"dist/cli.js"'
The output should include '"--stdio"'
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'includes terraform-cli-controller mcp command'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
The output should include '"terraform-cli-controller"'
The output should include '"mcp"'
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End
End

Describe 'Server Type Specific Configuration'
It 'configures api_based servers correctly'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# GitHub (api_based) should have env-file
The output should include '"github"'
The output should include '"--env-file"'
The output should include '"mcp/github-mcp-server:latest"'
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'configures mount_based servers with volumes'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Filesystem should have volume mounts
The output should include '"filesystem"'
The output should include '"--volume"'
The output should include '"/projects/MacbookSetup"'
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'configures privileged servers with special access'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Docker server should have docker socket mount
The output should include '"docker"'
The output should include '/var/run/docker.sock'
# Terraform-cli-controller should have network host
The output should include '"terraform-cli-controller"'
The output should include '"--network"'
The output should include '"host"'
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End
End

Describe 'JSON Formatting Quality'
It 'generates properly formatted Docker arguments'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Volume arguments should be separate, not concatenated
The output should include '"--volume"'
The output should not include '"--volume='
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'includes env-file references for all servers'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# All servers should reference .env file
The output should include '"--env-file"'
The output should include '"/Users/gfichtner/MacbookSetup/.env"'
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'expands environment variables correctly'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Environment variables should be expanded to absolute paths
The output should not include '$HOME'
The output should not include '$KUBECONFIG_HOST'
The output should include '/Users/'
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End
End

Describe 'Individual Server Parsing'
It 'parses server metadata correctly'
When run zsh "$PWD/mcp_manager.sh" parse github name
The status should be success
The output should include "GitHub MCP Server"
End

It 'parses github server type correctly'
When run zsh "$PWD/mcp_manager.sh" parse github server_type
The status should be success
The output should include "api_based"
End

It 'parses filesystem server type correctly'
When run zsh "$PWD/mcp_manager.sh" parse filesystem server_type
The status should be success
The output should include "mount_based"
End

It 'parses docker server type correctly'
When run zsh "$PWD/mcp_manager.sh" parse docker server_type
The status should be success
The output should include "privileged"
End

It 'parses Docker image sources correctly'
When run zsh "$PWD/mcp_manager.sh" parse github source.image
The status should be success
The output should include "mcp/github-mcp-server:latest"
End

It 'handles filesystem directory parsing correctly'
# Test with actual .env configuration
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Should include filesystem server with volume mounts
The output should include '"filesystem"'
The output should include '"--volume"'
The output should include '"/projects/'
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End
End

Describe 'Error Handling and Dependencies'
It 'validates registry file exists'
When run test -f mcp_server_registry.yml
The status should be success
End

It 'handles missing jinja2 gracefully'
# This test would require temporarily hiding jinja2 - skip for now
Skip "Would require complex test setup to hide jinja2"
End

It 'provides meaningful error for invalid commands'
When run zsh "$PWD/mcp_manager.sh" invalid-command
The status should not be success
The stderr should include "Usage:"
End
End
