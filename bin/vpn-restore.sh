#!/usr/bin/env bash
# Restore session VPN mappings from persistent config
# Called by tmux-resurrect post-restore-all hook

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

# Step 3: Clear the restoring flag
# VPN connection is handled by the client-session-changed hook (vpn-switch.sh)
# which fires naturally when the client lands on the restored session
tmux set-environment -gu @vpn_restoring
