#!/usr/bin/env bash

# Resolve symlinks so SCRIPT_DIR always points to the real bin/ directory
_self="${BASH_SOURCE[0]}"
[[ -L "$_self" ]] && _self="$(readlink -f "$_self")"
SCRIPT_DIR="$(cd "$(dirname "$_self")" && pwd)"
source "$SCRIPT_DIR/vpn-config.sh"

# No profiles configured — nothing to do
[[ ${#VPN_NAMES[@]} -eq 0 ]] && exit 0

# Skip VPN switching during session restore
RESTORING=$(tmux show-environment -g @vpn_restoring 2>/dev/null | grep -v '^-')
[[ -n "$RESTORING" ]] && exit 0

# Post-restore cooldown: after restore completes, queued client-session-changed
# events fire for multiple sessions. Only the explicit --post-restore call from
# vpn-restore.sh should proceed; all others are suppressed for 10 seconds.
if [[ "$2" != "--post-restore" ]]; then
    COOLDOWN_TS=$(tmux show-environment -g @vpn_restore_cooldown 2>/dev/null | sed 's/.*=//')
    if [[ -n "$COOLDOWN_TS" && "$COOLDOWN_TS" != "-@vpn_restore_cooldown" ]]; then
        NOW=$(date +%s)
        if (( NOW - COOLDOWN_TS < 10 )); then
            exit 0
        else
            # Cooldown expired, clean up
            tmux set-environment -gu @vpn_restore_cooldown
        fi
    fi
fi

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

# No VPN for this session — keep current state
if [[ -z "$SESSION_VPN" || "$SESSION_VPN" == "none" ]]; then
    exit 0
fi

# Already on correct VPN
[[ "$CURRENT_VPN" == "$SESSION_VPN" ]] && exit 0

# Connect via popup
vpn_popup_connect "$SESSION_VPN"
