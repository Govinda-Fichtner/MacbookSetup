# ShellSpec Formatting Guidelines

This document defines the formatting standards for ShellSpec test files in this project.

## Indentation Rules

### 1. **Two-Space Indentation**
Each nested level should be indented by exactly **2 spaces**. This applies to all blocks and their contents.

```bash
Describe 'Top Level Test Suite'
  Describe 'Nested Test Suite'
    It 'test case description'
      When run some_command
      The status should be success
    End
  End
End
```

### 2. **Block Structure Indentation**

#### Describe/Context Blocks
- Top-level `Describe` blocks start at column 0
- Nested `Describe` or `Context` blocks are indented 2 spaces from their parent
- The closing `End` aligns with the opening keyword

```bash
Describe 'Main Feature'
  Context 'when condition is true'
    Describe 'Sub Feature'
      # Content indented 6 spaces from start
    End
  End
End
```

#### It Blocks
- `It` blocks are indented 2 spaces from their parent `Describe`/`Context`
- Test assertions within `It` blocks are indented 2 more spaces

```bash
Describe 'Feature'
  It 'does something'
    When run ./script.sh
    The output should include "success"
    The status should be success
  End
End
```

#### BeforeEach/AfterEach/BeforeAll/AfterAll
- These blocks are indented at the same level as `It` blocks within their parent
- Function body content is indented 2 more spaces

```bash
Describe 'Test Suite'
  BeforeEach
    test_dir="$PWD/tmp/test_$$"
    mkdir -p "$test_dir"
  End

  AfterEach
    rm -rf "$test_dir"
  End

  It 'uses the test directory'
    When run test -d "$test_dir"
    The status should be success
  End
End
```

### 3. **Helper Functions**
- Helper functions defined within test blocks follow the same indentation
- Function bodies are indented 2 spaces from the function declaration

```bash
Describe 'Helpers'
  helper_function() {
    echo "helper output"
  }

  It 'uses helper'
    When call helper_function
    The output should equal "helper output"
  End
End
```

## Formatting Standards

### 1. **Quote Style**
- Use **single quotes** for all ShellSpec DSL keywords and test descriptions
- This provides consistency and avoids shell expansion issues

```bash
# Good
Describe 'Test Suite'
  It 'performs action'
    The output should include 'expected text'
  End
End

# Avoid
Describe "Test Suite"
  It "performs action"
    The output should include "expected text"
  End
End
```

### 2. **File Structure**
Every ShellSpec test file should follow this structure:

```bash
#!/bin/zsh
# Brief description of what this test file covers

# Global setup (if needed)
BeforeAll
  # Global initialization
End

AfterAll
  # Global cleanup
End

# Main test suites
Describe 'Primary Feature'
  # Setup/teardown for this suite
  BeforeEach
    # Test-specific setup
  End

  AfterEach
    # Test-specific cleanup
  End

  # Test cases
  It 'performs expected behavior'
    When run command
    The status should be success
  End

  # Nested suites for sub-features
  Describe 'Sub Feature'
    It 'handles specific case'
      # Test implementation
    End
  End
End

# Additional top-level test suites as needed
Describe 'Secondary Feature'
  # Tests...
End
```

### 3. **Test Organization**
- Group related tests using nested `Describe` blocks
- Use `Context` for conditional scenarios
- Keep each `It` block focused on a single behavior

```bash
Describe 'User Authentication'
  Describe 'login'
    Context 'with valid credentials'
      It 'returns success'
        # Test valid login
      End
    End

    Context 'with invalid credentials'
      It 'returns error'
        # Test invalid login
      End
    End
  End
End
```

### 4. **Assertion Formatting**
- Each assertion on its own line
- Multiple assertions within an `It` block should test related aspects
- Use explicit matchers for clarity

```bash
It 'processes input correctly'
  When run ./process.sh "input"
  The status should be success
  The output should include 'Processing'
  The output should not include 'Error'
  The line 1 should equal 'Starting process'
  The line 2 should match pattern '^Complete'
End
```

### 5. **Skip and Pending Tests**
- Use consistent formatting for skipped tests
- Provide clear reasons for skipping

```bash
It 'advanced feature test'
  Skip if 'Docker not available' '! command -v docker'
  When run docker_test
  The status should be success
End

Pending 'not yet implemented'
```

## Best Practices

### 1. **Descriptive Test Names**
- Use clear, descriptive names that explain what is being tested
- Start with a verb in present tense
- Be specific about the expected behavior

```bash
# Good
It 'validates email format before saving'
It 'returns error when file does not exist'

# Avoid
It 'test1'
It 'email test'
```

### 2. **Test Independence**
- Each test should be independent and not rely on others
- Use `BeforeEach`/`AfterEach` for proper setup/cleanup
- Avoid test order dependencies

### 3. **Temporary Files**
- Always create temporary files in a dedicated test directory
- Clean up after each test
- Use process ID ($$) for unique names

```bash
BeforeEach
  test_home="$PWD/tmp/test_home_$$"
  mkdir -p "$test_home"
  export TEST_HOME="$test_home"
End

AfterEach
  rm -rf "$test_home"
  unset TEST_HOME
End
```

### 4. **Mock and Stub Usage**
- Define mocks/stubs close to their usage
- Clear mock definitions improve test readability

```bash
Describe 'External Command Usage'
  Mock docker
    echo "mock docker output"
  End

  It 'handles docker commands'
    When run ./script_using_docker.sh
    The output should include 'mock docker output'
  End
End
```

## Formatting Checklist

Before committing ShellSpec tests, ensure:

- [ ] Consistent 2-space indentation throughout
- [ ] All blocks properly closed with `End`
- [ ] Single quotes used for DSL keywords and descriptions
- [ ] Proper nesting reflects test structure
- [ ] Descriptive test and suite names
- [ ] BeforeEach/AfterEach used for setup/cleanup
- [ ] No trailing whitespace
- [ ] File starts with appropriate shebang (#!/bin/zsh)

## Example: Properly Formatted Test File

```bash
#!/bin/zsh
# Unit tests for configuration validation

Describe 'Configuration Validation'
  BeforeEach
    test_dir="$PWD/tmp/config_test_$$"
    mkdir -p "$test_dir"
    test_config="$test_dir/config.yml"
  End

  AfterEach
    rm -rf "$test_dir"
  End

  Describe 'YAML parsing'
    It 'parses valid YAML configuration'
      cat > "$test_config" << 'EOF'
name: test
version: 1.0
EOF
      When run ./parse_config.sh "$test_config"
      The status should be success
      The output should include 'Configuration valid'
    End

    It 'rejects invalid YAML'
      echo "invalid: [yaml" > "$test_config"
      When run ./parse_config.sh "$test_config"
      The status should be failure
      The error should include 'Invalid YAML'
    End
  End

  Describe 'Required fields validation'
    Context 'when name is missing'
      It 'returns validation error'
        echo "version: 1.0" > "$test_config"
        When run ./parse_config.sh "$test_config"
        The status should be failure
        The error should include 'name is required'
      End
    End

    Context 'when all required fields present'
      It 'passes validation'
        cat > "$test_config" << 'EOF'
name: test
version: 1.0
description: Test config
EOF
        When run ./parse_config.sh "$test_config"
        The status should be success
      End
    End
  End
End
```

This formatting standard ensures consistency, readability, and maintainability across all ShellSpec test files in the project.
