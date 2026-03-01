#!/usr/bin/env bash
#
# vpn-switch.sh — Auto-switch VPN when user changes tmux session
#
# Hook:    client-session-changed (set in coffee.tmux)
# Args:    $1 = session name (from #{session_name})
#          $2 = --post-restore (optional, from vpn-restore.sh after resurrect)
# Flow:
#   1. Skip if restore in progress (@vpn_restoring) or within cooldown window
#   2. Acquire lock to prevent concurrent VPN switches
#   3. Read SESSION_VPN env var from the target session
#   4. Compare with currently active VPN (via vpn_detect_active)
#   5. If different: disconnect old VPN, wait 0.3s, connect new via popup
#

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
    if [[ -d "$LOCK_FILE" ]]; then
        # Check if lock holder is still alive
        _lock_pid=""
        [[ -f "$LOCK_FILE/pid" ]] && _lock_pid=$(cat "$LOCK_FILE/pid" 2>/dev/null)
        if [[ -n "$_lock_pid" ]] && kill -0 "$_lock_pid" 2>/dev/null; then
            # Lock holder is alive — back off
            exit 0
        else
            # Lock holder is dead — clean up and take the lock
            rm -rf "$LOCK_FILE"
            mkdir "$LOCK_FILE" 2>/dev/null || exit 0
        fi
    fi
fi
echo $$ > "$LOCK_FILE/pid"
trap 'rm -rf "$LOCK_FILE" 2>/dev/null' EXIT

SESSION_NAME="${1:-$(tmux display-message -p '#S')}"
SESSION_VPN=$(tmux show-environment -t "$SESSION_NAME" SESSION_VPN 2>/dev/null | cut -d= -f2)
CURRENT_VPN=$(vpn_detect_active)

# No VPN for this session — keep current state
if [[ -z "$SESSION_VPN" || "$SESSION_VPN" == "none" ]]; then
    exit 0
fi

# Already on correct VPN
[[ "$CURRENT_VPN" == "$SESSION_VPN" ]] && exit 0

# Disconnect current VPN before connecting new one to avoid routing conflicts
if [[ -n "$CURRENT_VPN" ]]; then
    vpn_disconnect "$CURRENT_VPN" >/dev/null 2>&1
    sleep 0.3
fi

# Connect via popup
vpn_popup_connect "$SESSION_VPN"
