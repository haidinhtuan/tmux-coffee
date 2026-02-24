#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vpn-config.sh"

# No profiles configured — nothing to do
[[ ${#VPN_NAMES[@]} -eq 0 ]] && exit 0

# Skip VPN switching during session restore
RESTORING=$(tmux show-environment -g @vpn_restoring 2>/dev/null | grep -v '^-')
[[ -n "$RESTORING" ]] && exit 0

# Prevent duplicate popups: only one vpn-switch at a time
LOCK_FILE="/tmp/tmux-vpn-switch.lock"
if ! mkdir "$LOCK_FILE" 2>/dev/null; then
    # Another vpn-switch is already running — check if it's stale (>30s)
    if [[ -d "$LOCK_FILE" ]]; then
        lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
        if (( lock_age > 30 )); then
            rmdir "$LOCK_FILE" 2>/dev/null
            mkdir "$LOCK_FILE" 2>/dev/null || exit 0
        else
            exit 0
        fi
    fi
fi
trap 'rmdir "$LOCK_FILE" 2>/dev/null' EXIT

SESSION_NAME="${1:-$(tmux display-message -p '#S')}"
SESSION_VPN=$(tmux show-environment -t "$SESSION_NAME" SESSION_VPN 2>/dev/null | cut -d= -f2)
CURRENT_VPN=$(vpn_detect_active)

# No VPN for this session — disconnect any active
if [[ -z "$SESSION_VPN" || "$SESSION_VPN" == "none" ]]; then
    [[ -n "$CURRENT_VPN" ]] && vpn_disconnect "$CURRENT_VPN"
    exit 0
fi

# Already on correct VPN
[[ "$CURRENT_VPN" == "$SESSION_VPN" ]] && exit 0

# Connect via popup
vpn_popup_connect "$SESSION_VPN"
