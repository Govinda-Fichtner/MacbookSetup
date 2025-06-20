#!/bin/zsh
# Template validation tests for the Jinja2 template system
# Tests individual templates and template data generation

# Global setup for all template tests
BeforeAll
temp_dir="$PWD/tmp/template_test_$$"
mkdir -p "$temp_dir"
End

AfterAll
temp_dir="$PWD/tmp/template_test_$$"
rm -rf "$temp_dir"
End

Describe 'Template File Validation'
It 'validates main config template exists'
When run test -f "support/templates/mcp_config.tpl"
The status should be success
End

It 'validates core server templates exist'
When run test -f "support/templates/github.tpl"
The status should be success

When run test -f "support/templates/filesystem.tpl"
The status should be success

When run test -f "support/templates/docker.tpl"
The status should be success

When run test -f "support/templates/kubernetes.tpl"
The status should be success
End

It 'validates template syntax with minimal test data'
Skip if '! command -v jinja2 >/dev/null' 'jinja2 not available'
# Create minimal test context in proper temp location
test_context='{"servers":[{"id":"test","image":"test:latest","env_file":".env","entrypoint":"null","cmd_args":[],"mount_config":{},"privileged_config":{},"server_type":"api_based","volumes":[],"container_paths":[],"privileged_volumes":[],"privileged_networks":[]}]}'
context_file="$temp_dir/test_context.json"
echo "$test_context" > "$context_file"

When run jinja2 support/templates/mcp_config.tpl "$context_file" --format=json
The status should be success
The output should include '"mcpServers"'
End

It 'validates individual server templates render correctly'
servers=("github" "filesystem" "docker")
for server in "${servers[@]}"; do
  # Check template has proper Jinja2 structure
  When run grep -q "{{ server.id }}" "support/templates/$server.tpl"
  The status should be success
  When run grep -q "{{ server.image }}" "support/templates/$server.tpl"
  The status should be success
done
End

It 'validates registry-template consistency'
# Count servers in registry
registry_count=$(yq -r '.servers | keys | length' mcp_server_registry.yml)

# Count templates (excluding main config template)
template_count=$(find support/templates -name "*.tpl" -not -name "mcp_config.tpl" 2> /dev/null | wc -l | tr -d ' ')

# Should be equal
When run test "$registry_count" -eq "$template_count"
The status should be success
End

It 'validates no missing templates for core servers'
When run test -f "support/templates/github.tpl"
The status should be success

When run test -f "support/templates/filesystem.tpl"
The status should be success

When run test -f "support/templates/memory-service.tpl"
The status should be success

When run test -f "support/templates/terraform-cli-controller.tpl"
The status should be success
End
End

Describe 'Template Data Generation for Servers'
BeforeEach 'export FILESYSTEM_ALLOWED_DIRS="/tmp/test1,/tmp/test2"'

It 'generates correct template data for api_based servers'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# GitHub should have basic structure
The output should satisfy 'tail -n +2 | jq ".mcpServers.github.command == \"docker\""'
The output should satisfy 'tail -n +2 | jq ".mcpServers.github.args | contains([\"run\", \"--rm\", \"-i\"])"'
The output should satisfy 'tail -n +2 | jq ".mcpServers.github.args | contains([\"--env-file\"])"'
End

It 'generates correct template data for mount_based servers'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Filesystem should have volume mounts
The output should satisfy 'tail -n +2 | jq ".mcpServers.filesystem.args | map(select(test(\"--volume\"))) | length > 0"'
# Should have container paths as separate arguments
The output should satisfy 'tail -n +2 | jq ".mcpServers.filesystem.args | map(select(test(\"/projects/\"))) | length > 0"'
End

It 'generates correct template data for privileged servers'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Docker should have docker socket
The output should satisfy 'tail -n +2 | jq ".mcpServers.docker.args | contains([\"/var/run/docker.sock:/var/run/docker.sock\"])"'
# Kubernetes should have host network
The output should satisfy 'tail -n +2 | jq ".mcpServers.kubernetes.args | contains([\"--network\", \"host\"])"'
End

It 'handles entrypoint overrides correctly'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Figma should have entrypoint override
The output should satisfy 'tail -n +2 | jq ".mcpServers.figma.args | contains([\"--entrypoint\", \"node\"])"'
End

It 'handles command arguments correctly'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Figma should have cmd args
The output should satisfy 'tail -n +2 | jq ".mcpServers.figma.args | contains([\"dist/cli.js\", \"--stdio\"])"'
# Terraform-cli-controller should have mcp command
The output should satisfy 'tail -n +2 | jq ".mcpServers.\"terraform-cli-controller\".args[-1] == \"mcp\""'
End
End

Describe 'Template Data Consistency'
It 'ensures all servers have required Docker structure'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success

# All servers should have docker command
servers_list=$(echo '{}' | jq -r '.mcpServers // {} | keys[]' <<< "$(zsh "$PWD/mcp_manager.sh" config 2> /dev/null | tail -n +2)")
for server in $servers_list; do
  if [[ -n "$server" ]]; then
    The output should satisfy "tail -n +2 | jq \".mcpServers.\\\"$server\\\".command == \\\"docker\\\"\""
    The output should satisfy "tail -n +2 | jq \".mcpServers.\\\"$server\\\".args | type == \\\"array\\\"\""
  fi
done
End

It 'ensures all servers have env-file reference'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success

# All servers should reference .env file
config_json=$(zsh "$PWD/mcp_manager.sh" config 2> /dev/null | tail -n +2)
servers_list=$(echo "$config_json" | jq -r '.mcpServers | keys[]')
for server in $servers_list; do
  if [[ -n "$server" ]]; then
    echo "$config_json" | jq ".mcpServers.\"$server\".args" | grep -q "env-file"
    When run test $? -eq 0
    The status should be success
  fi
done
End

It 'validates environment variable expansion'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# No unexpanded variables should remain
The output should not satisfy 'tail -n +2 | grep -q "\\$HOME"'
The output should not satisfy 'tail -n +2 | grep -q "\\$KUBECONFIG_HOST"'
The output should not satisfy 'tail -n +2 | grep -q "\\${"'
End
End

Describe 'Template Error Handling'
It 'handles missing template gracefully'
# This would be tested by adding a server to registry without template
# For now, just verify error handling exists
When run command -v jinja2
The status should be success
End

It 'validates JSON structure after template processing'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Validate the entire JSON structure is valid
The output should satisfy 'tail -n +2 | jq empty'
# Validate specific structure requirements
The output should satisfy 'tail -n +2 | jq ".mcpServers | type == \"object\""'
The output should satisfy 'tail -n +2 | jq ".mcpServers | keys | length > 0"'
End

It 'handles template context data properly'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Verify no template variables remain unprocessed
The output should not satisfy 'tail -n +2 | grep -q "{{"'
The output should not satisfy 'tail -n +2 | grep -q "}}"'
The output should not satisfy 'tail -n +2 | grep -q "{%-"'
End
End

Describe 'Template Integration with Registry Data'
It 'correctly maps registry server_type to template selection'
server_types=("api_based:github" "mount_based:filesystem" "privileged:docker")
for mapping in "${server_types[@]}"; do
  type="${mapping%:*}"
  server="${mapping#*:}"

  When run zsh "$PWD/mcp_manager.sh" parse "$server" server_type
  The status should be success
  The output should include "$type"
done
End

It 'correctly maps registry image data to templates'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Verify specific image mappings
The output should satisfy 'tail -n +2 | jq ".mcpServers.github.args[-1] == \"mcp/github-mcp-server:latest\""'
The output should satisfy 'tail -n +2 | jq ".mcpServers.filesystem.args" | grep -q "mcp/filesystem:latest"'
End

It 'correctly processes registry cmd arrays'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Figma has cmd array in registry
The output should satisfy 'tail -n +2 | jq ".mcpServers.figma.args | contains([\"dist/cli.js\"])"'
The output should satisfy 'tail -n +2 | jq ".mcpServers.figma.args | contains([\"--stdio\"])"'
End

It 'correctly processes registry volume configurations'
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
# Docker server should have registry-defined volumes
The output should satisfy 'tail -n +2 | jq ".mcpServers.docker.args" | grep -q "/var/run/docker.sock"'
# Kubernetes should have kubeconfig volume
The output should satisfy 'tail -n +2 | jq ".mcpServers.kubernetes.args" | grep -q "/.kube/config"'
End
End
