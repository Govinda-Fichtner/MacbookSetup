#!/bin/zsh
#
# CI Modifier Script
# This script modifies setup.sh to create a CI-compatible version

set -e

# Ensure setup.sh exists
if [[ ! -f "setup.sh" ]]; then
    echo "Error: setup.sh not found"
    exit 1
fi

# Create ci_setup.sh from setup.sh
cp setup.sh ci_setup.sh

# Add CI-specific environment variables after the 'set -e' line
sed -i.bak '/^set -e/a\
# CI-specific environment variables\
export CI=true\
export NONINTERACTIVE=1\
export HOMEBREW_NO_AUTO_UPDATE=1\
export HOMEBREW_NO_INSTALL_CLEANUP=1\
export HOMEBREW_NO_ENV_HINTS=1\
' ci_setup.sh

# Remove root user check from validate_system function
# shellcheck disable=SC2016
sed -i.bak '/if \[\[ \$EUID -eq 0 \]\]/,+4d' ci_setup.sh

# Clean up backup files
rm -f ci_setup.sh.bak

echo "Generated CI-compatible setup script at ci_setup.sh"
