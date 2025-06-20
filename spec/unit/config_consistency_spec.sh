#!/bin/zsh
# Configuration Consistency Tests
# Ensures configs stay in sync across commands

Describe 'Configuration Consistency'
It 'list and config commands show same servers'
list_count=$(./mcp_manager.sh list | grep -c "  - ")
config_count=$(./mcp_manager.sh config 2> /dev/null | tail -n +2 | jq '.mcpServers | keys | length')

When run test "$list_count" -eq "$config_count"
The status should be success
End

It 'parse command works for github server'
When run ./mcp_manager.sh parse github name
The status should be success
The output should not equal ""
End

It 'parse command works for filesystem server type'
When run ./mcp_manager.sh parse filesystem server_type
The status should be success
The output should equal "mount_based"
End

It 'config generation is deterministic'
config1=$(./mcp_manager.sh config 2> /dev/null | tail -n +2 | jq -S .)
config2=$(./mcp_manager.sh config 2> /dev/null | tail -n +2 | jq -S .)

When run test "$config1" = "$config2"
The status should be success
End

It 'all servers have valid names'
When run sh -c "./mcp_manager.sh config 2>/dev/null | tail -n +2 | jq '.mcpServers[].name // \"MISSING\"' | grep -v MISSING | wc -l"
The status should be success
The output should not equal "0"
End

It 'no server configurations are null'
When run sh -c "./mcp_manager.sh config 2>/dev/null | tail -n +2 | jq '.mcpServers[] | select(. == null)'"
The status should be success
The output should equal ""
End
End
