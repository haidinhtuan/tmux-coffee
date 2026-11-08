#!/usr/bin/env bash
# Preview for an fzf line: a tmux session, a window target (session:index),
# or a directory.
#
# Usage: coffee-preview.sh <raw fzf line>
#
# Session preview: one line per window (active marked), then the tail of the
# active pane, sized to $FZF_PREVIEW_LINES.

raw="$1"
esc=$'\x1b'
# strip ANSI, session marker, metadata after TAB, trailing padding
target=$(printf '%s' "$raw" | sed "s/${esc}\[[0-9;]*m//g" | sed -e 's/^● //' -e 's/^  //' | cut -f1 | sed 's/[[:space:]]*$//')
[[ -z "$target" ]] && exit 0

lines=${FZF_PREVIEW_LINES:-40}
cols=${FZF_PREVIEW_COLUMNS:-80}

BOLD='\033[1m'
DIM='\033[2m'
MAUVE='\033[38;2;203;166;247m'
BLUE='\033[38;2;164;197;255m'
PEACH='\033[38;2;255;198;161m'
GREEN='\033[38;2;189;240;185m'
OVERLAY='\033[38;2;108;112;134m'
RESET='\033[0m'

short_path() {
    local p="$1"
    [[ "$p" == "$HOME" ]] && { echo "~"; return; }
    [[ "$p" == "$HOME"/* ]] && p="~/${p#"$HOME"/}"
    echo "$p"
}

rule() {
    local label="$1" n
    n=$(( cols - ${#label} - 5 ))
    (( n < 0 )) && n=0
    printf '%b── %s %s%b\n' "$OVERLAY" "$label" "$(printf '─%.0s' $(seq 1 "$n"))" "$RESET"
}

# ---------- session ----------
if [[ "$target" != *:* ]] && tmux has-session -t "=$target" 2>/dev/null; then
    spath=$(tmux display-message -p -t "=$target:" '#{session_path}' 2>/dev/null)
    nwin=$(tmux display-message -p -t "=$target:" '#{session_windows}' 2>/dev/null)
    printf '%b%s%b  %b%s window%s%b  %b%s%b\n\n' \
        "$BOLD$MAUVE" "$target" "$RESET" \
        "$PEACH" "$nwin" "$([[ $nwin == 1 ]] || echo s)" "$RESET" \
        "$BLUE" "$(short_path "$spath")" "$RESET"

    # window overview
    name_w=$(tmux list-windows -t "=$target:" -F '#{window_name}' 2>/dev/null | awk '{ if (length > m) m = length } END { print (m > 20 ? 20 : m) }')
    tmux list-windows -t "=$target:" -F '#{window_active}|#{window_index}|#{window_name}|#{pane_current_command}|#{pane_current_path}|#{window_panes}' 2>/dev/null |
    while IFS='|' read -r active idx wname cmd wpath panes; do
        mark="  "; color="$RESET"
        [[ "$active" == 1 ]] && { mark="${GREEN}▶${RESET} "; color="$BOLD"; }
        [[ ${#wname} -gt 20 ]] && wname="${wname:0:19}…"
        extra=""; (( panes > 1 )) && extra="  ${DIM}[${panes} panes]${RESET}"
        printf '%b%b%2s  %-*s%b  %b%-10s%b  %b%s%b%b\n' \
            "$mark" "$color" "$idx" "$name_w" "$wname" "$RESET" \
            "$PEACH" "${cmd:0:10}" "$RESET" "$DIM" "$(short_path "$wpath")" "$RESET" "$extra"
    done

    used=$(( nwin + 4 ))
    remain=$(( lines - used - 1 ))
    if (( remain > 3 )); then
        echo
        rule "active pane"
        # drop trailing blank lines, keep the last $remain lines
        tmux capture-pane -ep -t "=$target:" 2>/dev/null |
            awk '{ buf[NR] = $0 } /[^[:space:]]/ { last = NR } END { for (i = 1; i <= last; i++) print buf[i] }' |
            tail -n "$remain"
    fi
    exit 0
fi

# ---------- window target (session:index) ----------
if [[ "$target" == *:* ]] && tmux has-session -t "${target%%:*}" 2>/dev/null; then
    tmux capture-pane -ep -t "$target" 2>/dev/null
    exit 0
fi

# ---------- directory ----------
dir="$target"
[[ "$dir" == "~" ]] && dir="$HOME"
[[ "$dir" == "~/"* ]] && dir="$HOME/${dir#"~/"}"
if [[ -d "$dir" ]]; then
    if command -v eza >/dev/null 2>&1; then
        # shellcheck disable=SC2086
        eza ${COFFEE_EZA_OPTIONS:--ahlT -L=2 --group-directories-first --icons --git --no-user --color=always} "$dir"
    else
        ls -la --color=always "$dir"
    fi
fi
