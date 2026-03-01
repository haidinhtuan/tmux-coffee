#!/usr/bin/env bash
#
# vpn-restore-session.sh — Restore VPN env var for a single session
#
# Hook:    session-created (set in coffee.tmux, runs in background with -b)
# Args:    $1 = session name (from #{hook_session_name})
# Flow:
#   1. Look up session name in ~/.tmux/vpn-sessions.conf
#   2. If found, set SESSION_VPN env var in the session
#   3. Apply post_connect env vars (e.g. SSH_AUTH_SOCK) per-session
#
# Does NOT connect VPN — that happens via vpn-switch.sh when you switch to it.
# Works for both new sessions and sessions restored by tmux-resurrect.

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
