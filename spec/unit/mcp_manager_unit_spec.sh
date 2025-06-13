#!/bin/zsh
# Unit tests for mcp_manager.sh core functionality
# These test the command interface without heavy Docker dependencies

Describe "MCP Manager Unit Tests"

Describe "Basic Command Interface"
It "should show help when called with help command"
When run zsh "$PWD/mcp_manager.sh" help
The status should be success
The output should include "Usage:"
The output should include "Commands:"
End

It "should handle version-like requests gracefully"
# The script doesn't support --version, but should give helpful error
When run zsh "$PWD/mcp_manager.sh" --version
The status should not be success
The stderr should include "Unknown command"
The stderr should include "help"
End

It "should list available servers"
When run zsh "$PWD/mcp_manager.sh" list
The status should be success
The output should include "github"
The output should include "context7"
The output should include "circleci"
End
End

Describe "Server Registry Parsing"
It "should parse server type for github"
When run zsh "$PWD/mcp_manager.sh" parse github server_type
The status should be success
The output should equal "api_based"
End

It "should parse server type for context7"
When run zsh "$PWD/mcp_manager.sh" parse context7 server_type
The status should be success
The output should equal "standalone"
End

It "should parse server name for github"
When run zsh "$PWD/mcp_manager.sh" parse github name
The status should be success
The output should include "GitHub"
End

It "should parse server name for context7"
When run zsh "$PWD/mcp_manager.sh" parse context7 name
The status should be success
The output should include "Context7"
End

It "should return null for unknown server"
# The script returns "null" for unknown servers, not an error
When run zsh "$PWD/mcp_manager.sh" parse unknown_server server_type
The status should be success
The output should equal "null"
End
End

Describe "Environment Variable Handling"
It "should show environment variables for github"
When run zsh "$PWD/mcp_manager.sh" parse github environment_variables
The status should be success
The output should include "GITHUB_PERSONAL_ACCESS_TOKEN"
End

It "should show null for context7 environment variables"
# Standalone servers return "null" for environment variables
When run zsh "$PWD/mcp_manager.sh" parse context7 environment_variables
The status should be success
The output should equal "null"
End
End

Describe "Docker Image Resolution"
It "should resolve docker image for github"
When run zsh "$PWD/mcp_manager.sh" parse github source.image
The status should be success
The output should include "mcp/github"
End

It "should resolve docker image for context7"
When run zsh "$PWD/mcp_manager.sh" parse context7 source.image
The status should be success
The output should include "local/context7-mcp"
End
End

Describe "Configuration Generation (Lightweight)"
It "should generate config preview successfully"
When run zsh "$PWD/mcp_manager.sh" config
The status should be success
The output should include "=== MCP Client Configuration Generation ==="
The output should include "Cursor Configuration"
The output should include "Claude Desktop Configuration"
End

It "should handle config command gracefully in CI environment"
When run env CI=true zsh "$PWD/mcp_manager.sh" config
The status should be success
The output should include "=== MCP Client Configuration Generation ==="
End
End

Describe "Error Handling"
It "should handle invalid commands gracefully"
When run zsh "$PWD/mcp_manager.sh" invalid_command
The status should not be success
The stderr should include "Unknown command"
The stderr should include "help"
End

It "should show usage for incomplete parse command"
When run zsh "$PWD/mcp_manager.sh" parse
The status should be success
The output should include "Usage:"
The output should include "parse <server_id> <config_key>"
End
End

# New fast unit tests from core functionality
Describe "Extended Server Type Classification"
It "recognizes filesystem as mount_based server type"
When run zsh "$PWD/mcp_manager.sh" parse filesystem server_type
The status should be success
The output should equal "mount_based"
End

It "recognizes terraform-cli-controller as privileged server type"
When run zsh "$PWD/mcp_manager.sh" parse terraform-cli-controller server_type
The status should be success
The output should equal "privileged"
End

It "recognizes docker as privileged server type"
When run zsh "$PWD/mcp_manager.sh" parse docker server_type
The status should be success
The output should equal "privileged"
End

It "recognizes heroku as api_based server type"
When run zsh "$PWD/mcp_manager.sh" parse heroku server_type
The status should be success
The output should equal "api_based"
End

It "recognizes rails as mount_based server type"
When run zsh "$PWD/mcp_manager.sh" parse rails server_type
The status should be success
The output should equal "mount_based"
End

It "recognizes figma as api_based server type"
When run zsh "$PWD/mcp_manager.sh" parse figma server_type
The status should be success
The output should equal "api_based"
End
End

Describe "Extended Server List Validation"
It "includes all expected servers in available list"
When run zsh "$PWD/mcp_manager.sh" list
The status should be success
The output should include "github"
The output should include "circleci"
The output should include "figma"
The output should include "heroku"
The output should include "filesystem"
The output should include "context7"
The output should include "terraform-cli-controller"
The output should include "docker"
The output should include "rails"
End
End

Describe "Extended Configuration Validation"
It "parses Docker image names correctly for registry-based servers"
When run zsh "$PWD/mcp_manager.sh" parse github source.image
The status should be success
The output should include "mcp/github"
End

It "parses Docker image names correctly for build-based servers"
When run zsh "$PWD/mcp_manager.sh" parse heroku source.image
The status should be success
The output should include "local/heroku-mcp-server"
End

It "parses Context7 image name correctly"
When run zsh "$PWD/mcp_manager.sh" parse context7 source.image
The status should be success
The output should include "local/context7-mcp"
End

It "parses Figma image name correctly"
When run zsh "$PWD/mcp_manager.sh" parse figma source.image
The status should be success
The output should include "figma-context-mcp"
End

It "parses Rails image name correctly"
When run zsh "$PWD/mcp_manager.sh" parse rails source.image
The status should be success
The output should include "local/mcp-server-rails"
End
End

Describe "Extended Error Handling and Edge Cases"
It "handles invalid server names gracefully"
When run zsh "$PWD/mcp_manager.sh" parse nonexistent_server server_type
The status should be success
The output should equal "null"
End

It "handles unknown configuration keys gracefully"
When run zsh "$PWD/mcp_manager.sh" parse github unknown_key
The status should be success
The output should equal "null"
End

It "handles missing parse arguments gracefully"
When run zsh "$PWD/mcp_manager.sh" parse
The status should be success
The output should include "Usage:"
The output should include "parse <server_id> <config_key>"
End
End

Describe "Extended Environment Variable Validation"
It "shows environment variables for api_based servers"
When run zsh "$PWD/mcp_manager.sh" parse heroku environment_variables
The status should be success
The output should include "HEROKU_API_KEY"
End

It "shows environment variables for figma server"
When run zsh "$PWD/mcp_manager.sh" parse figma environment_variables
The status should be success
The output should include "FIGMA_API_KEY"
End

It "shows null for standalone server environment variables"
When run zsh "$PWD/mcp_manager.sh" parse context7 environment_variables
The status should be success
The output should equal "null"
End

It "shows environment variables for mount_based servers"
When run zsh "$PWD/mcp_manager.sh" parse filesystem environment_variables
The status should be success
The output should include "FILESYSTEM_ALLOWED_DIRS"
End
End

End
