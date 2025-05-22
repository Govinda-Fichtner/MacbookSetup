#!/bin/bash
# CI-specific modifications to be applied to setup.sh
# This file contains only the differences needed for CI environments

# Function to patch the setup.sh script for CI use
patch_for_ci() {
  local setup_file="$1"
  local output_file="$2"

  # Create a copy of the original script
  cp "$setup_file" "$output_file"
  
  # Make it executable
  chmod +x "$output_file"
  
  # Apply CI-specific modifications
  
  # 1. Add CI environment marker near the top
  sed -i.bak '4i\
# Modified for CI environment\
' "$output_file"

  # 2. Modify the install_packages function to use a subset of packages
  # Find the install_packages function and replace its content
  sed -i.bak '/^install_packages()/,/^}/c\
install_packages() {\
  log_info "Installing essential packages for CI testing..."\
\
  # Install core packages directly (faster than full Brewfile)\
  brew install git zinit rbenv pyenv direnv\
\
  # Skip casks in CI to speed up testing\
  log_success "Essential packages installed successfully."\
}' "$output_file"

  # 3. Ensure .zshrc exists in CI (add after ZSHRC_PATH declaration)
  sed -i.bak '/ZSHRC_PATH=.*$/a\
if [[ ! -f "$ZSHRC_PATH" ]]; then\
  touch "$ZSHRC_PATH"\
fi\
' "$output_file"

  # 4. Remove any interactive prompts
  sed -i.bak 's/read -p/echo "CI mode: skipping prompt" #read -p/g' "$output_file"
  
  # 5. Add CI-specific logging at the start
  sed -i.bak '/^log_info "Starting setup process/a\
log_info "Running in CI environment - some operations will be modified"' "$output_file"

  # Clean up backup files
  rm -f "$output_file.bak"
}

