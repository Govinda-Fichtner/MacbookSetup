#!/bin/bash
# Install Homebrew Bundle if not available
# This script ensures the homebrew-bundle extension is installed before using brew bundle

set -euo pipefail

# Check if brew bundle is available
if ! brew bundle --help > /dev/null 2>&1; then
    echo "Installing homebrew-bundle..."
    brew tap homebrew/bundle
    
    # Verify installation was successful
    if ! brew bundle --help > /dev/null 2>&1; then
        echo "ERROR: Failed to install homebrew-bundle extension"
        exit 1
    fi
    
    echo "Successfully installed homebrew-bundle"
else
    echo "homebrew-bundle is already available"
fi
