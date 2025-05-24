#!/bin/bash
# CI-specific modifications to be applied to setup.sh
# This file contains only the differences needed for CI environments

# Log formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Function to ensure file has correct executable permissions
ensure_file_permissions() {
  local file_path="$1"
  local sudo_if_needed="${2:-false}"  # Optional flag to try sudo if regular chmod fails
  
  # Validate input
  if [[ -z "$file_path" ]]; then
    log_error "ensure_file_permissions: No file path provided"
    return 1
  fi

  if [[ ! -f "$file_path" ]]; then
    log_error "ensure_file_permissions: File does not exist: $file_path"
    return 1
  fi

  log_info "Setting executable permissions for $file_path..."
  
  # Check current permissions
  if [[ -x "$file_path" ]]; then
    log_info "File already has executable permissions: $file_path"
    return 0
  fi

  # Try setting permissions without sudo first
  if chmod +x "$file_path" 2>/dev/null; then
    if [[ -x "$file_path" ]]; then
      log_success "Successfully set executable permissions for $file_path"
      ls -l "$file_path"  # Display permissions for verification
      return 0
    else
      log_warning "chmod command succeeded but permissions not set correctly on $file_path"
    fi
  else
    log_warning "Failed to set executable permissions for $file_path with regular chmod"
  fi

  # If we're here, the first attempt failed. Try with sudo if allowed.
  if [[ "$sudo_if_needed" == "true" ]]; then
    log_info "Attempting to use sudo to set permissions on $file_path..."
    if sudo chmod +x "$file_path" 2>/dev/null; then
      if [[ -x "$file_path" ]]; then
        log_success "Successfully set executable permissions for $file_path using sudo"
        ls -l "$file_path"  # Display permissions for verification
        return 0
      else
        log_error "sudo chmod succeeded but permissions still not set correctly on $file_path"
      fi
    else
      log_error "Failed to set executable permissions with sudo on $file_path"
    fi
  else
    log_info "Skipping sudo attempt (not enabled for this call)"
  fi

  # If we reach here, all attempts failed
  log_error "Could not set executable permissions on $file_path after all attempts"
  log_info "Current permissions: $(ls -l "$file_path")"
  return 1
}

# Function to patch the setup.sh script for CI use
patch_for_ci() {
  local setup_file="$1"
  local output_file="$2"

  # Create a copy of the original script
  cp "$setup_file" "$output_file"
  
  # Apply CI-specific modifications
  
  # 1. Add CI environment marker near the top and ensure bash functions are exportable
  # Note: Using single quotes intentionally for literal string in sed pattern
  sed -i.bak '4i\
# Modified for CI environment\
export CI=true\
# Enable bash function exporting (important for subshell execution)\
set -a\
' "$output_file"

  # 2. Source HashiCorp installation functions directly from file rather than creating a temp file
  if [ -f "hashicorp_install.sh" ]; then
    log_info "Using existing hashicorp_install.sh for function definitions"
    # Read the content of hashicorp_install.sh, but skip the shebang line
    HASHICORP_FUNCTIONS=$(tail -n +2 "hashicorp_install.sh")
    # Create a temporary file with HashiCorp functions - with explicit exports
    cat > /tmp/hashicorp_functions.sh << EOF

# HashiCorp installation functions - directly included from hashicorp_install.sh
# Functions are explicitly exported for global availability
${HASHICORP_FUNCTIONS}

# Export functions for global availability
export -f install_hashicorp_tool
export -f install_terraform
export -f install_packer
EOF
  else
    log_error "hashicorp_install.sh not found - creating default implementation"
    cat > /tmp/hashicorp_functions.sh << 'EOF'

# HashiCorp installation functions
# Placed after all logging functions and before other functions
install_hashicorp_tool() {
  local tool=$1
  local version=$2
  local arch
  
  log_info "Checking if $tool is installed..."
  if command -v "$tool" >/dev/null 2>&1; then
    local current_version
    current_version=$("$tool" --version 2>/dev/null)
    log_success "$tool is already installed (version: $current_version)."
    return 0
  fi

  log_info "Installing HashiCorp $tool directly (version $version)..."
  
  # Create a temporary directory for the download
  local tmp_dir
  tmp_dir=$(mktemp -d)
  log_info "Created temporary directory: $tmp_dir"
  
  # Determine the architecture
  if [[ "$(uname -m)" == "arm64" ]]; then
    arch="arm64"
  else
    arch="amd64"
  fi
  
  # Set the download URL
  local download_url="https://releases.hashicorp.com/$tool/$version/${tool}_${version}_darwin_${arch}.zip"
  local zip_file="$tmp_dir/$tool.zip"
  
  # Download the zip file
  log_info "Downloading $tool from: $download_url"
  if ! curl -sSL "$download_url" -o "$zip_file"; then
    log_error "Failed to download $tool from $download_url"
    rm -rf "$tmp_dir"
    return 1
  fi
  
  # Extract the zip file
  log_info "Extracting $tool..."
  if ! unzip -q "$zip_file" -d "$tmp_dir"; then
    log_error "Failed to extract $tool"
    rm -rf "$tmp_dir"
    return 1
  fi
  
  # Move the binary to /usr/local/bin
  log_info "Installing $tool to /usr/local/bin..."
  if ! sudo mv "$tmp_dir/$tool" /usr/local/bin/; then
    log_error "Failed to move $tool binary to /usr/local/bin/"
    rm -rf "$tmp_dir"
    return 1
  fi
  
  # Set appropriate permissions
  sudo chmod +x "/usr/local/bin/$tool"
  
  # Clean up the temporary directory
  rm -rf "$tmp_dir"
  
  # Verify the installation
  if command -v "$tool" >/dev/null 2>&1; then
    local installed_version
    installed_version=$("$tool" --version)
    log_success "$tool $installed_version installed successfully."
    return 0
  else
    log_error "$tool installation failed. Please check the logs."
    return 1
  fi
}

# Install Terraform
install_terraform() {
  install_hashicorp_tool "terraform" "1.6.0"
}

# Install Packer
install_packer() {
  install_hashicorp_tool "packer" "1.11.2"
}

# Export functions for global availability
export -f install_hashicorp_tool
export -f install_terraform
export -f install_packer
EOF
  fi

  # 3. First remove any existing install_terraform or install_packer functions from setup.sh
  # (they might conflict with our injected versions)
  log_info "Removing any existing HashiCorp functions from the original script..."
  sed -i.bak '/^install_terraform()/,/^}/d' "$output_file"
  sed -i.bak '/^install_packer()/,/^}/d' "$output_file"

  # 4. Insert HashiCorp functions at a higher scope (right after CI environment marker)
  # Only inject if the functions don't already exist
  if ! grep -q "^# HashiCorp installation functions" "$output_file"; then
    # Find the line where CI environment marker is placed
    CI_MARKER=$(grep -n "^# Modified for CI environment" "$output_file" | head -1 | cut -d':' -f1)
    if [ -n "$CI_MARKER" ]; then
      # Find the line after 'set -a' (which should be right after the CI marker)
      INSERTION_POINT=$((CI_MARKER + 3))
      # Insert the HashiCorp functions immediately after the CI environment setup
      # This ensures they are defined at global scope before any other function
      sed -i.bak "${INSERTION_POINT}r /tmp/hashicorp_functions.sh" "$output_file"
      log_info "Successfully injected HashiCorp functions into $output_file"
    
      # Verify that the functions were actually injected
      if grep -q "install_terraform()" "$output_file"; then
        log_success "install_terraform function successfully injected into $output_file"
      else
        log_error "install_terraform function not found in $output_file after injection"
        return 1
      fi
      
      if grep -q "install_packer()" "$output_file"; then
        log_success "install_packer function successfully injected into $output_file"
      else
        log_error "install_packer function not found in $output_file after injection"
        return 1
      fi
    else
      log_error "Could not find insertion point after logging functions"
      return 1
    fi
  else
    log_info "HashiCorp functions already exist in the file, skipping injection"
  fi

  # Clean up the temporary file
  rm -f /tmp/hashicorp_functions.sh

  # NOTE: Moved removal of existing HashiCorp functions to before injection step

  # 5. Modify the install_packages function to use a subset of packages
  # Find the install_packages function and replace its content using awk
  # Note: Terraform and Packer are installed separately due to BUSL license
  log_info "Updating install_packages function to use HashiCorp functions..."
  
  # Create a cleaner heredoc for the awk script
  cat > /tmp/install_packages_awk.script << 'EOT'
/^install_packages\(\)/ {
  p=1
  print
  print "  log_info \"Installing essential packages for CI testing...\""
  print ""
  print "  # Install core packages directly (faster than full Brewfile)"
  print "  if ! brew install git zinit rbenv pyenv direnv starship kubectl helm kubectx; then"
  print "    log_error \"Failed to install some core packages\""
  print "    # Continue anyway as some packages might have been installed successfully"
  print "  fi"
  print ""
  print "  # Verify HashiCorp functions are available"
  print "  log_info \"Verifying HashiCorp functions availability...\""
  print ""
  print "  # Function to verify and run HashiCorp tool installation"
  print "  run_hashicorp_install() {"
  print "    local tool_func=\"$1\""
  print "    local tool_name=\"$2\""
  print ""
  print "    # First verify the function exists"
  print "    if ! declare -F \"$tool_func\" > /dev/null; then"
  print "      log_error \"$tool_func function not available - attempting recovery\""
  print "      # Try to source the function from the current script"
  print "      # shellcheck disable=SC1090"
  print "      source <(grep -A 50 \"^$tool_func()\" \"$0\" | grep -B 50 -m 1 \"^}\")"
  print "      "
  print "      # Check again after recovery attempt"
  print "      if ! declare -F \"$tool_func\" > /dev/null; then"
  print "        log_error \"Recovery failed: $tool_func function still not available\""
  print "        return 1"
  print "      fi"
  print "    fi"
  print ""
  print "    # Call the function directly (no subshell needed since we verified it exists)"
  print "    log_info \"Installing $tool_name...\""
  print "    if \"$tool_func\"; then"
  print "      log_success \"$tool_name installation successful\""
  print "      return 0"
  print "    else"
  print "      log_error \"$tool_name installation failed\""
  print "      return 1"
  print "    fi"
  print "  }"
  print ""
  print "  # Install HashiCorp tools with proper error handling"
  print "  run_hashicorp_install \"install_terraform\" \"Terraform\""
  print "  run_hashicorp_install \"install_packer\" \"Packer\""
  print ""
  print "  # Skip casks in CI to speed up testing"
  print "  log_success \"Essential packages installed successfully.\""
  next
} 
p && /^}/ {
  p=0
} 
!p {
  print
}
EOT

  # Run the awk script with the newly created script file
  awk -f /tmp/install_packages_awk.script "$output_file" > "$output_file.tmp" && mv "$output_file.tmp" "$output_file"
  
  # Clean up the temporary awk script file
  rm -f /tmp/install_packages_awk.script
  
  # Add a function to the script to load HashiCorp functions if needed
  # This avoids the problematic process substitution in the install_packages function
  log_info "Adding HashiCorp function loader to the script..."
  cat > /tmp/hashicorp_loader.sh << 'EOF'

# Function to load HashiCorp functions if they're not already available
load_hashicorp_functions() {
  if ! declare -F install_terraform > /dev/null || ! declare -F install_packer > /dev/null; then
    log_warning "Some HashiCorp functions are not available - attempting to load them"
    
    # Source the functions from the script file
    # First, find the functions in the file
    local terraform_func packer_func
    terraform_func=$(grep -n "^install_terraform()" "$0" | head -1 | cut -d':' -f1)
    packer_func=$(grep -n "^install_packer()" "$0" | head -1 | cut -d':' -f1)
    
    if [ -n "$terraform_func" ]; then
      log_info "Found install_terraform at line $terraform_func, loading function..."
      # Extract and eval the function definition
      eval "$(sed -n "${terraform_func},/^}/p" "$0")"
      export -f install_terraform
    fi
    
    if [ -n "$packer_func" ]; then
      log_info "Found install_packer at line $packer_func, loading function..."
      # Extract and eval the function definition
      eval "$(sed -n "${packer_func},/^}/p" "$0")"
      export -f install_packer
    fi
  fi
}

# Add call to load the functions before install_packages
load_hashicorp_functions
EOF

  # Insert the loader function before the install_packages function
  INSTALL_PACKAGES=$(grep -n "^install_packages()" "$output_file" | head -1 | cut -d':' -f1)
  if [ -n "$INSTALL_PACKAGES" ]; then
    INSERTION_POINT=$((INSTALL_PACKAGES - 1))
    sed -i.bak "${INSERTION_POINT}r /tmp/hashicorp_loader.sh" "$output_file"
    log_success "HashiCorp function loader added to the script."
  else
    log_error "Could not find install_packages function to place loader!"
  fi
  rm -f /tmp/hashicorp_loader.sh
  
  # 6. Verify function order and check for duplicates
  log_info "Verifying function order in $output_file..."
  if [ "$(grep -c "^install_packer()" "$output_file")" -eq 1 ]; then
    log_success "No duplicate install_packer functions found."
  else
    log_error "Duplicate install_packer functions found. Check $output_file manually."
  fi

  # 7. Add function verification code in the script to test at runtime
  log_info "Adding function verification code to the script..."
  # Create a verification function that will run at script start
  cat > /tmp/function_verification.sh << 'EOF'

# Function to verify that HashiCorp functions are properly defined
verify_hashicorp_functions() {
  log_info "Verifying HashiCorp functions are properly defined..."
  
  # Check if functions are available
  if ! declare -F install_terraform > /dev/null; then
    log_error "install_terraform function is not available!"
    # Attempt to recover by sourcing from the current file
    log_info "Attempting to source install_terraform function..."
    # shellcheck disable=SC1090
    source <(grep -A 20 "^install_terraform()" "$0" | grep -B 20 -m 1 "^}")
  fi
  
  if ! declare -F install_packer > /dev/null; then
    log_error "install_packer function is not available!"
    # Attempt to recover by sourcing from the current file
    log_info "Attempting to source install_packer function..."
    # shellcheck disable=SC1090
    source <(grep -A 20 "^install_packer()" "$0" | grep -B 20 -m 1 "^}")
  fi
  
  if ! declare -F install_hashicorp_tool > /dev/null; then
    log_error "install_hashicorp_tool function is not available!"
    # Attempt to recover by sourcing from the current file
    log_info "Attempting to source install_hashicorp_tool function..."
    # shellcheck disable=SC1090
    source <(grep -A 100 "^install_hashicorp_tool()" "$0" | grep -B 100 -m 1 "^}")
  fi
  
  # Verify after recovery attempt
  if declare -F install_terraform > /dev/null && 
     declare -F install_packer > /dev/null && 
     declare -F install_hashicorp_tool > /dev/null; then
    log_success "All HashiCorp functions are properly defined."
    return 0
  else
    log_error "Some HashiCorp functions are still missing after recovery attempt!"
    return 1
  fi
}

# Run verification after sourcing functions
verify_hashicorp_functions
EOF

  # Insert the verification function right after the HashiCorp functions
  HASHICORP_END=$(grep -n "^export -f install_packer" "$output_file" | head -1 | cut -d':' -f1)
  if [ -n "$HASHICORP_END" ]; then
    INSERTION_POINT=$((HASHICORP_END + 1))
    sed -i.bak "${INSERTION_POINT}r /tmp/function_verification.sh" "$output_file"
    log_success "Function verification code added to the script."
  else
    log_error "Could not find function exports to place verification code!"
  fi
  rm -f /tmp/function_verification.sh

  # Check for function presence in the file
  if grep -q "install_terraform" "$output_file" && grep -q "install_hashicorp_tool" "$output_file"; then
    grep -n "install_terraform" "$output_file" | head -1
    grep -n "install_hashicorp_tool" "$output_file" | head -1
    log_success "HashiCorp functions are present in the file at the lines shown above."
  else
    log_error "HashiCorp functions not properly injected!"
    return 1
  fi
  
  # 5. Ensure .zshrc exists and completions are properly loaded
  # Create a temporary file with the content to insert
  cat > /tmp/zshrc_config.txt << 'EOZSH'
# Check and create .zshrc if needed
if [[ ! -f "$ZSHRC_PATH" ]]; then
  touch "$ZSHRC_PATH"
fi

# Ensure zsh completions directory is in fpath
if ! grep -q "zsh/site-functions" "$ZSHRC_PATH" 2>/dev/null; then
  echo "fpath=(/opt/homebrew/share/zsh/site-functions \$fpath)" >> "$ZSHRC_PATH"
fi
EOZSH

  # Insert the content after ZSHRC_PATH declaration
  sed -i.bak "/ZSHRC_PATH=.*$/r /tmp/zshrc_config.txt" "$output_file"
  rm /tmp/zshrc_config.txt

  # 4. Remove any interactive prompts
  sed -i.bak 's/read -p/echo "CI mode: skipping prompt" #read -p/g' "$output_file"
  
  # 5. Add CI-specific logging at the start
  sed -i.bak '/^log_info "Starting setup process/a\
log_info "Running in CI environment - some operations will be modified"' "$output_file"

  # Patch zinit initialization script to fix typeset -g compatibility issue
  log_info "Patching zinit initialization script for CI compatibility..."
  
  # Create a function to patch zinit.zsh
  cat > /tmp/zinit_patch.sh << 'EOF'

# Function to patch zinit initialization script for compatibility with older zsh versions
patch_zinit_init() {
  log_info "Discovering Homebrew installation path..."
  local brew_prefix
  brew_prefix=""
  if command -v brew >/dev/null 2>&1; then
    brew_prefix=$(brew --prefix)
    log_info "Homebrew prefix detected: $brew_prefix"
  else
    log_warning "Homebrew command not found, using default paths"
    brew_prefix="/opt/homebrew"  # Default for Apple Silicon
  fi
  
  # Find all zinit installations in Cellar directory using glob pattern
  local cellar_zinit_paths=()
  if [[ -d "$brew_prefix/Cellar/zinit" ]]; then
    log_info "Searching for zinit in Homebrew Cellar directory..."
    # Find all zinit versions in Cellar and add them to paths
    for version_dir in "$brew_prefix/Cellar/zinit"/*; do
      if [[ -d "$version_dir" && -f "$version_dir/zinit.zsh" ]]; then
        cellar_zinit_paths+=("$version_dir/zinit.zsh")
        log_info "Found Cellar zinit installation: $version_dir/zinit.zsh"
      fi
    done
  else
    log_info "No Homebrew Cellar zinit directory found at $brew_prefix/Cellar/zinit"
  fi
  
  # Combine all possible paths, including dynamic ones
  local zinit_paths=(
    # Dynamic Homebrew paths
    "$brew_prefix/opt/zinit/zinit.zsh"
    "$brew_prefix/share/zinit/zinit.zsh"
    # Include all detected Cellar paths
    "${cellar_zinit_paths[@]}"
    # User installation paths
    "$HOME/.zinit/bin/zinit.zsh"
    "$HOME/.local/share/zinit/zinit.zsh"
    # System-wide installation paths
    "/usr/local/share/zinit/zinit.zsh"
    "/usr/local/opt/zinit/zinit.zsh"
    "/usr/share/zinit/zinit.zsh"
  )
  
  log_info "Searching for zinit initialization script..."
  
  local zinit_path=""
  for path in "${zinit_paths[@]}"; do
    if [[ -z "$path" ]]; then
      continue  # Skip empty paths
    fi
    
    log_info "Checking for zinit at: $path"
    if [[ -f "$path" ]]; then
      zinit_path="$path"
      log_success "Found zinit at: $zinit_path"
      break
    else
      log_info "Zinit not found at: $path"
    fi
  done
  
  if [[ -z "$zinit_path" ]]; then
    log_warning "Zinit initialization script not found, skipping patch"
    return 0
  fi
  
  # Check if the file is writable
  if [[ ! -w "$zinit_path" ]]; then
    log_error "Zinit initialization script found but not writable: $zinit_path"
    log_info "Attempting to make the file writable..."
    if ! chmod +w "$zinit_path" 2>/dev/null; then
      log_error "Failed to make the file writable, will try using sudo"
      if ! sudo chmod +w "$zinit_path" 2>/dev/null; then
        log_error "Failed to make the file writable even with sudo, cannot patch zinit"
        return 1
      else
        log_success "Made zinit file writable using sudo"
      fi
    else
      log_success "Made zinit file writable"
    fi
  fi
  
  # Create a backup of the original file
  local backup_file="${zinit_path}.bak"
  if [[ ! -f "$backup_file" ]]; then
    log_info "Creating backup of original zinit script at: $backup_file"
    cp "$zinit_path" "$backup_file"
  else
    log_info "Backup already exists at: $backup_file"
  fi
  
  # Replace 'typeset -g' with 'typeset' to fix compatibility issues
  log_info "Patching zinit script to replace 'typeset -g' with 'typeset'"
  
  # Count occurrences of 'typeset -g' before patching
  local count_before
  count_before=$(grep -c "typeset -g" "$zinit_path" || echo 0)
  log_info "Found $count_before occurrences of 'typeset -g' before patching"
  
  # Perform the patching
  if sed -i.tmp 's/typeset -g/typeset/g' "$zinit_path"; then
    rm -f "${zinit_path}.tmp"
    
    # Verify the changes were applied by counting occurrences after patching
    local count_after
    count_after=$(grep -c "typeset -g" "$zinit_path" || echo 0)
    log_info "Found $count_after occurrences of 'typeset -g' after patching"
    
    if [[ $count_after -eq 0 ]]; then
      log_success "Zinit initialization script patched successfully (removed $count_before occurrences of 'typeset -g')"
    elif [[ $count_after -lt $count_before ]]; then
      log_warning "Zinit initialization script partially patched (removed $(($count_before - $count_after)) of $count_before occurrences)"
    else
      log_error "Zinit initialization script patch failed - no occurrences were changed"
      # Restore from backup
      if [[ -f "$backup_file" ]]; then
        log_info "Restoring zinit script from backup"
        cp "$backup_file" "$zinit_path"
      fi
      return 1
    fi
  else
    log_error "Failed to patch zinit initialization script with sed command"
    # Restore from backup if patch failed
    if [[ -f "$backup_file" ]]; then
      log_info "Restoring zinit script from backup"
      cp "$backup_file" "$zinit_path"
    fi
    return 1
  fi
}

# Call the function to patch zinit
patch_zinit_init
EOF

  # Insert the zinit patch function before install_packages function
  INSTALL_PACKAGES=$(grep -n "^install_packages()" "$output_file" | head -1 | cut -d':' -f1)
  if [ -n "$INSTALL_PACKAGES" ]; then
    INSERTION_POINT=$((INSTALL_PACKAGES - 1))
    sed -i.bak "${INSERTION_POINT}r /tmp/zinit_patch.sh" "$output_file"
    log_success "Zinit patching function added to the script."
  else
    log_error "Could not find install_packages function to place zinit patcher!"
  fi
  rm -f /tmp/zinit_patch.sh

  # Modify the configure_shell function to better handle CI environments, especially zinit paths
  log_info "Enhancing configure_shell function for CI environment..."
  
  # Create a temporary file with zinit path discovery for configure_shell
  cat > /tmp/improved_zinit_config.awk << 'EOT'
/^  # Add zinit configuration/ {
  p=1
  print
  print "  # Add zinit configuration with dynamic path discovery for CI compatibility"
  print "  log_info \"Setting up zinit with dynamic path discovery...\""
  print "  # Find the zinit.zsh file using the same logic as patch_zinit_init"
  print "  local zinit_paths=("
  print "    \"$(brew --prefix 2>/dev/null)/opt/zinit/zinit.zsh\""
  print "    \"$(brew --prefix 2>/dev/null)/share/zinit/zinit.zsh\""
  print "    \"$HOME/.zinit/bin/zinit.zsh\""
  print "    \"$HOME/.local/share/zinit/zinit.zsh\""
  print "    \"/usr/local/share/zinit/zinit.zsh\""
  print "    \"/usr/local/opt/zinit/zinit.zsh\""
  print "  )"
  print ""
  print "  # Check for zinit in Homebrew Cellar directory (version-specific paths)"
  print "  local brew_prefix"
  print "  brew_prefix=\"\""
  print "  brew_prefix=\"$(brew --prefix 2>/dev/null)\""
  print "  if [[ -d \"$brew_prefix/Cellar/zinit\" ]]; then"
  print "    log_info \"Checking Homebrew Cellar for zinit...\""
  print "    local cellar_versions=(\"$brew_prefix/Cellar/zinit\"/*)"
  print "    for version_dir in \"${cellar_versions[@]}\"; do"
  print "      if [[ -d \"$version_dir\" && -f \"$version_dir/zinit.zsh\" ]]; then"
  print "        zinit_paths+=(\"$version_dir/zinit.zsh\")"
  print "        log_info \"Found zinit in Cellar: $version_dir/zinit.zsh\""
  print "      fi"
  print "    done"
  print "  fi"
  print ""
  print "  local zinit_path=\"\""
  print "  for path in \"${zinit_paths[@]}\"; do"
  print "    if [[ -f \"$path\" ]]; then"
  print "      zinit_path=\"$path\""
  print "      log_info \"Using zinit at: $zinit_path\""
  print "      break"
  print "    fi"
  print "  done"
  print ""
  print "  if [[ -z \"$zinit_path\" ]]; then"
  print "    log_warning \"Could not find zinit.zsh, using fallback path\""
  print "    # Use a fallback path as a last resort"
  print "    zinit_path=\"$(brew --prefix 2>/dev/null)/opt/zinit/zinit.zsh\""
  print "  fi"
  print ""
  print "  add_to_zshrc \"source.*zinit.zsh\" \"# Dynamic zinit path discovery for CI compatibility"
  print "ZINIT_PATH=\\\"$zinit_path\\\""
  print "if [[ -f \\\"\\$ZINIT_PATH\\\" ]]; then"
  print "  source \\\"\\$ZINIT_PATH\\\" || log_warning \\\"Failed to source zinit from \\$ZINIT_PATH\\\""
  print ""
  print "  # Load zinit plugins with CI-safe configuration"
  print "  zinit light zdharma/fast-syntax-highlighting"
  print "  zinit light zsh-users/zsh-autosuggestions"
  print "  zinit light macunha1/zsh-terraform"
  print "else"
  print "  log_warning \\\"Zinit not found at \\$ZINIT_PATH\\\""
  print "fi\" \"zinit setup with CI compatibility\""
  next
}
p && /^  # Add rbenv configuration/ {
  p=0
  print
  next
}
p {
  # Skip lines while in the zinit configuration section
  next
}
!p {
  print
}
EOT

  # Apply the awk script to modify the zinit configuration in configure_shell
  awk -f /tmp/improved_zinit_config.awk "$output_file" > "$output_file.tmp" && mv "$output_file.tmp" "$output_file"
  rm -f /tmp/improved_zinit_config.awk
  
  # Now update the shell reloading part of configure_shell
  log_info "Enhancing shell reload mechanism for CI environment..."
  cat > /tmp/improved_shell_reload.awk << 'EOT'
/^  # Reload the shell configuration more thoroughly/ {
  p=1
  print
  print "  log_info \"Reloading shell configuration in CI environment...\""
  print "  # Force zcompdump regeneration"
  print "  rm -f \"$HOME/.zcompdump\"*"
  print "  rm -f \"$HOME/.zcompcache\"/*"
  print "  # Source zshrc with error handling"
  print "  log_info \"Sourcing zshrc file: $ZSHRC_PATH\""
  print "  # shellcheck disable=SC1090"
  print "  if ! source \"$ZSHRC_PATH\"; then"
  print "    log_warning \"Failed to source $ZSHRC_PATH directly, continuing anyway\""
  print "    # Set environment variables directly to ensure availability"
  print "    export PATH=\"$HOME/.pyenv/bin:$PATH\""
  print "    export PATH=\"$HOME/.rbenv/bin:$PATH\""
  print "  else"
  print "    log_info \"Successfully sourced $ZSHRC_PATH\""
  print "  fi"
  print ""
  print "  # Initialize completions with error handling"
  print "  log_info \"Initializing shell completions...\""
  print "  if ! autoload -Uz compinit 2>/dev/null; then"
  print "    log_warning \"Failed to load compinit, skipping completion initialization\""
  print "  else"
  print "    # Run compinit with option to ignore insecure directories"
  print "    compinit -u 2>/dev/null || compinit -C -i 2>/dev/null || true"
  print "    log_info \"Completions initialized\""
  print "  fi"
  print ""
  print "  # Rehash commands with error handling"
  print "  rehash 2>/dev/null || true"
  print ""
  print "  log_success \"Shell configuration reloaded with enhanced CI compatibility.\""
  next
}
p && /^}/ {
  p=0
  print
  next
}
p {
  # Skip lines while processing the shell reload section
  next
}
!p {
  print
}
EOT

  # Apply the awk script to modify the shell reloading part
  CONFIGURE_SHELL_FUNC=$(grep -n "^configure_shell()" "$output_file" | head -1 | cut -d':' -f1)
  if [ -n "$CONFIGURE_SHELL_FUNC" ]; then
    log_info "Found configure_shell function at line $CONFIGURE_SHELL_FUNC, applying shell reload enhancement..."
    awk -f /tmp/improved_shell_reload.awk "$output_file" > "$output_file.tmp" && mv "$output_file.tmp" "$output_file"
    log_success "Shell reload enhancement applied successfully."
  else
    log_error "Could not find configure_shell function in $output_file!"
  fi
  
  # Clean up temporary file
  rm -f /tmp/improved_shell_reload.awk

  # Clean up backup files
  rm -f "$output_file.bak"

  # Use the ensure_file_permissions function to set and verify permissions
  if ! ensure_file_permissions "$output_file" "true"; then
    log_error "Failed to set executable permissions for $output_file despite multiple attempts"
    log_error "This may cause CI pipeline failures - manual intervention may be required"
    return 1
  fi

  log_info "CI-optimized script created at $output_file with execute permissions"
}
