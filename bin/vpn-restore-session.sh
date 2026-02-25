#!/usr/bin/env bash
# Restore VPN mapping for a single session when it's created
# Called by session-created hook and works for both new and restored sessions
#
# This script ONLY restores environment variables.
# VPN connection and OSUM are handled by vpn-switch.sh on manual session switch.

# Resolve symlinks so SCRIPT_DIR always points to the real bin/ directory
_self="${BASH_SOURCE[0]}"
[[ -L "$_self" ]] && _self="$(readlink -f "$_self")"
SCRIPT_DIR="$(cd "$(dirname "$_self")" && pwd)"
source "$SCRIPT_DIR/vpn-config.sh"

CONFIG_FILE="$HOME/.tmux/vpn-sessions.conf"
SESSION_NAME="$1"

[[ ! -f "$CONFIG_FILE" ]] && exit 0
[[ -z "$SESSION_NAME" ]] && exit 0

# Look up VPN mapping for this session
vpn=$(grep "^${SESSION_NAME}=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2-)

if [[ -n "$vpn" ]]; then
    tmux set-environment -t "$SESSION_NAME" SESSION_VPN "$vpn"

    # Apply post_connect env vars per-session (not globally) during restore
    if [[ -n "${VPN_POST_CONNECT[$vpn]+x}" ]]; then
        _cmd="${VPN_POST_CONNECT[$vpn]}"
        _cmd="${_cmd//set-environment -g/set-environment -t \"$SESSION_NAME\"}"
        eval "$_cmd"
    fi
fi
