#!/usr/bin/env bash
#
# vpn-save.sh — Persist a session-to-VPN mapping
#
# Hook:    none (called by vpn-set.sh and coffee-new-session.sh)
# Args:    $1 = session name
#          $2 = VPN profile name (or "none" to remove mapping)
# Config:  ~/.tmux/vpn-sessions.conf (key=value, auto-generated)

CONFIG_FILE="$HOME/.tmux/vpn-sessions.conf"
SESSION="$1"
VPN="$2"

[[ -z "$SESSION" || -z "$VPN" ]] && exit 1

# Remove existing entry for this session
grep -v "^${SESSION}=" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" 2>/dev/null
mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# Add new entry (unless VPN is "none")
if [[ "$VPN" != "none" ]]; then
    echo "${SESSION}=${VPN}" >> "$CONFIG_FILE"
fi
