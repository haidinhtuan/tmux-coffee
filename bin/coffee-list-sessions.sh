#!/usr/bin/env bash
# List tmux sessions with rich metadata and color.
#
# Usage: coffee-list-sessions.sh [--no-current] [--header]
#   --no-current  exclude the current session and omit markers (mixed zoxide view)
#   --header      print only the column header matching the current layout
#
# Width-aware: columns are chosen to fit the space the list actually gets.
#   Width source: $FZF_COLUMNS (inside fzf), else $COFFEE_COLUMNS (set by
#   coffee.sh before the popup opens), else the terminal width.
#   When the layout is side-by-side (width >= COFFEE_SPLIT_AT), the list only
#   gets ~40% of it; otherwise the full width.
#
# Line format: "<marker><name padded>\t<metadata>". Everything before the TAB
# is the session name (+ padding); callers use `cut -f1` and trim spaces.

NO_CURRENT=false
HEADER_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --no-current) NO_CURRENT=true ;;
        --header)     HEADER_ONLY=true ;;
    esac
done

CURRENT=$(tmux display-message -p '#S' 2>/dev/null)
CONFIG_FILE="$HOME/.tmux/vpn-sessions.conf"

# ---------- available width ----------
total_w=${FZF_COLUMNS:-${COFFEE_COLUMNS:-$(tput cols 2>/dev/null || echo 120)}}
split_at=${COFFEE_SPLIT_AT:-160}
if (( total_w >= split_at )); then
    list_w=$(( total_w * 40 / 100 - 4 ))
else
    list_w=$(( total_w - 4 ))
fi

# ---------- VPN mappings ----------
declare -A VPN_MAP
any_vpn=false
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS='=' read -r session vpn; do
        [[ -z "$session" || "$session" == \#* ]] && continue
        VPN_MAP["$session"]="$vpn"
        [[ -n "$vpn" && "$vpn" != "none" ]] && any_vpn=true
    done < "$CONFIG_FILE"
fi

# ---------- colors (Catppuccin-ish pastels) ----------
DIM='\033[2m'
GREEN='\033[38;2;189;240;185m'
BGREEN='\033[1;38;2;189;240;185m'
CYAN='\033[38;2;168;240;229m'
BLUE='\033[38;2;164;197;255m'
MAGENTA='\033[38;2;245;194;231m'
YELLOW='\033[38;2;255;240;194m'
RED='\033[38;2;255;181;194m'
HDR='\033[1;38;2;147;153;178m'   # overlay2, bold
RESET='\033[0m'

now=$(date +%s)

# Compact relative time: now, 5m, 2h, 3d, 5w
rel_time() {
    local d=$(( now - $1 ))
    if   (( d < 60 ));      then echo "now"
    elif (( d < 3600 ));    then echo "$(( d / 60 ))m"
    elif (( d < 86400 ));   then echo "$(( d / 3600 ))h"
    elif (( d < 604800 ));  then echo "$(( d / 86400 ))d"
    else                         echo "$(( d / 604800 ))w"
    fi
}

time_color() {
    local d=$(( now - $1 ))
    if   (( d < 300 ));   then printf '%s' "$GREEN"
    elif (( d < 3600 ));  then printf '%s' "$YELLOW"
    elif (( d < 86400 )); then printf '%s' "$DIM"
    else                       printf '%s' "$RED"
    fi
}

# ---------- collect sessions (most recently active first) ----------
mapfile -t rows < <(
    tmux list-sessions -F '#{session_activity}|#{session_name}|#{session_windows}|#{session_path}|#{window_name}|#{session_attached}' 2>/dev/null |
        sort -t'|' -k1 -rn
)

# Name column width: longest name, capped
name_w=7   # "SESSION"
for r in "${rows[@]}"; do
    IFS='|' read -r _ n _ _ _ _ <<< "$r"
    (( ${#n} > name_w )) && name_w=${#n}
done
(( name_w > 28 )) && name_w=28

# ---------- choose columns to fit list_w ----------
# fixed: marker(2) name(name_w) gap(2) attach(2) windows(3) gap(2) time(4)
base=$(( 2 + name_w + 2 + 2 + 3 + 2 + 4 ))
show_win=false; show_dir=false; show_vpn=false
win_w=14; dir_w=26; vpn_w=12
avail=$(( list_w - base ))
if (( avail >= win_w + 2 )); then show_win=true; avail=$(( avail - win_w - 2 )); fi
if (( avail >= 16 + 2 )); then
    show_dir=true
    (( avail - 2 < dir_w )) && dir_w=$(( avail - 2 ))
    (( avail - 2 > 40 )) && dir_w=40
    avail=$(( avail - dir_w - 2 ))
fi
if $any_vpn && (( avail >= vpn_w + 2 )); then show_vpn=true; fi

# Pad by characters, not bytes (bash printf pads bytes; ∕ and … are 3 bytes)
pad() { local s="$1" w="$2"; printf '%s%*s' "$s" $(( w > ${#s} ? w - ${#s} : 0 )) ''; }
pad_name() { pad "${1:0:$name_w}" "$name_w"; }

# ---------- header ----------
if $HEADER_ONLY; then
    line="  $(pad_name SESSION)"$'\t'"  $(printf '%3s' '#')"
    $show_vpn && line+="  $(printf "%-${vpn_w}s" VPN)"
    $show_dir && line+="  $(printf "%-${dir_w}s" DIR)"
    $show_win && line+="  $(printf "%-${win_w}s" WINDOW)"
    line+="  $(printf '%4s' AGO)"
    printf '%b%s%b\n' "$HDR" "$line" "$RESET"
    exit 0
fi

# ---------- rows ----------
for r in "${rows[@]}"; do
    IFS='|' read -r ts name windows spath win_name attached <<< "$r"
    [[ "$NO_CURRENT" == true && "$name" == "$CURRENT" ]] && continue

    if [[ "$NO_CURRENT" == false ]]; then
        [[ "$name" == "$CURRENT" ]] && marker="${BGREEN}●${RESET} " || marker="  "
    else
        marker=""
    fi

    # attached by another client
    if [[ "$attached" -gt 0 && "$name" != "$CURRENT" ]] || [[ "$attached" -gt 1 ]]; then
        attach="${GREEN}${RESET} "
    else
        attach="  "
    fi

    meta="${attach}${CYAN}$(printf '%3s' "$windows")${RESET}"

    if $show_vpn; then
        vpn="${VPN_MAP[$name]:-}"
        [[ "$vpn" == "none" ]] && vpn=""
        (( ${#vpn} > vpn_w )) && vpn="${vpn:0:$((vpn_w - 2))}.."
        if [[ -n "$vpn" ]]; then
            meta+="  ${GREEN}$(printf "%-${vpn_w}s" "$vpn")${RESET}"
        else
            meta+="  ${DIM}$(printf "%-${vpn_w}s" '·')${RESET}"
        fi
    fi

    if $show_dir; then
        if   [[ "$spath" == "$HOME" ]];   then dir="~"
        elif [[ "$spath" == "$HOME"/* ]]; then dir="~/${spath#"$HOME"/}"
        else dir="$spath"; fi
        (( ${#dir} > dir_w )) && dir="…${dir: -$((dir_w - 1))}"
        # U+2215 so fzf --delimiter='/' never splits session lines
        dir="${dir//\//$'\xe2\x88\x95'}"
        meta+="  ${BLUE}$(pad "$dir" "$dir_w")${RESET}"
    fi

    if $show_win; then
        (( ${#win_name} > win_w )) && win_name="${win_name:0:$((win_w - 2))}.."
        win_name="${win_name//\//$'\xe2\x88\x95'}"
        meta+="  ${MAGENTA}$(pad "$win_name" "$win_w")${RESET}"
    fi

    meta+="  $(time_color "$ts")$(printf '%4s' "$(rel_time "$ts")")${RESET}"

    printf '%b%s\t%b\n' "$marker" "$(pad_name "$name")" "$meta"
done
