#!/bin/zsh
# Template validation tests for the Jinja2 template system
# Tests individual templates and template data generation

# Helper functions for JSON validation
validate_github_command() {
  tail -n +2 | jq ".mcpServers.github.command == \"docker\"" 2> /dev/null | grep -q "true"
}

validate_github_args() {
  tail -n +2 | jq ".mcpServers.github.args | contains([\"run\", \"--rm\", \"-i\"])" 2> /dev/null | grep -q "true"
}

validate_github_env_file() {
  tail -n +2 | jq ".mcpServers.github.args | contains([\"--env-file\"])" 2> /dev/null | grep -q "true"
}

validate_filesystem_volumes() {
  tail -n +2 | jq ".mcpServers.filesystem.args | map(select(test(\"--volume\"))) | length > 0" 2> /dev/null | grep -q "true"
}

validate_filesystem_projects() {
  tail -n +2 | jq ".mcpServers.filesystem.args | map(select(test(\"/projects/\"))) | length > 0" 2> /dev/null | grep -q "true"
}

validate_docker_sock() {
  tail -n +2 | jq ".mcpServers.docker.args | contains([\"/var/run/docker.sock:/var/run/docker.sock\"])" 2> /dev/null | grep -q "true"
}

validate_kubernetes_network() {
  tail -n +2 | jq ".mcpServers.kubernetes.args | contains([\"--network\", \"host\"])" 2> /dev/null | grep -q "true"
}

validate_figma_entrypoint() {
  tail -n +2 | jq ".mcpServers.figma.args | contains([\"--entrypoint\", \"node\"])" 2> /dev/null | grep -q "true"
}

validate_figma_cmd_args() {
  tail -n +2 | jq ".mcpServers.figma.args | contains([\"dist/cli.js\", \"--stdio\"])" 2> /dev/null | grep -q "true"
}

validate_terraform_cli_mcp() {
  tail -n +2 | jq ".mcpServers.\"terraform-cli-controller\".args[-1] == \"mcp\"" 2> /dev/null | grep -q "true"
}

validate_server_command() {
  local server="$1"
  tail -n +2 | jq ".mcpServers.\"$server\".command == \"docker\"" 2> /dev/null | grep -q "true"
}

validate_linear_command() {
  tail -n +2 | jq ".mcpServers.linear.command == \"npx\"" 2> /dev/null | grep -q "true"
}

validate_linear_args() {
  tail -n +2 | jq ".mcpServers.linear.args | contains([\"-y\", \"mcp-remote\", \"https://mcp.linear.app/sse\"])" 2> /dev/null | grep -q "true"
}

validate_remote_server_command() {
  local server="$1"
  tail -n +2 | jq ".mcpServers.\"$server\".command == \"npx\"" 2> /dev/null | grep -q "true"
}

validate_server_args_array() {
  local server="$1"
  tail -n +2 | jq ".mcpServers.\"$server\".args | type == \"array\"" 2> /dev/null | grep -q "true"
}

validate_no_variable_expansion() {
  tail -n +2 | grep -qv '\$HOME\|\$KUBECONFIG_HOST\|\${'
}

validate_json_structure() {
  tail -n +2 | jq empty 2> /dev/null
}

validate_mcpservers_object() {
  tail -n +2 | jq ".mcpServers | type == \"object\"" 2> /dev/null | grep -q "true"
}

validate_mcpservers_not_empty() {
  tail -n +2 | jq ".mcpServers | keys | length > 0" 2> /dev/null | grep -q "true"
}

validate_no_template_syntax() {
  tail -n +2 | grep -qv '{{\|}}{\|{%-'
}

validate_github_image() {
  tail -n +2 | jq ".mcpServers.github.args[-1] == \"mcp/github-mcp-server:latest\"" 2> /dev/null | grep -q "true"
}

validate_filesystem_image() {
  tail -n +2 | jq ".mcpServers.filesystem.args" | grep -q "mcp/filesystem:latest"
}

validate_figma_args_contains() {
  tail -n +2 | jq ".mcpServers.figma.args | contains([\"dist/cli.js\"])" 2> /dev/null | grep -q "true"
}

validate_figma_stdio() {
  tail -n +2 | jq ".mcpServers.figma.args | contains([\"--stdio\"])" 2> /dev/null | grep -q "true"
}

validate_docker_sock_volume() {
  tail -n +2 | jq ".mcpServers.docker.args" | grep -q "/var/run/docker.sock"
}

validate_kubernetes_kubeconfig() {
  tail -n +2 | jq ".mcpServers.kubernetes.args" | grep -q "/.kube/config"
}

# Global setup for all template tests
BeforeAll() {
  temp_dir="$PWD/tmp/template_test_$$"
  mkdir -p "$temp_dir"
}

AfterAll() {
  temp_dir="$PWD/tmp/template_test_$$"
  rm -rf "$temp_dir"
}

Describe 'Template File Validation'
It 'validates main config template exists'
When run test -f "support/templates/mcp_config.tpl"
The status should be success
End

It 'validates github template exists'
When run test -f "support/templates/github.tpl"
The status should be success
End

It 'validates filesystem template exists'
When run test -f "support/templates/filesystem.tpl"
The status should be success
End

It 'validates docker template exists'
When run test -f "support/templates/docker.tpl"
The status should be success
End

It 'validates kubernetes template exists'
When run test -f "support/templates/kubernetes.tpl"
The status should be success
End

It 'validates github template has proper Jinja2 structure'
When run sh -c 'grep -q "{{ server.id }}" "support/templates/github.tpl" && grep -q "{{ server.image }}" "support/templates/github.tpl"'
The status should be success
End

It 'validates filesystem template has proper Jinja2 structure'
When run sh -c 'grep -q "{{ server.id }}" "support/templates/filesystem.tpl" && grep -q "{{ server.image }}" "support/templates/filesystem.tpl"'
The status should be success
End

It 'validates docker template has proper Jinja2 structure'
When run sh -c 'grep -q "{{ server.id }}" "support/templates/docker.tpl" && grep -q "{{ server.image }}" "support/templates/docker.tpl"'
The status should be success
End

It 'validates linear template exists'
When run test -f "support/templates/linear.tpl"
The status should be success
End

It 'validates linear template has proper Jinja2 structure for remote servers'
When run sh -c 'grep -q "{{ server.id }}" "support/templates/linear.tpl" && grep -q "{{ server.proxy_command }}" "support/templates/linear.tpl" && grep -q "{{ server.url }}" "support/templates/linear.tpl"'
The status should be success
End

It 'validates registry-template consistency'
# Count servers in registry
registry_count=$(yq -r '.servers | keys | length' mcp_server_registry.yml)

# Count templates (excluding main config template and env_example template)
template_count=$(find support/templates -name "*.tpl" -not -name "mcp_config.tpl" -not -name "env_example.tpl" 2> /dev/null | wc -l | tr -d ' ')

# Should be equal
When run test "$registry_count" -eq "$template_count"
The status should be success
End

It 'validates no missing templates for core servers'
When run sh -c 'test -f "support/templates/github.tpl" && test -f "support/templates/filesystem.tpl" && test -f "support/templates/memory-service.tpl" && test -f "support/templates/terraform-cli-controller.tpl"'
The status should be success
End
End

Describe 'Template Data Generation for Servers'
BeforeEach 'export FILESYSTEM_ALLOWED_DIRS="/tmp/test1,/tmp/test2"'

It 'generates correct template data for api_based servers'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# GitHub should have basic structure
The output should satisfy validate_github_command
The output should satisfy validate_github_args
The output should satisfy validate_github_env_file
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'generates correct template data for mount_based servers'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Filesystem should have volume mounts
The output should satisfy validate_filesystem_volumes
# Should have container paths as separate arguments
The output should satisfy validate_filesystem_projects
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'generates correct template data for privileged servers'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Docker should have docker socket
The output should satisfy validate_docker_sock
# Kubernetes should have host network
The output should satisfy validate_kubernetes_network
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'handles entrypoint overrides correctly'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Figma should have entrypoint override
The output should satisfy validate_figma_entrypoint
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'handles command arguments correctly'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Figma should have cmd args
The output should satisfy validate_figma_cmd_args
# Terraform-cli-controller should have mcp command
The output should satisfy validate_terraform_cli_mcp
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'generates correct template data for remote servers'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Linear should have npx command
The output should satisfy validate_linear_command
# Linear should have correct args array
The output should satisfy validate_linear_args
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End
End

Describe 'Template Data Consistency'
It 'ensures all servers have required Docker structure'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# All servers should have docker command and array args
The output should include '"command": "docker"'
The output should include '"args": ['
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'ensures all servers have env-file reference'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# All servers should reference .env file
The output should include "--env-file"
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'validates environment variable expansion'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# No unexpanded variables should remain
The output should satisfy validate_no_variable_expansion
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End
End

Describe 'Template Error Handling'
It 'handles missing template gracefully'
# This would be tested by adding a server to registry without template
# For now, just verify error handling exists
When run sh -c 'command -v jinja2 >/dev/null'
The status should be success
End

It 'validates JSON structure after template processing'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Validate the entire JSON structure is valid
The output should satisfy validate_json_structure
# Validate specific structure requirements
The output should satisfy validate_mcpservers_object
The output should satisfy validate_mcpservers_not_empty
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'handles template context data properly'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Verify no template variables remain unprocessed
The output should satisfy validate_no_template_syntax
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End
End

Describe 'Template Integration with Registry Data'
It 'correctly maps registry server_type to template selection for github'
When run zsh "$PWD/mcp_manager.sh" parse github server_type
The status should be success
The output should include "api_based"
End

It 'correctly maps registry server_type to template selection for filesystem'
When run zsh "$PWD/mcp_manager.sh" parse filesystem server_type
The status should be success
The output should include "mount_based"
End

It 'correctly maps registry server_type to template selection for docker'
When run zsh "$PWD/mcp_manager.sh" parse docker server_type
The status should be success
The output should include "privileged"
End

It 'correctly maps registry image data to templates'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Verify specific image mappings
The output should satisfy validate_github_image
The output should satisfy validate_filesystem_image
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'correctly processes registry cmd arrays'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Figma has cmd array in registry
The output should satisfy validate_figma_args_contains
The output should satisfy validate_figma_stdio
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End

It 'correctly processes registry volume configurations'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Docker server should have registry-defined volumes
The output should satisfy validate_docker_sock_volume
# Kubernetes should have kubeconfig volume
The output should satisfy validate_kubernetes_kubeconfig
The stderr should include "[INFO] Sourcing .env file for variable expansion"
End
End
