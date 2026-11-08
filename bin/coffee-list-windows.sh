#!/usr/bin/env bash
# List the windows of one session for the drill-down view.
#
# Usage: coffee-list-windows.sh <session>
#
# Line format: "<index>\t<name>  <command>  <dir>  [N panes]"
# Field 1 is the window index; the session comes from the picker's mode file.

session="$1"
[[ -z "$session" ]] && exit 0

PEACH='\033[38;2;255;198;161m'
BLUE='\033[38;2;164;197;255m'
GREEN='\033[38;2;189;240;185m'
CYAN='\033[38;2;168;240;229m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

short_path() {
    local p="$1"
    [[ "$p" == "$HOME" ]] && { echo "~"; return; }
    [[ "$p" == "$HOME"/* ]] && p="~/${p#"$HOME"/}"
    echo "$p"
}
pad() { local s="$1" w="$2"; printf '%s%*s' "$s" $(( w > ${#s} ? w - ${#s} : 0 )) ''; }

# Width the list gets (same rule as coffee-list-sessions.sh)
total_w=${FZF_COLUMNS:-${COFFEE_COLUMNS:-$(tput cols 2>/dev/null || echo 120)}}
if (( total_w >= ${COFFEE_SPLIT_AT:-160} )); then list_w=$(( total_w * 40 / 100 - 4 )); else list_w=$(( total_w - 4 )); fi

name_w=$(tmux list-windows -t "=$session:" -F '#{window_name}' 2>/dev/null |
    awk '{ if (length > m) m = length } END { m += 1; print (m > 22 ? 22 : (m < 6 ? 6 : m)) }')

tmux list-windows -t "=$session:" \
    -F '#{window_index}|#{window_active}|#{window_name}|#{pane_current_command}|#{pane_current_path}|#{window_panes}' 2>/dev/null |
while IFS='|' read -r idx active name cmd path panes; do
    mark="  "; style=""
    [[ "$active" == 1 ]] && { mark="${GREEN}●${RESET} "; style="$BOLD"; }
    (( ${#name} > name_w )) && name="${name:0:$((name_w - 1))}…"
    extra=""; extra_len=0
    (( panes > 1 )) && { extra="  ${DIM}[${panes}p]${RESET}"; extra_len=6; }
    # fit the path into what is left: mark(2) idx(2) tab(1) name gap cmd(10) gaps(4)
    path=$(short_path "$path")
    path_w=$(( list_w - 2 - 2 - 1 - name_w - 2 - 10 - 2 - extra_len - 5 ))
    (( path_w < 8 )) && path_w=8
    (( ${#path} > path_w )) && path="…${path: -$((path_w - 1))}"
    printf '%b%s\t%b%b%s%b  %b%s%b  %b%s%b%b\n' \
        "$mark" "$(printf '%2s' "$idx")" \
        "$style" "$CYAN" "$(pad "$name" "$name_w")" "$RESET" \
        "$PEACH" "$(pad "${cmd:0:10}" 10)" "$RESET" \
        "$BLUE" "$path" "$RESET" "$extra"
done
