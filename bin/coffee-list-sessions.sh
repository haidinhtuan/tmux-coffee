#!/usr/bin/env bash
# List tmux sessions with metadata (window count, VPN, working dir, last attached)
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
GREEN='\033[1;32m'
DIM='\033[2m'
RESET='\033[0m'

# Relative time from epoch timestamp (e.g., "2h 15m ago", "3d 4h ago")
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

tmux list-sessions -F '#{session_last_attached}|#{session_name}|#{session_windows}|#{pane_current_path}' 2>/dev/null |
    sort -t'|' -k1 -rn |
while IFS='|' read -r last_ts name windows pane_path; do
    # Skip current session if --no-current
    [[ "$NO_CURRENT" == true && "$name" == "$CURRENT" ]] && continue

    # Marker
    if [[ "$NO_CURRENT" == false ]]; then
        if [[ "$name" == "$CURRENT" ]]; then
            marker="${GREEN}●${RESET} "
        else
            marker="  "
        fi
    else
        marker=""
    fi

    # VPN
    vpn="${VPN_MAP[$name]:-}"
    [[ -z "$vpn" || "$vpn" == "none" ]] && vpn="--"
    [[ ${#vpn} -gt 12 ]] && vpn="${vpn:0:10}.."

    # Working dir (relative to $HOME, truncate from left if long)
    if [[ "$pane_path" == "$HOME" ]]; then
        dir="~"
    elif [[ "$pane_path" == "$HOME"/* ]]; then
        dir="~/${pane_path#$HOME/}"
    else
        dir="$pane_path"
    fi
    if [[ ${#dir} -gt 28 ]]; then
        dir="..${dir: -26}"
    fi

    # Time
    time_str="$(relative_time "$last_ts")"

    printf "%b%s\t%b%sw  %-12s %-28s %s%b\n" \
        "$marker" "$name" "$DIM" "$windows" "$vpn" "$dir" "$time_str" "$RESET"
done
