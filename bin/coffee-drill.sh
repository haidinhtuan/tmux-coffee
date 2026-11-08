#!/usr/bin/env bash
# Drill-down between the session list and one session's windows.
# Called by fzf `transform` on Right/Left; prints the fzf actions to run.
#
# Usage: coffee-drill.sh in|out <mode_file> <pwin_file> <query> <focused line>
#
#   in  (Right): in SESSIONS mode with an empty query, show the focused
#                session's windows (cursor on its active window). Mode file
#                becomes "SESSWIN<TAB><session>".
#   out (Left):  in SESSWIN mode, go back to the session list with the cursor
#                on that session.
# Anything else falls through to the normal cursor movement in the query.

dir="$1"; mode_file="$2"; pwin_file="$3"; query="$4"; line="$5"
BIN_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
mode=$(cat "$mode_file" 2>/dev/null)

esc=$'\x1b'
strip() { printf '%s' "$1" | sed "s/${esc}\[[0-9;]*m//g" | sed -e 's/^● //' -e 's/^  //' | cut -f1 | sed 's/[[:space:]]*$//'; }
# quote for use inside an fzf action argument run by sh
q() { printf "'%s'" "${1//\'/\'\\\'\'}"; }

footer="bash $BIN_DIR/coffee-draw-footer.sh"

if [[ "$dir" == in ]]; then
    if [[ "$mode" != SESSIONS || -n "$query" ]]; then echo "forward-char"; exit 0; fi
    session=$(strip "$line")
    if [[ -z "$session" ]] || ! tmux has-session -t "=$session" 2>/dev/null; then
        echo "forward-char"; exit 0
    fi
    printf 'SESSWIN\t%s\n' "$session" > "$mode_file"
    # 1-based position of the active window in the list
    pos=$(tmux list-windows -t "=$session:" -F '#{window_active}' 2>/dev/null | grep -n '^1$' | cut -d: -f1)
    pos=${pos:-1}
    # peach label marks the window level (sessions level uses the default mauve)
    label=$'\e[1;38;2;250;179;135m'" $session › windows "$'\e[0m'
    printf '%s' "reload-sync(bash $BIN_DIR/coffee-list-windows.sh $(q "$session"))"
    printf '%s' "+change-list-label~${label//\~/-}~"
    printf '%s' "+change-header(   #  WINDOW  ·  ← sessions  ·  enter: switch to window)"
    printf '%s' "+change-preview(bash $BIN_DIR/coffee-preview.sh --window $(q "$session") {1})"
    printf '%s' "+pos($pos)"
    printf '%s' "+execute-silent($footer WINDOWS)"
    echo
    exit 0
fi

if [[ "$dir" == out ]]; then
    if [[ "$mode" != SESSWIN* ]]; then echo "backward-char"; exit 0; fi
    session="${mode#*$'\t'}"
    echo SESSIONS > "$mode_file"
    echo 0 > "$pwin_file"
    pos=$(bash "$BIN_DIR/coffee-list-sessions.sh" | sed "s/${esc}\[[0-9;]*m//g" |
        sed -e 's/^● //' -e 's/^  //' | cut -f1 | sed 's/[[:space:]]*$//' | grep -nxF -- "$session" | cut -d: -f1)
    pos=${pos:-1}
    printf '%s' "reload-sync(bash $BIN_DIR/coffee-list-sessions.sh)"
    printf '%s' "+change-list-label( sessions )"
    printf '%s' "+transform-header(bash $BIN_DIR/coffee-list-sessions.sh --header)"
    printf '%s' "+change-preview(bash $BIN_DIR/coffee-preview.sh {} $pwin_file)"
    printf '%s' "+pos($pos)"
    printf '%s' "+execute-silent($footer SESSIONS)"
    echo
    exit 0
fi
