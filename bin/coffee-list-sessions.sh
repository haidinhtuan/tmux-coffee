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

# Relative time from epoch timestamp
relative_time() {
    local ts=$1 now diff
    now=$(date +%s)
    diff=$((now - ts))
    if (( diff < 60 )); then echo "<1m"
    elif (( diff < 3600 )); then echo "$((diff / 60))m"
    elif (( diff < 86400 )); then echo "$((diff / 3600))h"
    else echo "$((diff / 86400))d"
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

    # Working dir (basename, or ~ for $HOME)
    if [[ "$pane_path" == "$HOME" ]]; then
        dir="~"
    else
        dir=$(basename "$pane_path")
    fi
    [[ ${#dir} -gt 12 ]] && dir="${dir:0:10}.."

    # Time
    time_str="$(relative_time "$last_ts")"

    printf "%b%s\t%b%sw  %-12s %-12s %s%b\n" \
        "$marker" "$name" "$DIM" "$windows" "$vpn" "$dir" "$time_str" "$RESET"
done
