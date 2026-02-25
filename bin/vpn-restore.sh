#!/usr/bin/env bash
# Restore session VPN mappings from persistent config
# Called by tmux-resurrect post-restore-all hook

# Resolve symlinks so SCRIPT_DIR always points to the real bin/ directory
_self="${BASH_SOURCE[0]}"
[[ -L "$_self" ]] && _self="$(readlink -f "$_self")"
SCRIPT_DIR="$(cd "$(dirname "$_self")" && pwd)"
source "$SCRIPT_DIR/vpn-config.sh"

CONFIG_FILE="$HOME/.tmux/vpn-sessions.conf"

[[ ! -f "$CONFIG_FILE" ]] && exit 0

# Step 1: Restore environment variables for all sessions
while IFS='=' read -r session vpn; do
    # Skip comments and empty lines
    [[ "$session" =~ ^#.*$ || -z "$session" ]] && continue

    # Check if session exists
    if tmux has-session -t "$session" 2>/dev/null; then
        tmux set-environment -t "$session" SESSION_VPN "$vpn"

        # Apply post_connect env vars per-session (not globally) during restore
        if [[ -n "${VPN_POST_CONNECT[$vpn]+x}" ]]; then
            _cmd="${VPN_POST_CONNECT[$vpn]}"
            _cmd="${_cmd//set-environment -g/set-environment -t \"$session\"}"
            eval "$_cmd"
        fi
    fi
done < "$CONFIG_FILE"

# Step 2: Clean up orphaned entries
"$SCRIPT_DIR/vpn-cleanup.sh"

# Step 3: Set cooldown timestamp to suppress queued client-session-changed events
# that fire for multiple sessions after the restoring flag is cleared.
# Only the explicit vpn-switch call below (with --post-restore) will proceed.
tmux set-environment -g @vpn_restore_cooldown "$(date +%s)"
tmux set-environment -gu @vpn_restoring

# Step 4: Connect VPN for the current session only
CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)
if [[ -n "$CURRENT_SESSION" ]]; then
    "$SCRIPT_DIR/vpn-switch.sh" "$CURRENT_SESSION" --post-restore
fi
