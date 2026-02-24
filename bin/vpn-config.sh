#!/usr/bin/env bash
# VPN configuration parser for tmux-coffee
# Source this file to get VPN profile data from INI-style config

COFFEE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Get config path from tmux option or use default
VPN_CONFIG_FILE=$(tmux show-option -gqv "@coffee-vpn-config" 2>/dev/null)
VPN_CONFIG_FILE="${VPN_CONFIG_FILE:-$HOME/.tmux/vpn-profiles.conf}"

# Arrays for VPN profiles
VPN_NAMES=()
declare -A VPN_CONNECT
declare -A VPN_DETECT
declare -A VPN_DISCONNECT
declare -A VPN_POST_CONNECT
declare -A VPN_POPUP_W
declare -A VPN_POPUP_H
declare -A VPN_CONNECT_BEFORE

# Parse INI config file
vpn_parse_config() {
    [[ ! -f "$VPN_CONFIG_FILE" ]] && return 0

    local current_section=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip inline comments and trailing whitespace
        line="${line%%#*}"
        [[ -z "${line// }" ]] && continue

        # Section header: [Name]
        if [[ "$line" =~ ^\[(.+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            VPN_NAMES+=("$current_section")
            # Defaults
            VPN_POPUP_W["$current_section"]=60
            VPN_POPUP_H["$current_section"]=10
            VPN_CONNECT_BEFORE["$current_section"]=false
            continue
        fi

        # Key = Value pairs
        if [[ -n "$current_section" && "$line" =~ ^[[:space:]]*([^=]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            # Trim trailing whitespace
            key="${key%"${key##*[![:space:]]}"}"
            value="${value%"${value##*[![:space:]]}"}"

            case "$key" in
                connect)                VPN_CONNECT["$current_section"]="$value" ;;
                detect)                 VPN_DETECT["$current_section"]="$value" ;;
                disconnect)             VPN_DISCONNECT["$current_section"]="$value" ;;
                post_connect)           VPN_POST_CONNECT["$current_section"]="$value" ;;
                popup_width)            VPN_POPUP_W["$current_section"]="$value" ;;
                popup_height)           VPN_POPUP_H["$current_section"]="$value" ;;
                connect_before_session) VPN_CONNECT_BEFORE["$current_section"]="$value" ;;
            esac
        fi
    done < "$VPN_CONFIG_FILE"
}

# Detect which VPN is currently active (returns name or empty)
vpn_detect_active() {
    for name in "${VPN_NAMES[@]}"; do
        if [[ -n "${VPN_DETECT[$name]}" ]] && eval "${VPN_DETECT[$name]}" 2>/dev/null; then
            echo "$name"
            return 0
        fi
    done
    return 1
}

# Disconnect a VPN by profile name
vpn_disconnect() {
    local name="$1"
    if [[ -n "${VPN_DISCONNECT[$name]}" ]]; then
        eval "${VPN_DISCONNECT[$name]}"
    fi
}

# Connect a VPN via tmux popup, then run post_connect hook
vpn_popup_connect() {
    local name="$1"
    local w="${VPN_POPUP_W[$name]:-60}"
    local h="${VPN_POPUP_H[$name]:-10}"
    local cmd="${VPN_CONNECT[$name]}"

    [[ -z "$cmd" ]] && return 1

    tmux display-popup -E -w "$w" -h "$h" -b rounded \
        -T " 󰖂 Connecting to $name " "$cmd"

    # Run post_connect hook if defined
    if [[ -n "${VPN_POST_CONNECT[$name]}" ]]; then
        eval "${VPN_POST_CONNECT[$name]}"
    fi
}

# Parse config on source
vpn_parse_config
