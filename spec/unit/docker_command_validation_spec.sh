#!/bin/zsh
# Docker Command Validation Tests
# Ensures generated Docker commands are properly formatted

Describe 'Docker Command Validation'
It 'generates valid JSON configuration'
When run sh -c "./mcp_manager.sh config 2>/dev/null | tail -n +2 | jq empty"
The status should be success
End

It 'validates all servers have docker command'
When run sh -c "./mcp_manager.sh config 2>/dev/null | tail -n +2 | jq '.mcpServers[].command'"
The status should be success
The output should include "docker"
End

It 'validates all servers have args array'
When run sh -c "./mcp_manager.sh config 2>/dev/null | tail -n +2 | jq '.mcpServers[].args | type'"
The status should be success
The output should include "array"
End

It 'validates env-file arguments are properly formatted'
When run sh -c "./mcp_manager.sh config 2>/dev/null | tail -n +2 | jq '.mcpServers.github.args[]' | grep env-file"
The status should be success
The output should include "--env-file"
End

It 'validates filesystem server has volume mounts'
When run sh -c "./mcp_manager.sh config 2>/dev/null | tail -n +2 | jq '.mcpServers.filesystem.args[]' | grep volume"
The status should be success
The output should include "--volume"
End

It 'validates privileged servers have appropriate flags'
When run sh -c "./mcp_manager.sh config 2>/dev/null | tail -n +2 | jq '.mcpServers.docker.args | join(\" \")'"
The status should be success
The output should include "/var/run/docker.sock"
End

It 'validates kubernetes server has network host'
When run sh -c "./mcp_manager.sh config 2>/dev/null | tail -n +2 | jq '.mcpServers.kubernetes.args[]' | grep network"
The status should be success
The output should include "--network"
End

It 'validates all Docker arguments are separate array elements'
# No concatenated arguments like "--volume=/path"
When run sh -c "./mcp_manager.sh config 2>/dev/null | tail -n +2 | jq '.mcpServers[].args[]' | grep -E '^\"--[a-z-]+='"
The status should not be success
End
End
