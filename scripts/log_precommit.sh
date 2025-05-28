#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2296,SC2034,SC2154,SC1091,SC2155

# Pre-commit logging script
# Logs pre-commit hook results to help monitor their effectiveness

set -euo pipefail

# Configuration
readonly LOG_DIR="${HOME}/.macbook-setup/logs"
readonly LOG_FILE="${LOG_DIR}/pre-commit.log"
readonly MAX_LOG_SIZE=10485760 # 10MB in bytes

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Function to rotate log if it gets too large
rotate_log_if_needed() {
  if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2> /dev/null || echo 0) -gt $MAX_LOG_SIZE ]]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
    echo "Log rotated at $(date)" > "$LOG_FILE"
  fi
}

# Function to log pre-commit session
log_precommit_session() {
  local session_start
  local git_branch
  local git_commit

  session_start=$(date '+%Y-%m-%d %H:%M:%S')
  git_branch=$(git branch --show-current 2> /dev/null || echo "unknown")
  git_commit=$(git rev-parse --short HEAD 2> /dev/null || echo "unknown")

  # Rotate log if needed
  rotate_log_if_needed

  # Start logging session and environment
  {
    echo "=================================="
    echo "Pre-commit Session: $session_start"
    echo "Branch: $git_branch"
    echo "Commit: $git_commit"
    echo "PWD: $(pwd)"
    echo "=================================="
    echo "Pre-commit environment:"
    echo "  From ref: ${PRE_COMMIT_FROM_REF:-none}"
    echo "  To ref: ${PRE_COMMIT_TO_REF:-none}"
    echo "  Source: ${PRE_COMMIT_SOURCE:-none}"
    echo "  Hook name: ${PRE_COMMIT_HOOK_NAME:-none}"
    echo "  Hook type: ${PRE_COMMIT_HOOK_TYPE:-none}"
    echo "  Hook stage: ${PRE_COMMIT_HOOK_STAGE:-none}"
    echo "  Hook id: ${PRE_COMMIT_HOOK_ID:-none}"
    echo ""
    echo "Session ended: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=================================="
    echo ""
  } >> "$LOG_FILE"

  return 0
}

# Function to show recent log entries
show_recent_logs() {
  if [[ -f "$LOG_FILE" ]]; then
    echo "Recent pre-commit activity:"
    tail -50 "$LOG_FILE"
  else
    echo "No pre-commit logs found at $LOG_FILE"
  fi
}

# Function to show log statistics
show_log_stats() {
  if [[ -f "$LOG_FILE" ]]; then
    local total_sessions=$(grep -c "Pre-commit Session:" "$LOG_FILE" 2> /dev/null || echo 0)
    local successful_sessions=$(grep -c "✅ All pre-commit hooks passed" "$LOG_FILE" 2> /dev/null || echo 0)
    local failed_sessions=$(grep -c "❌ Some pre-commit hooks failed" "$LOG_FILE" 2> /dev/null || echo 0)
    local log_size=$(stat -f%z "$LOG_FILE" 2> /dev/null || echo 0)

    echo "Pre-commit Statistics:"
    echo "  Total sessions: $total_sessions"
    echo "  Successful: $successful_sessions"
    echo "  Failed: $failed_sessions"
    echo "  Log size: $(numfmt --to=iec "$log_size")"
    echo "  Log location: $LOG_FILE"
  else
    echo "No pre-commit logs found."
  fi
}

# Main execution
main() {
  case "${1:-log}" in
    "log")
      log_precommit_session
      ;;
    "show")
      show_recent_logs
      ;;
    "stats")
      show_log_stats
      ;;
    "help" | "-h" | "--help")
      echo "Usage: $0 [log|show|stats|help]"
      echo "  log   - Log current pre-commit session (default)"
      echo "  show  - Show recent log entries"
      echo "  stats - Show pre-commit statistics"
      echo "  help  - Show this help message"
      ;;
    *)
      echo "Unknown command: $1"
      echo "Use '$0 help' for usage information"
      exit 1
      ;;
  esac
}

main "$@"
