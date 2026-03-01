#!/usr/bin/env bash
#
# vpn-cleanup.sh — Remove orphaned VPN mappings from config
#
# Hook:    session-closed (set in coffee.tmux, runs in background with -b)
# Args:    none
# Flow:
#   1. List all existing tmux sessions
#   2. Read ~/.tmux/vpn-sessions.conf
#   3. Drop entries whose session no longer exists
#   4. Rewrite config in place
#
# Also called by vpn-restore.sh after resurrect to clean stale entries.

CONFIG_FILE="$HOME/.tmux/vpn-sessions.conf"
TEMP_FILE="${CONFIG_FILE}.tmp"

[[ ! -f "$CONFIG_FILE" ]] && exit 0

# Get list of existing sessions
existing_sessions=$(tmux list-sessions -F '#S' 2>/dev/null)

# Don't cleanup if no sessions exist (server is shutting down)
[[ -z "$existing_sessions" ]] && exit 0

# Keep only header and mappings for existing sessions
echo "# Session to VPN mappings (auto-generated)" > "$TEMP_FILE"

while IFS='=' read -r session vpn; do
    # Skip comments and empty lines
    [[ "$session" =~ ^#.*$ || -z "$session" ]] && continue

    # Keep only if session still exists
    if echo "$existing_sessions" | grep -qx "$session"; then
        echo "${session}=${vpn}" >> "$TEMP_FILE"
    fi
done < "$CONFIG_FILE"

mv "$TEMP_FILE" "$CONFIG_FILE"
