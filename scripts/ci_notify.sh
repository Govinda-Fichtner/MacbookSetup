#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2296,SC2034,SC2154,SC1091

# Script for handling CI build notifications
# Usage: ci_notify.sh <status> [message]

set -euo pipefail

# Default values
typeset NOTIFICATION_SOUND="Funk"
typeset CI_DASHBOARD="https://cirrus-ci.com/github/Govinda-Fichtner/MacbookSetup"

# Function to send notification
send_notification() {
    typeset status=$1
    typeset message=${2:-"No message provided"}
    typeset title="Cirrus CI"
    typeset subtitle=""
    
    case $status in
        "failure")
            subtitle="Build Failed"
            NOTIFICATION_SOUND="Basso"
            ;;
        "success")
            subtitle="Build Succeeded"
            NOTIFICATION_SOUND="Glass"
            ;;
        *)
            subtitle="Build Status: $status"
            ;;
    esac
    
    # Try terminal-notifier if available (more features)
    if command -v terminal-notifier >/dev/null 2>&1; then
        terminal-notifier \
            -title "$title" \
            -subtitle "$subtitle" \
            -message "$message" \
            -sound "$NOTIFICATION_SOUND" \
            -open "$CI_DASHBOARD"
    else
        # Fallback to osascript
        osascript -e "display notification \"$message\" with title \"$title\" subtitle \"$subtitle\" sound name \"$NOTIFICATION_SOUND\""
    fi
}

# Function to get build errors from log
get_build_errors() {
    typeset commit_hash
    commit_hash=$(git rev-parse HEAD)
    typeset errors
    
    # Fetch and parse errors from the verification log
    errors=$(curl -s "https://api.cirrus-ci.com/v1/task/${commit_hash}/logs/verify.log" | grep '::error::' || true)
    
    if [[ -n "$errors" ]]; then
        echo "$errors" | sed 's/::error:://'
    else
        echo "Check CI dashboard for details"
    fi
}

# Main execution
main() {
    typeset status=${1:-"unknown"}
    typeset message=${2:-$(get_build_errors)}
    
    send_notification "$status" "$message"
    
    # If it's a failure, also log to a file for reference
    if [[ "$status" == "failure" ]]; then
        mkdir -p "${HOME}/.cirrus/logs"
        {
            echo "=== Build Failure ==="
            echo "Date: $(date)"
            echo "Status: $status"
            echo "Message: $message"
            echo "Dashboard: $CI_DASHBOARD"
            echo "====================" 
        } >> "${HOME}/.cirrus/logs/build_failures.log"
    fi
}

main "$@" 