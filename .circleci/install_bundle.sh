#!/bin/bash
# Install Homebrew Bundle if not available
# This script ensures the homebrew-bundle extension is installed before using brew bundle

set -euo pipefail

# Function to check if brew bundle works
check_bundle() {
  brew bundle --help > /dev/null 2>&1
}

# Function to install bundle support
install_bundle() {
  echo "Installing homebrew-bundle support..."

  # Modern Homebrew has bundle built-in, but we may need to install it
  # First try updating brew to get the latest features
  echo "Updating Homebrew..."
  brew update || {
    echo "Warning: Failed to update Homebrew, continuing..."
  }

  # Try installing the bundle command directly
  if ! check_bundle; then
    echo "Attempting to install bundle support..."
    # In newer versions, bundle is part of core Homebrew
    # Try installing it explicitly
    brew install homebrew/bundle/brew-bundle 2> /dev/null || {
      # If that fails, try the old tap method
      echo "Trying legacy installation method..."
      brew tap homebrew/bundle 2> /dev/null || true
    }
  fi
}

# Main logic
if ! check_bundle; then
  install_bundle

  # Final verification
  if ! check_bundle; then
    echo "ERROR: Failed to install homebrew-bundle extension"
    echo "Debug information:"
    echo "Homebrew version: $(brew --version)"
    echo "Available brew commands:"
    brew commands | grep -i bundle || echo "No bundle commands found"
    exit 1
  fi

  echo "Successfully installed homebrew-bundle"
else
  echo "homebrew-bundle is already available"
fi

# Test the bundle command with a simple operation
echo "Testing bundle functionality..."
if ! brew bundle check --no-lock 2> /dev/null; then
  echo "Warning: brew bundle check failed, but command is available"
else
  echo "Bundle functionality verified successfully"
fi
