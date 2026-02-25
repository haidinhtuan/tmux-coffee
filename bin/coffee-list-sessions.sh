#!/usr/bin/env bash
# List tmux sessions with rich metadata and color
# Usage: coffee-list-sessions.sh [--no-current]
#   --no-current: exclude current session and omit markers (for default mixed view)

NO_CURRENT=false
[[ "$1" == "--no-current" ]] && NO_CURRENT=true

CURRENT=$(tmux display-message -p '#S' 2>/dev/null)
CONFIG_FILE="$HOME/.tmux/vpn-sessions.conf"

# Load VPN mappings
declare -A VPN_MAP
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS='=' read -r session vpn; do
        [[ -z "$session" || "$session" == \#* ]] && continue
        VPN_MAP["$session"]="$vpn"
    done < "$CONFIG_FILE"
fi

# Colors
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
BGREEN='\033[1;32m'
CYAN='\033[36m'
BLUE='\033[34m'
MAGENTA='\033[35m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

# Relative time from epoch timestamp
relative_time() {
    local ts=$1 now diff
    now=$(date +%s)
    diff=$((now - ts))
    if (( diff < 60 )); then
        echo "<1m ago"
    elif (( diff < 3600 )); then
        local mins=$((diff / 60))
        echo "${mins}m ago"
    elif (( diff < 86400 )); then
        local hrs=$((diff / 3600))
        local mins=$(( (diff % 3600) / 60 ))
        if (( mins > 0 )); then
            echo "${hrs}h ${mins}m ago"
        else
            echo "${hrs}h ago"
        fi
    else
        local days=$((diff / 86400))
        local hrs=$(( (diff % 86400) / 3600 ))
        if (( hrs > 0 )); then
            echo "${days}d ${hrs}h ago"
        else
            echo "${days}d ago"
        fi
    fi
}

# Time color based on recency
time_color() {
    local ts=$1 now diff
    now=$(date +%s)
    diff=$((now - ts))
    if (( diff < 300 )); then
        echo "$GREEN"
    elif (( diff < 3600 )); then
        echo "$YELLOW"
    elif (( diff < 86400 )); then
        echo "$DIM"
    else
        echo "$RED"
    fi
}


tmux list-sessions -F '#{session_last_attached}|#{session_name}|#{session_windows}|#{pane_current_path}|#{pane_current_command}|#{session_attached}' 2>/dev/null |
    sort -t'|' -k1 -rn |
while IFS='|' read -r last_ts name windows pane_path cmd attached; do
    # Skip current session if --no-current
    [[ "$NO_CURRENT" == true && "$name" == "$CURRENT" ]] && continue

    # Marker
    if [[ "$NO_CURRENT" == false ]]; then
        if [[ "$name" == "$CURRENT" ]]; then
            marker="${BGREEN}●${RESET} "
        else
            marker="  "
        fi
    else
        marker=""
    fi

    # VPN
    vpn="${VPN_MAP[$name]:-}"
    [[ -z "$vpn" || "$vpn" == "none" ]] && vpn=""
    [[ ${#vpn} -gt 12 ]] && vpn="${vpn:0:10}.."

    # Working dir (relative to $HOME, truncate from left if long)
    if [[ "$pane_path" == "$HOME" ]]; then
        dir="~"
    elif [[ "$pane_path" == "$HOME"/* ]]; then
        dir="~/${pane_path#$HOME/}"
    else
        dir="$pane_path"
    fi
    [[ ${#dir} -gt 24 ]] && dir="..${dir: -22}"

    # Time
    time_str="$(relative_time "$last_ts")"
    tc="$(time_color "$last_ts")"

    # Command (truncate)
    [[ ${#cmd} -gt 10 ]] && cmd="${cmd:0:8}.."

    # Attached indicator (other clients)
    if [[ "$attached" -gt 0 && "$name" != "$CURRENT" ]]; then
        attach_icon="${GREEN} ${RESET}"
    elif [[ "$attached" -gt 1 ]]; then
        attach_icon="${GREEN} ${RESET}"
    else
        attach_icon="  "
    fi

    # Build colored segments (pad visible text inside color codes for alignment)
    win_seg="${CYAN}$(printf ' %-2s' "$windows")${RESET}"

    if [[ -n "$vpn" ]]; then
        vpn_seg="${GREEN}$(printf '%-12s' "$vpn")${RESET}"
    else
        vpn_seg="${DIM}$(printf '%-12s' '--')${RESET}"
    fi

    dir_seg="${BLUE}$(printf '%-24s' "$dir")${RESET}"
    cmd_seg="${MAGENTA}$(printf ' %-10s' "$cmd")${RESET}"
    time_seg="${tc}$(printf ' %s' "$time_str")${RESET}"

    # Truncate session name to fit column
    [[ ${#name} -gt 18 ]] && name="${name:0:16}.."
    printf "%b%s\t%b %b  %b  %b  %b  %b\n" \
        "$marker" "$name" "$attach_icon" "$win_seg" "$vpn_seg" "$dir_seg" "$cmd_seg" "$time_seg"
done
