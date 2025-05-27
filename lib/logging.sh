#!/bin/zsh

# Logging configuration
# Log levels (lower number = higher priority)
readonly LOG_LEVEL_ERROR=0
readonly LOG_LEVEL_WARNING=1
readonly LOG_LEVEL_INFO=2
readonly LOG_LEVEL_DEBUG=3

# Default log level (can be overridden by MACBOOK_SETUP_LOG_LEVEL)
CURRENT_LOG_LEVEL=${MACBOOK_SETUP_LOG_LEVEL:-2}  # Default to INFO

# Colors
readonly LOG_COLOR_ERROR='\033[0;31m'    # Red
readonly LOG_COLOR_WARNING='\033[0;33m'  # Yellow
readonly LOG_COLOR_INFO='\033[0;34m'     # Blue
readonly LOG_COLOR_DEBUG='\033[0;90m'    # Gray
readonly LOG_COLOR_SUCCESS='\033[0;32m'  # Green
readonly LOG_COLOR_RESET='\033[0m'

# Logging utility functions
log() {
    local level=$1
    local color=$2
    local prefix=$3
    local message=$4
    
    # Check if this log level should be displayed
    if [[ $level -le $CURRENT_LOG_LEVEL ]]; then
        printf "%b[%s]%b %s\n" "$color" "$prefix" "$LOG_COLOR_RESET" "$message" >&2
    fi
}

log_error() {
    log $LOG_LEVEL_ERROR "$LOG_COLOR_ERROR" "ERROR" "$1"
}

log_warning() {
    log $LOG_LEVEL_WARNING "$LOG_COLOR_WARNING" "WARNING" "$1"
}

log_info() {
    log $LOG_LEVEL_INFO "$LOG_COLOR_INFO" "INFO" "$1"
}

log_debug() {
    log $LOG_LEVEL_DEBUG "$LOG_COLOR_DEBUG" "DEBUG" "$1"
}

log_success() {
    log $LOG_LEVEL_INFO "$LOG_COLOR_SUCCESS" "SUCCESS" "$1"
}

# Function to set log level
set_log_level() {
    local level=$1
    if [[ $level =~ ^[0-3]$ ]]; then
        CURRENT_LOG_LEVEL=$level
        log_debug "Log level set to $level"
        return 0
    else
        log_error "Invalid log level: $level (must be 0-3)"
        return 1
    fi
}

# Function to get current log level name
get_log_level_name() {
    case $CURRENT_LOG_LEVEL in
        0) echo "ERROR" ;;
        1) echo "WARNING" ;;
        2) echo "INFO" ;;
        3) echo "DEBUG" ;;
        *) echo "UNKNOWN" ;;
    esac
}

# Progress indicator functions
start_progress() {
    if [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_INFO ]]; then
        printf '%b[INFO]%b %s ... ' "$LOG_COLOR_INFO" "$LOG_COLOR_RESET" "$1" >&2
    fi
}

end_progress() {
    local status=$1  # "success", "warning", or "error"
    local message=${2:-""}
    
    if [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_INFO ]]; then
        case "$status" in
            "success")
                printf '%b✓%b\n' "$LOG_COLOR_SUCCESS" "$LOG_COLOR_RESET" >&2
                [[ -n "$message" ]] && log_success "$message"
                ;;
            "warning")
                printf '%b⚠%b\n' "$LOG_COLOR_WARNING" "$LOG_COLOR_RESET" >&2
                [[ -n "$message" ]] && log_warning "$message"
                ;;
            "error")
                printf '%b✗%b\n' "$LOG_COLOR_ERROR" "$LOG_COLOR_RESET" >&2
                [[ -n "$message" ]] && log_error "$message"
                ;;
        esac
    fi
}

# Initialize log level from environment variable if set
[[ -n "$MACBOOK_SETUP_LOG_LEVEL" ]] && set_log_level "$MACBOOK_SETUP_LOG_LEVEL"

# Export functions and variables
export CURRENT_LOG_LEVEL
export -f log_error log_warning log_info log_debug log_success set_log_level get_log_level_name
export -f start_progress end_progress 