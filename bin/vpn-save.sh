#!/usr/bin/env bash
# Save session VPN mapping to persistent config

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
