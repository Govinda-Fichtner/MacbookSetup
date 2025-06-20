#!/bin/zsh
# Registry Schema Validation Tests
# Ensures registry entries are well-formed and consistent

Describe 'Registry Schema Validation'
It 'validates GitHub server has required fields'
When run ./mcp_manager.sh parse github name
The status should be success
The output should not equal ""
The output should not equal "null"
End

It 'validates filesystem server has correct type'
When run ./mcp_manager.sh parse filesystem server_type
The status should be success
The output should include "mount_based"
End

It 'validates memory-service server has correct type'
When run ./mcp_manager.sh parse memory-service server_type
The status should be success
The output should include "mount_based"
End

It 'validates GitHub server type is api_based'
When run ./mcp_manager.sh parse github server_type
The status should be success
The output should equal "api_based"
End

It 'validates Docker server type is privileged'
When run ./mcp_manager.sh parse docker server_type
The status should be success
The output should equal "privileged"
End

It 'validates GitHub source type is registry'
When run ./mcp_manager.sh parse github source.type
The status should be success
The output should equal "registry"
End

It 'validates memory-service source type is build'
When run ./mcp_manager.sh parse memory-service source.type
The status should be success
The output should equal "build"
End

It 'validates GitHub server has environment variables'
When run ./mcp_manager.sh parse github environment_variables
The status should be success
The output should not equal "null"
The output should include "GITHUB_PERSONAL_ACCESS_TOKEN"
End

It 'validates GitHub server name is descriptive'
When run ./mcp_manager.sh parse github name
The status should be success
The output should include "GitHub"
End

It 'validates filesystem server name is descriptive'
When run ./mcp_manager.sh parse filesystem name
The status should be success
The output should include "Filesystem"
End

It 'validates GitHub Docker image follows convention'
When run ./mcp_manager.sh parse github source.image
The status should be success
The output should include ":"
End

It 'validates filesystem Docker image follows convention'
When run ./mcp_manager.sh parse filesystem source.image
The status should be success
The output should include ":"
End

It 'validates memory-service has Dockerfile'
When run test -f "support/docker/mcp-server-memory-service/Dockerfile"
The status should be success
End

It 'validates registry file is valid YAML'
When run yq -r '.servers | keys | length' mcp_server_registry.yml
The status should be success
The output should not equal ""
End
End
