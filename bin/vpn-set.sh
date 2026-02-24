#!/usr/bin/env bash
# Set VPN for current session and save to persistent config
# Usage: vpn-set.sh [VPN_NAME]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vpn-config.sh"

VPN_NAME="${1:-}"
SESSION=$(tmux display-message -p '#S')

if [[ -z "$VPN_NAME" ]]; then
    # Build dynamic list from config
    options="None"
    for name in "${VPN_NAMES[@]}"; do
        options="$options\n$name"
    done
    VPN_NAME=$(printf "$options" | fzf --height=$((${#VPN_NAMES[@]} + 4)) --border --prompt="Select VPN for session '$SESSION': ")
    [[ -z "$VPN_NAME" ]] && exit 0
fi

if [[ "$VPN_NAME" == "None" || "$VPN_NAME" == "none" ]]; then
    tmux set-environment SESSION_VPN "none"
    "$SCRIPT_DIR/vpn-save.sh" "$SESSION" "none"
    echo "Session '$SESSION' set to no VPN"
else
    # Validate VPN name exists in config (exact match, then case-insensitive)
    found=false
    for name in "${VPN_NAMES[@]}"; do
        if [[ "$name" == "$VPN_NAME" ]]; then
            VPN_NAME="$name"
            found=true
            break
        fi
    done
    if [[ "$found" == "false" ]]; then
        for name in "${VPN_NAMES[@]}"; do
            if [[ "${name,,}" == "${VPN_NAME,,}" ]]; then
                VPN_NAME="$name"
                found=true
                break
            fi
        done
    fi
    if [[ "$found" == "false" ]]; then
        echo "Unknown VPN: $VPN_NAME"
        echo "Valid options: none, $(IFS=', '; echo "${VPN_NAMES[*]}")"
        exit 1
    fi
    tmux set-environment SESSION_VPN "$VPN_NAME"
    "$SCRIPT_DIR/vpn-save.sh" "$SESSION" "$VPN_NAME"
    echo "Session '$SESSION' set to $VPN_NAME VPN"
fi
