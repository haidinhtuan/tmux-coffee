#!/usr/bin/env bash
# Preview for an fzf line: a tmux session, a window target (session:index),
# or a directory.
#
# Usage: coffee-preview.sh <raw fzf line> [state_file]
#        coffee-preview.sh --step <+1|-1|0> <state_file>
#
# Session preview: one line per window, then the tail of the previewed
# window's active pane, sized to $FZF_PREVIEW_LINES.
#
# Window stepping (Alt+Left/Right in the picker): the state file holds an
# offset from the session's active window. The preview writes the previewed
# target to "<state_file>.sel" ("session<TAB>window_index") so that Enter can
# open the session on that window. --step 0 resets (on cursor move).

if [[ "$1" == "--step" ]]; then
    step="$2"; f="$3"
    [[ -z "$f" ]] && exit 0
    if [[ "$step" == 0 ]]; then
        echo 0 > "$f"
    else
        cur=$(cat "$f" 2>/dev/null); cur=${cur:-0}
        echo $(( cur + step )) > "$f"
    fi
    exit 0
fi

BOLD='\033[1m'; MAUVE='\033[38;2;203;166;247m'; PEACH='\033[38;2;255;198;161m'
BLUE='\033[38;2;164;197;255m'; RESET='\033[0m'

# Drill-down: preview one window of a session
if [[ "$1" == "--window" ]]; then
    sess="$2"; idx=$(printf '%s' "$3" | sed 's/^[^0-9]*//; s/[^0-9].*//')
    [[ -z "$sess" || -z "$idx" ]] && exit 0
    t="=$sess:$idx"
    info=$(tmux display-message -p -t "$t" '#{window_name}|#{pane_current_command}|#{pane_current_path}|#{window_panes}' 2>/dev/null) || exit 0
    IFS='|' read -r wname cmd wpath panes <<< "$info"
    [[ "$wpath" == "$HOME"/* ]] && wpath="~/${wpath#"$HOME"/}"
    printf '%b%s › %s: %s%b  %b%s%b  %b%s%b  %s\n\n' "$BOLD$MAUVE" "$sess" "$idx" "$wname" "$RESET" \
        "$PEACH" "$cmd" "$RESET" "$BLUE" "$wpath" "$RESET" "$([[ $panes -gt 1 ]] && echo "[$panes panes]")"
    tmux capture-pane -ep -t "$t" 2>/dev/null |
        awk '{ buf[NR] = $0 } /[^[:space:]]/ { last = NR } END { for (i = 1; i <= last; i++) print buf[i] }' |
        tail -n $(( ${FZF_PREVIEW_LINES:-40} - 2 ))
    exit 0
fi

raw="$1"
state_file="$2"
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
    # centered section heading: dim lines, mauve label
    local label=" $1 " total left right
    total=$(( cols - 2 - ${#label} ))
    (( total < 4 )) && total=4
    left=$(( total / 2 )); right=$(( total - left ))
    printf '%b%s%b%s%b%s%b\n' "$OVERLAY" "$(printf '─%.0s' $(seq 1 "$left"))" \
        "$BOLD$MAUVE" "$label" "$RESET$OVERLAY" "$(printf '─%.0s' $(seq 1 "$right"))" "$RESET"
}

# ---------- session ----------
if [[ "$target" != *:* ]] && tmux has-session -t "=$target" 2>/dev/null; then
    spath=$(tmux display-message -p -t "=$target:" '#{session_path}' 2>/dev/null)
    nwin=$(tmux display-message -p -t "=$target:" '#{session_windows}' 2>/dev/null)
    printf '%b%s%b  %b%s window%s%b  %b%s%b\n' \
        "$BOLD$MAUVE" "$target" "$RESET" \
        "$PEACH" "$nwin" "$([[ $nwin == 1 ]] || echo s)" "$RESET" \
        "$BLUE" "$(short_path "$spath")" "$RESET"

    # which window to preview: active window + offset (wraps around)
    mapfile -t win_idx < <(tmux list-windows -t "=$target:" -F '#{window_index}' 2>/dev/null)
    active_idx=$(tmux display-message -p -t "=$target:" '#{window_index}' 2>/dev/null)
    offset=0
    [[ -n "$state_file" ]] && offset=$(cat "$state_file" 2>/dev/null)
    offset=${offset:-0}
    pos=0
    for i in "${!win_idx[@]}"; do [[ "${win_idx[$i]}" == "$active_idx" ]] && pos=$i; done
    n=${#win_idx[@]}
    (( n > 0 )) && pos=$(( ( (pos + offset) % n + n ) % n ))
    show_idx="${win_idx[$pos]:-$active_idx}"
    [[ -n "$state_file" ]] && printf '%s\t%s\n' "$target" "$show_idx" > "$state_file.sel"

    # window overview
    rule "windows"
    name_w=$(tmux list-windows -t "=$target:" -F '#{window_name}' 2>/dev/null | awk '{ if (length > m) m = length } END { print (m > 20 ? 20 : m) }')
    tmux list-windows -t "=$target:" -F '#{window_active}|#{window_index}|#{window_name}|#{pane_current_command}|#{pane_current_path}|#{window_panes}' 2>/dev/null |
    while IFS='|' read -r active idx wname cmd wpath panes; do
        mark="  "; color="$RESET"
        [[ "$idx" == "$show_idx" ]] && { mark="${GREEN}▶${RESET} "; color="$BOLD"; }
        [[ "$active" == 1 ]] && wname="$wname*"
        [[ ${#wname} -gt 20 ]] && wname="${wname:0:19}…"
        extra=""; (( panes > 1 )) && extra="  ${DIM}[${panes} panes]${RESET}"
        printf '%b%b%2s  %-*s%b  %b%-10s%b  %b%s%b%b\n' \
            "$mark" "$color" "$idx" "$name_w" "$wname" "$RESET" \
            "$PEACH" "${cmd:0:10}" "$RESET" "$DIM" "$(short_path "$wpath")" "$RESET" "$extra"
    done

    used=$(( nwin + 4 ))  # header + rule + windows + blank + rule
    remain=$(( lines - used - 1 ))
    if (( remain > 3 )); then
        echo
        wlabel=$(tmux display-message -p -t "=$target:$show_idx" 'window #{window_index}: #{window_name}' 2>/dev/null)
        hint=""; (( n > 1 )) && hint="  (alt ←/→)"
        rule "$wlabel$hint"
        # drop trailing blank lines, keep the last $remain lines
        tmux capture-pane -ep -t "=$target:$show_idx" 2>/dev/null |
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
